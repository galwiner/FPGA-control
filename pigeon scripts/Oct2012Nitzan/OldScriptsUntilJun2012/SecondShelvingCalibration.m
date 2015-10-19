function valid=T1(varargin)
dic=Dictator.me;

%recall double shelving line parameters
[secondFreq secondPulseTime]=S2DTransFreqAndPiTime(1);

%set filename information
destDir=dic.saveDir;
thisFile=[mfilename('fullpath') '.m' ];
[filePath fileName]=fileparts(thisFile);
scriptText=fileread(thisFile);
saveFileName=fullfile(destDir ,[fileName datestr(now,'-ddmmmyy-HHMMSS')]);

% main variables
waitTime=1;%[100 500 linspace(1000,10000,3)]; %in milli-seconds
%secondPulseTimes=secondPulseTime;
secondPulseTimes=linspace(0,100,100); 

ExpRepetitions=100;
ExpChunkSize=20;
% repeat the experiment a total of ExpRepetitions, in ExpChunkSize repetitions
% each time
N=floor(ExpRepetitions/ExpChunkSize);
out=zeros(N,ExpChunkSize,2,length(secondPulseTimes),length(waitTime));
progress=zeros(size(out));
stamp=zeros(N,4); %keep track of the time stamp and the dictator variables

% set silent mode (no graph printing)
silent=1;
%-------------- Set GUI figures ---------------------
if ~silent
    InitializeAxes (dic.GUI.sca(1),'Photons #','Cases Counted #','Fluorescence Histogram',...
        [0 dic.maxPhotonsNumPerReadout],[],0);
    lines =InitializeAxes (dic.GUI.sca(9),'shelving time (ms)','Dark Counts %','Shelving prob',...
        [secondPulseTimes(1) secondPulseTimes(end)],[0 100],2);
    set(lines(1),'XData',[],'YData',[],'Marker','.','MarkerSize',10);
end
%-------------- SitOnIt - to tune the delay of shutters ----------------

if (dic.SitOnItFlag)
    cont=1;
    while (cont)
        if (dic.stop)
            cont=0;
        end
        r=shutterExperimentSequence(1,10);
        pause(0.01);       
        cont=0;
    end
    return;
end
%-------------- Main function scan loops ---------------------

savetimerOnOffFlag=dic.timerOnOffFlag;
dic.timerOnOffFlag=0;
startTime=now;
ResetStopFile;
disp('----------------------------------------------');
for iteration=1:N
    disp(sprintf('Iteration %d',iteration));
    for index1 = 1:length(waitTime)
        for index2=1:length(secondPulseTimes)
            if IsStop
                disp('Run stopped by User!');
                disp('----------------------------------------------');
                return;
            end
            secondPulseTime=secondPulseTimes(index2);
            r=experimentSequence(ExpChunkSize,waitTime(index1),0);
            out(iteration,:,1,index2,index1)=r; %measure up
            progress(iteration,:,1,index1)=ones(1,ExpChunkSize)*100;
            r=experimentSequence(ExpChunkSize,waitTime(index1),1);
            out(iteration,:,2,index2,index1)=r; %measure down
            progress(iteration,:,2,index2,index1)=ones(1,ExpChunkSize)*100;
            stamp(iteration,:)=[now,dic.FRF,dic.TimeRF,dic.F674];
            progpercent=mean(reshape(progress,1,[]));
            fprintf('%.1f %% (%.2f min2go)',progpercent,24*60*(now-startTime)/progpercent*(100-progpercent));
            if ~(silent)
                dic.GUI.sca(1);
                hist(r,1:2:dic.maxPhotonsNumPerReadout);
                 AddLinePoint(lines(1),waitTime(index1),dark(index1));
            end
            savedata;
        end       
    end
end

fprintf('avg dark=%.2f\n',mean(reshape(out,1,[])<8)*100);
dic.timerOnOffFlag=savetimerOnOffFlag;
%------------ Save data ------------------

