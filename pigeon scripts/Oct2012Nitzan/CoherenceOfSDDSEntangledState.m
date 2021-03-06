function CoherenceOfSDDSEntangledState

dic=Dictator.me;

ParityPhase=0:2*pi/30:2*pi;
% WaitTime=[1 10 20 50 100];% in ms
% WaitTime=[0.01 0.1 0.3 0.5 0.7 1];% in ms
WaitTime=[0.5 2 5];% in ms

PhaseForDSSD=5.03;

%GateDetuning=-0.013;
repetitions=50;
%SBoffset=-0.006;
%GateDetuning=0.0128; "working"

ParityTime=3;
% ParityTime=3.2;


ParityAmplitude=500;

SBoffset=-0.000;
% GateDetuning=(22.7+2)/1000; 


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

lines =InitializeAxes (dic.GUI.sca(11),...
    'Gate Phase','Populations %','Parity Scan',...
    [ParityPhase(1) ParityPhase(end)],[-1 1],3);
darkCountLine(1) = lines(1);
fitLine(1) = lines(2);
set(darkCountLine(1),'Marker','.','MarkerSize',10,'Color','b');

darkCountLine(2) = lines(2);
set(darkCountLine(2),'Marker','.','MarkerSize',10,'Color','r');

% darkCountLine(3) = lines(3);
% set(darkCountLine(3),'Marker','.','MarkerSize',10,'Color','k');

lines2 =InitializeAxes (dic.GUI.sca(10),...
    'Time (ms)','Parity Contrast','Coherence decay',...
    [WaitTime(1) WaitTime(end)],[0 1],1);
darkCountLine2(1) = lines2(1);
set(darkCountLine2(1),'Marker','.','MarkerSize',10,'Color','k');


%-------------- main scan loop ---------------------


%f674Span=-0.07:0.007:0.07;
% set(dic.GUI.sca(10),'XLim',[PulseTime(1) PulseTime(end)]);

% darkBank = zeros(length(Vmodes),2,length(PulseTime));
dark=zeros(length(WaitTime),length(ParityPhase));
p0=zeros(length(WaitTime),length(ParityPhase));
p1=zeros(length(WaitTime),length(ParityPhase));
p2=zeros(length(WaitTime),length(ParityPhase));


dic.setNovatech('Red','freq',dic.SinglePass674freq+(dic.vibMode(1).freq-dic.GateInfo.GateDetuningkHz/1000),'amp',dic.GateInfo.RedAmp);
dic.setNovatech('Blue','freq',dic.SinglePass674freq-(dic.vibMode(1).freq-dic.GateInfo.GateDetuningkHz/1000),'amp',dic.GateInfo.BlueAmp);

dic.setNovatech('Red','clock','external','phase',0);
dic.setNovatech('Blue','clock','external','phase',0);

dic.setNovatech('Parity','freq',dic.SinglePass674freq,'amp',ParityAmplitude);
dic.setNovatech('Echo','freq',dic.SinglePass674freq,'phase',PhaseForDSSD,'amp',ParityAmplitude);

if dic.SitOnItFlag
    cont=1;
