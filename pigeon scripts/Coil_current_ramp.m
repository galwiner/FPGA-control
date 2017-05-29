% This script generats a sequenec of currents through a coil via the PSU
% The PSU maps 0-10V on to 0-200A of current.
%%
prog=CodeGenerator;

%% Crreat a ramp of current from 0 to 95A at 5A jumps with 1S wait
pulseSeq={};
tstart = zeros(1,20);
tend = zeros(1,20);
Volt = zeros(1,20);
deltaT=2e6;
deltaT=2e7;
for i = 1:20
    tstart(1,i) = (i-1)*deltaT;
%     Volt(1,i) = VoltageFromCurrent(5*(i-1));
    Volt(1,i) = VoltageFromCurrent(50);
    pulseSeq{i} =  AnalogPulse('AO0',tstart(1,i),deltaT-1,Volt(1,i));
end
%%

prog.GenSeq(pulseSeq);
prog.GenFinish;
%prog.DisplayCode;


%FPGA/Host control
com=Tcp2Labview('localhost',6340);
pause(1);
com.UploadCode(prog);
com.UpdateFpga;
com.WaitForHostIdle;
com.Execute(1);  
com.Delete;