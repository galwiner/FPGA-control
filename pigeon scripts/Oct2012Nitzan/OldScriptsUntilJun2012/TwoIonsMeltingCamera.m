function TwoIonsSwapCamera(varargin)
dic=Dictator.me;

Amp=3.1; minAmp=1.7;
Vcap=400;
minX=257;
minY=338;%261;
LaserHeatingFrequency=213;
doheat=1; theat=10000; % in microsec
waittime=[10000];
repetitions=50;
thresh=6200;

%% set filename information
destDir=dic.saveDir;
thisFile=[mfilename('fullpath') '.m' ];
[filePath fileName]=fileparts(thisFile);
scriptText=fileread(thisFile);
saveFileName=fullfile(destDir ,[fileName datestr(now,'-ddmmmyy-HHMMSS')]);

%% ------------------ init camera ----------------------------------
par1=libpointer('int32Ptr',0);
par2=libpointer('int32Ptr',0);
par3=libpointer('singlePtr',0);

DRV_NOT_INITIALIZED=20075;
DRV_IDLE=20073;
DRV_SUCCESS=20002;
addpath('C:\Program Files\Andor Luca\Drivers');
if (~libisloaded('ATMCD32D'))
    loadlibrary('ATMCD32D','ATMCD32D.H');
end
if (calllib('ATMCD32D','GetStatus',par1)==DRV_NOT_INITIALIZED)
    calllib('ATMCD32D','Initialize','');
    calllib('ATMCD32D','CoolerON');
    calllib('ATMCD32D','SetTemperature',-20);
else
    disp(sprintf('Already Initialized.'));
end    

pause(1);
calllib('ATMCD32D','SetAcquisitionMode',1);
calllib('ATMCD32D','SetReadMode',4);
calllib('ATMCD32D','SetHSSpeed',0,0);
calllib('ATMCD32D','GetNumberVSSpeeds',par1);
calllib('ATMCD32D','SetVSSpeed',0);
calllib('ATMCD32D','SetTriggerMode',7); %0 internal, 1 external 7 ext exposure
calllib('ATMCD32D','SetFastExtTrigger',0); %0 wait until keep clean cycle ends before snapshot, 1 - dont wait
calllib('ATMCD32D','SetEMCCDGain',255);
calllib('ATMCD32D','SetExposureTime',0.10);
calllib('ATMCD32D','SetShutter',0,0,100,0);% type,mode,close time[ms],opentime
calllib('ATMCD32D','GetDetector',par1,par2);
NumOfXpixels=130;%get(par1,'Value');
NumOfYpixels=15;%get(par2,'Value');

binX=1;

IntegrateLine=1;
if IntegrateLine 
    binY=NumOfYpixels;
else
    binY=1;
end

%binY=1;%NumOfYpixels;
error=calllib('ATMCD32D','SetImage',binX,binY,minX,minX+NumOfXpixels-1,minY,minY+NumOfYpixels-1);  %int hbin, int vbin, int hstart, int hend, int vstart, int vend
NumOfYpixels=NumOfYpixels/binY;
NumOfXpixels=NumOfXpixels/binX;
im=uint16(zeros(NumOfXpixels,NumOfYpixels));
imPtr=libpointer('uint16Ptr',im);
%% -------------- set GUI ---------------
InitializeAxes (dic.GUI.sca(1),'Photons #','Cases Counted #','Fluorescence Histogram',...
    [0 100],[0 1.5],1);

lines =InitializeAxes (dic.GUI.sca(9),...
    'x pixels ','y','LUCA snapshot',...
    [0 NumOfXpixels],[0 30000],1);
% set(lines,'XData',[],'YData',[],'Color',randRGBNoWhite,...
%     'LineWidth',0.5,'Marker','.','MarkerSize',10);
%% data definition

% waittime=linspace(1000,2000,2);%linspace(100,100,1); %in milli-seconds

r=nan(NumOfXpixels,NumOfYpixels,repetitions,length(waittime));
success=nan(repetitions,length(waittime));
%% open keithley (change RF trap voltage)
%keith=visa('ni','USB0::0x05E6::0x3390::1310276::INSTR');
keith=openUSB('USB0::0x05E6::0x3390::1310276::0::INSTR');

fprintf(keith,['VOLTage ' num2str(Amp) ' V']);
pause(1);
dic.Vcap=Vcap;
pause(1);

%% resume mechanism
if dic.resumeFlag
    lst=dir(fullfile(destDir,[fileName '*.mat']));
    for t=1:length(lst); lstdate{t}=lst(t).name(length([fileName '-'])+1:end-4); end
    [sorted,indx]=sort(lstdate);
    reply = input(sprintf('Do you want to resume last run from %s? Y/N [Y]: ',lstdate{indx(end)}), 's');
    if isempty(reply)
        reply = 'Y';
    end
    if (strcmp(reply,'Y'))
        load(fullfile(destDir,lst(indx(end)).name),'r');
