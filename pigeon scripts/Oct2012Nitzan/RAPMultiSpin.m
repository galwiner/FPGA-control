function RAPMultiSpin(varargin)
dic=Dictator.me;
savedata=1;
pulseTime=dic.T674;
pulseAmp=100;
rep=100;

SlowPiTime=46;

phaselastpulse=pi/2; %0 is sigma y, pi/2 sigmax
MMFreq=dic.MMFreq;


DDSToUse=1; % 1 is 674 ; 2 is the one for RF (temporarily on double pass)

%%%%% RAP PARAMETERS %%%%%%%
%   SweepTime=(1:5:200);
  SweepTime=(1:40:1500);
%  SweepTime=(1:600:10000);



% RAPWindow=80; % in kHz
RAPWindow=80; % in kHz
DoStopFreqScan=0;
if DoStopFreqScan==1
    StopRAPFrequency=-RAPWindow/4:RAPWindow/100:RAPWindow/4;
    ScanParameter=StopRAPFrequency;
else
    ScanParameter=SweepTime;
end

if DoStopFreqScan==0
    DoHalfRAP=[0 1]; DeltaCentralFreq=0; %kHz
else
    DoHalfRAP=0; DeltaCentralFreq=0; %kHz
end
DoRAPBack=0;
RAPTime=500;

RAPonMM=1;
TimePerStep=0.1; % in microsec
FakeRAP=0; %in case of a Fake RAP, the sweep is done on the opposite side
SweepPower=100; % in %% RAPWindow=80; % in kHz
EchoAmp=80;%50;

SpinLockTest=0;
%SpinLockWait=500; %Wait Time in the equatorial plane
if SpinLockTest==1    
    xaxisplot='Spin-Lock Wait Time (mus)';
elseif DoStopFreqScan==1
    xaxisplot='Stop Frequency Detuning (kHz)';
else
    xaxisplot='Sweep Time (mus)';
end
%%%%% RAP PARAMETERS %%%%%%%%%%%%%%%

if DoRAPBack==1
    PanelNumber=6;
else
    PanelNumber=4;
end

%
% % Reinitialize DDS
% DDSSingleToneInitialization(1,85);DDSSingleToneInitialization(2,3);


dic.setNovatech('Red','amp',0);
dic.setNovatech('Blue','amp',0); %multiply by zero
dic.setNovatech('Parity','freq',dic.SinglePass674freq+dic.MMFreq,'amp',0);
dic.setNovatech('Echo','amp',0);
dic.setNovatech('DoublePass','freq',dic.updateF674,'amp',1000);

pause(1);

%--------options-------------
CrystalCheckPMT;
valid = 0;
%-------------- Set GUI figures ---------------------
InitializeAxes (dic.GUI.sca(1),'Photons #','Cases Counted #','Fluorescence Histogram',...
    [0 dic.maxPhotonsNumPerReadout],[],0);
lines =InitializeAxes (dic.GUI.sca(PanelNumber),...
    xaxisplot,'Dark Counts %','RAP',...
    [ScanParameter(1) ScanParameter(end)],[0 100],2);
grid(dic.GUI.sca(10),'on');
set(lines(1),'Marker','.','MarkerSize',10,'Color','b');
set(lines(2),'Marker','.','MarkerSize',10,'Color','g');

