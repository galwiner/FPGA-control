function BasicMeltingCamera(varargin)
% this file measures the following scenerio - 
% two ions, trapped at high rf, become decrystalized when encountering 
% 422 on resonance beam. This means that they cannot undergo detection.
% The guess is that the compensation is very bad and needs coarse graining
% so that at least detection can be accomplished at high rf without
% de-crystalization.


dic=Dictator.me;
% camera parameters
minX=321;
minY=230;%261;
NumOfXpixels=130;
NumOfYpixels=15;
binX=1;
binY=NumOfYpixels;
% non-scan parameters
Amp=3.1; minAmp=1;
Vcap=50;
repetitions=1;
thresh=5200;
% scan parameters
AVdcl=[2.3:0.1:2.4]; 
HPVcomp=[40:10:50];
% putput parameters
r=nan(NumOfXpixels,repetitions,length(AVdcl),length(HPVcomp));
success=nan(repetitions,length(AVdcl),length(HPVcomp));
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
dic.Vcap=Vcap; %pause(3);
dic.Vkeith=Amp;
for idx1=1:length(HPVcomp)
    dic.HPVcomp=HPVcomp(idx1);
    for idx2=1:length(AVdcl)
        dic.AVdcl=AVdcl(idx2);
        for rep=1:repetitions
            if (dic.stop) 
                return;
            end
            % single sequence (snapshot after on resonance light)
            r(:,rep,idx2,idx1)=experimentSeq(1);
            dic.GUI.sca(9); cla; plot(r(:,rep,idx2,idx1));
            if NumOfIons(r(:,rep,idx2,idx1),thresh)==2
                success(rep,idx2,idx1)=1;
            else %try to recover
                success(rep,idx2,idx1)=0;
                fprintf('Trying to recover...');
                dic.Vkeith=minAmp; pause(1); dic.Vkeith=Amp;
                testImage=experimentSeq(0);
                if NumOfIons(testImage,thresh)~=2
                    fprintf('Crystal desolved\n');
                    %savedata;
                    return;
                else
                    fprintf('succeeded\n');
                end
            end
            % display results
            
            dic.GUI.sca(11); cla; y=reshape(r,size(r,1),[]); imagesc(y); ylabel('x pixel'); xlabel('Exp index'); title(sprintf('Vkeith=%.2fV, Vcap=%.2f',Amp,Vcap)); [m,n]=size(y); axis([1 n 1 m]);
            dic.GUI.sca(10); 
            succ=zeros(length(AVdcl),length(HPVcomp));
            for tmp1=1:length(HPVcomp)
                for tmp2=1:length(AVdcl)
                    idx=find(~isnan(success(:,tmp2,tmp1)));
                    succ(tmp2,tmp1)=mean(success(idx,tmp2,tmp1))*100;
                end
            end
            imagesc(AVdcl,HPVcomp,succ); axis([min(AVdcl) max(AVdcl) min(HPVcomp) max(HPVcomp)]);
            xlabel('Vdcl'); ylabel('Vcomp');
            shading flat;
            colorbar;
        end
    end
end
% ---------------- FUNCTION definition -----------------------
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
    function r=experimentSeq(onresBeforeSnap) %create and run a single sequence of detection
        calllib('ATMCD32D','StartAcquisition');
        pause(0.5);
        exposuretime=450;% in millisec
        if onresBeforeSnap
            Single_Pulse(Pulse('OnRes422',0,50*dic.TDetection));
        end
        Single_Pulse(Pulse('CameraTrigger',1,exposuretime*1000));
        calllib('ATMCD32D','GetStatus',par1);
        get(par1,'Value');
        pause(0.5);
        [error,Image]=calllib('ATMCD32D','GetAcquiredData16',imPtr,int32(NumOfXpixels*NumOfYpixels));
        r=Image;
    end
end
