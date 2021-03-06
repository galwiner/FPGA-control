function MolmerSorensenEchoTestGateTimeScanbyParity

dic=Dictator.me;

ParityPhase=3.8;  

repetitions=200;

ParityTime=6;

ParityAmplitude=250;

SBoffset=0.00;


doEcho=1;
% Echoduration=10.8;
Echoduration=9.13;
GateTime=60:5:170;

% Echostart=dic.GateInfo.GateTime_mus-Echoduration-10;

EchoPhase=2.2;
EchoAmplitude=350;

if ~exist('Vmodes')
    Vmodes = [1];
end
%-------------- Set GUI figures ---------------------
InitializeAxes (dic.GUI.sca(1),'Photons #','Cases Counted #','Fluorescence Histogram',...
                [0 dic.maxPhotonsNumPerReadout],[],0);

lines =InitializeAxes (dic.GUI.sca(11),...
    'Echo Time (mus)','Populations %','Looking at Parity Minimum',...
    [GateTime(1) GateTime(end)],[-1 1],3);
darkCountLine(1) = lines(1);
fitLine(1) = lines(2);
set(darkCountLine(1),'Marker','.','MarkerSize',10,'Color','b');

darkCountLine(2) = lines(2);
set(darkCountLine(2),'Marker','.','MarkerSize',10,'Color','r');

darkCountLine(3) = lines(3);
set(darkCountLine(3),'Marker','.','MarkerSize',10,'Color','k');

%-------------- main scan loop ---------------------


%f674Span=-0.07:0.007:0.07;    
% set(dic.GUI.sca(10),'XLim',[PulseTime(1) PulseTime(end)]);

% darkBank = zeros(length(Vmodes),2,length(PulseTime));
dark=zeros(length(GateTime));
p0=zeros(length(GateTime));
p1=zeros(length(GateTime));
p2=zeros(length(GateTime));

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
    
    dic.setNovatech('Red','clock','external','phase',0);
    dic.setNovatech('Blue','clock','external','phase',0);
    dic.setNovatech('Echo','freq',dic.SinglePass674freq,'amp',EchoAmplitude,'phase',EchoPhase);
    
    dic.setNovatech('Parity','freq',dic.SinglePass674freq,'amp',ParityAmplitude);
    for index2 = 1:length(GateTime)
        
        CrystalCheckPMT;
        
        if dic.stop
            return
        end
        dic.setNovatech('DoublePass','freq',dic.updateF674+SBoffset/2,'amp',1000);
        dic.setNovatech('Parity','phase',ParityPhase);
        
        Echostart=GateTime(index2)/2;
       
        r=experimentSequence(GateTime(index2),Vmodes);
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
        AddLinePoint(darkCountLine(1),GateTime(index2),parity(index2));
        
        AddLinePoint(darkCountLine(2),GateTime(index2),p0(index2)/100);
        AddLinePoint(darkCountLine(3),GateTime(index2),p2(index2)/100);
        
        pause(0.1);
        %         end
    end
end
%------------ Save data ------------------
if (dic.AutoSaveFlag)
    showData='figure;plot(GateTime,p0,''g'',GateTime,p1,''b'',GateTime,p2,''r'');xlabel(''Gate Time[\mus]'');ylabel(''Populations'');';
    dic.save;
end
%--------------------------------------------------------------------
    function r=experimentSequence(gatetime,mode)
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
            % Gate Pulse With Echo
            prog.GenSeq([Pulse('674PulseShaper',1,gatetime-5),...
                         Pulse('674Echo',Echostart,Echoduration),...
                         Pulse('674Gate',3,gatetime),Pulse('674DoublePass',3,gatetime)]);
        else
            prog.GenSeq([Pulse('674PulseShaper',1,gatetime),...
                         Pulse('674Gate',3,gatetime),Pulse('674DoublePass',3,gatetime)]);            
        end
        
%         prog.GenSeq([Pulse('NoiseEater674',5,dic.T674/2),...
%                      Pulse('674DoublePass',5,dic.T674/2),...
%                      Pulse('674Parity',3,dic.T674/2)]);
        prog.GenSeq([Pulse('674DoublePass',6,ParityTime),...
                     Pulse('674Parity',6,ParityTime)]);
        
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