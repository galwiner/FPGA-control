function RAPVsRabi(waittime)

dic=Dictator.me;

% set file name
destDir=dic.saveDir;
thisFile=[mfilename('fullpath') '.m' ];
[filePath fileName]=fileparts(thisFile);
saveFileName=fullfile(destDir ,[fileName datestr(now,'-ddmmmyy-HHMMSS')]);

PulseTime=dic.T674;

if ~exist('waittime')
     waittime=[10 100 1000 2000 5000 10000]; %in msec
end

if dic.TwoIonFlag
    OffResCoolingTime=1000; % in ms
else
    OffResCoolingTime=1000; % in ms
end

repetitions=100;
chunksize=2;

%use shutter?
useShutter=0;

% number of sweeps
iterationsize=repetitions/chunksize;

%%%%% RAP PARAMETERS %%%%%%%
%SweepTime=1:20:300;
SweepTime=120;

RAPWindow=700; % in kHz
DoRAPBack=0;
%StepFreq=5; %in kHz
TimePerStep=0.01; % in microsec
FakeRAP=0; %in case of a Fake RAP, the sweep is done on the opposite side
SweepPower=100; % in %
%%%%% RAP PARAMETERS %%%%%%%%%%%%%%%

% ------------Set GUI axes ---------------
InitializeAxes(dic.GUI.sca(1),'Photons #','Cases Counted #','Fluorescence Histogram',...
                [0 dic.maxPhotonsNumPerReadout],[],0);

lines =InitializeAxes(dic.GUI.sca(7),...
    'Waittime Time[ms]','Dark Counts %','Heating Measurement',...
    [waittime(1)-0.0001 waittime(end)],[0 100],2);
grid(dic.GUI.sca(4),'on');
set(lines(1),'Marker','.','MarkerSize',10,'Color','b');
set(lines(2),'Marker','.','MarkerSize',10,'Color','r');
%set(lines(3),'Marker','.','MarkerSize',10,'Color','g');

% -------- Main function scan loops ------
dark = zeros(iterationsize,length(waittime));
darkRAP = zeros(iterationsize,length(waittime));

initialCrystal=zeros(iterationsize,length(waittime));
finalCrystal=zeros(iterationsize,length(waittime));
progress=zeros(iterationsize,length(waittime));
% -------- Resume mechanism ---------------
if dic.resumeFlag
    lst=dir(fullfile(destDir,[fileName '*.mat']));
    for t=1:length(lst) 
        lstdate{t}=lst(t).name(length([fileName '-'])+1:end-4); end
    [sorted,indx]=sort(lstdate);
    reply = input(sprintf('Do you want to resume last run from %s? Y/N [Y]: ',lstdate{indx(end)}), 's');
    if isempty(reply)
        reply = 'Y';
    end
    if (strcmp(reply,'Y'))
        load(fullfile(destDir,lst(indx(end)).name),'dark','initialCrystal','finalCrystal','index2');
        sind2=index2;
        progress(1:(index2-1),:)=ones(index2-1,length(waittime));
        fprintf('Resuming run\n');
    else
        sind2=1;
        sind1=1;
    end
else
    sind2=1;
    sind1=1;
end

