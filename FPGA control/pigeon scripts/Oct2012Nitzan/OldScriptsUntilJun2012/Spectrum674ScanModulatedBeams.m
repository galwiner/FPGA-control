function Spectrum674Scan(varargin)
% determine file name
dic=Dictator.me; 
destDir=dic.saveDir;
thisFile=[mfilename('fullpath') '.m' ];
[filePath fileName]=fileparts(thisFile);
saveFileName=fullfile(destDir ,[fileName datestr(now,'-ddmmmyy-HHMMSS')]);

% setting experiments parameters; 
%timeList=dic.T674*40;
%timeList=4.5;
timeList=3.4*20;


% Bring back to normal mode
%dic.setNovatech4Amp(1,0); ChannelSwitch('DIO7','on');
% Puts 674 in MS mode
Amplitude=1000; %max is 1000
dic.setNovatech4Amp(1,Amplitude); ChannelSwitch('DIO7','off');
SBDetuning=1.1; % in MHz
dic.setNovatech4Freq(1,SBDetuning);




% scan around micromotion sideband
FreqMM=str2num(query(dic.KeithUSB1,'Freq?'))/1e6;
%   detuneList=-FreqMM+[-0.05:0.005:0.05];timeList=[700];

%scan around S1/2->D5/2,+5/2 
% detuneList=-dic.FRF/2.802*1.68+[-0.01:0.001:0.01]; timeList=dic.T674*30;

%scan around S1/2->D5/2,-1/2 
% detuneList=2*dic.FRF/2.802*1.68+[-0.05:0.002:0.05]; dic.T674*5;


%scan around S1/2->D5/2,+3/2
% detuneList=[-7.44:0.005:0];

%detuneList=[-1.2:0.01:-0.8];
%detuneList=[-6:0.01:0];
%detuneList=[-3.1:0.1:3.1];
% detuneList=[-2.1:0.03:2.1];
% detuneList=[-1.5:0.03:1.5];
detuneList=[-1.5:0.03:1.5];

%--------options------------- 
for i=1:2:size(varargin,2)
   switch lower(char(varargin(i)))
       case 'freq'
           detuneList=varargin{i+1};
       case 'duration'
           timeList=varargin{i+1};
   end; %switch
end;%for loop
if (dic.SitOnItFlag)
    cont=1;
    while (cont)
        if dic.stp %check stop button without resetting it
            cont=0;
        end
        r=experimentSequence(timeList(1),-21.75);
        r(1) = [];
        pause(0.01);
        dic.GUI.sca(1); %get an axis from Dictator GUI to show data
        hist(r,1:2:dic.maxPhotonsNumPerReadout);
        xlabel(num2str(round(sum(r<dic.darkCountThreshold)/length(r)*100)),'FontSize',250);
    end
    return
end
darkBank=zeros(length(timeList),length(detuneList));
darkCountsLine =InitializeAxes (dic.GUI.sca(9),...
                       'detune [MHz]','Dark Counts %','off resonance shelving',...
                       [detuneList(1) detuneList(end)],[0 100],1);
set(darkCountsLine,'Marker','.','MarkerSize',10);
% measurements loops
for ind1=1:length(timeList)
    set(darkCountsLine,'xdata',[],'ydata',[]);
    disp(sprintf('Pulse time %d',timeList(ind1)));
    for ind2=1:length(detuneList)
        r=experimentSequence(timeList(ind1),detuneList(ind2));
        % Sets 674 in MS mode
        dic.setNovatech4Amp(1,Amplitude); ChannelSwitch('DIO7','off');
        dic.setNovatech4Freq(1,SBDetuning);

        % Plot fluorescence histogram
        dic.GUI.sca(1); %get histogram axes 
        hist(r,0:1:(2.5*dic.maxPhotonsNumPerReadout));
        if dic.TwoIonFlag
            dark =100-sum( (r>dic.TwoIonsCountThreshold)*2+...
                                 ((r>dic.darkCountThreshold)&(r<dic.TwoIonsCountThreshold))*1 ...
                                )/2/length(r)*100;
        else
            dark = sum( r<dic.darkCountThreshold)/length(r)*100;
        end
        darkBank(ind1,ind2)=dark;
        AddLinePoint(darkCountsLine,detuneList(ind2),dark)
        xlabel('detuning [MHz]');
        ylabel('dark counts %');
        pause(0.1);
        savethis;
        stopLoop=dic.stop;
        if stopLoop||~CrystalCheckPMT
           return
        end
    end % Loop 2
end % Loop 1

    function savethis
        if (dic.AutoSaveFlag)
            scriptText=fileread(thisFile);
            scriptText(find(int8(scriptText)==10))='';
            showData='figure;plot(detuneList,darkBank);xlabel(''F_{674} [Mhz]'');ylabel(''dark[%]'');';
            dicParameters=dic.getParameters;
            save(saveFileName,'detuneList','timeList','FreqMM','darkBank','showData','dicParameters','scriptText');
%             disp(['Save data in : ' saveFileName]);
        end
    end
%----------------------------------------------------------------
    function r=experimentSequence(pulseTime,pulseDetune)
        prog=CodeGenerator;
        prog.GenDDSPullParametersFromBase;
        prog.GenSeq(Pulse('ExperimentTrigger',0,50));
        prog.GenSeq(Pulse('674DDS1Switch',0,-1,'amp',100));
        % Doppler coolng
        prog.GenSeq(Pulse('OffRes422',0,1));%turn off cooling
        prog.GenSeq(Pulse('OnResCooling',0,dic.Tcooling));
      
        % OffResonance/Shelving pulse
        prog.GenSeq(Pulse('OpticalPumping',0,dic.Toptpump));        
        prog.GenSeq([Pulse('NoiseEater674',1,pulseTime-2),...
                     Pulse('674DDS1Switch',0,pulseTime,'freq',dic.updateF674+pulseDetune)]);
                 
        % detection
        prog.GenSeq([Pulse('OnRes422',0,dic.TDetection) Pulse('PhotonCount',0,dic.TDetection)]);
        %resume cooling
        prog.GenSeq(Pulse('Repump1033',0,dic.T1033));
        prog.GenSeq(Pulse('OffRes422',0,0));
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