function savedata    
    if (dic.AutoSaveFlag)
%          showData='figure; cla; darkUp=mean(reshape(out(1:iteration,:,1,1,:),ExpChunkSize*iteration,[])<8)*100; darkDown=mean(reshape(out(1:iteration,:,2,1,:),ExpChunkSize*iteration,[])<8)*100; plot(waitTime,darkUp,''xb-'',waitTime,darkDown,''or-'');xlabel(''wait time(mili sec)'');ylabel(''dark[%]''); title(''Shelving %%'');';
        showData='figure; cla; darkUp=mean(reshape(out(1:iteration,:,1,:,1),ExpChunkSize*iteration,[])<8)*100; darkDown=mean(reshape(out(1:iteration,:,2,:,1),ExpChunkSize*iteration,[])<8)*100; plot(secondPulseTimes,darkUp,''xb-'',secondPulseTimes,darkDown,''or-'');xlabel(''Shelving time(microsec)'');ylabel(''dark[%]''); title(sprintf(''Shelving [%.2f completed]'',progpercent));';
        dicParameters=dic.getParameters;
        save(saveFileName,'progpercent','waitTime','out','iteration','ExpChunkSize','N','index1','showData','dicParameters','scriptText','secondPulseTimes');
        disp(['Save data in : ' saveFileName]);
    end
end

%------------------------ experiment sequence -----------------
    function r=experimentSequence(rep,waitTimeMs,measDown)
        prog=CodeGenerator;
        prog.GenDDSPullParametersFromBase;
        % set DDS freq and amp
        prog.GenSeq(Pulse('674DDS1Switch',2,-1,'freq',dic.updateF674,'amp',100));
        prog.GenSeq(Pulse('Repump1033',0,dic.T1033));

        prog.GenSeq(Pulse('ExperimentTrigger',0,50));
        % Doppler coolng
        prog.GenSeq(Pulse('OffRes422',0,1));%turn off cooling
        prog.GenSeq(Pulse('OnResCooling',0,dic.Tcooling));
        prog.GenSeq(Pulse('OpticalPumping',1,dic.Toptpump));
%         prog.GenRepeatSeq([Pulse('674DDS1Switch',2,12,'freq',dic.updateF674-0.4*dic.FRF),...
%                            Pulse('Repump1033',17,dic.T1033)],2);
%         % prepare initial state in down
%         prog.GenSeq([Pulse('674PulseShaper',2,dic.TimeRF-1),...
%                      Pulse('RFDDS2Switch',3,dic.TimeRF,'phase',0)]); 
        
        % the big wait
        prog.GenSeq(Pulse('Shutters',0,0)); %shut down all lasers (takes <=3ms)
        prog.GenSeq(Pulse('RFDDS2Switch',2,-1,'freq',3.1415*dic.FRF,'amp',0)); %turn off RF
        prog.GenPause((waitTimeMs-4)*1000); %convert to microseconds
        prog.GenSeq(Pulse('Shutters',0,-1));%open all lasers (takes <=4ms)
        prog.GenPause(4000);
        prog.GenSeq(Pulse('RFDDS2Switch',2,-1,'freq',dic.FRF,'amp',dic.ampRF)); %turn RF back on
        
        % measure down instead of up
        if (measDown)
            prog.GenSeq([Pulse('674PulseShaper',2,dic.TimeRF-1),...
                     Pulse('RFDDS2Switch',3,dic.TimeRF,'phase',0)]); 
        end
        % first Shelving pulse
        %prog.GenSeq([Pulse('NoiseEater674',1,dic.T674-2),...
        %             Pulse('674DDS1Switch',0,dic.T674,'freq',dic.updateF674)]);
        
        % second Shelving pulse
