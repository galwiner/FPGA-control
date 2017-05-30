% Pigeon hello world script

prog=CodeGenerator;
prog.GenSetAO('AO0',1111);
prog.GenSetAO('AO1',1010);
prog.GenSetAO('AO1',1011);
prog.GenSeq([Pulse('DigOut0',0,1e6),Pulse('DigOut1',1000,1e6)]);
prog.GenSetAO('AO0',0);
prog.GenPause(1e6);

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