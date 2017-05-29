dic=Dictator.me;

prog=CodeGenerator;
prog.GenDDSPullParametersFromBase;
prog.GenSeq(Pulse('674Switch2NovaTech',0,-1));
prog.GenSeq(Pulse('ExperimentTrigger',0,50));
prog.GenSeq(Pulse('OffRes422',0,500));

% set DDS freq and amp
prog.GenSeq(Pulse('674DDS1Switch',0,-1,'freq',dic.F674,'amp',100));
% Doppler coolng
prog.GenSeq(Pulse('OffRes422',0,1));%turn off cooling
prog.GenSeq(Pulse('OnResCooling',0,dic.Tcooling) );
prog.GenSeq(Pulse('OpticalPumping',0,dic.Toptpump));

prog.GenPause(10*1000);     

prog.GenSeq(Pulse('OpticalPumping',0,dic.Toptpump));
PulseTime=dic.T674;
prog.GenSeq([Pulse('NoiseEater674',2,PulseTime-2),...
            Pulse('674DDS1Switch',0,PulseTime)]);
% detection
prog.GenSeq([Pulse('OnRes422',0,dic.TDetection) Pulse('PhotonCount',0,dic.TDetection)]);
%resume cooling
prog.GenSeq(Pulse('Repump1033',0,dic.T1033));
prog.GenSeq(Pulse('OffRes422',0,0));
prog.GenFinish;

% FPGA/Host control
n=dic.com.UploadCode(prog);
dic.com.UpdateFpga;
dic.com.WaitForHostIdle;

dic.com.Execute(1);
dic.com.WaitForHostIdle;
r=dic.com.ReadOut(-1);

fprintf('result=%g\n',r);