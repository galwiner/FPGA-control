function DDSSingleToneFullPower (DDSnum,freq,pwr)
if ~exist('pwr')
    pwr = 100;
end
prog= CodeGenerator;
prog.GenDDSResetPulse(DDSnum);
prog.GenDDSInitialization(DDSnum,0);
prog.GenDDSFrequencyWord(DDSnum,1,freq);
prog.GenDDSIPower(DDSnum,pwr);
prog.GenDDSPushParametersToBase;
prog.GenFinish;

dic=Dictator.me;

dic.com.UploadCode(prog);
dic.com.UpdateFpga;
dic.com.WaitForHostIdle; % wait until host finished it last task
dic.com.Execute(2);
s=Semaphore.me; 
s.release;