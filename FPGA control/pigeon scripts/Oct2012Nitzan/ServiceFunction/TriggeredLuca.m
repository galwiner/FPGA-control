function TriggeredLuca

% init camera
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
exposureTime=200; %in miliseconds
calllib('ATMCD32D','SetExposureTime',exposureTime/1000);
calllib('ATMCD32D','SetShutter',0,0,100,0);% type,mode,close time[ms],opentime
calllib('ATMCD32D','GetDetector',par1,par2);
%     NumOfXpixels=100;%get(par1,'Value');
%     NumOfYpixels=50;%get(par2,'Value');
NumOfXpixels=150;%get(par1,'Value');
NumOfYpixels=150;%get(par2,'Value');
minX=90+170;
minY=90+110;
binX=1;
IntegrateLine=0;
if IntegrateLine
    binY=NumOfYpixels;
else
    binY=1;
end
error=calllib('ATMCD32D','SetImage',binX,binY,minX,minX+NumOfXpixels-1,minY,minY+NumOfYpixels-1);  %int hbin, int vbin, int hstart, int hend, int vstart, int vend
NumOfYpixels=NumOfYpixels/binY;
NumOfXpixels=NumOfXpixels/binX;
im=uint16(zeros(NumOfXpixels,NumOfYpixels));
imPtr=libpointer('uint16Ptr',im);


% loop and show images
dic=Dictator.me;
figure(567);clf;
while ~dic.stop
    tmp=experimentSequence;
    m=min(min(tmp));
    M=max(max(tmp));
    imshow(tmp');
    caxis([400 800]);
end
    function r=experimentSequence
        calllib('ATMCD32D','StartAcquisition');
        prog=CodeGenerator;
        prog.GenDDSPullParametersFromBase;
        
        % set DDS freq and amp
        prog.GenSeq(Pulse('ExperimentTrigger',0,50));
        % detection
        prog.GenSeq([ Pulse('CameraTrigger',1,exposureTime*1000) Pulse('OnResCooling',0,exposureTime*1000)]);
        prog.GenPause(1000);
        prog.GenFinish;
        dic.com.UploadCode(prog);
        dic.com.UpdateFpga;
        dic.com.WaitForHostIdle; % wait until host finished it last task
        dic.com.Execute(1);
        dic.com.WaitForHostIdle;
        stam=dic.com.ReadOut(1);
        pause(0.5);
        calllib('ATMCD32D','GetStatus',par1);% fprintf('%s\n',get(par1,'Value')); pause(1);
        [error,Image]=calllib('ATMCD32D','GetAcquiredData16',imPtr,int32(NumOfXpixels*NumOfYpixels));
        r=Image;
    end
end