%        load('E:\measrments\DataArchive\archive03-Jan-2012\TwoIonsMeltingCamera-03Jan12-143514.mat','r');
%         load('E:\measrments\DataArchive\archive04-Jan-2012\TwoIonsMeltingCamera-04Jan12-112854.mat','r');
        [w,sind1,sind2]=find(isnan(r),1);
    else
        sind2=1;
        sind1=1;
    end
else
    sind2=1;
    sind1=1;
end
%% -------------- main scan loop -----------
grid on ;


% y=experimentSeq(5000);
% gca = dic.GUI.sca(9);
% cla;
% plot(y);
% 
% 

firstShot=experimentSeq(1000,0,500);
gca = dic.GUI.sca(9);
cla;
plot(firstShot);
title('first shot for sanity check');
for index=sind2:length(waittime)
    fprintf('**************** waittime of %g\n',waittime(index));
    for count=sind1:repetitions
        fprintf('%d,',count);
%         defaultvalidation=validateCrystal;
        
        if (dic.stop)
            fclose(keith);
            return;
        end
        r(:,:,count,index) = experimentSeq(waittime(index),doheat,500);
        savedata;
        gca = dic.GUI.sca(9);
        cla;
        if (NumOfYpixels==1)
            plot(r(:,1,count,index));
            title(sprintf('cam snapshot %.0f',count));
            
            
            if NumOfIons(r(:,1,count,index),thresh)==2
                success(count,index)=1;
            else
%                 dic.resumeFlag=1;
%                 manualreject=input('Will stop now if you write anything','s');
%                 if ~isempty(manualreject)
%                     return;
%                 end
                success(count,index)=0;
                if ~validateCrystal
                    fprintf('Crystal desolved');
                    savedata;
