function ChannelSwitch(Name,OnOff)

prog=CodeGenerator;
if (strcmp(lower(OnOff),'on'))
    prog.GenSeq(Pulse(Name,0,0));
else
    prog.GenSeq(Pulse(Name,0,-1));
end
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