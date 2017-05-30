function RAP674Test

dic=Dictator.me;

% SweepTime=[10 20 100 500 1000 2000 5000]; %in microsec
% SweepTime=1:2:80;
SweepTime=1:30:201;

RAPWindow=300; % in kHz
DoRAPBack=0;
%StepFreq=5; %in kHz
TimePerStep=0.01; % in microsec
StaticKnife=0; %leaves the RAP Knife to the initial position 
FakeRAP=0; %in case of a Fake RAP, the sweep is done on the opposite side
useShutters=0;
SweepPower=100; % in %
repetitions=50;
waittime=0; % in ms

LaserHeatingFrequency=213;
doheat=0; theat=2000; % in microsec

% ------------Set GUI axes ---------------
InitializeAxes(dic.GUI.sca(1),'Photons #','Cases Counted #','Fluorescence Histogram',...
                [0 dic.maxPhotonsNumPerReadout],[],0);

lines =InitializeAxes (dic.GUI.sca(5),...
    'SweepTime[\mus]','Dark Counts %','RAP',...
    [SweepTime(1) SweepTime(end)],[0 100],2);
grid(dic.GUI.sca(5),'on');
set(lines(1),'Marker','.','MarkerSize',10,'Color','b');
set(lines(2),'Marker','.','MarkerSize',10,'Color','r');

% -------- Main function scan loops ------
dark = zeros(size(SweepTime));
for index1 = 1:length(SweepTime)
    if dic.stop
        return
    end
    r=experimentSequence(SweepTime(index1),dic.updateF674);
    dic.GUI.sca(1); %get an axis from Dictator GUI to show data
    hist(r,0:1:(1.8*dic.maxPhotonsNumPerReadout));
    if dic.TwoIonFlag
        dark(index1) =100-sum( (r>dic.TwoIonsCountThreshold)*2+...
                             ((r>dic.darkCountThreshold)&(r<dic.TwoIonsCountThreshold))*1 ...
                            )/2/length(r)*100;
    else
        dark(index1) = sum( r<dic.darkCountThreshold)/length(r)*100;
    end
    AddLinePoint(lines(1),SweepTime(index1),dark(index1));
    pause(0.1);
end

% Reinitialize the DDS (should be cleaner)
% DDSSingleToneInitialization(1,85);DDSSingleToneInitialization(2,3);

%--------------- Save data ------------------
if (dic.AutoSaveFlag)
    destDir=dic.saveDir;
    thisFile=[mfilename('fullpath') '.m' ];
    [filePath fileName]=fileparts(thisFile);
    scriptText=fileread(thisFile);
    scriptText(find(int8(scriptText)==10))='';
    showData='figure;plot(SweepTime,dark);xlabel(''Sweep Time[\mus]'');ylabel(''dark[%]'');';
    saveFileName=fullfile(destDir ,[fileName datestr(now,'-ddmmmyy-HHMMSS')]);
    dicParameters=dic.getParameters;
    save(saveFileName,'SweepTime','dark','showData','dicParameters','scriptText');
    disp(['Save data in : ' saveFileName]);
end 


%--------------------------------------------------------------------
    function r=experimentSequence(SweepTime,freq)
        prog=CodeGenerator;       
        prog.GenDDSPullParametersFromBase;
        
        prog.GenSeq(Pulse('674Switch2NovaTech',0,-1));
        prog.GenSeq(Pulse('ExperimentTrigger',0,50));
        % Doppler coolng
        prog.GenSeq(Pulse('OffRes422',0,500));%turn off cooling
        prog.GenSeq(Pulse('OnResCooling',0,dic.Tcooling) );
        % set DDS freq and amp
        prog.GenSeq(Pulse('674DDS1Switch',0,-1,'freq',freq,'amp',100));

