function MolmerSorensenGateAsymDetuning2DScan

dic=Dictator.me;

%  GateTime=1:8:301;  % on COM MODE
%   GateTime=1:24:801;  % on Stretch 
%   GateTime=1:14:1101;  % on Stretch 
 GateTime=1:15:501;  % on Stretch 


%GateDetuning=-0.013;
repetitions=50;
%GateDetuning=0.0128; "working"

% SBoffset=-0.0005;
SBoffset=-0.0025:0.0003:0.0025;
% -0.0005;


% dic.GateInfo.GateDetuningkHz=23.7;

 dic.GateInfo.GateDetuningkHz=19.8;
% dic.GateInfo.GateDetuningkHz=15.8;


doEcho=0;
Echoduration=2.92;
% Echostart=dic.GateInfo.GateTime_mus-Echoduration-10;
% Echostart=dic.GateInfo.GateTime_mus-20;
% Echostart=dic.GateInfo.GateTime_mus/sqrt(2);
Echostart=dic.GateInfo.GateTime_mus/2;

EchoPhase=3.22+3.14/2;
EchoAmplitude=1000;


if ~exist('Vmodes')
    Vmodes = [1];
end
%-------------- Set GUI figures ---------------------
InitializeAxes (dic.GUI.sca(1),'Photons #','Cases Counted #','Fluorescence Histogram',...
                [0 dic.maxPhotonsNumPerReadout],[],0);

lines =InitializeAxes (dic.GUI.sca(7),...
    'Gate Time [mus]','Populations %','Entangling Gate',...
    [GateTime(1) GateTime(end)],[0 100],3);
darkCountLine(1) = lines(1);
fitLine(1) = lines(2);
set(darkCountLine(1),'Marker','.','MarkerSize',10,'Color','b');

darkCountLine(2) = lines(2);
set(darkCountLine(2),'Marker','.','MarkerSize',10,'Color','r');

darkCountLine(3) = lines(3);
set(darkCountLine(3),'Marker','.','MarkerSize',10,'Color','g');

%-------------- main scan loop ---------------------


%f674Span=-0.07:0.007:0.07;
% set(dic.GUI.sca(10),'XLim',[PulseTime(1) PulseTime(end)]);

% darkBank = zeros(length(Vmodes),2,length(PulseTime));
dark=zeros(length(GateTime),length(SBoffset));
p0=zeros(length(GateTime),length(SBoffset));
p1=zeros(length(GateTime),length(SBoffset));
p2=zeros(length(GateTime),length(SBoffset));

if dic.SitOnItFlag
    cont=1;
    while (cont)
        if (dic.stop)
            cont=0;
        end
        dic.setNovatech4Amp(1,1000)
        dic.setNovatech4Amp(2,0);
        
        
        dic.setNovatech4Amp(2,1000);dic.setNovatech4Freq(2,dic.F674);
        dic.setNovatech4Freq(1,Freq674SinglePass-(dic.vibMode(1).freq));
        dic.setNovatech4Freq(0,Freq674SinglePass+(dic.vibMode(1).freq));
        r=experimentSequence(10,1);
        dic.GUI.sca(1); %get an axis from Dictator GUI to show data
        hist(r,0:1:(1.8*dic.maxPhotonsNumPerReadout));
        if dic.TwoIonFlag
            darkf =100-sum( (r>dic.TwoIonsCountThreshold)*2+...
                ((r>dic.darkCountThreshold)&(r<dic.TwoIonsCountThreshold))*1 ...
                )/2/length(r)*100;
        else
            darkf = sum( r<dic.darkCountThreshold)/length(r)*100;
        end
        xlabel(num2str(round(darkf)),'FontSize',100);
    end