%     dic.setNovatech('Parity','freq',dic.SinglePass674freq,'phase',2.7,'amp',ParityAmplitude);
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
    for index1=1:length(WaitTime)
            set(lines(2),'XData',[],'YData',[]);
            set(lines(1),'XData',[],'YData',[]);
        for index2 = 1:length(ParityPhase)
            CrystalCheckPMT;
            
            if dic.stop
                return
            end
            dic.setNovatech('DoublePass','freq',dic.updateF674+SBoffset/2,'amp',1000);
            dic.setNovatech('Parity','phase',ParityPhase(index2));
            %         dic.setNovatech('Echo','phase',ParityPhase(index2));
            
            r=experimentSequence(Vmodes,WaitTime(index1)*1000);
            dic.GUI.sca(1); %get an axis from Dictator GUI to show data
            hist(r,0:1:(1.8*dic.maxPhotonsNumPerReadout));
            if dic.TwoIonFlag
                dark(index1,index2) =100-sum( (r>dic.TwoIonsCountThreshold)*2+...
                    ((r>dic.darkCountThreshold)&(r<dic.TwoIonsCountThreshold))*1 ...
                    )/2/length(r)*100;
                %p0(index1)=dark(index1);
                p0(index1,index2)=sum(r<dic.darkCountThreshold)/length(r)*100;
                p2(index1,index2)=sum(r>dic.TwoIonsCountThreshold)/length(r)*100;
                p1(index1,index2)=100-p0(index1,index2)-p2(index1,index2);
            else
                dark(index1,index2) = sum( r<dic.darkCountThreshold)/length(r)*100;
            end
            
            parityt(index2)=(p0(index1,index2)+p2(index1,index2)-p1(index1,index2))/100;
            parity(index1,index2)=(p0(index1,index2)+p2(index1,index2)-p1(index1,index2))/100;
            %         disp(sprintf('%f %f %f %f',p0(index2),p1(index2),p2(index2),parity(index2)));
            AddLinePoint(darkCountLine(1),ParityPhase(index2),parity(index1,index2));
            
%             AddLinePoint(darkCountLine(2),ParityPhase(index2),p0(index1,index2)/100);
%             AddLinePoint(darkCountLine(3),ParityPhase(index2),p2(index1,index2)/100);
            
            pause(0.1);
            %         end
        end
        %             'Lower',[0,0],...
%             'Upper',[1,2*pi],...
        s = fitoptions('Method','NonlinearLeastSquares',...
            'Startpoint',[0.5 0 0]);
        f = fittype('a*sin(2*x-b)+c','options',s);
        [c2,gof2] = fit(ParityPhase',parityt',f);
        ParityContrast(index1)=abs(c2.a);
        disp(sprintf('Parity Contrast = %.3f  Phase Shift = %1.2f  Offset = %.2f',c2.a,c2.b,c2.c));

        set(lines(2),'XData',ParityPhase,'YData',c2(ParityPhase));
        
        AddLinePoint(darkCountLine2(1),WaitTime(index1),ParityContrast(index1));
        pause(2);

    end
end
%------------ Save data ------------------
if (dic.AutoSaveFlag)
    showData='figure;plot(WaitTime,ParityContrast);figure;plot(ParityPhase,p0,''g'',ParityPhase,p1,''b'',ParityPhase,p2,''r'');xlabel(''Gate Time[\mus]'');ylabel(''Populations'');';
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
%         if ParityTime<4
%             prog.GenSeq([Pulse('674DoublePass',0,ParityTime),...
%                          Pulse('674Echo',0,ParityTime)]);
%         else
%             prog.GenSeq([Pulse('674DoublePass',0,ParityTime),...
%                      Pulse('674Echo',0,ParityTime),...
%                      Pulse('NoiseEater674',1,ParityTime-1)]);
%         end
         
%         % TRANSFORM BACK INTO SS+DD

%         
%         prog.GenSeq([Pulse('674DoublePass',3,ParityTime),...
%                          Pulse('674Echo',3,ParityTime)]);
% 
%                      
%         prog.GenSeq([Pulse('674DoublePass',3,ParityTime),...
%                          Pulse('674Echo',3,ParityTime)]);

        prog.GenPause(waittime);
                     
%         prog.GenSeq([Pulse('674DoublePass',3,ParityTime),...
%                          Pulse('674Echo',3,ParityTime)]);
                     
% %         %%%%%%%%%% PARITY ANALYSIS %%%%%%%%%%%%%%%%%%
        if ParityTime<4
            prog.GenSeq([Pulse('674DoublePass',3,ParityTime),...
                         Pulse('674Parity',3,ParityTime)]);
        else
            prog.GenSeq([Pulse('674DoublePass',0,ParityTime),...
                     Pulse('674Parity',0,ParityTime),...
                     Pulse('NoiseEater674',1,ParityTime-1)]);
        end
%         %%%%%%%%%% END OF PARITY ANALYSIS %%%%%%%%%%%%%
         
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