function [optVdcl,optVcomp]=T1EffVsCompLinScan(a,b)
dic=Dictator.me;

% set file name
destDir=dic.saveDir;
thisFile=[mfilename('fullpath') '.m' ];
[filePath fileName]=fileparts(thisFile);
saveFileName=fullfile(destDir ,[fileName datestr(now,'-ddmmmyy-HHMMSS')]);

PulseTime=dic.T674;
OffResCoolingTime=1000;
waittime=5000;%000; %in msec


%scan along a linear combination of Vdcl=a*Vcomp+b
%a=0.0087301176519572476;
%a=0.00646
if ~exist('a')
    a=0.00752;
end
%b=1.2832911194990408;
%b=1.328;
if ~exist('b')
    b=1.13;
end

fprintf('-------- following AVdcl=aVcomp+b for a=%.4f,b=%.2f\n -------------',a,b);

Vcomp=0:10:50;
%Vcomp=[30 40];

AVdcl=round(1000*(a*Vcomp+b))/1000; %rounded to mV perc
dic.AVdcr=0;

repetitions=50;
chunksize=1;

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
lines =InitializeAxes (dic.GUI.sca(11),...
    'electrode idx','Dark %//Det Photons','Detection and Shelving',...
    [1 length(AVdcl)],[0 100],2);
lines2 =InitializeAxes (dic.GUI.sca(10),...
    'electrode idx','Melting %//Dark % after wait','Melting and Shelving after wait',...
    [1 length(AVdcl)],[0 100],2);
lines3 =InitializeAxes (dic.GUI.sca(6),...
    'electrode idx','Rabi Period','Micromotion Sideband Flop',...
    [1 length(AVdcl)],[0 1000],2);


set(lines(1),'Marker','.','MarkerSize',10,'Color','b');
set(lines(2),'Marker','.','MarkerSize',10,'Color','r');            
set(lines2(1),'Marker','.','MarkerSize',10,'Color','b');
set(lines2(2),'Marker','.','MarkerSize',10,'Color','r');            

set(lines3(1),'Marker','.','MarkerSize',10,'Color','b');            

% -------- Main function scan loops ------
dark = zeros(iterationsize,length(AVdcl));
initialCrystal=zeros(iterationsize,length(AVdcl));
finalCrystal=zeros(iterationsize,length(AVdcl));
detectionEff=zeros(1,length(AVdcl));
shelvingEff=zeros(1,length(AVdcl));
photoncount=zeros(iterationsize,length(AVdcl));
progress=zeros(size(dark));

AVdclOrig=dic.AVdcl;
HPVcompOrig=dic.HPVcomp;

% check detection and regular shelving (sanity check)
for idx2=1:length(AVdcl)
    f674=dic.updateF674;
    %set electroedes to tested value
    dic.HPVcomp=Vcomp(idx2);
    dic.AVdcl=AVdcl(idx2);
    % make sure we have a crystal
    [res initial]=CrystalCheckPMT;
    if dic.stop || ~res
        savethis;
        dic.HPVcomp=HPVcompOrig;
        dic.AVdcl=AVdclOrig;
        return;
    end
    % 422 detection
    r = detectionSeq(dic.F422onRes);
    detectionEff(idx2)=mean(r);
    % 674 shelving
    r=shelvingSeq(f674,dic.T674,100);
    
    shelvingEff(idx2) =100-sum( (r>dic.TwoIonsCountThreshold)*2+...
        ((r>dic.darkCountThreshold)&(r<dic.TwoIonsCountThreshold))*1 ...
        )/2/length(r)*100;
    %show intermediate graph   
%     RabiMicroM=MicromotionCarrierRabiScan674S;
%     AddLinePoint(lines3(1),idx2,RabiMicroM);
    
    AddLinePoint(lines(1),idx2,mean(detectionEff(idx2)));
    AddLinePoint(lines(2),idx2,mean(shelvingEff(idx2)));
    pause(0.1);
    