%-------------- Main function scan loops ---------------------
dark = zeros(size(ScanParameter));
fidelity = zeros(size(ScanParameter));

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
    
    for index1 = 1:length(ScanParameter)
        
        for index2 = 1:length(DoHalfRAP)
            if dic.stop
                DDSSingleToneInitialization(1,dic.SinglePass674freq);DDSSingleToneInitialization(2,dic.F674/2);
                return;
            end
            if countcheck==15
                CrystalCheckPMT;
                countcheck=0;
            else
                countcheck=countcheck+1;
            end
            
             dic.setNovatech('Parity','amp',1000);

            if DDSToUse==1
                dic.setNovatech('DoublePass','freq',dic.estimateF674+RAPonMM*MMFreq/2,'amp',1000);
            else
                dic.setNovatech('DoublePass','amp',0);
                dic.setNovatech('Echo','freq',dic.SinglePass674freq,'amp',EchoAmp);
            end
            
            pause(0.1);
            if DDSToUse==1
                FreqToRAP=dic.SinglePass674freq; %RAP on Single Pass
            else
                % notice the factor 1/2, because of the multipler after the DDS
                FreqToRAP=(dic.estimateF674+RAPonMM*MMFreq/2)/2; % RAP on Double Pass
            end
            if DoStopFreqScan==0
                r=experimentSequence(FreqToRAP,ScanParameter(index1)*(1-0.5*DoHalfRAP(index2)),pulseAmp,DoHalfRAP(index2),0);%(FreqSinglePass,pulseTime,pulseAmp);
            else
                r=experimentSequence(FreqToRAP,RAPTime*(1-0.5*DoHalfRAP(index2)),pulseAmp,DoHalfRAP(index2),ScanParameter(index1));%(FreqSinglePass,pulseTime,pulseAmp);
            end
            dic.GUI.sca(1);
            hist(r,1:1:dic.maxPhotonsNumPerReadout);
            if dic.TwoIonFlag
                dark(index1) =100-sum( (r>dic.TwoIonsCountThreshold)*2+...
                    ((r>dic.darkCountThreshold)&(r<dic.TwoIonsCountThreshold))*1 ...
                    )/2/length(r)*100;
%                 fidelity(index1)=100-sum( (r>dic.TwoIonsCountThreshold)*2+(r<dic.darkCountThreshold)*2)/2/length(r)*100;
                 fidelity(index1)=sum((r>dic.darkCountThreshold)&(r<dic.TwoIonsCountThreshold))/length(r)*100;

            else
                dark(index1) = sum( r<dic.darkCountThreshold)/length(r)*100;
                fidelity(index1)=dark(index1);
            end
            AddLinePoint(lines(index2),ScanParameter(index1),dark(index1));
            %         AddLinePoint(lines(2),SweepTime(index1),fidelity(index1));
            
        end
    end
    DDSSingleToneInitialization(1,dic.SinglePass674freq);DDSSingleToneInitialization(2,dic.F674/2);
    dic.setNovatech('Echo','amp',0);
    
    showData='figure;plot(ScanParameter,dark);xlabel(''Pulse Time (mus)''); ylabel(''Dark''); title(''Micromotion Beat Note'');';
    dic.save;
end
%%------------------------ experiment sequence -----------------
    function r=experimentSequence(pFreq,pTime,pAmp,dohalfRAP,stopfreqdetuning)
        
        prog=CodeGenerator;
        prog.GenDDSPullParametersFromBase;
        
        % set DDS freq and amp
        prog.GenSeq(Pulse('ExperimentTrigger',0,50));
        % Doppler coolng
        prog.GenSeq(Pulse('OffRes422',0,1));%turn off cooling
        prog.GenSeq(Pulse('OnResCooling',10,dic.Tcooling));
        % update the noiseEater value
        
%         prog.GenSeq(Pulse('674PulseShaper',0,0));
        if DDSToUse==1            
            prog.GenSeq([Pulse('674DDS1Switch',0,15,'amp',100),...
                Pulse('NoiseEater674',2,10),Pulse('674DoublePass',0,15),...
                Pulse('Repump1033',15,dic.T1033),...
                Pulse('OpticalPumping',16+dic.T1033,dic.Toptpump)]);
            prog.GenSeq(Pulse('674DDS1Switch',2,-1));
        else
            prog.GenSeq([Pulse('RFDDS2Switch',0,15,'amp',100),...
                Pulse('NoiseEater674',2,10),Pulse('674DoublePass',0,15),Pulse('674Echo',0,15),...
                Pulse('Repump1033',15,dic.T1033),...
                Pulse('OpticalPumping',16+dic.T1033,dic.Toptpump)]);
            prog.GenSeq(Pulse('674DDS1Switch',2,-1));
        end