%                     dic.resumeFlag=1;
                    return;
                end
            end
            
            dic.GUI.sca(11);
            y=reshape(r,size(r,1),[]);
            imagesc(y''); xlabel('x pixel'); ylabel('Exp index'); title(sprintf('Vkeith=%.2fV, Vcap=%.2f',Amp,Vcap));
                        
            dic.GUI.sca(10);
            succ=zeros(size(waittime));
            for tmp=1:length(waittime)
                idx=find(~isnan(success(:,tmp)));
                succ(tmp)=mean(success(idx,tmp))*100;
            end
            plot(waittime/1000,succ,'-x');
            xlabel('waittime(s)'); ylabel('crystal %');
            axis([min(waittime) (max(waittime)+1) 0 100]);
        else
            pcolor(double(r(:,:,count,index))');
            shading flat;
            colormap gray;
        end
        
         pause(1);
        
    end
    sind1=1; %resume from one again
end

fclose(keith);

% ------ make sure we have two ions ------
    function res=validateCrystal
%         shot=experimentSeq(0,0,100000);
        flag=1;
        attempts=0;
        while flag==1 
            
%         while (NumOfIons(shot,thresh)~=2)&&(attempts<6)
            attempts=attempts+1;
            gca = dic.GUI.sca(5);
%             title('Validating');
            title(sprintf('Validating: %.0f attempt',attempts));
            experimentSeq(0,0,100000);
            fprintf(keith,['VOLTage ' num2str(minAmp) ' V']);
            
%             shot=experimentSeq(0,0,500);
%             for t=linspace(Amp,minAmp,100)
%                 fprintf(keith,['VOLTage ' num2str(t) ' V']);
%                 pause(0.01);
%                 if (dic.stop)
%                     fclose(keith);
%                     return;
%                 end
%             end

            experimentSeq(0,0,500000);
            fprintf(keith,['VOLTage ' num2str(Amp) ' V']);
%             pause(0.5);
              
%             for t=linspace(minAmp,Amp,100)
%                 fprintf(keith,['VOLTage ' num2str(t) ' V']);
%                 pause(0.01);
%                 if (dic.stop)
%                     fclose(keith);
%                     return;
%                 end
%             end
%             shot=experimentSeq(0,0,500);
            shot=experimentSeq(0,0,100000);
            plot(shot);
            
            % condition is given to flag
            flag=(NumOfIons(shot,thresh)~=2)&&(attempts<6);
        end
        if NumOfIons(shot,thresh)==2
            res=true;
        else
            res=false;
        end
    end
%------------ Save data ------------------
    function savedata
        if (dic.AutoSaveFlag)
            %        showData='figure; cla;[m,I]=max(r(:,1,:));I=reshape(I,1,[]); plot(I); xlabel(''exp #''); ylabel(''ion position''); title(sprintf(''Vrf=3.1V, Vcap=%.2f'',Vcap));';
            showData='figure; cla;y=reshape(r,size(r,1),[]);imagesc(y''); xlabel(''x pixel''); ylabel(''Exp index''); title(sprintf(''Vkeith=%.2fV, Vcap=%.2f'',Amp,Vcap));';
            dicParameters=dic.getParameters;
            save(saveFileName,'repetitions','Vcap','minAmp','Amp','index','count','waittime','r','index','count','showData','dicParameters','scriptText');
            disp(['Save data in : ' saveFileName]);
        end
    end

    function out = NumOfIons (imageSum,thresh)
        maxValue = double(max(imageSum));
        if ~exist('thresh')
            binLine = double(imageSum>0.7*maxValue);
        else
            binLine = double(imageSum>max([thresh 0]));
        end
        binLine([1 end]) = 0;
        f = find(binLine);
        for index2 = 1:length(f)
            if (binLine(f(index2)+1)~=binLine(f(index2)))&&(binLine(f(index2)-1)~=binLine(f(index2)))
                binLine(f(index2)) = 0;
            end
        end
        idx = diff(binLine);
        %sanity check on peaks
        peakStarts=find(idx==1);
        peakEnds=find(idx==-1);
        peakCenters=floor((peakStarts+peakEnds)/2);
        peakWidths=peakEnds-peakStarts;
        if (length(peakStarts)==2)&&(sum(peakWidths>3)==2)&&(abs(diff(peakCenters))>4)
            out=2;
            hold on; plot(maxValue*binLine,'r'); hold off;
        else %maybe one ion
            
            binLine = double(imageSum>0.7*maxValue);
            binLine([1 end]) = 0;
            f = find(binLine);
            for index2 = 1:length(f)
                if (binLine(f(index2)+1)~=binLine(f(index2)))&&(binLine(f(index2)-1)~=binLine(f(index2)))
                    binLine(f(index2)) = 0;
                end
            end
            idx = diff(binLine);
            %sanity check on peaks
            peakStarts=find(idx==1);
            peakEnds=find(idx==-1);
            peakCenters=floor((peakStarts+peakEnds)/2);
            peakWidths=peakEnds-peakStarts;
            if (length(peakStarts)==1)&&(peakWidths>3)
                out=1;
                hold on; plot(maxValue*binLine,'r'); hold off;
            else
                out=-1;
            end
        end
    end
% ------------------------- Experiment sequence ------------------------------------
    function r=experimentSeq(waitt,Heat,offResTime)%create and run a single sequence of detection
        calllib('ATMCD32D','StartAcquisition');
        pause(0.5);
        prog=CodeGenerator;
        prog.GenDDSPullParametersFromBase;
        prog.GenSeq(Pulse('ExperimentTrigger',0,50));  
        % trial
        prog.GenSeq(Pulse('Repump1092',0,0,'freq',dic.F1092));
        
        prog.GenSeq(Pulse('OffRes422',0,offResTime));
        
        %set-up detection(also=optical repump), 1092 and on-res cooling freq.
        prog.GenSeq(Pulse('OnRes422',0,-1,'freq',dic.F422onResCool));
        if waitt>0
            prog.GenSeq(Pulse('OffRes422',0,100));
            prog.GenSeq(Pulse('OnResCooling',0,dic.Tcooling));
            
            if Heat==1
                % Heating with probe beam
                prog.GenSeq(Pulse('OnRes422',0,-1,'freq',LaserHeatingFrequency));
                prog.GenPause(2000);
                prog.GenSeq(Pulse('OnRes422',0,theat));
                prog.GenSeq(Pulse('OpticalPumping',0,dic.Toptpump));
                
                % brings back 422 to initial frequency for cooling
                prog.GenSeq(Pulse('OnRes422',0,-1,'freq',dic.F422onResCool));
            end
            prog.GenSeq(Pulse('Repump1092',0,-1));
            prog.GenSeq(Pulse('Repump1033',0,-1));

            %        prog.GenSeq(Pulse('Shutters',0,0));
            prog.GenPause(waitt*1000);
            %        prog.GenSeq(Pulse('Shutters',0,-1));
            %        prog.GenPause(5000); %convert to microseconds
            prog.GenSeq(Pulse('Repump1033',0,0));

        else
            prog.GenPause(1000);
        end
        
        
        %prog.GenPause(waitt*1000);
        %prog.GenSeq(Pulse('CameraTrigger',1,10000));
        %prog.GenSeq(Pulse('OnRes422',1,1000));
%         prog.GenSeq(Pulse('OffRes422',0,3000000));
        
        exposuretime=450;% in millisec
%         prog.GenSeq([Pulse('CameraTrigger',1,exposuretime*1000),...
%                             Pulse('OnRes422',1,exposuretime*1000)]);
        prog.GenSeq([Pulse('CameraTrigger',1,exposuretime*1000),...
            Pulse('OffRes422',1,exposuretime*1000) Pulse('Repump1092',1,exposuretime*1000)]);
        prog.GenSeq(Pulse('OffRes422',0,0));
        prog.GenSeq(Pulse('Repump1092',0,0));
        
        prog.GenFinish;
        %prog.DisplayCode;
        % FPGA/Host control
        com=Tcp2Labview('localhost',6340);
        pause(0.5);
        com.UploadCode(prog);
        com.UpdateFpga;
        com.Execute(1);
        com.WaitForHostIdle;
        com.Delete;
        pause(0.5);
        calllib('ATMCD32D','GetStatus',par1);
        get(par1,'Value');
        pause(0.5);
        [error,Image]=calllib('ATMCD32D','GetAcquiredData16',imPtr,int32(NumOfXpixels*NumOfYpixels));
        r=Image;
        
    end
end
