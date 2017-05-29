function valid=FreqScan674(varargin)
dic=Dictator.me;
savedata=1;

%scanVector=(0.9846+(-0.8:0.01:0.1));%[(-0.9846+(-0.2:0.01:0.5))];% (0.9846+(-0.5:0.04:0.2))];

RadialCooling=1;

if RadialCooling
    sidebandLightShift=1.2%1.8415;%1.8455; %radial
    RSBfreq=1.141%1.8285;
else
    sidebandLightShift=1.00;%0.9951;%1.0152; %axial
    RSBfreq=0.9846;
end


pulseTime=dic.T674*linspace(0.1,50,20);
pulseAmp=100;
%RSBfreq=1.8262;
BSBfreq=-RSBfreq;

probfreq=BSBfreq;

f674=dic.updateF674;


%--------options-------------
for i=1:2:size(varargin,2)
    switch lower(char(varargin(i)))
        case 'freq'
            f674List=varargin{i+1};
        case 'duration'
            pulseTime=varargin{i+1};
        case 'amp'
            pulseAmp=varargin{i+1};
        case 'save'
            savedata=varargin{i+1};
        case 'deflectorguaging'
            forDeflectorGuaging = varargin{i+1};
    end; %switch
end;%for loop
valid = 0;
%-------------- Set GUI figures ---------------------
InitializeAxes (dic.GUI.sca(1),'Photons #','Cases Counted #','Fluorescence Histogram',...
    [0 dic.maxPhotonsNumPerReadout],[],0);
lines =InitializeAxes (dic.GUI.sca(11),'Time(\mu s)','Dark Counts %','Sidebands',...
    [pulseTime(1) pulseTime(end)],[0 100],2);
set(lines(1),'XData',[],'YData',[],'Marker','.','MarkerSize',10,'Color','b');
set(lines(2),'XData',[],'YData',[],'Marker','.','MarkerSize',10,'Color','r');

%-------------- Main function scan loops ---------------------
dark = zeros(size(pulseTime));
indx=1;
for index1 = 1:length(pulseTime)
    if dic.stop
        return
    end
    r=experimentSequence(f674+probfreq,pulseTime(index1),pulseAmp);
    dic.GUI.sca(1); hist(r,1:1:dic.maxPhotonsNumPerReadout);
    dark(indx) = sum( r<dic.darkCountThreshold)/length(r)*100;
    AddLinePoint(lines(1),pulseTime(index1),dark(indx));
    indx=indx+1;
end
%------------ Save data ------------------
if (dic.AutoSaveFlag&&savedata)
    destDir=dic.saveDir;
    thisFile=[mfilename('fullpath') '.m' ];
    [filePath fileName]=fileparts(thisFile);
    scriptText=fileread(thisFile);
    scriptText(find(int8(scriptText)==10))='';
    showData='figure;plot(pulseTime,dark);xlabel(''Time(\mu s)'');ylabel(''dark[%]'');';
    saveFileName=fullfile(destDir ,[fileName datestr(now,'-ddmmmyy-HHMMSS')]);
    dicParameters=dic.getParameters;
    save(saveFileName,'pulseTime','dark','showData','dicParameters','scriptText');
    disp(['Save data in : ' saveFileName]);
end

%%------------------------ experiment sequence -----------------
    function r=experimentSequence(pFreq,pTime,pAmp)
        prog=CodeGenerator;
        prog.GenDDSPullParametersFromBase;

        % set DDS freq and amp
        prog.GenSeq(Pulse('674Switch2NovaTech',0,-1));
        prog.GenSeq(Pulse('674DDS1Switch',2,-1,'freq',dic.updateF674+sidebandLightShift,'amp',pAmp));
        prog.GenSeq(Pulse('ExperimentTrigger',0,50));
        % Doppler coolng
        prog.GenSeq(Pulse('OffRes422',0,1));%turn off cooling
        prog.GenSeq(Pulse('OnResCooling',10,dic.Tcooling));
        % OffResonance/Shelving pulse
        prog.GenSeq(Pulse('OpticalPumping',1,dic.Toptpump));
%         prog.GenSeq([Pulse('674PulseShaper',1,dic.TimeRF-2),...
%                          Pulse('RFDDS2Switch',2,dic.TimeRF)]);

        %sideband cooling/heating
        coolingTime=8000;
        prog.GenSeq([Pulse('NoiseEater674',3,coolingTime) ...
            Pulse('674DDS1Switch',2,coolingTime,'amp',100) ...
            Pulse('OpticalPumping',0,coolingTime) ...
            Pulse('Repump1033',1,coolingTime+dic.T1033)]);  

        % optical pumping
        prog.GenSeq(Pulse('OpticalPumping',1,dic.Toptpump));
        
        % shelving+detection
        prog.GenSeq([Pulse('NoiseEater674',1,pTime),...
            Pulse('674DDS1Switch',0,pTime,'freq',pFreq,'amp',pAmp)]);
        prog.GenSeq([Pulse('OnRes422',0,dic.TDetection) Pulse('PhotonCount',0,dic.TDetection)]);
        
        %resume cooling
        prog.GenSeq(Pulse('Repump1033',0,dic.T1033));
        prog.GenSeq([Pulse('OffRes422',0,0) Pulse('Repump1092',0,0)]);
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

