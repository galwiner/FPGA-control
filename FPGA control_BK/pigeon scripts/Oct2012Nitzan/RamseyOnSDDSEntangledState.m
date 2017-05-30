function RamseyOnSDDSEntangledState

dic=Dictator.me;

%  WaitTime=[1 5 10 20 50 100]; % in ms
WaitTime=1:2:100; % in ms


repetitions=100;

ParityTime=3;

ParityAmplitude=500;

% PhaseForDSSD=3.86;
PhaseForDSSD=4.9;

DoPrepareDFSState=1;

SBoffset=-0.000;


doEcho=0;
% echostart=100/sqrt(2);
echostart=round(110/sqrt(2));
echoduration=3.3;
% echoduration=0.1;

if ~exist('Vmodes')
    Vmodes = [1];
end
%-------------- Set GUI figures ---------------------
InitializeAxes (dic.GUI.sca(1),'Photons #','Cases Counted #','Fluorescence Histogram',...
                [0 dic.maxPhotonsNumPerReadout],[],0);

if DoPrepareDFSState==0
    panel=11;
else
    panel=10;
end

lines =InitializeAxes (dic.GUI.sca(panel),...
    'Time (ms)','Parity %','Coherence of DFS State',...
    [WaitTime(1) WaitTime(end)],[-1 1],3);
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
dark=zeros(length(WaitTime));
p0=zeros(length(WaitTime));
p1=zeros(length(WaitTime));
p2=zeros(length(WaitTime));


dic.setNovatech('Red','freq',dic.SinglePass674freq+(dic.vibMode(1).freq-dic.GateInfo.GateDetuningkHz/1000),'amp',dic.GateInfo.RedAmp);
dic.setNovatech('Blue','freq',dic.SinglePass674freq-(dic.vibMode(1).freq-dic.GateInfo.GateDetuningkHz/1000),'amp',dic.GateInfo.BlueAmp);

% dic.setNovatech('Red','clock','external','phase',0);
% dic.setNovatech('Blue','clock','external','phase',0);

dic.setNovatech('Parity','freq',dic.SinglePass674freq,'phase',0.6,'amp',ParityAmplitude);
dic.setNovatech('Echo','freq',dic.SinglePass674freq,'phase',PhaseForDSSD,'amp',ParityAmplitude);

if dic.SitOnItFlag
    cont=1;
    dic.setNovatech('Parity','freq',dic.SinglePass674freq,'phase',2.1,'amp',ParityAmplitude);
    while (cont)
        if (dic.stop)
            cont=0;
            return
        end
        dic.setNovatech('DoublePass','freq',dic.updateF674+SBoffset/2,'amp',1000);
        r=experimentSequence(Vmodes);
        dic.GUI.sca(1); %get an axis from Dictator GUI to show data
        hist(r,0:1:(1.8*dic.maxPhotonsNumPerReadout));
        dark=100-sum( (r>dic.TwoIonsCountThreshold)*2+...
            ((r>dic.darkCountThreshold)&(r<dic.TwoIonsCountThreshold))*1 ...
            )/2/length(r)*100;
        %p0(index1)=dark(index1);
        p0=sum(r<dic.darkCountThreshold)/length(r)*100;
        p2=sum(r>dic.TwoIonsCountThreshold)/length(r)*100;
        p1=100-p0-p2;
        disp(sprintf('P0= %f P2= %f P1= %f',p0,p2,p1));  
 
    end
else
    for index2 = 1:length(WaitTime)
        
        CrystalCheckPMT;
        
        if dic.stop
            return
        end
        dic.setNovatech('DoublePass','freq',dic.updateF674+SBoffset/2,'amp',1000);
        
        r=experimentSequence(Vmodes,WaitTime(index2)*1000);
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
        AddLinePoint(darkCountLine(1),WaitTime(index2),parity(index2));
        
%          AddLinePoint(darkCountLine(2),WaitTime(index2),p0(index2)/100);
%          AddLinePoint(darkCountLine(3),WaitTime(index2),p2(index2)/100);
        
        pause(0.1);
        %         end
    end
end
%------------ Save data ------------------
if (dic.AutoSaveFlag)
    showData='figure;plot(WaitTime,p0,''g'',WaitTime,p1,''b'',WaitTime,p2,''r'');xlabel(''Gate Time[\mus]'');ylabel(''Populations'');';
    dic.save;
end
%--------------------------------------------------------------------
    function r=experimentSequence(mode,waittime)
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
                        

        
        % Gate Pulse
        prog.GenSeq(Pulse('Repump1092',0,1));
        if (doEcho && (pulsetime>echostart+echoduration+1))
        else
            prog.GenSeq([Pulse('674PulseShaper',1,dic.GateInfo.GateTime_mus-5),...
                Pulse('674Gate',3,dic.GateInfo.GateTime_mus),Pulse('674DoublePass',3,dic.GateInfo.GateTime_mus)]);
        end
        
        %%%%%%%%%% PREPARATION OF SD+DS STATE %%%%%%%%%%%%%%     
        
        if DoPrepareDFSState==1
            if ParityTime<4
                prog.GenSeq([Pulse('674DoublePass',0,ParityTime),...
                    Pulse('674Echo',0,ParityTime)]);
            else
                prog.GenSeq([Pulse('674DoublePass',0,ParityTime),...
                    Pulse('674Echo',0,ParityTime),...
                    Pulse('NoiseEater674',1,ParityTime-1)]);
            end
        end

        prog.GenPause(waittime);
                     
        prog.GenSeq([Pulse('674DoublePass',3,ParityTime),...
                         Pulse('674Echo',3,ParityTime)]);
                     
% % %         %%%%%%%%%% PARITY ANALYSIS %%%%%%%%%%%%%%%%%%
%         if ParityTime<4
%             prog.GenSeq([Pulse('674DoublePass',3,ParityTime),...
%                          Pulse('674Parity',3,ParityTime)]);
%         else
%             prog.GenSeq([Pulse('674DoublePass',0,ParityTime),...
%                      Pulse('674Parity',0,ParityTime),...
%                      Pulse('NoiseEater674',1,ParityTime-1)]);
%         end
% %         %%%%%%%%%% END OF PARITY ANALYSIS %%%%%%%%%%%%%
         
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