function valid=FreqScan674(varargin)
dic=Dictator.me;
savedata=1;

%  f674List = dic.F674+(-0.3:0.020:0.3);
%  f674List = dic.F674+(-0.04:0.003:0.05);
 
pulseTime=dic.T674;
% pulseTime=5;

pulseAmp=100;
lineNum=3;
if dic.curBeam==0 %674 beam horizontal at 45 deg to axial
    f674List=dic.F674+(-1:0.040:1);
else             %674 beam vertical at 45 deg to axial
    f674List=dic.F674+(-0.1:0.005:0.1); 
    if (lineNum~=3)
        [secondLineFreq,secondLineTime,isOptPumpNeeded]=S2DTransFreqAndPiTime(lineNum);
        f674List=secondLineFreq+(-0.1:0.005:0.1); 
    end
end
%              f674List = 74.5:0.01:75.5;
%f674List = 72.9:0.06:78.55;
% f674List = 76.5:0.03:77.5;

% f674List = 69.8:0.005:70.2;
% f674List = 74.5:0.04:77.5;
% f674List = 75.5:0.03:76.5;

    f674List = 77:0.03:77.2;

% Puts 674 in normal mode
dic.setNovatech4Amp(1,0); ChannelSwitch('DIO7','on');
  
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
lines =InitializeAxes (dic.GUI.sca(3),'F_{674} [MHz]','Dark Counts %','Shelving Line',...
    [f674List(1) f674List(end)],[0 100],2);
set(lines(1),'XData',[],'YData',[],'Marker','.','MarkerSize',10);
set(lines(2),'Color',[0 0 0],'XData',[],'YData',[]);

%-------------- Main function scan loops ---------------------
dark = zeros(size(f674List));
if dic.SitOnItFlag
    cont=1;
    while (cont)
        if (dic.stop)
            cont=0;
        end
        r=experimentSequence(dic.F674,pulseTime,pulseAmp);
        dic.GUI.sca(1); %get an axis from Dictator GUI to show data
        hist(r,1:1:dic.maxPhotonsNumPerReadout);
        xlabel(num2str(sum( r<dic.darkCountThreshold)/length(r)*100,2),...
            'FontSize',100);
    end
else
    for index1 = 1:length(f674List)
        if dic.stop
            return
        end
        r=experimentSequence(f674List(index1),pulseTime,pulseAmp);
        dic.GUI.sca(1);
        hist(r,1:1:dic.maxPhotonsNumPerReadout);
        if dic.TwoIonFlag
            dark(index1) =100-sum( (r>dic.TwoIonsCountThreshold)*2+...
                ((r>dic.darkCountThreshold)&(r<dic.TwoIonsCountThreshold))*1 ...
                )/2/length(r)*100;
        else
            dark(index1) = sum( r<dic.darkCountThreshold)/length(r)*100;
        end
        AddLinePoint(lines(1),f674List(index1),dark(index1))
    end
    %---------- fitting and updating ---------------------
    [peakValue,x0,w,xInterpulated,fittedCurve,isValidFit] = ...
        FitToSincSquared(f674List',dark');
    if (~isValidFit)||(peakValue<=60)||((max(dark)-min(dark))<=60)
        disp('Invalid fit');
    elseif (lineNum==3)
        dic.F674 = x0;
        dic.F674FWHM = 2*0.44295/w;
        dic.DarkMax = peakValue;
        set(lines(2),'XData',xInterpulated,'YData',fittedCurve);
        gca = dic.GUI.sca(3);
        text(f674List(2),0.9*peakValue,{strcat(num2str(round(peakValue)),'%')...
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
        showData='figure;plot(f674List,dark);xlabel(''F_674 [Mhz]'');ylabel(''dark[%]'');';
        saveFileName=fullfile(destDir ,[fileName datestr(now,'-ddmmmyy-HHMMSS')]);
        dicParameters=dic.getParameters;
        save(saveFileName,'f674List','dark','showData','dicParameters','scriptText');
        disp(['Save data in : ' saveFileName]);
    end
end
%%------------------------ experiment sequence -----------------
    function r=experimentSequence(pFreq,pTime,pAmp)
        prog=CodeGenerator;
        prog.GenDDSPullParametersFromBase;

        % set DDS freq and amp
        prog.GenSeq(Pulse('674Switch2NovaTech',0,-1));
        prog.GenSeq(Pulse('674DDS1Switch',2,-1,'freq',pFreq,'amp',pAmp));
        prog.GenSeq(Pulse('ExperimentTrigger',0,50));
        % Doppler coolng
        prog.GenSeq(Pulse('OffRes422',0,1));%turn off cooling
        prog.GenSeq(Pulse('OnResCooling',10,dic.Tcooling));
        % OffResonance/Shelving pulse
        prog.GenSeq(Pulse('OpticalPumping',1,dic.Toptpump));
%         prog.GenSeq([Pulse('674PulseShaper',1,dic.TimeRF-2),...
%                          Pulse('RFDDS2Switch',2,dic.TimeRF)]);
        if (pAmp>50)
            prog.GenSeq([Pulse('NoiseEater674',3,pTime),...
                Pulse('674DDS1Switch',2,pTime)]);
        else
            prog.GenSeq([Pulse('674DDS1Switch',2,pTime)]);
        end
         % detection
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

