function valid=FreqScan674(varargin)
dic=Dictator.me;
savedata=1;

%scanVector=(0.9846+(-0.8:0.01:0.1));%[(-0.9846+(-0.2:0.01:0.5))];% (0.9846+(-0.5:0.04:0.2))];

RadialCooling=1;
pulseAmp=100;
%f674List = 80:0.025:81;

if RadialCooling
    pulseTime=dic.T674*35;
    %RSBfreq=2.0094; % radial 1
    RSBfreq=1.138;%1.982%1.138%1.138%1.825;%1.8252; % radial 2
    sidebandLightShift=1.264%2.105%1.21;%1.84; %radial
else
    pulseTime=dic.T674*15;        
    RSBfreq=0.984; % axial
    sidebandLightShift=1.107;%1.0152; %axial
end


BSBfreq=-RSBfreq;
f674=dic.updateF674;
% scanVector=(-0.01:0.0006:0.01);% (0.9846+(-0.5:0.04:0.2))];
%scanVector=(-0.001:0.00001:0.001);
scanVector=(-0.02:0.002:0.02);

blueList = f674+BSBfreq+scanVector;
redList = f674+RSBfreq+scanVector;
f674List=[redList blueList];
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
lines =InitializeAxes (dic.GUI.sca(7),'F_{674} [MHz]','Dark Counts %','Sidebands',...
    [scanVector(1) scanVector(end)],[0 100],2);
set(lines(1),'XData',[],'YData',[],'Marker','.','MarkerSize',10,'Color','b');
set(lines(2),'XData',[],'YData',[],'Marker','.','MarkerSize',10,'Color','r');

%-------------- Main function scan loops ---------------------
dark = zeros(size(f674List));
indx=1;
for index1 = 1:length(redList)
    if dic.stop
        return
    end
    r=experimentSequence(f674List(indx),pulseTime,pulseAmp);
    dic.GUI.sca(1); hist(r,1:1:dic.maxPhotonsNumPerReadout);
    dark(indx) = sum( r<dic.darkCountThreshold)/length(r)*100;
    AddLinePoint(lines(2),scanVector(index1),dark(indx));
    indx=indx+1;
end
for index1 = 1:length(blueList)
    if dic.stop
        return
    end
    r=experimentSequence(f674List(indx),pulseTime,pulseAmp);
    dic.GUI.sca(1); hist(r,1:1:dic.maxPhotonsNumPerReadout);
    dark(indx) = sum( r<dic.darkCountThreshold)/length(r)*100;
    AddLinePoint(lines(1),scanVector(index1),dark(indx));
    indx=indx+1;
end
R=max(dark(length(blueList)+1:end))/max(dark(1:length(blueList)));
estimatedNbar=R/(1-R);
text(0,80,sprintf('R=%.2f',estimatedNbar));
disp(sprintf('R=%.2f, nbar=%.2f',R,estimatedNbar));
%---------- fitting and updating ---------------------
% [peakValue,x0,w,xInterpulated,fittedCurve,isValidFit] = ...
%     FitToSincSquared(scanVector',dark');
% if (~isValidFit)||(peakValue<=60)||((max(dark)-min(dark))<=60)
%     disp('Invalid fit');
% else
%     dic.F674FWHM = 2*0.44295/w;
%     dic.DarkMax = peakValue;
%     set(lines(2),'XData',xInterpulated,'YData',fittedCurve);
%     gca = dic.GUI.sca(3);
%     text(scanVector(2),0.9*peakValue,{strcat(num2str(round(peakValue)),'%')...
%         ,sprintf('%2.3f MHz',x0),sprintf('%d KHz FWHM',round(2*1e3*0.44295/w))})
%     grid on
% 
%     valid=1;
% end
%------------ Save data ------------------
if (dic.AutoSaveFlag&&savedata)
    destDir=dic.saveDir;
    thisFile=[mfilename('fullpath') '.m' ];
    [filePath fileName]=fileparts(thisFile);
    scriptText=fileread(thisFile);
    scriptText(find(int8(scriptText)==10))='';
    showData='figure;plot(scanVector,dark(1:length(scanVector)),''r'',scanVector,dark(length(scanVector)+1:end),''b'');xlabel(''F_674 [Mhz]'');ylabel(''dark[%]'');';
    saveFileName=fullfile(destDir ,[fileName datestr(now,'-ddmmmyy-HHMMSS')]);
    dicParameters=dic.getParameters;
    save(saveFileName,'f674List','scanVector','dark','showData','dicParameters','scriptText');
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
%         prog.GenSeq(Pulse('674DDS1Switch',2,-1,'freq',pFreq,'amp',100));        
        coolingTime=10000;
        prog.GenSeq([Pulse('NoiseEater674',3,coolingTime) ...
            Pulse('674DDS1Switch',2,coolingTime,'amp',100) ...
            Pulse('OpticalPumping',0,coolingTime) ...
            Pulse('Repump1033',0,coolingTime+dic.T1033)]);  
        
%         prog.GenRepeatSeq([Pulse('NoiseEater674',2,pulseTime),...
%                            Pulse('674DDS1Switch',1,pulseTime,'freq',dic.updateF674+RSBfreq),...
%                            Pulse('Repump1033',pulseTime,dic.T1033),...
%                            Pulse('OpticalPumping',pulseTime+dic.T1033,dic.Toptpump)],2);                          

        % optical pumping
        prog.GenSeq(Pulse('OpticalPumping',1,dic.Toptpump));
       % prog.GenPause(4000);
        
        % BSB/RSB last pulse
%         prog.GenSeq(Pulse('674DDS1Switch',2,-1,'freq',dic.updateF674-BSBfreq,'amp',pAmp));

        % waittime
%         prog.GenSeq(Pulse('Shutters',0,0)); %shut down all lasers (takes <=3ms)
%         prog.GenSeq(Pulse('RFDDS2Switch',2,-1,'freq',3.1415*dic.FRF,'amp',0)); %turn off RF
%         prog.GenPause(100); %convert to microseconds
%         prog.GenSeq(Pulse('Shutters',0,-1));%open all lasers (takes <=4ms)
        %prog.GenPause(10000);
%         prog.GenSeq(Pulse('RFDDS2Switch',2,-1,'freq',dic.FRF,'amp',dic.ampRF)); %turn RF back on

        % shelving+detection
        if (pAmp>50)
            prog.GenSeq([Pulse('NoiseEater674',1,pTime),...
                Pulse('674DDS1Switch',0,pTime,'freq',pFreq,'amp',pAmp)]);
        else
            prog.GenSeq([Pulse('674DDS1Switch',2,pTime)]);
        end
        prog.GenSeq([Pulse('OnRes422',0,dic.TDetection) Pulse('PhotonCount',0,dic.TDetection)]);
        %resume cooling
        prog.GenSeq(Pulse('Repump1033',0,dic.T1033));

        prog.GenSeq([Pulse('OffRes422',0,0) Pulse('Repump1092',0,0)]);
        prog.GenFinish;    
        dic.com.UploadCode(prog);
        dic.com.UpdateFpga;
        dic.com.WaitForHostIdle; % wait until host finished it last task
        rep=100;
        dic.com.Execute(rep);
        dic.com.WaitForHostIdle;
        r = dic.com.ReadOut(rep);
        r = r(2:end);
    end
end

