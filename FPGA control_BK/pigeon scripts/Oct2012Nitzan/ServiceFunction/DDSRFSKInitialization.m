function DDSRFSKInitialization (DDSnum,freq)

dic=Dictator.me;
prog= CodeGenerator;
prog.GenDDSPullParametersFromBase;
prog.GenDDSResetPulse(DDSnum);
prog.GenPause(20);

prog.GenDDSInitialization(DDSnum,2);
prog.GenDDSBusState('20','20');% set the DAC output mode
prog.GenDDSWRBPulse(DDSnum);
prog.GenDDSIOUDPulse(DDSnum);
    
prog.GenDDSFrequencyWord(DDSnum,1,freq);
prog.GenDDSIPower(DDSnum,0);

prog.GenDDSPushParametersToBase;
prog.GenFinish;

dic.com.UploadCode(prog);
dic.com.UpdateFpga;
dic.com.WaitForHostIdle; % wait until host finished it last task
dic.com.Execute(1);
s=Semaphore.me;
s.release;