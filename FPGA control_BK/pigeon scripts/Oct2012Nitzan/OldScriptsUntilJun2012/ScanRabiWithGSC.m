function ScanRabiWithGSC(varargin)

dic=Dictator.me;

PulseTime=1:5:300;
detunning =0;
Vmode=1;
%--------options------------- 
for i=1:2:size(varargin,2)
   switch lower(char(varargin(i)))
       case 'mode'
           Vmode=varargin{i+1};
           if Vmode>0
              detunning=-dic.vibMode(Vmode).freq;
           else
              detunning=0; 
           end
       case 'duration'
           PulseTime=varargin{i+1};
   end; %switch
end;%for loop

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
        prog.GenSeq(Pulse('ExperimentTrigger',0,50));
        prog.GenSeq(Pulse('674DDS1Switch',0,-1,'freq',freq,'amp',100));
        % Doppler coolng
        prog.GenSeq(Pulse('OffRes422',0,1));%turn off cooling
        prog.GenSeq(Pulse('OnResCooling',0,dic.Tcooling));
        % continuous GSC 
        mode=1;
        prog.GenSeq([Pulse('NoiseEater674',2,dic.vibMode(mode).coolingTime),...
                     Pulse('674DDS1Switch',2,dic.vibMode(mode).coolingTime,'freq',dic.updateF674+dic.vibMode(mode).freq+dic.acStarkShift674),...
                     Pulse('Repump1033',0,dic.vibMode(mode).coolingTime+dic.T1033),...
                     Pulse('OpticalPumping',0,dic.vibMode(mode).coolingTime+dic.T1033+dic.Toptpump)]);              
        % pulsed GSC  
        prog.GenRepeatSeq([Pulse('NoiseEater674',2,dic.vibMode(mode).coldPiTime),...
                           Pulse('674DDS1Switch',1,dic.vibMode(mode).coldPiTime,'freq',dic.updateF674+dic.vibMode(mode).freq),...
                           Pulse('Repump1033',dic.vibMode(mode).coldPiTime,dic.T1033),...
                           Pulse('OpticalPumping',dic.vibMode(mode).coldPiTime+dic.T1033,dic.Toptpump)],2);                          
 
        %sideband Shelving
        prog.GenSeq([Pulse('NoiseEater674',2,pulseTime),...
                     Pulse('674DDS1Switch',2,pulseTime,'freq',freq)]);
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