function DDSparallelSetting
DDSnum=2;
dic=Dictator.me;
prog= CodeGenerator;
prog.GenDDSPullParametersFromBase;
prog.GenDDSResetPulse(DDSnum);
prog.GenPause(20);
prog.GenDDSInitialization(DDSnum,0);
prog.GenDDSFrequencyWord(DDSnum,1,2);
prog.GenDDSIPower(DDSnum,100);


prog.GenDDSBusState('1D',dec2hex(BinVec2Dec(current20Line)));
prog.GenDDSWRBPulse(DDSnum);
prog.GenDDSIOUDPulse(DDSnum);

prog.GenDDSPushParametersToBase;
prog.GenFinish;

dic.com.UploadCode(prog);
dic.com.UpdateFpga;
dic.com.WaitForHostIdle; % wait until host finished it last task
dic.com.Execute(1);
s=Semaphore.me;
s.release;