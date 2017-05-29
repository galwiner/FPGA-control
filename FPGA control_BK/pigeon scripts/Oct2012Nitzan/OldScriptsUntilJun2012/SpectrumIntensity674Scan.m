function SpectrumIntensity674Scan(varargin)
dic=Dictator.me;
temp=dic.noiseEater674;

detuneList=[-1.7 -1.2 -0.8 -0.4 0.4 0.8 1.2 1.7];
timeList=[100 300 600 1000];
intensityList=(0.01:0.02:0.8);
%--------------------options------------- 
for i=1:2:size(varargin,2)
   switch lower(char(varargin(i)))
       case 'freq'
           detuneList=varargin{i+1};
       case 'duration'
           timeList=varargin{i+1};
       case 'intensity'
           intensityList=varargin{i+1};

   end; %switch
end;%for loop


darkBank=zeros(length(detuneList),length(timeList),length(intensityList));
darkCountsLine =InitializeAxes (dic.GUI.sca(9),...
                       'intensity [V]','Dark Counts %','off resonance shelving',...
                       [intensityList(1) intensityList(end)],[0 100],1);
set(darkCountsLine,'Marker','.','MarkerSize',10);
%-------------- measurements loops ----------------  
for ind1=1:length(detuneList)        
    disp(sprintf('Pulse detune %d',detuneList(ind1)));
    for ind2=1:length(timeList)       
        set(darkCountsLine,'xdata',[],'ydata',[]);
        for intensityInd=1:length(intensityList)
            if dic.stop 
               return
            end
            dic.noiseEater674=-3276*intensityList(intensityInd);
            r=experimentSequence(timeList(ind2),detuneList(ind1));
            % Plot fluorescence histogram
            dic.GUI.sca(1); %get histogram axes 
            hist(r,0:1:(1.8*dic.maxPhotonsNumPerReadout));
            if dic.TwoIonFlag
                dark =100-sum( (r>dic.TwoIonsCountThreshold)*2+...
                                     ((r>dic.darkCountThreshold)&(r<dic.TwoIonsCountThreshold))*1 ...
                                    )/2/length(r)*100;
            else
                dark = sum( r<dic.darkCountThreshold)/length(r)*100;
            end
            darkBank(ind1,ind2,intensityInd)=dark;
            %dic.GUI.sca(9); % main plotting axes
            AddLinePoint(darkCountsLine,intensityList(intensityInd),dark)
            pause(0.1);
        end % Loop 2
    end % Loop 1
    %--------------- saving------------------
end 
if (dic.AutoSaveFlag)
    destDir=dic.saveDir;
    thisFile=[mfilename('fullpath') '.m' ];
    [filePath fileName]=fileparts(thisFile);
    scriptText=fileread(thisFile);
    showData='figure;plot(intensityList,squeeze(darkBank(1,:,:))'');xlabel(''intensity[V]'');ylabel(''dark[%]'');';    
    saveFileName=fullfile(destDir ,[fileName datestr(now,'-ddmmmyy-HHMMSS')]);
    dicParameters=dic.getParameters;
    save(saveFileName,'detuneList','timeList','intensityList','darkBank','showData','dicParameters','scriptText');
    disp(['Save data in : ' saveFileName]);
end  
dic.noiseEater674=temp;
%----------------------------------------------------------------
    function r=experimentSequence(pulseTime,pulseDetune)
        prog=CodeGenerator;
        prog.GenDDSPullParametersFromBase;
        prog.GenSeq(Pulse('ExperimentTrigger',0,50));
        prog.GenSeq(Pulse('674DDS1Switch',0,-1,'freq',dic.updateF674+pulseDetune,'amp',100));
        % Doppler coolng
        prog.GenSeq(Pulse('OffRes422',0,1));%turn off cooling
        prog.GenSeq(Pulse('OnResCooling',0,dic.Tcooling));
        % ground state cooling 
%         prog.GenSeq([Pulse('674DDS1',1,dic.TSidebandCooling,'freq',dic.updateF674+dic.ionAxialFreq+dic.acStarkShift674),...
%                      Pulse('Repump1033',0,dic.TSidebandCooling+dic.T1033),...
%                      Pulse('OpticalPumping',0,dic.TSidebandCooling+dic.T1033+dic.Toptpump)]);        
        % OffResonance/Shelving pulse
        prog.GenSeq(Pulse('OpticalPumping',0,dic.Toptpump));        
        prog.GenSeq([Pulse('NoiseEater674',2,pulseTime) Pulse('674DDS1Switch',2,pulseTime)]);

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

