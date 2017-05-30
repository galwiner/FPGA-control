close all;
clear all;
instrreset

prog=CodeGenerator;

prog.GenSetAO('AO0',2^15/64);

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