function SingleQubitAddressingRAP(varargin)
dic=Dictator.me;
savedata=1;
pulseTime=dic.T674;
pulseAmp=100;
rep=200;


phaselastpulse=pi/2; %0 is sigma y, pi/2 sigmax
MMFreq=21.75;


%%%%% RAP PARAMETERS %%%%%%%
 SweepTime=10:40:1200;

% SweepTime=1:5:100;

RAPWindow=100; % in kHz
DoHalfRAP=0;

DoRAPBack=0;
RAPTime=600;

TimePerStep=0.02; % in microsec
FakeRAP=0; %in case of a Fake RAP, the sweep is done on the opposite side
SweepPower=100; % in %
%%%%% RAP PARAMETERS %%%%%%%%%%%%%%%


% 
% % Reinitialize DDS
% DDSSingleToneInitialization(1,85);DDSSingleToneInitialization(2,3);


dic.setNovatech('Red','amp',0);
dic.setNovatech('Blue','amp',0); %multiply by zero
dic.setNovatech('Parity','amp',0);
dic.setNovatech('Echo','amp',0);

pause(1);
    
%--------options-------------
CrystalCheckPMT;
valid = 0;
%-------------- Set GUI figures ---------------------
InitializeAxes (dic.GUI.sca(1),'Photons #','Cases Counted #','Fluorescence Histogram',...
    [0 dic.maxPhotonsNumPerReadout],[],0);
lines =InitializeAxes (dic.GUI.sca(7),...
    'Sweep Time [\mus]','Dark Counts %','RAP',...
    [SweepTime(1) SweepTime(end)],[0 100],2);
grid(dic.GUI.sca(10),'on');
set(lines(1),'Marker','.','MarkerSize',10,'Color','b');
set(lines(2),'Marker','.','MarkerSize',10,'Color','g');

%-------------- Main function scan loops ---------------------
dark = zeros(size(SweepTime));
fidelity = zeros(size(SweepTime));

countcheck=0;
if dic.SitOnItFlag
    cont=1;
    while (cont)
        if (dic.stop)
            cont=0;
        end
        r=experimentSequence(dic.SinglePass674freq,SweepTime,pulseAmp);
        dic.GUI.sca(1); %get an axis from Dictator GUI to show data
        hist(r,1:1:dic.maxPhotonsNumPerReadout);
        xlabel(num2str(sum( r<dic.darkCountThreshold)/length(r)*100,2),...
            'FontSize',100);
    end
else
    
        set(lines(1),'XData',[],'YData',[]);
        set(lines(2),'XData',[],'YData',[]);
        for index1 = 1:length(SweepTime)
            if dic.stop
                return;
            end
            if countcheck==15
                CrystalCheckPMT;
                countcheck=0;
            else
                countcheck=countcheck+1;
            end
            
            dic.setNovatech('DoublePass','freq',dic.estimateF674+MMFreq/2,'amp',1000);
            
            pause(0.1);
            r=experimentSequence(dic.SinglePass674freq,SweepTime(index1),pulseAmp);%(FreqSinglePass,pulseTime,pulseAmp);
            dic.GUI.sca(1);
            hist(r,1:1:dic.maxPhotonsNumPerReadout);
            if dic.TwoIonFlag
                dark(index1) =100-sum( (r>dic.TwoIonsCountThreshold)*2+...
                    ((r>dic.darkCountThreshold)&(r<dic.TwoIonsCountThreshold))*1 ...
                    )/2/length(r)*100;
                fidelity(index1)=100-sum( (r>dic.TwoIonsCountThreshold)*2+(r<dic.darkCountThreshold)*2)/2/length(r)*100;
            else
                dark(index1) = sum( r<dic.darkCountThreshold)/length(r)*100;
                fidelity(index1)=dark(index1);
            end
            AddLinePoint(lines(1),SweepTime(index1),dark(index1));
            AddLinePoint(lines(2),SweepTime(index1),fidelity(index1));

            
        end

        showData='figure;plot(SweepTime,dark);xlabel(''Pulse Time (mus)''); ylabel(''Dark''); title(''Micromotion Beat Note'');';
        dic.save;
end
%%------------------------ experiment sequence -----------------
    function r=experimentSequence(pFreq,pTime,pAmp)

        prog=CodeGenerator;
        prog.GenDDSPullParametersFromBase;

        % set DDS freq and amp
        prog.GenSeq(Pulse('ExperimentTrigger',0,50));
        % Doppler coolng
        prog.GenSeq(Pulse('OffRes422',0,1));%turn off cooling
        prog.GenSeq(Pulse('OnResCooling',10,dic.Tcooling));
        % update the noiseEater value
        prog.GenSeq([Pulse('674DDS1Switch',0,15,'amp',100),...
            Pulse('NoiseEater674',2,10),Pulse('674DoublePass',0,15),...
            Pulse('Repump1033',15,dic.T1033),...
            Pulse('OpticalPumping',16+dic.T1033,dic.Toptpump)]);
        prog.GenSeq(Pulse('674DDS1Switch',2,-1));

            % experiment based on RAP
            if FakeRAP %if fake RAP, put the window off resonance
                StartFreq=pFreq+RAPWindow/1000/2;
                StopFreq=StartFreq+RAPWindow/1000;
            else
                StartFreq=pFreq-RAPWindow/1000/2;
                if DoHalfRAP
                    StopFreq=StartFreq+RAPWindow/1000/2;
                else
                    StopFreq=StartFreq+RAPWindow/1000;
                end
            end
            prog.GenSeq(Pulse('674DDS1Switch',0,-1,'freq',StartFreq,'phase',0));
            StepFreq=(StopFreq-StartFreq)/(pTime/TimePerStep);
            % set DDS freq and amp
            prog.GenDDSResetPulse;
            prog.GenDDSInitialization(1,2);
            prog.GenDDSFrequencyWord(1,1,StartFreq);
            prog.GenDDSFrequencyWord(1,2,StopFreq);
            prog.GenDDSSweepParameters (1,StepFreq,TimePerStep);
            prog.GenDDSIPower(1,0); prog.GenPause(200);
            prog.GenDDSIPower(1,SweepPower); prog.GenPause(100);
            
            %sweep forward            
            prog.GenDDSFSKState(1,1); 
            prog.GenSeq([Pulse('674DDS1Switch',0,0,'amp',SweepPower),Pulse('674DoublePass',0,0)]);
            prog.GenPause(RAPTime);
            prog.GenPause(10);
            if DoRAPBack
               %sweep backwards
               prog.GenDDSFSKState(1,0);
               prog.GenPause(RAPTime);
            end
            
            % turn 674 off
            prog.GenSeq([Pulse('674DDS1Switch',0,-1,'amp',0),Pulse('674DoublePass',0,-1)]);
            prog.GenDDSFSKState(1,0);
            prog.GenDDSInitialization(1,0);
            
        % detection
        prog.GenSeq([Pulse('OnRes422',0,dic.TDetection) Pulse('PhotonCount',0,dic.TDetection)]);
        % resume cooling
        prog.GenSeq(Pulse('Repump1033',0,dic.T1033));

        prog.GenSeq([Pulse('OffRes422',0,0) Pulse('Repump1092',0,0)]);
        prog.GenFinish;    
        dic.com.UploadCode(prog);
        dic.com.UpdateFpga;
        dic.com.WaitForHostIdle; % wait until host finished it last task
        dic.com.Execute(rep);
        dic.com.WaitForHostIdle;
        r = dic.com.ReadOut(rep);
        r = r(2:end);
    end        
end

