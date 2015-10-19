function valid=FreqScan674(varargin)
dic=Dictator.me;
savedata=1;

%scanVector=(0.9846+(-0.8:0.01:0.1));%[(-0.9846+(-0.2:0.01:0.5))];% (0.9846+(-0.5:0.04:0.2))];

scanVector=(1:10:100);%[(-0.9846+(-0.2:0.01:0.5))];% (0.9846+(-0.5:0.04:0.2))];
WaitTimeList = scanVector;

sidebandLightShift=1.855; 

pulseTime=dic.T674*10;
pulseAmp=100;
BSBfreq=-1.8245;
RSBfreq=-BSBfreq;

coolingTime=8000;

%--------options-------------
for i=1:2:size(varargin,2)
    switch lower(char(varargin(i)))
        case 'WaitTime'
            WaitTimeList=varargin{i+1};
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
lines =InitializeAxes (dic.GUI.sca(7),'WaitTime [ms]','Dark Counts  Max %','Sidebands',...
    [scanVector(1) scanVector(end)],[0 100],2);
set(lines(1),'XData',[],'YData',[],'Marker','.','MarkerSize',10);
set(lines(2),'Color',[0 0 0],'XData',[],'YData',[]);

%-------------- Main function scan loops ---------------------
dark = zeros(size(WaitTimeList));
if dic.SitOnItFlag
    cont=1;
    while (cont)
        if (dic.stop)
            cont=0;
        end
        r=experimentSequence(0,pulseTime,pulseAmp);
        dic.GUI.sca(1); %get an axis from Dictator GUI to show data
        hist(r,1:1:dic.maxPhotonsNumPerReadout);
        xlabel(num2str(sum( r<dic.darkCountThreshold)/length(r)*100,2),...
            'FontSize',100);
    end
else
    for index1 = 1:length(WaitTimeList)
        if dic.stop
            return
        end
        r=experimentSequence(WaitTimeList(index1),pulseTime,pulseAmp);
        dic.GUI.sca(1);
        hist(r,1:1:dic.maxPhotonsNumPerReadout);
        if dic.TwoIonFlag
            dark(index1) =100-sum( (r>dic.TwoIonsCountThreshold)*2+...
                ((r>dic.darkCountThreshold)&(r<dic.TwoIonsCountThreshold))*1 ...
                )/2/length(r)*100;
        else
            dark(index1) = sum( r<dic.darkCountThreshold)/length(r)*100;
        end
        AddLinePoint(lines(1),scanVector(index1),dark(index1))
    end
    %---------- fitting and updating ---------------------
    [peakValue,x0,w,xInterpulated,fittedCurve,isValidFit] = ...
        FitToSincSquared(scanVector',dark');
    if (~isValidFit)||(peakValue<=60)||((max(dark)-min(dark))<=60)
        disp('Invalid fit');
    else
        dic.F674FWHM = 2*0.44295/w;
        dic.DarkMax = peakValue;
        set(lines(2),'XData',xInterpulated,'YData',fittedCurve);
        gca = dic.GUI.sca(3);
        text(scanVector(2),0.9*peakValue,{strcat(num2str(round(peakValue)),'%')...
            ,sprintf('%2.3f MHz',x0),sprintf('%d KHz FWHM',round(2*1e3*0.44295/w))})
        grid on

        valid=1;
    end
    %------------ Save data ------------------
    if (dic.AutoSaveFlag&&savedata)
        destDir=dic.saveDir;
        thisFile=[mfilename('fullpath') '.m' ];
        [filePath fileName]=fileparts(thisFile);
        scriptText=fileread(thisFile);
        scriptText(find(int8(scriptText)==10))='';
        showData='figure;plot(scanVector,dark);xlabel(''WaitTime [ms]'');ylabel(''dark[%]'');';
        saveFileName=fullfile(destDir ,[fileName datestr(now,'-ddmmmyy-HHMMSS')]);
        dicParameters=dic.getParameters;
        save(saveFileName,'WaitTimeList','scanVector','dark','showData','dicParameters','scriptText');
        disp(['Save data in : ' saveFileName]);
    end
end
%%------------------------ experiment sequence -----------------
    function r=experimentSequence(WaitTime,pTime,pAmp)
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
        %prog.GenSeq(Pulse('674DDS1Switch',2,-1,'freq',pFreq,'amp',100));        
        prog.GenSeq([Pulse('NoiseEater674',3,coolingTime) ...
            Pulse('674DDS1Switch',2,coolingTime,'amp',100) ...
            Pulse('OpticalPumping',0,coolingTime) ...
            Pulse('Repump1033',1,coolingTime+dic.T1033)]);  

        % optical pumping
        prog.GenSeq(Pulse('OpticalPumping',1,dic.Toptpump));
        % BSB/RSB last pulse
%         prog.GenSeq(Pulse('674DDS1Switch',2,-1,'freq',dic.updateF674-BSBfreq,'amp',pAmp));

        % wait 
         prog.GenPause(WaitTime*1000); %convert to microseconds
%         prog.GenSeq(Pulse('Shutters',0,0)); %shut down all lasers (takes <=3ms)
%         prog.GenSeq(Pulse('RFDDS2Switch',2,-1,'freq',3.1415*dic.FRF,'amp',0)); %turn off RF
%         prog.GenPause((WaitTime-4)*1000); %convert to microseconds
%         prog.GenSeq(Pulse('Shutters',0,-1));%open all lasers (takes <=4ms)
%         prog.GenPause(4000);
%         prog.GenSeq(Pulse('RFDDS2Switch',2,-1,'freq',dic.FRF,'amp',dic.ampRF)); %turn RF back on

        % shelving+detection
        if (pAmp>50)
            prog.GenSeq([Pulse('NoiseEater674',1,pTime),...
                Pulse('674DDS1Switch',0,pTime,'freq',dic.updateF674+RSBfreq,'amp',pAmp)]);
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
        rep=200;
        dic.com.Execute(rep);
        dic.com.WaitForHostIdle;
        r = dic.com.ReadOut(rep);
        r = r(2:end);
    end
end

