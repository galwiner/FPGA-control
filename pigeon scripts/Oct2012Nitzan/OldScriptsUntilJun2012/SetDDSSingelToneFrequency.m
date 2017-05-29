function SetDDSSingelToneFrequency (DDSnum,freq)

prog= CodeGenerator;
prog.GenDDSPullParametersFromBase;
prog.GenDDSFrequencyWord(DDSnum,1,freq);
prog.GenDDSPushParametersToBase;
prog.GenFinish;

dic=Dictator.me;

dic.com.UploadCode(prog);
dic.com.UpdateFpga;
dic.com.WaitForHostIdle; % wait until host finished it last task
dic.com.Execute(2);
s=Semaphore.me; 
s.release;