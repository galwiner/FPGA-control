function MicromotionWith674(varargin)
% *************** experiment description *******************************
% Vkeithley=3.1 (0.83V power)
% Both Vcap=50 Volts
% 674 beam = 1 (horizontal)

% setting experiments parameters; 
dic=Dictator.me;

FreqMM=str2num(query(dic.KeithUSB1,'Freq?'))/1e6;
detuneList=-FreqMM;
%timeList=50; 
if dic.curBeam==0 %674 beam horizontal at 45 deg to axial
    timeList=20; 
elseif dic.curBeam==1            %674 beam vertical 
    timeList=80; 
elseif dic.curBeam==2            %674 beam radial
    timeList=500; 
end

Vcomp=[0 15 30 45];
Vdcl=1.3+[-0.3:0.1:0.5]; 
dic.AVdcr=0;

%Vdcl=-1.776+[-0.24:0.061:0.24]; %left DC voltage
% AVdcl=-2.4:0.05:-1.8; %left DC voltage
% Vcomp=[-8.0:0.5:-4]; %compensation electrode
% % FINE TUNE scan of electrodes
% Vdcl=[-2.3:0.02:-2];
% Vcomp=[-6.7:0.05:-6];
darkBank=nan(length(Vdcl),length(Vcomp));
carrierBank=nan(length(Vdcl),length(Vcomp));
detectionEff=nan(length(Vdcl),length(Vcomp));
if (length(Vdcl)>1)&&(length(Vcomp)==1)
    darkCountsLine =InitializeAxes (dic.GUI.sca(11),...
                           'Vdcl(V)','Dark Counts %','Vdcl scan',...
                           [Vdcl(1) Vdcl(end)],[0 100],1);
   set(darkCountsLine,'Marker','.','MarkerSize',10);
elseif (length(Vdcl)==1)&&(length(Vcomp)>1)
    darkCountsLine =InitializeAxes (dic.GUI.sca(11),...
                           'Vcomp(V)','Dark Counts %','Vcomp scan',...
                           [Vcomp(1) Vcomp(end)],[0 100],1);
    set(darkCountsLine,'Marker','.','MarkerSize',10);
else 
    darkCountsLine=dic.GUI.sca(11);
    xlabel('Vcomp(V)'); ylabel('Vdcl(V)'); title('micromotion shelving eff');
    set(darkCountsLine,'XLim',[Vcomp(1) Vcomp(end)],'YLim',[Vdcl(1) Vdcl(end)]);
    detectionAx=dic.GUI.sca(7);
    xlabel('Vcomp(V)'); ylabel('Vdcl(V)'); title('detection eff');
    set(detectionAx,'XLim',[Vcomp(1) Vcomp(end)],'YLim',[Vdcl(1) Vdcl(end)]);
    carrierAx=dic.GUI.sca(10);
    xlabel('Vcomp(V)'); ylabel('Vdcl(V)'); title('carrier shelving eff');
end

% determine filename to save
destDir=dic.saveDir;
thisFile=[mfilename('fullpath') '.m' ];
[filePath fileName]=fileparts(thisFile);
saveFileName=fullfile(destDir ,[fileName datestr(now,'-ddmmmyy-HHMMSS')]);
if dic.resumeFlag
    lst=dir(fullfile(destDir,[fileName '*.mat']));
    for t=1:length(lst); lstdate{t}=lst(t).name(length([fileName '-'])+1:end-4); end
    [sorted,indx]=sort(lstdate);
    reply = input(sprintf('Do you want to resume last run from %s? Y/N [Y]: ',lstdate{indx(end)}), 's');
    if isempty(reply)
        reply = 'Y';
    end
    if (strcmp(reply,'Y'))
        load(fullfile(destDir,lst(indx(end)).name),'darkBank','detectionEff');
        [sind1,sind2]=find(isnan(darkBank),1);
    else
        sind2=1;
        sind1=1;
    end
else
    sind2=1;
    sind1=1;
end
% measurements loops
AVdclOrig=dic.AVdcl;
HPVcompOrig=dic.HPVcomp;
for ind2=sind2:length(Vcomp)
    
    for ind1=sind1:length(Vdcl)
        f674=dic.updateF674; %sets electrodes to default while updating F674