%         secondPulseTime=50; %for BSB -0.9852
        prog.GenSeq([Pulse('NoiseEater674',1,secondPulseTime-2) ...
            Pulse('674DDS1Switch',0,secondPulseTime,'freq',secondFreq)]);
       
        % detection
        prog.GenSeq([Pulse('OnRes422',0,dic.TDetection) Pulse('PhotonCount',0,dic.TDetection)]);
        %resume cooling
        prog.GenSeq(Pulse('Repump1033',0,dic.T1033));
        prog.GenSeq([Pulse('OffRes422',0,0) Pulse('Repump1092',0,0)]);
%         prog.GenPause(1000);
        prog.GenFinish;    
        dic.com.UploadCode(prog);
        dic.com.UpdateFpga;
        dic.com.WaitForHostIdle; % wait until host finished it last task
        dic.com.Execute(rep);
        dic.com.WaitForHostIdle;
        r = dic.com.ReadOut(rep);
        %r = r(2:end);
    end
%------------------------ experiment sequence for tuning shutter -------
function r=shutterExperimentSequence(rep,waitTimeMs)
        prog=CodeGenerator;
        prog.GenDDSPullParametersFromBase;
        % set DDS freq and amp
        prog.GenSeq(Pulse('674DDS1Switch',2,-1,'freq',dic.updateF674,'amp',100));
        prog.GenSeq(Pulse('Repump1033',0,dic.T1033));

        prog.GenSeq(Pulse('ExperimentTrigger',0,50));
        
        prog.GenSeq([Pulse('OffRes422',0,-1) Pulse('674DDS1Switch',0,-1) Pulse('OpticalPumping',0,-1)]);%turn off cooling
        prog.GenPause(2500); 
        prog.GenSeq([Pulse('OffRes422',0,0) Pulse('674DDS1Switch',0,0) Pulse('OpticalPumping',0,0)]);%turn on cooling
        prog.GenPause(5000); 
        %prog.GenSeq(Pulse('OnResCooling',0,dic.Tcooling));
        %prog.GenSeq(Pulse('OpticalPumping',1,dic.Toptpump));
%         prog.GenRepeatSeq([Pulse('674DDS1Switch',2,12,'freq',dic.updateF674-0.4*dic.FRF),...
%                            Pulse('Repump1033',17,dic.T1033)],2);

        % the big wait
        prog.GenSeq(Pulse('Shutters',0,0));
        prog.GenPause(10000); %convert to microseconds
        prog.GenSeq(Pulse('Shutters',0,-1));
        prog.GenPause(5000); %convert to microseconds
        prog.GenSeq([Pulse('OffRes422',0,1) Pulse('674DDS1Switch',0,1) Pulse('OpticalPumping',0,1)]);%turn off cooling
        prog.GenPause(2500); 
         % first Shelving pulse
        prog.GenSeq([Pulse('NoiseEater674',1,dic.T674-2),...
                     Pulse('674DDS1Switch',0,dic.T674,'freq',dic.updateF674)]);
        % second Shelving pulse
        % secondPulseTime=50; %for BSB
        prog.GenSeq([Pulse('NoiseEater674',1,secondPulseTime-2) ...
            Pulse('674DDS1Switch',0,secondPulseTime,'freq',secondFreq)]);
        
        % detection
        prog.GenSeq([Pulse('OnRes422',0,dic.TDetection) Pulse('PhotonCount',0,dic.TDetection)]);
        %resume cooling
        prog.GenSeq(Pulse('Repump1033',0,dic.T1033));
        prog.GenSeq([Pulse('OffRes422',0,0) Pulse('Repump1092',0,0)]);
        prog.GenWait(1000);
        prog.GenFinish;    
        dic.com.UploadCode(prog);
        dic.com.UpdateFpga;
        dic.com.WaitForHostIdle; % wait until host finished it last task
        dic.com.Execute(rep);
        dic.com.WaitForHostIdle;
        r = dic.com.ReadOut(rep);
        %r = r(2:end);
    end
end