tic;
for index2=sind2:iterationsize
    
    fprintf('Completing %d out of total %d repetitions\n',index2*chunksize,repetitions);
    for index1 = 1:length(waittime)
        % make sure you start with a crystal
        if dic.TwoIonFlag
            [final initial]=CrystalCheckPMT;
            initialCrystal(index2,index1)=initial;
            finalCrystal(index2,index1)=final;
        else
            final=1;
        end
        if dic.stp || ~final %||(lengthr~=chunksize)
            savethis;
            return;
        end
        
        % Reinitialize DDS
        DDSSingleToneInitialization(1,85);DDSSingleToneInitialization(2,3);

        %%%%%%%%%%%%%%%%%%%%%
        % Rabi Shelving
        if dic.TwoIonFlag
            valid=0; limitcounter=5;
            while ~valid&&limitcounter
                r=experimentSequence(waittime(index1),dic.updateF674,0); lengthr=length(r);
                [final initial]=CrystalCheckPMT;
                if limitcounter==5
                    initialCrystal(index2,index1)=initial;
                    finalCrystal(index2,index1)=final;
                else
                    disp('Warning : Experiment repeated due to crystal melting.');
                end
                valid=initial;
                limitcounter=limitcounter-1;
            end
        else
            % Third index is spin state, Fourth is Rabi shelving (0) or RAP (1)
            r=experimentSequence(waittime(index1),dic.updateF674,0,0); lengthr=length(r);
            if lengthr==0
                disp('Repeating measurement Due to FPGA error.');
                r=experimentSequence(waittime(index1),dic.updateF674,0,1); lengthr=length(r);
            end
        end
        
        % Reinitialize DDS
        DDSSingleToneInitialization(1,85);DDSSingleToneInitialization(2,3);
        pause(1);            
        %%%%%%%%%%%%%%%%%%%%%
        % RAP Shelving
        if dic.TwoIonFlag
            valid=0; limitcounter=5;
            while ~valid&&limitcounter
                rdown=experimentSequence(waittime(index1),dic.updateF674,1); lengthrdown=length(rdown);
                [final initial]=CrystalCheckPMT;
                if limitcounter==5
                    initialCrystal(index2,index1)=initial;
                    finalCrystal(index2,index1)=final;
                else
                    disp('Warning : Experiment repeated due to crystal melting.');
                end
                valid=initial;
                limitcounter=limitcounter-1;
            end
        else
            % Third index is spin state, Fourth is Rabi shelving (0) or RAP (1)
            rRAP=experimentSequence(waittime(index1),dic.updateF674,0,1); lengthrRAP=length(rRAP);
            if lengthrRAP==0
                disp('Repeating measurement Due to FPGA error.');
                rRAP=experimentSequence(waittime(index1),dic.updateF674,0,1); lengthrRAP=length(rRAP);
            end
        end
        
        %%%%%%%%%%%%%%%%
        if dic.TwoIonFlag
            if dic.stp || ~final ||(lengthr~=chunksize)||(lengthrRAP~=chunksize)||~limitcounter
                savethis;
                return;
            end
        else
            if dic.stp
                savethis;
                return;
            end
        end

        progress(index2,index1)=1;
    %     r=experimentSequence(PulseTime(index1),dic.updateF674);
        dic.GUI.sca(1); %get an axis from Dictator GUI to show data
        hist(r,0:1:(1.8*dic.maxPhotonsNumPerReadout));
        if (index1==1)
            set(lines(1),'XData',[],'YData',[]);
            set(lines(2),'XData',[],'YData',[]);
        end
        
        if dic.TwoIonFlag
            dark(index2,index1) =100-sum(r>dic.darkCountThreshold)/lengthr*100;                            
            darkdown(index2,index1) =100-sum(rdown>dic.darkCountThreshold)/lengthrdown*100;                            
                            
            AddLinePoint(lines(1),waittime(index1),mean(dark(1:index2,index1)));
            AddLinePoint(lines(2),waittime(index1),mean(darkdown(1:index2,index1)));
            
            pause(0.1);pp=mean(dark(1:index2,index1));
            ppdown=mean(darkdown(1:index2,index1));

            fprintf('(%s) Wait= %d // UpEff=%.2f(+/-%.2f) // DownEff=%.2f(+/-%.2f) // Melting =%.2f %%\n',progressStr,waittime(index1),pp,sqrt(pp*(100-pp)/index2),ppdown,sqrt(ppdown*(100-ppdown)/index2),mean(1-initialCrystal(1:index2,index1))*100);
        else
            dark(index2,index1) = sum( r<dic.darkCountThreshold)/lengthr*100;
            darkRAP(index2,index1) = sum(rRAP<dic.darkCountThreshold)/lengthrRAP*100;
            AddLinePoint(lines(1),waittime(index1),mean(dark(1:index2,index1)))
            AddLinePoint(lines(2),waittime(index1),mean(darkRAP(1:index2,index1)))
            pause(0.1);
            fprintf('(%s) Wait= %d // Rabi Eff=%.2f // RAP Eff=%.2f \n',progressStr,waittime(index1),mean(dark(1:index2,index1)),mean(darkRAP(1:index2,index1)));
        end
        
    end
    savethis;
    if dic.TwoIonFlag 
        fprintf('iteration %d: 5 sec cooling: ',iterationsize);
        for dummy=1:5
            pause(1);
            fprintf('%d,',5-dummy);
        end
        fprintf('\n');
    end
end

% set(lines(2),'XData',waittime,'YData',mean(dark));
% set(lines(1),'XData',waittime,'YData',mean(dark));

savethis;
dic.Vcap=50;
pause(6);
dic.Vkeith=1.5;

%--------------- Save data ------------------
    function sstr=progressStr
        percentageCompleted=mean(reshape(progress,1,[]));
        stamp=toc;
        total=stamp/percentageCompleted;
        s=total-stamp;
        if s>3600
            sstr=sprintf('%.1f comp, rem=%.2f h',100*percentageCompleted,s/3600);
        elseif s>60
            sstr=sprintf('%.1f comp, rem=%.2f m',100*percentageCompleted,s/60);
        else
            sstr=sprintf('%.1f comp, rem=%.2f s',100*percentageCompleted,s);
        end
    end

    function savethis
        
        scriptText=fileread(thisFile);
        scriptText(find(int8(scriptText)==10))='';
%        showData='figure;plot(waittime,mean(dark(1:index2,:)),''b'',waittime,mean(darkdown(1:index2,:)),''r'',waittime,mean((1-initialCrystal(1:index2,:))*100),''g'');xlabel(''Wait Time[ms]'');ylabel(''dark[%]//Melt[%]''); title(sprintf(''Shelving Eff and Melt Events at Vkeith=%g Vcap=%g'',Vkeith,Vcap))';
        showData='figure;plot(waittime,mean(dark(1:index2,:)),''b'',waittime,mean(darkRAP(1:index2,:)),''r'',waittime,mean((1-initialCrystal(1:index2,:))*100),''g'');xlabel(''Wait Time[ms]'');ylabel(''dark[%]//Melt[%]''); title(sprintf(''Shelving Eff and Melt Events at Vkeith=%g Vcap=%g'',Vkeith,Vcap))';
        dicParameters=dic.getParameters;
        Vkeith=dic.Vkeith; Vcap=dic.Vcap;
        save(saveFileName,'progress','waittime','dark','darkRAP','initialCrystal','finalCrystal','chunksize','repetitions','index1','index2','Vkeith','Vcap','showData','dicParameters','scriptText');
        disp(['Save data in : ' saveFileName]);        
    end

