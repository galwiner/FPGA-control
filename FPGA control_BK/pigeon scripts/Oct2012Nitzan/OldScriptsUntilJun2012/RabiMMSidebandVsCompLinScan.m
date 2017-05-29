function TwoIonsHeating
dic=Dictator.me;

% set file name
destDir=dic.saveDir;
thisFile=[mfilename('fullpath') '.m' ];
[filePath fileName]=fileparts(thisFile);
saveFileName=fullfile(destDir ,[fileName datestr(now,'-ddmmmyy-HHMMSS')]);

PulseTime=dic.T674;
waittime=100; %in msec

%scan along a linear combination of Vdcl=a*Vcomp+b
%a=-0.0087301176519572476;
a=-0.0067301176519572476;
%b=1.2832911194990408;
b=1.28;

Vcomp=0:5:50;
AVdcl=round(1000*(a*Vcomp+b))/1000; %rounded to mV perc
dic.AVdcr=0;

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
detectionEff=zeros(1,length(AVdcl));
shelvingEff=zeros(1,length(AVdcl));
RabiP=zeros(1,length(AVdcl));

AVdclOrig=dic.AVdcl;
HPVcompOrig=dic.HPVcomp;

% check detection and regular shelving (sanity check)
for idx2=1:length(AVdcl)
    f674=dic.updateF674;
    %set electroedes to tested value
    dic.HPVcomp=Vcomp(idx2);
    dic.AVdcl=AVdcl(idx2);
    % make sure we have a crystal
    [res initial]=CrystalCheckPMT(dic.Vkeith);
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
    
    RabiP(idx2)=MicromotionCarrierRabiScan674;
    AddLinePoint(lines3(1),idx2,RabiP(idx2));

    
    AddLinePoint(lines(1),idx2,mean(detectionEff(idx2)));
    AddLinePoint(lines(2),idx2,mean(shelvingEff(idx2)));
    pause(0.1);
    
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
%     showData='figure;plot(1:length(AVdcl),mean(shelvingEff(,:)),''r'',1:length(AVdcl),mean(detectionEff(1:repetitions,:)),''b''); xlabel(''electrode idx''); ylabel(''Shelv %/Det''); title(''Shelving and detection''); figure; plot(1:length(AVdcl),mean(1-initialCrystal(1:repetitions,:)),''r'',1:length(AVdcl),mean(dark(1:repetitions,:)),''b''); xlabel(''electrode idx''); ylabel(''Melt %/Shelv %''); title(''melting and shelving after wait'');';
    dicParameters=dic.getParameters;
    save(saveFileName,'waittime','Vcomp','AVdcl','RabiP','detectionEff','shelvingEff','idx2','showData','dicParameters','scriptText');
    disp(['Save data in : ' saveFileName]);
end

%--------------------------------------------------------------------
    function r=experimentSequence(waitt,freq)
        prog=CodeGenerator;
        prog.GenDDSPullParametersFromBase;
        prog.GenSeq(Pulse('674Switch2NovaTech',0,-1));
        prog.GenSeq(Pulse('ExperimentTrigger',0,50));
        prog.GenSeq(Pulse('OffRes422',0,1000000)); %1 sec instead of 500 mu sec

        % set DDS freq and amp
        prog.GenSeq(Pulse('674DDS1Switch',0,-1,'freq',freq,'amp',100));
        % Doppler coolng
        prog.GenSeq(Pulse('OffRes422',0,1));%turn off cooling
        prog.GenSeq(Pulse('OnResCooling',0,dic.Tcooling) );
        prog.GenSeq(Pulse('OpticalPumping',0,dic.Toptpump));
        
        if waitt>0
            prog.GenPause(waitt*1000);     
        end
        
        prog.GenSeq(Pulse('OpticalPumping',0,dic.Toptpump));
%          prog.GenPause(10);
%         prog.GenSeq([Pulse('674PulseShaper',1,dic.TimeRF-2),...
%                      Pulse('RFDDS2Switch',2,dic.TimeRF)]);
        % wait 
%          prog.GenWait(10000); %half a second
        %sideband Shelving
        if (PulseTime>3)
           prog.GenSeq([Pulse('NoiseEater674',2,PulseTime-2),...
                        Pulse('674DDS1Switch',0,PulseTime)]);
        else
           prog.GenSeq(Pulse('674DDS1Switch',0,PulseTime));
        end
        % detection
        prog.GenSeq([Pulse('OnRes422',0,dic.TDetection) Pulse('PhotonCount',0,dic.TDetection)]);
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
        if (length(r))~=chunksize
            fprintf('chunksize=%g differs from retrieved date %g\n',chunksize,length(r));
        end
        %if chunksize>1
         %   r = r(2:end);
        %end
    end

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
        prog.GenPause(200000);     
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