% Blink coils and MOT

prog=CodeGenerator;

pulseSeq={Pulse('DigOut0',5e2,1e3),...
    AnalogPulse('AO0',7e2,1e3,8),AnalogPulse('AO0',2e3,1e3,5)}; %MOT laser on for 5 seconds
% pulseSeq={Pulse('DigOut0',0,0)};
prog.GenSeq(pulseSeq);
% prog.GenSetAO('AO1',(0/10)*2^15);
prog.GenFinish;
prog.DisplayCode;


% %FPGA/Host control
% com=Tcp2Labview('localhost',6340);
% pause(1);
% com.UploadCode(prog);
% com.UpdateFpga;
% com.WaitForHostIdle;
% com.Execute(1);  
% com.Delete;