%        prog.GenSeq(Pulse('OpticalPumping',10,dic.Toptpump));       
        if useShutters
            delaywait=6;
            prog.GenSeq(Pulse('DIO7',0,0)); %422 shutter: shut down light
            prog.GenPause(delaywait*1000);
            prog.GenSeq(Pulse('OpticalPumping',0,dic.Toptpump));
            % the big wait
            prog.GenSeq(Pulse('Shutters',0,0)); %shut down all lasers (takes <=3ms)        
            prog.GenPause(delaywait*1000); %convert to microseconds
        else
            prog.GenSeq(Pulse('OpticalPumping',10,dic.Toptpump));            
        end
        
        if doheat==1
            % Heating with probe beam
            prog.GenSeq(Pulse('OnRes422',0,-1,'freq',LaserHeatingFrequency));
            prog.GenPause(2000);
            prog.GenSeq(Pulse('OnRes422',0,theat));
            prog.GenSeq(Pulse('OpticalPumping',0,dic.Toptpump));
            
            % brings back 422 to initial frequency for cooling
            prog.GenSeq(Pulse('OnRes422',0,-1,'freq',dic.F422onResCool));
        end
        
        if waittime>0
            prog.GenPause(waittime*1000);
            prog.GenSeq(Pulse('OpticalPumping',10,dic.Toptpump));            
        end

        
        %%%%%%%%%%%
        %% RAP TEST %%%
        %%%%%%%%%%%

        % if fake RAP, put the window off resonance
        if FakeRAP
            StartFreq=freq+RAPWindow/1000/2
            StopFreq=StartFreq+RAPWindow/1000;
        else
            StopFreq=freq+RAPWindow/1000/2;
            StartFreq=freq-RAPWindow/1000/2;            
        end
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

        if StaticKnife  %leaves the RAP Knife to the initial position 
                        % this checks off resonant excitation
            prog.GenDDSFSKState(1,0);
        else
            prog.GenDDSFSKState(1,1);

        end

        prog.GenSeq(Pulse('674DDS1Switch',0,0,'amp',SweepPower));
       
        prog.GenPause(SweepTime)

        if DoRAPBack
            prog.GenDDSFSKState(1,0);
            prog.GenPause(SweepTime)
        end
        prog.GenSeq(Pulse('674DDS1Switch',0,-1,'amp',0));
        
        prog.GenDDSFSKState(1,0);
        
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%% SECOND RAP %%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%


        freq2=freq-dic.FRF*(0+(-1/2-3/2)*1.68/2.802);
        StartFreq=freq2+RAPWindow/1000/2;
        StopFreq=StartFreq+RAPWindow/1000;
        prog.GenSeq(Pulse('674DDS1Switch',0,-1,'freq',StartFreq,'amp',100));
        StepFreq=(StopFreq-StartFreq)/(SweepTime/TimePerStep);
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
        
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%% END SECOND RAP %%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        
         %%%%%%%%%%%
        %% TEST %%%
        %%%%%%%%%%%
        if useShutters
            prog.GenSeq(Pulse('Shutters',0,-1));%open all lasers (takes <=4ms)
            prog.GenPause(delaywait*1000); %convert to microseconds
            prog.GenSeq(Pulse('DIO7',0,-1)); %422 shutter: turn on light
            prog.GenPause(delaywait*1000);
        end
        
        %% the big wait
%         waitTimeMs=10;
%         prog.GenSeq(Pulse('Shutters',0,0)); %shut down all lasers (takes <=3ms)
%         prog.GenSeq(Pulse('674DDS1Switch',0,-1,'freq',50,'amp',0)); %turn off 674
%         prog.GenPause((waitTimeMs-4)*1000); %convert to microseconds
%         prog.GenSeq(Pulse('Shutters',0,-1));%open all lasers (takes <=4ms)
%         prog.GenPause(4000);

        %sideband Shelving
%         pulseTime=dic.T674;
%         
%         if (pulseTime>3)
%            prog.GenSeq([Pulse('NoiseEater674',2,pulseTime-2),...
%                         Pulse('674DDS1Switch',0,pulseTime)]);
%         else
%            prog.GenSeq(Pulse('674DDS1Switch',0,pulseTime));
%         end
        
        % detection
        prog.GenSeq([Pulse('OnRes422',0,dic.TDetection) Pulse('PhotonCount',0,dic.TDetection)]);
        %resume cooling
        prog.GenSeq(Pulse('Repump1033',0,dic.T1033));
        prog.GenSeq(Pulse('OffRes422',0,0));
        prog.GenFinish;

        dic.com.UploadCode(prog);
        dic.com.UpdateFpga;
        dic.com.WaitForHostIdle; % wait until host finished it last task
        dic.com.Execute(repetitions);
        dic.com.WaitForHostIdle;
        r = dic.com.ReadOut(repetitions);
        r = r(2:end);
    end
end    