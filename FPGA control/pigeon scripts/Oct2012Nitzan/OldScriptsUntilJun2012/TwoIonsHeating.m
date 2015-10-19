function TwoIonsHeating(waittime)
dic=Dictator.me;

% set file name
destDir=dic.saveDir;
thisFile=[mfilename('fullpath') '.m' ];
[filePath fileName]=fileparts(thisFile);
saveFileName=fullfile(destDir ,[fileName datestr(now,'-ddmmmyy-HHMMSS')]);

% PulseTime=0.1:10:300;
PulseTime=dic.T674;
if ~exist('waittime')
     waittime=[100 1000 10000 30000]; %in msec
end

OffResCoolingTime=1000; % in ms
repetitions=100;
chunksize=1;

%use shutter?
useShutter=0;

% number of sweeps
iterationsize=repetitions/chunksize;


% if dic.curBeam==0 %674 beam horizontal at 45 deg to axial
%     PulseTime=0.1:1:50;
% elseif dic.curBeam==1             %674 beam vertical at 45 deg to axial
%     PulseTime=1:3:150;
% else
%     PulseTime=1:20:600;
% end
% ------------Set GUI axes ---------------
InitializeAxes(dic.GUI.sca(1),'Photons #','Cases Counted #','Fluorescence Histogram',...
                [0 dic.maxPhotonsNumPerReadout],[],0);

lines =InitializeAxes (dic.GUI.sca(7),...
    'Waittime Time[ms]','Dark Counts %','Heating Measurement',...
    [waittime(1)-0.0001 waittime(end)],[0 100],2);
grid(dic.GUI.sca(4),'on');
set(lines(1),'Marker','.','MarkerSize',10,'Color','b');
set(lines(2),'Marker','.','MarkerSize',10,'Color','r');

% -------- Main function scan loops ------
dark = zeros(iterationsize,length(waittime));
repeatedExpt = zeros(iterationsize,length(waittime));
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
        load(fullfile(destDir,lst(indx(end)).name),'dark','initialCrystal','finalCrystal','index2','repeatedExpt');
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
            %initialCrystal(index2,index1)=initial;
            %finalCrystal(index2,index1)=final;
        else
            final=1;
        end
        if dic.stp || ~final %||(lengthr~=chunksize)
            savethis;
            return;
        end
        
        % cont until valid result
        valid=0; limitcounter=5;
        while ~valid&&limitcounter
            r=experimentSequence(waittime(index1),dic.updateF674); lengthr=length(r);
            [final initial]=CrystalCheckPMT;
            if limitcounter==5
                initialCrystal(index2,index1)=initial;
                finalCrystal(index2,index1)=final;                
            else
                disp('Warning : Experiment repeated due to crystal melting.');
            end
            valid=initial;
            limitcounter=limitcounter-1;
            repeatedExpt(index2,index1)=repeatedExpt(index2,index1)+1;
        end
        
        if dic.stp || ~final ||(lengthr~=chunksize)||~limitcounter
            savethis;
            return;
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
%              dark(index2,index1) =100-sum( (r>dic.TwoIonsCountThreshold)*2+...
%                                   ((r>dic.darkCountThreshold)&(r<dic.TwoIonsCountThreshold))*1 ...
%                                  )/2/lengthr*100;
            dark(index2,index1) =100-sum(r>dic.darkCountThreshold)/lengthr*100;                            
                            
            AddLinePoint(lines(1),waittime(index1),mean(dark(1:index2,index1)));
            AddLinePoint(lines(2),waittime(index1),mean((1-initialCrystal(1:index2,index1))*100));
            pause(0.1);pp=mean(dark(1:index2,index1));
            fprintf('(%s) Wait= %d // Det Eff=%.2f(+/-%.2f) // Melting =%.2f %%\n',progressStr,waittime(index1),pp,sqrt(pp*(100-pp)/index2),mean(1-initialCrystal(1:index2,index1))*100);
        else
            dark(index2,index1) = sum( r<dic.darkCountThreshold)/lengthr*100;
            AddLinePoint(lines(1),waittime(index1),mean(dark(1:index2,index1)))
            pause(0.1);
            fprintf('(%s) Wait= %d // Det Eff=%.2f \n',progressStr,waittime(index1),mean(dark(1:index2,index1)));
        end
        
    end
    savethis;
    fprintf('iteration %d: 5 sec cooling: ',iterationsize);
    takeFive;
    fprintf('\n');
