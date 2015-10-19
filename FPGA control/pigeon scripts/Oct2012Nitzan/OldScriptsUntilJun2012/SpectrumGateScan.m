function Spectrum674Scan(varargin)
% setting experiments parameters; 
dic=Dictator.me;
% noiseEater=0.5V
detuneList=-2.5:0.025:2.5;
timeList=[150];
%--------options------------- 
for i=1:2:size(varargin,2)
   switch lower(char(varargin(i)))
       case 'freq'
           detuneList=varargin{i+1};
       case 'duration'
           timeList=varargin{i+1};
   end; %switch
end;%for loop

darkBank=zeros(length(timeList),length(detuneList));
darkCountsLine =InitializeAxes (dic.GUI.sca(9),...
                       'detune [MHz]','Dark Counts %','off resonance shelving',...
                       [detuneList(1) detuneList(end)],[0 100],1);
set(darkCountsLine,'Marker','.','MarkerSize',10);
% measurements loops
dic.setNovatech4Amp(1,500);
dic.setNovatech4Amp(0,485);
for ind1=1:length(timeList)
    set(darkCountsLine,'xdata',[],'ydata',[]);
    disp(sprintf('Pulse time %d',timeList(ind1)));
    for ind2=1:length(detuneList)

        dic.setNovatech4Freq(0,dic.updateF674-detuneList(ind2));
        dic.setNovatech4Freq(1,dic.updateF674+detuneList(ind2));
        
        r=experimentSequence(timeList(ind1));
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
        stopLoop=dic.stop;
        if stopLoop 
           return
        end
    end % Loop 2
end % Loop 1
if (dic.AutoSaveFlag)
    destDir=dic.saveDir;
    thisFile=[mfilename('fullpath') '.m' ];
    [filePath fileName]=fileparts(thisFile);
    scriptText=fileread(thisFile);
    showData='figure;plot(detuneList,darkBank);xlabel(''F_{674} [Mhz]'');ylabel(''dark[%]'');';
    saveFileName=fullfile(destDir ,[fileName datestr(now,'-ddmmmyy-HHMMSS')]);
    dicParameters=dic.getParameters;
    save(saveFileName,'detuneList','timeList','darkBank','showData','dicParameters','scriptText');
    disp(['Save data in : ' saveFileName]);
end 
  
%----------------------------------------------------------------
    function r=experimentSequence(pulseTime)
        prog=CodeGenerator;
        prog.GenDDSPullParametersFromBase;
        prog.GenSeq(Pulse('ExperimentTrigger',0,50));
        prog.GenSeq(Pulse('674DDS1Switch',0,-1,'amp',100));
        % Doppler coolng
        prog.GenSeq(Pulse('OffRes422',0,1));%turn off cooling
        prog.GenSeq(Pulse('OnResCooling',0,dic.Tcooling));
        % OffResonance/Shelving pulse
        prog.GenSeq(Pulse('OpticalPumping',0,dic.Toptpump));        
          prog.GenSeq([Pulse('674Switch2NovaTech',0,pulseTime),...
                       Pulse('NoiseEater674',1,pulseTime)]);

        % detection
        prog.GenSeq([Pulse('OnRes422',0,dic.TDetection) Pulse('PhotonCount',0,dic.TDetection)]);
        %resume cooling
        prog.GenSeq(Pulse('Repump1033',0,dic.T1033));
        prog.GenSeq(Pulse('OffRes422',0,0));
        prog.GenFinish;
        
        dic.com.UploadCode(prog);
        dic.com.UpdateFpga;
        dic.com.WaitForHostIdle; % wait until host finished it last task
        rep=400;
        dic.com.Execute(rep);
        dic.com.WaitForHostIdle;
        r = dic.com.ReadOut(rep);
        r = r(2:end);
    end 
end

