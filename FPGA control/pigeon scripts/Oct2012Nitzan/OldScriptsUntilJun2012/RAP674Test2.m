function RAP674Test

dic=Dictator.me;

% SweepTime=[10 20 100 500 1000 2000 5000]; %in microsec
% RAPWindow=1:10:100; %in kHz
RAPWindow=100; % in kHz
% detuning=-0.1:0.01:0.1;
detuning=0;

% SweepRate=50; %kHz/microsec
%  SweepTime=SweepRate*RAPWindow; % in microsec

SweepTime=1:100:1000; %in microsec

%StepFreq=5; %in kHz
TimePerStep=0.1; % in microsec
StaticKnife=0;
SweepPower=0; % in %
repetitions=4;

% ------------Set GUI axes ---------------
InitializeAxes(dic.GUI.sca(1),'Photons #','Cases Counted #','Fluorescence Histogram',...
                [0 dic.maxPhotonsNumPerReadout],[],0);

lines =InitializeAxes (dic.GUI.sca(5),...
    'SweepTime[\mus]','Dark Counts %','Rabi Scan',...
    [SweepTime(1) SweepTime(end)],[0 100],2);
grid(dic.GUI.sca(5),'on');
set(lines(1),'Marker','.','MarkerSize',10,'Color','b');
set(lines(2),'Marker','.','MarkerSize',10,'Color','r');

% -------- Main function scan loops ------
dark = zeros(size(SweepTime));
for index1 = 1:length(SweepTime)
    if dic.stop
        return
    end
    r=experimentSequence(RAPWindow,SweepTime(index1),dic.F674);
    dic.GUI.sca(1); %get an axis from Dictator GUI to show data
    hist(r,0:1:(1.8*dic.maxPhotonsNumPerReadout));
    if dic.TwoIonFlag
        dark(index1) =100-sum( (r>dic.TwoIonsCountThreshold)*2+...
                             ((r>dic.darkCountThreshold)&(r<dic.TwoIonsCountThreshold))*1 ...
                            )/2/length(r)*100;
    else
        dark(index1) = sum( r<dic.darkCountThreshold)/length(r)*100;
    end
    AddLinePoint(lines(1),SweepTime(index1),dark(index1));
    pause(0.1);
end

% Reinitialize the DDS (should be cleaner)
%DDSSingleToneInitialization(1,85);DDSSingleToneInitialization(2,3);

% %dic.vibMode(1).freq=0.99;
% [Nbar,Omega,y]=fitNbar2CarrierRabi((PulseTime)*1e-6,dark/100,dic.vibMode(1).freq,pi/4);
% disp(sprintf('average n = %.2f  PiTime = %4.2f [mus]',Nbar,2*pi/Omega/4*1e6+0.5));
% set(lines(2),'XData',PulseTime,'YData',y*100);
% % update T674 if the chi square is small
% if mean((y*100-dark).^2)<50
%     dic.T674=2*pi/Omega/4*1e6+0.1;% the 0.5 is a correction 
% rabi=dic.T674;

%--------------- Save data ------------------
if (dic.AutoSaveFlag)
    destDir=dic.saveDir;
    thisFile=[mfilename('fullpath') '.m' ];
    [filePath fileName]=fileparts(thisFile);
    scriptText=fileread(thisFile);
    scriptText(find(int8(scriptText)==10))='';
    showData='figure;plot(SweepTime,dark);xlabel(''Sweep Time[\mus]'');ylabel(''dark[%]'');';
    saveFileName=fullfile(destDir ,[fileName datestr(now,'-ddmmmyy-HHMMSS')]);
    dicParameters=dic.getParameters;
    save(saveFileName,'RAPWindow','SweepTime','detuning','dark','repetitions','showData','dicParameters','scriptText');
    disp(['Save data in : ' saveFileName]);
end 

%--TEST TEST TEST--------------------------------------------------------
    function r=experimentSequence(RAPWindow,sweeptime,freq)
        prog=CodeGenerator;       
        prog.GenDDSPullParametersFromBase;
        
        prog.GenSeq(Pulse('674Switch2NovaTech',0,-1));
        prog.GenSeq(Pulse('ExperimentTrigger',0,50));
        % Doppler coolng
        
        %%%%%%%%%%%
        %% TEST %%%
        %%%%%%%%%%%
        

% %% CA MARCHE         
% prog.GenDDSResetPulse; prog.GenDDSInitialization(1,1);
% prog.GenDDSFrequencyWord(1,1,0.03);
% prog.GenDDSFrequencyWord(1,2,0.8); prog.GenDDSIPower(1,0);
% prog.GenPause(100);
% prog.GenDDSIPower(1,100);
% prog.GenDDSFSKState(1,1); prog.GenPause(125);
% prog.GenDDSFSKState(1,0); prog.GenDDSIPower(1,0);
% %%%%%

% prog.GenDDSResetPulse; prog.GenDDSInitialization(1,4);
% prog.GenDDSSweepParameters (1,1,0.01);
% prog.GenDDSFrequencyWord(1,1,0.03);
% prog.GenDDSFrequencyWord(1,2,0.8); %prog.GenDDSIPower(1,0);
% prog.GenPause(100);
% prog.GenDDSIPower(1,100);
% prog.GenDDSFSKState(1,1); prog.GenPause(100);
% prog.GenDDSFSKState(1,0);  prog.GenPause(50);
% prog.GenDDSIPower(1,0);