%--------------------------------------------------------------------
    function r=experimentSequence(waitt,freq,measDown,ToRAPOrNotToRAP)
        prog=CodeGenerator;
        prog.GenDDSPullParametersFromBase;
        prog.GenSeq(Pulse('674Switch2NovaTech',0,-1));
        prog.GenSeq(Pulse('ExperimentTrigger',0,50));
        prog.GenSeq(Pulse('OffRes422',0,OffResCoolingTime*1000)); 

        % set DDS freq and amp
        prog.GenSeq(Pulse('674DDS1Switch',0,-1,'freq',freq,'amp',100));
        %prog.GenSeq(Pulse('674DDS1Switch',0,-1,'freq',0.9*freq,'amp',0));
        
        % set RF at fake freq value and zero amplitude
        prog.GenSeq(Pulse('RFDDS2Switch',2,-1,'freq',3.1415*dic.FRF,'amp',0)); %turn off RF                

        % Doppler coolng
        prog.GenSeq(Pulse('OffRes422',0,10));%turn off cooling
        prog.GenSeq(Pulse('OnResCooling',0,dic.Tcooling) );
        delaywait=6;
        if useShutter
            prog.GenSeq(Pulse('DIO7',0,0)); %422 shutter: shut down light
            prog.GenPause(delaywait*1000);
        end
        prog.GenSeq(Pulse('OpticalPumping',0,dic.Toptpump));
        if waitt>0
            if useShutter
                % the big wait
                prog.GenSeq(Pulse('Shutters',0,0)); %shut down all lasers (takes <=3ms)
                prog.GenPause((waitt-delaywait)*1000); %convert to microseconds
                prog.GenSeq(Pulse('Shutters',0,-1));%open all lasers (takes <=4ms)                
                prog.GenPause(delaywait*1000); %convert to microseconds
            else
                prog.GenPause(waitt*1000);
                prog.GenSeq(Pulse('OpticalPumping',0,dic.Toptpump));
            end
        end

        % measure down instead of up
         if measDown
            prog.GenSeq(Pulse('RFDDS2Switch',2,-1,'freq',dic.FRF,'amp',dic.ampRF)); %turn RF back on
            prog.GenSeq([Pulse('674PulseShaper',1,dic.TimeRF-1),...
                     Pulse('RFDDS2Switch',2,dic.TimeRF)]);
         end
         
         if ToRAPOrNotToRAP
             %%%%%%%% RAP %%%%%%%%%%%%%%%%%
             %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
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
             prog.GenDDSFSKState(1,1);
             prog.GenSeq(Pulse('674DDS1Switch',0,0,'amp',SweepPower));
             prog.GenPause(SweepTime)
             if DoRAPBack
                 prog.GenDDSFSKState(1,0);
                 prog.GenPause(SweepTime)
             end
             prog.GenSeq(Pulse('674DDS1Switch',0,-1,'amp',0));
             prog.GenDDSFSKState(1,0);
             %%%%%%%% END OF RAP %%%%%%%%%%%%%%%%%
             %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%             
         else
             %Shelving of m=+1/2 to +3/2
             if (PulseTime>3)
                 prog.GenSeq([Pulse('NoiseEater674',2,PulseTime-2),...
                     Pulse('674DDS1Switch',0,PulseTime)]);
             else
                 prog.GenSeq(Pulse('674DDS1Switch',0,PulseTime));
             end
             
%              %Shelving of m=+1/2 to -1/2
%              prog.GenSeq([Pulse('NoiseEater674',2,40-2),...
%                  Pulse('674DDS1Switch',0,40,'freq',freq-dic.FRF*(0+(-1/2-3/2)*1.68/2.802))]);
         end
        
        % detection
        if useShutter
            prog.GenSeq(Pulse('DIO7',0,-1)); %422 shutter: turn on light
            prog.GenPause(delaywait*1000);
        end
        
        
        prog.GenSeq([Pulse('OnRes422',100,dic.TDetection) Pulse('PhotonCount',100,dic.TDetection)]);
        %resume cooling
        prog.GenSeq(Pulse('Repump1033',0,dic.T1033));
        prog.GenSeq(Pulse('OffRes422',0,0));
        prog.GenFinish;

        dic.com.UploadCode(prog);
        dic.com.UpdateFpga;
        dic.com.WaitForHostIdle; % wait until host finished it last task
        dic.com.Execute(chunksize);
        dic.com.WaitForHostIdle;
        r = dic.com.ReadOut(-1);
        if length(r)~= chunksize
            fprintf('Problem FPGA readout %g insted of %g\n',length(r),chunksize);
        end
    end
end
    
    