else
    
    dic.setNovatech('Red','freq',dic.SinglePass674freq+(dic.vibMode(1).freq-dic.GateInfo.GateDetuningkHz/1000),'amp',dic.GateInfo.RedAmp);
    dic.setNovatech('Blue','freq',dic.SinglePass674freq-(dic.vibMode(1).freq-dic.GateInfo.GateDetuningkHz/1000),'amp',dic.GateInfo.BlueAmp);
    dic.setNovatech('Parity','amp',0);
    dic.setNovatech('Echo','freq',dic.SinglePass674freq,'amp',EchoAmplitude,'phase',EchoPhase);
    
    dic.setNovatech('Parity','clock','external');
    dic.setNovatech('Red','clock','external');
    for index1=1:length(SBoffset)
            
        
        for index2 = 1:length(GateTime)            
            
            CrystalCheckPMT;
            
            if dic.stop
                return
            end
            dic.setNovatech('DoublePass','freq',dic.updateF674+SBoffset(index1)/2,'amp',1000);
            
            r=experimentSequence(GateTime(index2),Vmodes);
            dic.GUI.sca(1); %get an axis from Dictator GUI to show data
            hist(r,0:1:(1.8*dic.maxPhotonsNumPerReadout));
            if dic.TwoIonFlag
                dark(index2) =100-sum( (r>dic.TwoIonsCountThreshold)*2+...
                    ((r>dic.darkCountThreshold)&(r<dic.TwoIonsCountThreshold))*1 ...
                    )/2/length(r)*100;
                %p0(index1)=dark(index1);
                p0(index2,index1)=sum(r<dic.darkCountThreshold)/length(r)*100;
                p2(index2,index1)=sum(r>dic.TwoIonsCountThreshold)/length(r)*100;
                p1(index2,index1)=100-p0(index2,index1)-p2(index2,index1);
            else
                dark(index2,index1) = sum( r<dic.darkCountThreshold)/length(r)*100;
            end
            dic.GUI.sca(7);
            imagesc(SBoffset,GateTime,p0);
            axis([min(SBoffset) max(SBoffset) min(GateTime) max(GateTime)]);
            colorbar;
            xlabel('Asymmetric Detuning( kHz)'); ylabel('GateTime(mus)'); title('P0');
            dic.GUI.sca(6);
            imagesc(SBoffset,GateTime,p1);
            axis([min(SBoffset) max(SBoffset) min(GateTime) max(GateTime)]);
            colorbar;
            xlabel('Asymmetric Detuning( kHz)'); ylabel('GateTime(mus)'); title('P1');
            dic.GUI.sca(11);
            imagesc(SBoffset,GateTime,p2);
            axis([min(SBoffset) max(SBoffset) min(GateTime) max(GateTime)]);
            colorbar;
            xlabel('Asymmetric Detuning( kHz)'); ylabel('GateTime(mus)'); title('P2');
            dic.GUI.sca(4);
            imagesc(SBoffset,GateTime,abs(p2-p0)+p1);
            axis([min(SBoffset) max(SBoffset) min(GateTime) max(GateTime)]);
            colorbar;
            xlabel('Asymmetric Detuning( kHz)'); ylabel('GateTime(mus)'); title('|P2-P0|+P1');            
            %         AddLinePoint(darkCountLine(1),GateTime(index2),p0(index2,index1));
            %         AddLinePoint(darkCountLine(2),GateTime(index2),p2(index2,index1));
            %          AddLinePoint(darkCountLine(3),GateTime(index2),p1(index2,index1));
            pause(0.1);
            %         end
        end
    end
end
%------------ Save data ------------------
if (dic.AutoSaveFlag)
    showData=['figure; imagesc(GateTime,SBoffset,p0(index1,index2)); axis([min(SBoffset) max(SBoffset) min(GateTime) max(GateTime)]);colorbar; ylabel(''Asym Detuning ( kHz)''); xlabel(''GateTime(mus)''); title(''P0'');' ...
            'figure; imagesc(GateTime,SBoffset,p1(index1,index2)); axis([min(SBoffset) max(SBoffset) min(GateTime) max(GateTime)]);colorbar; ylabel(''Asym Detuning (kHz)''); xlabel(''GateTime(mus)''); title(''P1'');' ... 
            'figure; imagesc(GateTime,SBoffset,p2(index1,index2)); axis([min(SBoffset) max(SBoffset) min(GateTime) max(GateTime)]);colorbar; ylabel(''Asym Detuning ( kHz)''); xlabel(''GateTime(mus)''); title(''P2'');'];

    %     showData='figure;plot(GateTime,p0,''g'',GateTime,p1,''b'',GateTime,p2,''r'');xlabel(''Gate Time[\mus]'');ylabel(''Populations'');';
    dic.save;
end
%--------------------------------------------------------------------
    function r=experimentSequence(pulsetime,mode)
        prog=CodeGenerator;
        prog.GenDDSPullParametersFromBase;
%         prog.GenWaitExtTrigger;
        
        prog.GenSeq(Pulse('ExperimentTrigger',0,50));
