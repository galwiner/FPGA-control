function MolmerSorensenEchoTest

dic=Dictator.me;

% ParityPhase=0:2*pi/40:2*pi;  

repetitions=200;

ParityTime=6;

ParityAmplitude=1000;

SBoffset=0.00;


doEcho=1;
Echostart=dic.GateInfo.GateTime_mus/2;
Echoduration=0.2:0.3:7;
EchoPhase=2.2;
EchoAmplitude=1000;

if ~exist('Vmodes')
    Vmodes = [1];
end
%-------------- Set GUI figures ---------------------
InitializeAxes (dic.GUI.sca(1),'Photons #','Cases Counted #','Fluorescence Histogram',...
                [0 dic.maxPhotonsNumPerReadout],[],0);

lines =InitializeAxes (dic.GUI.sca(7),...
    'Echo Time (mus)','Populations %','Test Echo Pulse',...
    [Echoduration(1) Echoduration(end)],[0 100],3);
darkCountLine(1) = lines(1);
fitLine(1) = lines(2);
set(darkCountLine(1),'Marker','.','MarkerSize',10,'Color','g');

darkCountLine(2) = lines(2);
set(darkCountLine(2),'Marker','.','MarkerSize',10,'Color','r');

darkCountLine(3) = lines(3);
set(darkCountLine(3),'Marker','.','MarkerSize',10,'Color','b');

%-------------- main scan loop ---------------------


%f674Span=-0.07:0.007:0.07;    
% set(dic.GUI.sca(10),'XLim',[PulseTime(1) PulseTime(end)]);

% darkBank = zeros(length(Vmodes),2,length(PulseTime));
dark=zeros(length(Echoduration));
p0=zeros(length(Echoduration));
p1=zeros(length(Echoduration));
p2=zeros(length(Echoduration));

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

    dic.setNovatech('Red','freq',dic.SinglePass674freq+3.1*(dic.vibMode(1).freq-dic.GateInfo.GateDetuningkHz/1000),'amp',dic.GateInfo.RedAmp);
    dic.setNovatech('Blue','freq',dic.SinglePass674freq-3.1*(dic.vibMode(1).freq-dic.GateInfo.GateDetuningkHz/1000),'amp',dic.GateInfo.BlueAmp);
    
    dic.setNovatech('Red','clock','external','phase',0);
    dic.setNovatech('Blue','clock','external','phase',0);
    dic.setNovatech('Echo','freq',dic.SinglePass674freq,'amp',EchoAmplitude,'phase',EchoPhase);
    
    dic.setNovatech('Parity','freq',dic.SinglePass674freq,'amp',ParityAmplitude);
    for index2 = 1:length(Echoduration)
        
        CrystalCheckPMT;
        
        if dic.stop
            return
        end
        dic.setNovatech('DoublePass','freq',dic.updateF674+SBoffset/2,'amp',1000);
        
        r=experimentSequence(Echoduration(index2),Vmodes);
        dic.GUI.sca(1); %get an axis from Dictator GUI to show data
        hist(r,0:1:(1.8*dic.maxPhotonsNumPerReadout));
        if dic.TwoIonFlag
            dark(index2) =100-sum( (r>dic.TwoIonsCountThreshold)*2+...
                ((r>dic.darkCountThreshold)&(r<dic.TwoIonsCountThreshold))*1 ...
                )/2/length(r)*100;
            %p0(index1)=dark(index1);
            p0(index2)=sum(r<dic.darkCountThreshold)/length(r)*100;
            p2(index2)=sum(r>dic.TwoIonsCountThreshold)/length(r)*100;
            p1(index2)=100-p0(index2)-p2(index2);
        else
            dark(index2) = sum( r<dic.darkCountThreshold)/length(r)*100;
        end
        parity(index2)=(p0(index2)+p2(index2)-p1(index2))/100;
%         disp(sprintf('%f %f %f %f',p0(index2),p1(index2),p2(index2),parity(index2)));
        AddLinePoint(darkCountLine(1),Echoduration(index2),p1(index2));
        
        AddLinePoint(darkCountLine(2),Echoduration(index2),p0(index2));
        AddLinePoint(darkCountLine(3),Echoduration(index2),p2(index2));
        
        pause(0.1);
        %         end
    end
end
%------------ Save data ------------------
if (dic.AutoSaveFlag)
    showData='figure;plot(Echoduration,p0,''g'',Echoduration,p1,''b'',Echoduration,p2,''r'');xlabel(''Gate Time[\mus]'');ylabel(''Populations'');';
    dic.save;
end
%--------------------------------------------------------------------
    function r=experimentSequence(echoduration,mode)
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
        
        prog.GenSeq(Pulse('OpticalPumping',0,dic.Toptpump));
                
        
        % Gate Pulse
        prog.GenSeq(Pulse('Repump1092',0,1));
        if doEcho
            % Gate Pulse With Echo Simultaneous in the Gate
%             prog.GenSeq([Pulse('674PulseShaper',1,dic.GateInfo.GateTime_mus-5),...
%                          Pulse('674Echo',Echostart,echoduration),...
%                          Pulse('674Gate',3,dic.GateInfo.GateTime_mus),Pulse('674DoublePass',3,dic.GateInfo.GateTime_mus)]);

        %  Gate Pulse With Echo while Gate beams switched off
        prog.GenSeq([Pulse('674PulseShaper',1,dic.GateInfo.GateTime_mus-5),...
                         Pulse('674Echo',3+Echostart,echoduration),...
                         Pulse('674Gate',3,Echostart),Pulse('674DoublePass',3,dic.GateInfo.GateTime_mus),...
                         Pulse('674Gate',3+Echostart+echoduration,dic.GateInfo.GateTime_mus-Echostart-echoduration)]);
        else
            prog.GenSeq([Pulse('674PulseShaper',1,dic.GateInfo.GateTime_mus-5),...
                         Pulse('674Gate',3,dic.GateInfo.GateTime_mus),Pulse('674DoublePass',3,dic.GateInfo.GateTime_mus)]);            
        end
        
%         prog.GenSeq([Pulse('674DoublePass',6,ParityTime),...
%                      Pulse('674Parity',6,ParityTime)]);
        
        prog.GenSeq(Pulse('Repump1092',0,0));

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