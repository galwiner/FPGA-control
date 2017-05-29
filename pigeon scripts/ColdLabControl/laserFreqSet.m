function laserFreqSet(prog,laserNum,freq)

prog.GenSetAO('AO0',1);
prog.GenPause(1e6);
pulseSeq=[Pulse(1,1,1)];


end