%         prog.GenWaitExtTrigger;
        
        prog.GenSeq(Pulse('674DDS1Switch',0,-1,'amp',100));
        % Doppler coolng
        prog.GenSeq(Pulse('OffRes422',0,1));%turn off cooling
        prog.GenSeq(Pulse('OnResCooling',0,dic.Tcooling));
        
        prog.GenSeq(Pulse('OpticalPumping',0,dic.Toptpump));
        
        %%%%%%%%%%%%% SIDEBAND COOLING %%%%%%%%%%%%%%%%
        SeqGSC=[]; N=4; Tstart=2;
        Mode2Cool=mode;
        if (~isempty(Mode2Cool))
            for mode=Mode2Cool
                % turn on carrier mode
                SeqGSC=[SeqGSC,Pulse('NoiseEater674',Tstart,dic.vibMode(mode).coolingTime/N),...
                               Pulse('674DoublePass',Tstart,dic.vibMode(mode).coolingTime/N),... 
                               Pulse('674DDS1Switch',Tstart,dic.vibMode(mode).coolingTime/N,...
                                     'freq',dic.SinglePass674freq+dic.vibMode(mode).freq+dic.acStarkShift674)];
                Tstart=2+Tstart+dic.vibMode(mode).coolingTime/N;
            end
            prog.GenSeq([Pulse('Repump1033',0,0), Pulse('OpticalPumping',0,0)]);
            prog.GenRepeatSeq(SeqGSC,N);
            prog.GenSeq([Pulse('Repump1033',dic.T1033,-1), Pulse('OpticalPumping',dic.T1033,-1)]);
            % pulsed GSC
            for mode=fliplr(Mode2Cool)
            prog.GenRepeatSeq([Pulse('NoiseEater674',2,dic.vibMode(mode).coldPiTime),...
                               Pulse('674DoublePass',2,dic.vibMode(mode).coldPiTime),... 
                               Pulse('674DDS1Switch',2,dic.vibMode(mode).coldPiTime,'freq',dic.SinglePass674freq+dic.vibMode(mode).freq),...
                               Pulse('Repump1033',dic.vibMode(mode).coldPiTime,dic.T1033),...
                               Pulse('OpticalPumping',dic.vibMode(mode).coldPiTime+dic.T1033,dic.Toptpump)],2);                          
            end
        end         
        %%%%%%%%%% END OF GROUND STATE COOLING %%%%%%%%%%
%         prog.GenSeq(Pulse('OpticalPumping',0,dic.Toptpump));
%         prog.GenSeq(Pulse('Shutters',0,0)); %shut down all lasers (takes <=3ms)
%         prog.GenPause(4000);
        
        prog.GenSeq(Pulse('OpticalPumping',0,dic.Toptpump));
                
        
        if (doEcho && (pulsetime>Echostart+Echoduration+1))
            % Gate Pulse With Echo Simultaneous in the Gate
%             prog.GenSeq([Pulse('674PulseShaper',1,dic.GateInfo.GateTime_mus-5),...
%                          Pulse('674Echo',Echostart,echoduration),...
%                          Pulse('674Gate',3,dic.GateInfo.GateTime_mus),Pulse('674DoublePass',3,dic.GateInfo.GateTime_mus)]);

        %  Gate Pulse With Echo while Gate beams switched off
        prog.GenSeq([Pulse('674PulseShaper',1,pulsetime-5),...
                         Pulse('674Echo',3+Echostart,Echoduration),...
                         Pulse('674Gate',3,Echostart),Pulse('674DoublePass',3,pulsetime),...
                         Pulse('674Gate',3+Echostart+Echoduration,pulsetime-Echostart-Echoduration)]);
        else
            prog.GenSeq([Pulse('674PulseShaper',1,pulsetime-5),...
                         Pulse('674Gate',3,pulsetime),Pulse('674DoublePass',3,pulsetime)]);            
%             prog.GenSeq([Pulse('674PulseShaper',1,pulsetime+10),...
%                          Pulse('674Gate',10,pulsetime),Pulse('674DoublePass',10,pulsetime)]);            

        end
        prog.GenSeq(Pulse('Repump1092',0,0));
%         prog.GenSeq(Pulse('OpticalPumping',0,dic.Toptpump));
        

%         prog.GenSeq(Pulse('Shutters',0,-1));%open all lasers (takes <=4ms)                        
%         prog.GenPause(4000);
        
        % detection
        prog.GenSeq([Pulse('OnRes422',0,dic.TDetection) Pulse('PhotonCount',0,dic.TDetection)]);
        %resume cooling
        prog.GenSeq(Pulse('Repump1033',0,dic.T1033));
        prog.GenSeq(Pulse('OffRes422',0,0));
        prog.GenFinish;
        
        dic.com.UploadCode(prog);
        dic.com.UpdateFpga;
        dic.com.WaitForHostIdle; % wait until host finished it last task
        dic.com.Execute(repetitions);
        dic.com.WaitForHostIdle;
        r = dic.com.ReadOut(repetitions);
        r = r(2:end);
    end

end