end

set(lines(2),'XData',waittime,'YData',mean(dark));
savethis;
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
        showData='figure;plot(waittime,mean(dark(1:index2,:)),''b'',waittime,mean((1-initialCrystal(1:index2,:))*100),''r'');xlabel(''Wait Time[ms]'');ylabel(''dark[%]//Melt[%]''); title(sprintf(''Shelving Eff and Melt Events at Vkeith=%g Vcap=%g'',Vkeith,Vcap))';
        dicParameters=dic.getParameters;
        Vkeith=dic.Vkeith; Vcap=dic.Vcap;
        save(saveFileName,'repeatedExpt','progress','waittime','dark','initialCrystal','finalCrystal','chunksize','repetitions','index1','index2','Vkeith','Vcap','showData','dicParameters','scriptText');
        disp(['Save data in : ' saveFileName]);
        
    end

%--------------------------------------------------------------------
    function r=experimentSequence(waitt,freq)
        prog=CodeGenerator;
        prog.GenDDSPullParametersFromBase;
        prog.GenSeq(Pulse('674Switch2NovaTech',0,-1));
        prog.GenSeq(Pulse('ExperimentTrigger',0,50));
        prog.GenSeq(Pulse('OffRes422',0,OffResCoolingTime*1000)); 

        % set DDS freq and amp
        prog.GenSeq(Pulse('674DDS1Switch',0,-1,'freq',freq,'amp',100));
        %prog.GenSeq(Pulse('674DDS1Switch',0,-1,'freq',0.9*freq,'amp',0));
        

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
               %prog.GenSeq(Pulse('RFDDS2Switch',2,-1,'freq',3.1415*dic.FRF,'amp',0)); %turn off RF
                
                prog.GenPause((waitt-delaywait)*1000); %convert to microseconds
                prog.GenSeq(Pulse('Shutters',0,-1));%open all lasers (takes <=4ms)
                
                %prog.GenSeq(Pulse('RFDDS2Switch',2,-1,'freq',dic.FRF,'amp',dic.ampRF)); %turn RF back on
                %prog.GenSeq(Pulse('674DDS1Switch',0,-1,'freq',freq,'amp',100));
                prog.GenPause(delaywait*1000); %convert to microseconds
%                 prog.GenSeq(Pulse('OpticalPumping',0,dic.Toptpump));
            else
                prog.GenPause(waitt*1000);
                prog.GenSeq(Pulse('OpticalPumping',0,dic.Toptpump));
            end
        end
        
        %Shelving of m=+1/2 to +3/2
        if (PulseTime>3)
           prog.GenSeq([Pulse('NoiseEater674',2,PulseTime-2),...
                        Pulse('674DDS1Switch',0,PulseTime)]);
        else
           prog.GenSeq(Pulse('674DDS1Switch',0,PulseTime));
        end

        %Shelving of m=+1/2 to -1/2
        prog.GenSeq([Pulse('NoiseEater674',2,30-2),...
            Pulse('674DDS1Switch',0,30,'freq',freq-dic.FRF*(0+(-1/2-3/2)*1.68/2.802))]);
        
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
%         dic.com.WaitForHostIdle;
        r = dic.com.ReadOut(-1);
        if length(r)~= chunksize
            fprintf('Problem FPGA readout %g insted of %g\n',length(r),chunksize);
        end
    end
end
    