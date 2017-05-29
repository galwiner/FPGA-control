function TwoIonsSwapCamera(varargin)
dic=Dictator.me;
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
NumOfXpixels=100;
NumOfYpixels=50;

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
calllib('ATMCD32D','SetExposureTime',0.020);
calllib('ATMCD32D','SetShutter',0,0,100,0);% type,mode,close time[ms],opentime
calllib('ATMCD32D','GetDetector',par1,par2);
NumOfXpixels=200;%get(par1,'Value');
NumOfYpixels=100;%get(par2,'Value');
minX=200;
minY=250;
binX=1;

IntegrateLine=0;
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
    [0 NumOfXpixels],[0 20000],1);
% set(lines,'XData',[],'YData',[],'Color',randRGBNoWhite,...
%     'LineWidth',0.5,'Marker','.','MarkerSize',10);
%% data definition

waittime=1;%linspace(100,100,1); %in milli-seconds
repetitions=1;
r=zeros(NumOfXpixels,NumOfYpixels,repetitions,length(waittime));
% %% open keithley (change RF trap voltage)
% keith=visa('ni','USB0::0x05E6::0x3390::1310276::INSTR');
% fopen(keith);
% Amp=1.3;
% fprintf(keith,['VOLTage ' num2str(Amp) ' V']);
% fclose(keith);
%% -------------- main scan loop -----------
Vcap=500;
grid on ;
for index=1:length(waittime)
    for count=1:repetitions
        if (dic.stop)
            return;
        end
        r(:,:,count,index) = experimentSeq(waittime(index));
        gca = dic.GUI.sca(9);
        cla;
        if (NumOfYpixels==1)
            plot(r(:,1,count,index));
        else
            pcolor(double(r(:,:,count,index))');
            shading flat;
            colormap gray;
        end
        title(sprintf('cam snapshot %.0f',count));
        pause(1);
        savedata;
    end

end
 
    %------------ Save data ------------------
function savedata    
    if (dic.AutoSaveFlag)
        showData='figure; cla;[m,I]=max(r(:,1,:));I=reshape(I,1,[]); plot(I); xlabel(''exp #''); ylabel(''ion position''); title(sprintf(''Vrf=3.1V, Vcap=%.2f'',Vcap));';
        dicParameters=dic.getParameters;
        save(saveFileName,'repetitions','Vcap','waittime','r','index','count','showData','dicParameters','scriptText');
        disp(['Save data in : ' saveFileName]);
    end
end


%% ------------------------- Experiment sequence ------------------------------------    
    function r=experimentSeq(waitt)%create and run a single sequence of detection
        calllib('ATMCD32D','StartAcquisition');
        pause(0.5);
        prog=CodeGenerator;
        prog.GenDDSPullParametersFromBase;
        prog.GenSeq(Pulse('OffRes422',0,500));
        
        %prog.GenPause(waitt*1000);
        %prog.GenSeq(Pulse('CameraTrigger',1,10000));
        %prog.GenSeq(Pulse('OnRes422',1,1000));
        exposuretime=90; % in millisec
        prog.GenSeq([Pulse('CameraTrigger',1,exposuretime*1000),...
                     Pulse('OnRes422',1,exposuretime*1000)]);
        prog.GenSeq(Pulse('OffRes422',0,0));
        prog.GenFinish;
        %prog.DisplayCode;
        % FPGA/Host control
        com=Tcp2Labview('localhost',6340);
        pause(1);
        com.UploadCode(prog);
        com.UpdateFpga;
        com.Execute(1);
        com.WaitForHostIdle;
        com.Delete;
        pause(0.5);
        calllib('ATMCD32D','GetStatus',par1);
        get(par1,'Value')
        pause(1);
        [error,Image]=calllib('ATMCD32D','GetAcquiredData16',imPtr,int32(NumOfXpixels*NumOfYpixels));
        r=Image;

    end
end
