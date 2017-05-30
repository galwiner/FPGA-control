function BlueSideBandScanGSCandRAP(varargin)

dic=Dictator.me;

PulseTime=1:15:500;
Vmode=1;
detunning=-dic.vibMode(Vmode).freq;

%%%%%% RAP PARAMETERS %%%%%%%
SweepTime=150;
RAPWindow=300; % in kHz
TimePerStep=0.01; % in microsec
SweepPower=100;
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% %--------options------------- 
% for i=1:2:size(varargin,2)
%    switch lower(char(varargin(i)))
%        case 'mode'
%            Vmode=varargin{i+1};
%            if Vmode>0
%               detunning=-dic.vibMode(Vmode).freq;
%            else
%               detunning=0; 
%            end
%        case 'duration'
%            PulseTime=varargin{i+1};
%    end; %switch
% end;%for loop
% disp(detunning)

%-------------- Set GUI figures ---------------------
InitializeAxes (dic.GUI.sca(1),'Photons #','Cases Counted #','Fluorescence Histogram',...
                [0 dic.maxPhotonsNumPerReadout],[],0);

lines =InitializeAxes (dic.GUI.sca(9),...
    'Pulse Time[\mus]','Dark Counts %','Rabi Scan',...
    [PulseTime(1) PulseTime(end)],[0 100],1);

set(lines(1),'Marker','.','MarkerSize',10,'Color','b');

%-------------- main scan loop ---------------------
dark = zeros(size(PulseTime));
for index1 = 1:length(PulseTime)
    if dic.stop
        return
    end
    r=experimentSequence(PulseTime(index1),dic.updateF674+detunning);
    dic.GUI.sca(1); %get an axis from Dictator GUI to show data
    hist(r,0:1:(1.8*dic.maxPhotonsNumPerReadout));
    if dic.TwoIonFlag
        dark(index1) =100-sum( (r>dic.TwoIonsCountThreshold)*2+...
                             ((r>dic.darkCountThreshold)&(r<dic.TwoIonsCountThreshold))*1 ...
                            )/2/length(r)*100;
    else
        dark(index1) = sum( r<dic.darkCountThreshold)/length(r)*100;
    end
    AddLinePoint(lines(1),PulseTime(index1),dark(index1));
    pause(0.1);
end
%--------------- Save data ------------------
if (dic.AutoSaveFlag)
    destDir=dic.saveDir;
    thisFile=[mfilename('fullpath') '.m' ];
    [filePath fileName]=fileparts(thisFile);
    scriptText=fileread(thisFile);
    showData='figure;plot(PulseTime,dark);xlabel(''Pulse Time[\mus]'');ylabel(''dark[%]'');';
    saveFileName=fullfile(destDir ,[fileName datestr(now,'-ddmmmyy-HHMMSS')]);
    dicParameters=dic.getParameters;
    save(saveFileName,'PulseTime','dark','Vmode','showData','dicParameters','scriptText');
    disp(['Save data in : ' saveFileName]);
end 
% --------------------------------------------------------------------
    function r=experimentSequence(pulseTime,freq)

        prog=CodeGenerator;
        prog.GenDDSPullParametersFromBase;
        prog.GenDDSResetPulse;
        prog.GenSeq(Pulse('ExperimentTrigger',0,50));
        prog.GenSeq(Pulse('674DDS1Switch',0,-1,'freq',freq,'amp',100));
        % Doppler coolng
        prog.GenSeq(Pulse('OffRes422',0,1));%turn off cooling
        prog.GenSeq(Pulse('OnResCooling',0,dic.Tcooling));
                     
         % continuous GSC
        SeqGSC=[]; N=4; Tstart=2;
        Mode2Cool=1;
        if (~isempty(Mode2Cool))
            for mode=Mode2Cool
                SeqGSC=[SeqGSC,Pulse('NoiseEater674',Tstart,dic.vibMode(mode).coolingTime/N),...
                               Pulse('674DDS1Switch',Tstart,dic.vibMode(mode).coolingTime/N,...
                                     'freq',dic.updateF674+dic.vibMode(mode).freq+dic.acStarkShift674)];
                Tstart=2+Tstart+dic.vibMode(mode).coolingTime/N;
            end
            prog.GenSeq([Pulse('Repump1033',0,0), Pulse('OpticalPumping',0,0)]);
            prog.GenRepeatSeq(SeqGSC,N);
            prog.GenSeq([Pulse('Repump1033',dic.T1033,-1), Pulse('OpticalPumping',dic.T1033,-1)]);
            % pulsed GSC
            for mode=fliplr(Mode2Cool)
            prog.GenRepeatSeq([Pulse('NoiseEater674',2,dic.vibMode(mode).coldPiTime),...
                               Pulse('674DDS1Switch',2,dic.vibMode(mode).coldPiTime,'freq',dic.updateF674+dic.vibMode(mode).freq),...
                               Pulse('Repump1033',dic.vibMode(mode).coldPiTime,dic.T1033),...
                               Pulse('OpticalPumping',dic.vibMode(mode).coldPiTime+dic.T1033,dic.Toptpump)],2);                          
            end
        end                                
 
        %sideband Shelving
        %prog.GenSeq([Pulse('NoiseEater674',2,pulseTime),...
        %             Pulse('674DDS1Switch',2,pulseTime,'freq',freq)]);

        %%%%%%%%%%%
        %% RAP %%%%
        %%%%%%%%%%%

        
        StopFreq=freq+RAPWindow/1000/2;
        StartFreq=freq-RAPWindow/1000/2;
        prog.GenSeq(Pulse('674DDS1Switch',0,-1,'freq',StartFreq,'amp',100));
        
        StepFreq=(StopFreq-StartFreq)/(SweepTime/TimePerStep);
        % set DDS freq and amp
        %             prog.GenSeq(Pulse('674DDS1Switch',0,-1,'freq',StartFreq,'amp',100));
        prog.GenDDSResetPulse;
        prog.GenDDSInitialization(1,2);
        prog.GenDDSFrequencyWord(1,1,StartFreq);
        prog.GenDDSFrequencyWord(1,2,StopFreq);
        prog.GenDDSSweepParameters (1,StepFreq,TimePerStep);
        prog.GenDDSIPower(1,0); prog.GenPause(200);
        prog.GenDDSIPower(1,SweepPower); prog.GenPause(100);        
        prog.GenDDSFSKState(1,1);
        prog.GenSeq(Pulse('674DDS1Switch',0,0,'amp',SweepPower));
        prog.GenPause(SweepTime)
        prog.GenSeq(Pulse('674DDS1Switch',0,-1,'amp',0));       
        prog.GenDDSFSKState(1,0);                 
        %%%%% END OF RAP %%%%%%%%%%%%%%
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        
        % detection
        prog.GenSeq([Pulse('OnRes422',0,dic.TDetection) Pulse('PhotonCount',0,dic.TDetection)]);
        %resume cooling
        prog.GenSeq(Pulse('Repump1033',0,dic.T1033));
        prog.GenSeq(Pulse('OffRes422',0,0));
        prog.GenFinish;

        dic.com.UploadCode(prog);
        dic.com.UpdateFpga;
        dic.com.WaitForHostIdle; % wait until host finished it last task
        rep=200;
        dic.com.Execute(rep);
        dic.com.WaitForHostIdle;
        r = dic.com.ReadOut(rep);
        r = r(2:end);
    end

end