%         prog.GenSeq(Pulse('674PulseShaper',0,1));
       
        % experiment based on RAP
        if FakeRAP==1 %if fake RAP, put the window off resonance
            StartFreq=pFreq+RAPWindow/1000/2;
            StopFreq=StartFreq+RAPWindow/1000;
        else
            StartFreq=pFreq-RAPWindow/1000/2;
            if dohalfRAP==1
                StopFreq=pFreq-DeltaCentralFreq/1000+0*StartFreq;
            else
                if DoStopFreqScan==1
                    StopFreq=pFreq+(stopfreqdetuning)/1000;
                else
                    StopFreq=StartFreq+RAPWindow/1000;
                end
            end
        end
        
        
        if DDSToUse==1
            prog.GenSeq(Pulse('674DDS1Switch',0,-1,'freq',StartFreq,'phase',0));
        else
            prog.GenSeq(Pulse('RFDDS2Switch',0,-1,'phase',0));
        end
        if SpinLockTest==0
            StepFreq=(StopFreq-StartFreq)/(pTime/TimePerStep);
        else
            StepFreq=(StopFreq-StartFreq)/(RAPTime/TimePerStep);
        end
                
        % set DDS freq and amp
        % prog.GenDDSResetPulse;
        prog.GenDDSInitialization(DDSToUse,2);
        prog.GenDDSFrequencyWord(DDSToUse,1,StartFreq);
        prog.GenDDSFrequencyWord(DDSToUse,2,StopFreq);
        prog.GenDDSSweepParameters (DDSToUse,StepFreq,TimePerStep);
        prog.GenDDSIPower(DDSToUse,0); prog.GenPause(200);
%         prog.GenDDSIPower(DDSToUse,0*SweepPower); prog.GenPause(100);

        % Transfer all ions into dark state.
%         prog.GenSeq([Pulse('674DDS1Switch',0,SlowPiTime,'amp',100),Pulse('674DoublePass',0,SlowPiTime),Pulse('674Parity',0,SlowPiTime)]);

        if DDSToUse==1
            prog.GenSeq([Pulse('674DDS1Switch',0,0,'amp',SweepPower),Pulse('674DoublePass',0,0)]);
        else            
            prog.GenSeq([Pulse('RFDDS2Switch',0,0,'amp',100),Pulse('674DoublePass',0,0),Pulse('674Echo',0,0)]);
        end
        
        %         prog.GenDDSIPower(DDSToUse,100); prog.GenPause(50);
        if DDSToUse==2
            for j=1:5
                prog.GenDDSIPower(DDSToUse,floor(j/10*SweepPower)+50); prog.GenPause(50);
            end
        else
%             for j=1:5
%                 prog.GenDDSIPower(DDSToUse,floor(j/5*SweepPower)); prog.GenPause(50);
%             end
        end
        %sweep forward
        prog.GenDDSFSKState(DDSToUse,1);
        
        if SpinLockTest==0
            prog.GenPause(pTime);
        else
            prog.GenPause(RAPTime);
        end
        %         prog.GenPause(200);
        
        if DoRAPBack
            % WaitTime in the equatorial plane;
            if (SpinLockTest==1) && (pTime>0)
                prog.GenPause(pTime);
            end
            %sweep backwards
            prog.GenDDSFSKState(DDSToUse,0);
            
            if SpinLockTest==0 
                prog.GenPause(pTime);
            else
                prog.GenPause(RAPTime);
            end
        end
        
        if DDSToUse==2
            for j=5:-1:1
                prog.GenDDSIPower(DDSToUse,floor(j/10*SweepPower)+50); prog.GenPause(50);
            end
        else
%             for j=5:-1:1
%                 prog.GenDDSIPower(DDSToUse,floor(j/5*SweepPower)); prog.GenPause(50);
%             end            
        end
        % turn 674 off
        if DDSToUse==1
            prog.GenSeq([Pulse('674DDS1Switch',0,-1,'amp',0),Pulse('674DoublePass',0,-1)]);
        else
            prog.GenSeq([Pulse('RFDDS2Switch',0,-1,'amp',SweepPower),Pulse('674DoublePass',0,-1),Pulse('674Echo',0,-1)]);
        end
        prog.GenDDSFSKState(DDSToUse,0);
        
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

