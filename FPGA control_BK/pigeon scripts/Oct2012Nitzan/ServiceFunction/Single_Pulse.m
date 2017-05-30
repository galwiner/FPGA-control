function Single_Pulse(p)
prog=CodeGenerator;
prog.GenDDSPullParametersFromBase;
prog.GenSeq(p);
prog.GenFinish;
%prog.DisplayCode;
% FPGA/Host control
com=Tcp2Labview('localhost',6340);
pause(1);
com.UploadCode(prog);
com.UpdateFpga;
com.WaitForHostIdle;
com.Execute(1);  
com.Delete;