end
tic;
% measure "Almost T1" and de-crystal events
for rep=1:iterationsize
    for idx2=1:length(AVdcl)
        f674=dic.updateF674;
        %set electrodes to tested value
        dic.HPVcomp=Vcomp(idx2);
        dic.AVdcl=AVdcl(idx2);
        % make sure we have a crystal
        [res initial]=CrystalCheckPMT;
        finalCrystal(rep,idx2)=res;
        initialCrystal(rep,idx2)=initial;

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
            dic.HPVcomp=HPVcompOrig;
            dic.AVdcl=AVdclOrig;            
            return;
        end
        
        % cont until valid result
        valid=0; limitcounter=5;
        while ~valid&&limitcounter
            r=experimentSequence(waittime,f674); lengthr=length(r);
            [final initial]=CrystalCheckPMT;
            if limitcounter==5
                initialCrystal(rep,idx2)=initial;
                finalCrystal(rep,idx2)=final;
            else
                disp('Warning : Experiment repeated due to crystal melting.');
            end
            valid=initial;
            limitcounter=limitcounter-1;
        end
        
        if dic.stop || ~final ||(lengthr~=chunksize)||~limitcounter
            savethis;
            return;
        end       
        %%%%%%%%%%%%%%%%%%%%%%%%%
        
        % "Almost T1"
        %r=experimentSequence(waittime,f674);
        photoncount(rep,idx2)=mean(r);
        if dic.TwoIonFlag
            dark(rep,idx2) =100-sum(r>dic.darkCountThreshold)/length(r)*100;
        else
            dark(rep,idx2) = sum( r<dic.darkCountThreshold)/length(r)*100;
        end
        %calculate progress
        progress(rep,idx2)=1;
        
        % return electrodes to origianl value
        dic.HPVcomp=HPVcompOrig;
        dic.AVdcl=AVdclOrig;
        fprintf('(%s) Vdcl,Vcomp=%.2f,%.2f; decrystal %.2f, shelving efficiency %.2f \n',progressStr,AVdcl(idx2),Vcomp(idx2),100*mean(1-initialCrystal(1:rep,idx2)),mean(dark(1:rep,idx2)));
        AddLinePoint(lines2(1),idx2,mean(dark(1:rep,idx2)));
        AddLinePoint(lines2(2),idx2,mean(1-initialCrystal(1:rep,idx2)));
        pause(0.1);
        % 2 second cooling
        if mod(idx2,3)==0
            fprintf('during electrode scan: 2 sec cooling: ');
            takeFive(2);
            fprintf('\n');
        end
    end
    % 5 second cooling
    fprintf('iteration %d: 2 sec cooling: ',rep);
    takeFive(2);
    fprintf('\n');
    set(lines2(1),'XData',[],'YData',[]);
    set(lines2(2),'XData',[],'YData',[]);
    % find optimum and save
    tmp=mean(dark(1:rep,:));
    idx=find(tmp==max(tmp),1);
    optVcomp=Vcomp(idx);
    optVdcl=AVdcl(idx);
    savethis;
end

savethis;

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

%--------------- Save data ------------------
function savethis
    scriptText=fileread(thisFile);
    scriptText(find(int8(scriptText)==10))='';
    showData='figure;plot(1:length(AVdcl),shelvingEff,''r'',1:length(AVdcl),detectionEff,''b''); xlabel(''electrode idx''); ylabel(''Shelv %/Det''); title(''Shelving and detection''); figure; plot(1:length(AVdcl),mean(1-initialCrystal(1:rep,:)),''r'',1:length(AVdcl),mean(dark(1:rep,:)),''b''); xlabel(''electrode idx''); ylabel(''Melt %/Shelv %''); title(''melting and shelving after wait'');';
    dicParameters=dic.getParameters;
    save(saveFileName,'waittime','Vcomp','AVdcl','photoncount','rep','initialCrystal','finalCrystal','dark','detectionEff','shelvingEff','chunksize','repetitions','idx2','showData','dicParameters','scriptText');
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
        
        % set RF at fake freq value and zero amplitude
%         prog.GenSeq(Pulse('RFDDS2Switch',2,-1,'freq',3.1415*dic.FRF,'amp',0)); %turn off RF                

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

        %Shelving of m=+1/2 to +3/2
        if (PulseTime>3)
           prog.GenSeq([Pulse('NoiseEater674',2,PulseTime-2),...
                        Pulse('674DDS1Switch',0,PulseTime)]);
        else
           prog.GenSeq(Pulse('674DDS1Switch',0,PulseTime));
        end
        
        %Shelving of m=+1/2 to -1/2
        prog.GenSeq([Pulse('NoiseEater674',2,40-2),...
            Pulse('674DDS1Switch',0,40,'freq',freq-dic.FRF*(0+(-1/2-3/2)*1.68/2.802))]);
        
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

%--------------------------------------------------------------------
    function r=detectionSeq(freq)%create and run a single sequence of detection
        prog=CodeGenerator; 
        prog.GenSeq(Pulse('ExperimentTrigger',0,50));
        %set-up detection(also=optical repump), 1092 and on-res cooling freq. 
        if (freq>0)
            prog.GenSeq(Pulse('OnRes422',0,-1,'freq',freq));
        end
       % prog.GenSeq(Pulse('Repump1092',0,0,'freq',dic.F1092));
        prog.GenSeq(Pulse('OffRes422',0,100));
        prog.GenSeq(Pulse('OnResCooling',0,dic.Tcooling));
        prog.GenSeq([Pulse('OnRes422',100,dic.TDetection) Pulse('PhotonCount',100,dic.TDetection)]);
        prog.GenSeq(Pulse('OffRes422',500,0));
        prog.GenFinish;
        %prog.DisplayCode;

        % FPGA/Host control
        n=dic.com.UploadCode(prog);
        dic.com.UpdateFpga;
        dic.com.WaitForHostIdle;

        dic.com.Execute(100);
        dic.com.WaitForHostIdle;
        r=dic.com.ReadOut(100);
    end

    function r=shelvingSeq(pFreq,pTime,pAmp)
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
        dic.com.Execute(100);
        dic.com.WaitForHostIdle;
        r = dic.com.ReadOut(100);
        r = r(2:end);
    end
end