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
NumOfYpixels=100;

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
calllib('ATMCD32D','SetTriggerMode',1); %0 internal, 1 external 7 ext exposure
calllib('ATMCD32D','SetFastExtTrigger',0); %0 wait until keep clean cycle ends before snapshot, 1 - dont wait
calllib('ATMCD32D','SetEMCCDGain',255);
calllib('ATMCD32D','SetExposureTime',0.100);
calllib('ATMCD32D','SetShutter',0,0,100,0);% type,mode,close time[ms],opentime
calllib('ATMCD32D','GetDetector',par1,par2);
NumOfXpixels=300;%get(par1,'Value');
NumOfYpixels=100;%get(par2,'Value');
minX=200;
minY=280;
binX=1; 
binY=NumOfYpixels;
error=calllib('ATMCD32D','SetImage',binX,binY,minX,minX+NumOfXpixels-1,minY,minY+NumOfYpixels-1);  %int hbin, int vbin, int hstart, int hend, int vstart, int vend
NumOfYpixels=NumOfYpixels/binY;
NumOfXpixels=NumOfXpixels/binX;
im=uint16(zeros(NumOfXpixels,NumOfYpixels));
imPtr=libpointer('uint16Ptr',im);
%% data definition
Vdcl=-1.67; %left DC voltage
ftest=[0.98:0.002:1.05];%[0.97:0.0001:0.99]; %excitation frequency of secular mode via RF electrodes
r=zeros(NumOfXpixels,NumOfYpixels,length(ftest),length(Vdcl));
%% -------------- set GUI ---------------
InitializeAxes (dic.GUI.sca(1),'Photons #','Cases Counted #','Fluorescence Histogram',...
    [0 100],[0 1.5],1);

%lines =InitializeAxes (dic.GUI.sca(9),...
%    'Rep num ','Photons Counts #','S_{1/2}-P_{1/2} Fluorescence',...
%    [0 NumOfXpixels],[0 20000],1);
%line2d=InitializeAxes (dic.GUI.sca(8),...
%    'Vdcl(V) ','fexcite(MHz)','micromotion',...
%    [min(Vdcl) max(Vdcl)],[min(ftest) max(ftest)],1);
%% open keithley (change RF trap voltage)
keith=visa('ni','USB0::0x05E6::0x3390::1310276::INSTR');
fopen(keith);
Amp=1.9;
fprintf(keith,['VOLTage ' num2str(Amp) ' V']);
fclose(keith);
%% open novatech (to change ftest frequency)
novatech=openSerial('COM13','BaudRate',19200); %open novatec file id
novaAmp=50; %in units of 1/1024 of 1Volt
fprintf(novatech,'F1 3.0'); %Set f=3MHz for channel 1
fprintf(novatech,sprintf('V1 %.0f',novaAmp));
%% -------------- main scan loop -----------

grid on ;
count=0;
for index=1:length(Vdcl)
    dic.com.UpdateTrapElectrode(0,0,0,Vdcl(index),0)
    for index2=1:length(ftest)
        if (dic.stop)
            return;
        end
   %     fprintf(novatech,sprintf('F1 %.2f',20-ftest(index2)));
        pause(0.2);
        r(:,:,index2,index) = experimentSeq(21-ftest(index2));
        gca = dic.GUI.sca(9);
        cla;
        if (NumOfYpixels==1)
            plot(r(:,1,index2,index));
            dic.GUI.sca(10);
            cla;
            [m,I]=max(r(:,1,:,:));  
            m=reshape(m,length(ftest),length(Vdcl));
            %imagesc(Vdcl,ftest,m);
            %colorbar;
            plot(ftest,m);
            axis([min(ftest) max(ftest) 0 8000]);
        else
            pcolor(double(r(:,:,index2,index))');
            shading flat;
            colormap gray;
        end
        count=(index2+(index-1)*length(ftest))/(length(ftest)*length(Vdcl))*100;
        title(sprintf('cam snapshot %.0f %%',count));
        
        pause(1);
        %savedata;
    end

end

%% close the excitation of the RF
fprintf(novatech,'F1 3.0'); %Set f=3MHz for channel 1
fprintf(novatech,'V1 0');
fclose(novatech);

%% ------------ Save data ------------------
function savedata    
    if (dic.AutoSaveFlag)
        showData='figure; cla;[m,I]=max(r(:,1,:));I=reshape(I,1,[]); plot(I); xlabel(''exp #''); ylabel(''ion position''); title(sprintf(''Vkeith=%.2f'',Amp));';
        dicParameters=dic.getParameters;
        save(saveFileName,'repetitions','Amp','waittime','r','index','count','showData','dicParameters','scriptText');
        disp(['Save data in : ' saveFileName]);
    end
end


%% ------------------------- Experiment sequence ------------------------------------    
    function r=experimentSeq(freq) %create and run a single sequence of detection
        calllib('ATMCD32D','StartAcquisition');
        pause(0.5);
        prog=CodeGenerator;
        prog.GenDDSPullParametersFromBase;
        prog.GenSeq(Pulse('OffRes422',0,500));
        prog.GenSeq(Pulse('OnRes422',0,0));
        prog.GenSeq(Pulse('CameraTrigger',1,10000));
        
        prog.GenSeq(Pulse('OnRes422',0,-1));
        prog.GenSeq(Pulse('OffRes422',0,0));
        fprintf(novatech,sprintf('V1 %.0f',novaAmp));
        fprintf(novatech,sprintf('F1 %.2f',freq));        
        prog.GenPause(10000);
        fprintf(novatech,'F1 3.0');        
        fprintf(novatech,sprintf('V1 0'));
        
        prog.GenFinish;
        %prog.DisplayCode;
        % FPGA/Host control
        com=Tcp2Labview('localhost',6340);
        pause(0.1);
        com.UploadCode(prog);
        com.UpdateFpga;
        com.Execute(1);
        com.WaitForHostIdle;
        com.Delete;
        pause(0.5);
        calllib('ATMCD32D','GetStatus',par1);
        get(par1,'Value')
        [error,Image]=calllib('ATMCD32D','GetAcquiredData16',imPtr,int32(NumOfXpixels*NumOfYpixels));
        r=Image;

    end
end
