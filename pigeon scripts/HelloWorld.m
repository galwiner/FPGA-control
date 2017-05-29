% Pigeon hello world script

prog=CodeGenerator;
% prog.GenSetAO('AO3',2^15);
% prog.GenSetAO('AO1',1010);
% prog.GenSetAO('AO1',1011);
prog.GenSeq({Pulse('DigOut0',1,1e7)});
% prog.GenSetAO('AO0',1);
% prog.GenPause(1e6);
% pulseSeq=[Pulse(1,1,1)];
% state=0;
% for i=0:20
%     state=~state;
%     pulseSeq(i+1)=Pulse('DigOut0',i*2*5e6,5e6);
%     
% end
% pulseSeq=[Pulse('DigOut0',0,1)];
% prog.GenSeq(pulseSeq);
% for ind=1:2:100
%     prog.GenSetAO('AO1',(2^16/2) * sin(ind*2*pi/50));
% end


prog.GenFinish;
prog.DisplayCode;
%FPGA/Host control
com=Tcp2Labview('localhost',6340);
pause(1);
com.UploadCode(prog);
com.UpdateFpga;
com.WaitForHostIdle;
com.Execute(1);  
com.Delete;