%         dic.com.UpdateTrapElectrode(0,0,0,Vdcl(ind1),Vcomp(ind2)); pause(1);
        dic.AVdcl=Vdcl(ind1);
        dic.HPVcomp=Vcomp(ind2);
        
        r=experimentSequence(timeList,f674+detuneList);
        % Plot fluorescence histogram
        dic.GUI.sca(1); %get histogram axes 
        hist(r,0:1:(2.5*dic.maxPhotonsNumPerReadout));
        dark = sum( r<dic.darkCountThreshold)/length(r)*100;
        darkBank(ind1,ind2)=dark;
        %perform carrier check
        rrr=experimentSequence(dic.T674,f674);
        dark = sum( rrr<dic.darkCountThreshold)/length(rrr)*100;
        carrierBank(ind1,ind2)=dark;
        % perform detection efficienct check
        rr = detectionSeq;
        rr(1) = [];
        detectionEff(ind1,ind2)=mean(rr);
        %plot
        if (length(Vdcl)>1)&&(length(Vcomp)==1)
            AddLinePoint(darkCountsLine,Vdcl(ind1),darkBank(ind1,ind2));
        elseif (length(Vdcl)==1)&&(length(Vcomp)>1)
            AddLinePoint(darkCountsLine,Vcomp(ind2),darkBank(ind1,ind2));
        else 
            axes(darkCountsLine);
            pcolor(Vcomp,Vdcl,darkBank); shading flat; colorbar;
            axes(detectionAx);
            pcolor(Vcomp,Vdcl,detectionEff); shading flat; colorbar;
            axes(carrierAx);
            pcolor(Vcomp,Vdcl,carrierBank); shading flat; colorbar;
        end
        
        
        
        stopLoop=dic.stop;
        dic.HPVcomp=HPVcompOrig;
        dic.AVdcl=AVdclOrig;
        pause(0.1);
        if stopLoop ||~CrystalCheckPMT
            dic.HPVcomp=HPVcompOrig;
            dic.AVdcl=AVdclOrig;
           return
        end
    end
    savenow;
end
dic.com.UpdateTrapElectrode(0,0,0,dic.Vdcl,dic.Vcomp); pause(1);
savenow;

function savenow
    if (dic.AutoSaveFlag)
        
        
        scriptText=fileread(thisFile);
        scriptText(find(int8(scriptText)==10))='';
        showData=['figure; if (length(Vdcl)>1)&&(length(Vcomp)==1)' ...
                'plot(Vdcl,darkBank); xlabel(''Vdcl(V)''); ylabel(''Dark Counts %'');' ...
                'elseif (length(Vdcl)==1)&&(length(Vcomp)>1)'...
                'plot(Vcomp,darkBank);xlabel(''Vcomp(V)''); ylabel(''Dark Counts %''); '...
                'else '...
                'imagesc(Vcomp,Vdcl,darkBank); shading flat; colorbar; xlabel(''Vcomp(V)''); ylabel(''Vdcl(V)''); title(''micronotion sb shelving eff'');' ...
                'figure; imagesc(Vcomp,Vdcl,carrierBank); shading flat; colorbar; xlabel(''Vcomp(V)''); ylabel(''Vdcl(V)''); title(''carrier shelving eff'');' ...
                'figure; imagesc(Vcomp,Vdcl,detectionEff); shading flat; colorbar; xlabel(''Vcomp(V)''); ylabel(''Vdcl(V)''); title(''detection eff'');' ...
                'end '];
        
        dicParameters=dic.getParameters;
        save(saveFileName,'Vdcl','Vcomp','detectionEff','carrierBank','detuneList','timeList','darkBank','showData','dicParameters','scriptText');
        disp(['Save data in : ' saveFileName]);
    end 
end
%----------------------------------------------------------------
    function r=experimentSequence(pulseTime,pulseFreq)
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
                     Pulse('674DDS1Switch',0,pulseTime,'freq',pulseFreq)]);

        
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

    function [r,rep]=detectionSeq %create and run a single sequence of detection
        freq=dic.F422onRes;
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

        rep=100;
        dic.com.Execute(rep);
        dic.com.WaitForHostIdle;
        r=dic.com.ReadOut(rep);
    end
end