%%% CA MARCHE AUSSI !
% prog.GenDDSResetPulse; prog.GenDDSInitialization(1,4);
% prog.GenDDSFrequencyWord(1,1,0.05);
% prog.GenDDSPhaseWord(1,1,0); prog.GenDDSPhaseWord(1,2,pi/2);
% prog.GenDDSFrequencyWord(1,2,0.8); %prog.GenDDSIPower(1,0);
% prog.GenPause(100);
% prog.GenDDSIPower(1,100);
% prog.GenDDSFSKState(1,1); prog.GenPause(50);
% prog.GenDDSFSKState(1,0);  prog.GenPause(50);
% prog.GenDDSIPower(1,0);
%%%%%%%%%%%%%%% 

% prog.GenDDSResetPulse;
prog.GenDDSInitialization(1,2); %prog.GenDDSFSKState(1,1);
prog.GenDDSFrequencyWord(1,1,0.05);
prog.GenDDSFrequencyWord(1,2,0.1);
prog.GenDDSSweepParameters(1,0.01,50);
%prog.GenDDSIPower(1,0); prog.GenPause(100);
prog.GenDDSIPower(1,100);
prog.GenDDSFSKState(1,1);
prog.GenPause(100);prog.GenDDSFSKState(1,0);
prog.GenPause(100);

%%%%%%%%%%%
        %% TEST %%%
        %%%%%%%%%%%

        
        %resume cooling
        prog.GenSeq(Pulse('OffRes422',0,0));
        prog.GenFinish;

        dic.com.UploadCode(prog);
        dic.com.UpdateFpga;
        dic.com.WaitForHostIdle; % wait until host finished it last task
        dic.com.Execute(1);
        dic.com.WaitForHostIdle;
        r = dic.com.ReadOut(1);
%         r = r(2:end);
    end
%--------------------------------------------------------------------
    function r=fin(RAPWindow,sweeptime,freq)
        prog=CodeGenerator;       
        prog.GenDDSPullParametersFromBase;
        
        prog.GenSeq(Pulse('674Switch2NovaTech',0,-1));
        prog.GenSeq(Pulse('ExperimentTrigger',0,50));
        % Doppler coolng
        prog.GenSeq(Pulse('OffRes422',0,500));%turn off cooling
        prog.GenSeq(Pulse('OnResCooling',0,dic.Tcooling) );
        prog.GenSeq(Pulse('674DDS1Switch',0,-1,'freq',freq,'amp',SweepPower));
        
        prog.GenSeq(Pulse('OpticalPumping',10,dic.Toptpump));
        %%%%%%%%%%%
        %% TEST %%%
        %%%%%%%%%%%
        if StaticKnife
            RAPWindow=0;
        end
        
        % if fake RAP, put the window off resonance
        
        StopFreq=freq+RAPWindow/1000/2+detuning;
        StartFreq=freq-RAPWindow/1000/2+detuning;
        
        StepFreq=(RAPWindow/1000)/(sweeptime/TimePerStep);
        % set DDS freq and amp
        %             prog.GenSeq(Pulse('674DDS1Switch',0,-1,'freq',StartFreq,'amp',100));
        prog.GenDDSResetPulse;
        prog.GenDDSInitialization(1,2);
        
        prog.GenDDSFrequencyWord(1,1,StartFreq);
        prog.GenDDSFrequencyWord(1,2,StopFreq);
        prog.GenDDSSweepParameters (1,StepFreq,TimePerStep);

        
        prog.GenDDSIPower(1,0);
        prog.GenWait(1000);
        prog.GenDDSIPower(1,100);
  
        
        prog.GenSeq(Pulse('674DDS1Switch',0,0,'freq',StartFreq,'amp',SweepPower));
        prog.GenDDSFSKState(1,1);
        
        prog.GenPause(sweeptime)
        %%%
        prog.GenSeq(Pulse('674DDS1Switch',0,-1,'freq',freq,'amp',0));
        prog.GenDDSFSKState(1,0);
        
        
         %%%%%%%%%%%
        %% TEST %%%
        %%%%%%%%%%%

        
        %% the big wait
%         waitTimeMs=10;
%         prog.GenSeq(Pulse('Shutters',0,0)); %shut down all lasers (takes <=3ms)
%         prog.GenSeq(Pulse('674DDS1Switch',0,-1,'freq',50,'amp',0)); %turn off 674
%         prog.GenPause((waitTimeMs-4)*1000); %convert to microseconds
%         prog.GenSeq(Pulse('Shutters',0,-1));%open all lasers (takes <=4ms)
%         prog.GenPause(4000);

        %sideband Shelving
%         pulseTime=dic.T674;
%         
%         if (pulseTime>3)
%            prog.GenSeq([Pulse('NoiseEater674',2,pulseTime-2),...
%                         Pulse('674DDS1Switch',0,pulseTime)]);
%         else
%            prog.GenSeq(Pulse('674DDS1Switch',0,pulseTime));
%         end
        
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