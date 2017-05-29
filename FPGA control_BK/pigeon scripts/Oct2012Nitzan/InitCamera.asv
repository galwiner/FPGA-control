function InitCamera(varargin)
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
calllib('ATMCD32D','SetExposureTime',0.020);
calllib('ATMCD32D','SetShutter',0,0,100,0);% type,mode,close time[ms],opentime
calllib('ATMCD32D','GetDetector',par1,par2);
NumOfXpixels=150;%get(par1,'Value');
NumOfYpixels=150;%get(par2,'Value');
minX=280;
minY=150;
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
waittime=1;%in milli-seconds
repetitions=1;
r=zeros(NumOfXpixels,NumOfYpixels,repetitions,length(waittime));
%% ------------------------- Experiment sequence ------------------------------------    
    function r=experimentSeq(pFreq,pTime,pAmp)%create and run a single sequence of detection
        calllib('ATMCD32D','StartAcquisition');
        pause(0.5);
        prog=CodeGenerator;
        prog.GenDDSPullParametersFromBase;
        prog.GenSeq(Pulse('OffRes422',0,500));
        
        % set DDS freq and amp
        prog.GenSeq(Pulse('ExperimentTrigger',0,50));
        % Doppler coolng
        prog.GenSeq(Pulse('OffRes422',0,1));%turn off cooling
        prog.GenSeq(Pulse('OnResCooling',10,dic.Tcooling));
        % update the noiseEater value

        prog.GenSeq(Pulse('674PulseShaper',0,0));
        
        if pAmp<50
            prog.GenSeq(Pulse('674DDS1Switch',2,-1,'freq',pFreq,'amp',100));            
            prog.GenSeq([Pulse('674DDS1Switch',0,15),...
                         Pulse('NoiseEater674',2,10),Pulse('674DoublePass',0,15),...        
                         Pulse('Repump1033',15,dic.T1033),...
                         Pulse('OpticalPumping',16+dic.T1033,dic.Toptpump)]);
            prog.GenSeq(Pulse('674DDS1Switch',2,-1,'amp',pAmp));
            prog.GenSeq([Pulse('674DDS1Switch',2,pTime),...
                         Pulse('NoiseEater674',3,pTime-1),...
                         Pulse('674DoublePass',2,pTime)]);
        else         
            prog.GenSeq(Pulse('674DDS1Switch',2,-1,'freq',pFreq,'amp',pAmp)); 
            %activate noise eater, move it to int hold and repump
            prog.GenSeq([Pulse('674DDS1Switch',0,15),...
                         Pulse('NoiseEater674',2,10),Pulse('674DoublePass',0,15),...        
                         Pulse('Repump1033',15,dic.T1033),...
                         Pulse('OpticalPumping',16+dic.T1033,dic.Toptpump)]);
            %drive the pi pulse
            prog.GenSeq([Pulse('674DDS1Switch',2,pTime),...
                         Pulse('674DoublePass',2,pTime)]);
        end
        
        
        
        exposuretime=100; % in millisec
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

% %%------------------------ experiment sequence -----------------
%     function r=experimentSequence(pFreq,pTime,pAmp)
%         prog=CodeGenerator;
%         prog.GenDDSPullParametersFromBase;
% 
%         % set DDS freq and amp
%         prog.GenSeq(Pulse('ExperimentTrigger',0,50));
%         % Doppler coolng
%         prog.GenSeq(Pulse('OffRes422',0,1));%turn off cooling
%         prog.GenSeq(Pulse('OnResCooling',10,dic.Tcooling));
%         % update the noiseEater value
% 
%         prog.GenSeq(Pulse('674PulseShaper',0,0));
%         
%         if pAmp<50
%             if strcmp(OscName,'674DDS1Switch')
%                 prog.GenSeq(Pulse('674DDS1Switch',2,-1,'freq',pFreq,'amp',100));            
%             end
%             prog.GenSeq([Pulse(OscName,0,15),...
%                          Pulse('NoiseEater674',2,10),Pulse('674DoublePass',0,15),...        
%                          Pulse('Repump1033',15,dic.T1033),...
%                          Pulse('OpticalPumping',16+dic.T1033,dic.Toptpump)]);
%             prog.GenSeq(Pulse('674DDS1Switch',2,-1,'amp',pAmp));
%             prog.GenSeq([Pulse(OscName,2,pTime),...
%                          Pulse('NoiseEater674',3,pTime-1),...
%                          Pulse('674DoublePass',2,pTime)]);
%         else         
%             if strcmp(OscName,'674DDS1Switch')
%                 prog.GenSeq(Pulse('674DDS1Switch',2,-1,'freq',pFreq,'amp',pAmp)); 
%             end
%             %activate noise eater, move it to int hold and repump
%             prog.GenSeq([Pulse('674DDS1Switch',0,15),...
%                          Pulse('NoiseEater674',2,10),Pulse('674DoublePass',0,15),...        
%                          Pulse('Repump1033',15,dic.T1033),...
%                          Pulse('OpticalPumping',16+dic.T1033,dic.Toptpump)]);
%             %drive the pi pulse
%             prog.GenSeq([Pulse(OscName,2,pTime),...
%                          Pulse('674DoublePass',2,pTime)]);
%         end
%         
%         prog.GenSeq(Pulse('674PulseShaper',0,1));
%         
%         % detection
%         prog.GenSeq([Pulse('OnRes422',0,dic.TDetection) Pulse('PhotonCount',0,dic.TDetection)]);
%         % resume cooling
%         prog.GenSeq(Pulse('Repump1033',0,dic.T1033));
% 
%         prog.GenSeq([Pulse('OffRes422',0,0) Pulse('Repump1092',0,0)]);
%         prog.GenFinish;    
%         dic.com.UploadCode(prog);
%         dic.com.UpdateFpga;
%         dic.com.WaitForHostIdle; % wait until host finished it last task
%         rep=100;
%         dic.com.Execute(rep);
%         dic.com.WaitForHostIdle;
%         r = dic.com.ReadOut(rep);
%         r = r(2:end);
%     end
% end
