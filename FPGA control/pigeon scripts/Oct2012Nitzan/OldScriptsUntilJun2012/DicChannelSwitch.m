function DicChannelSwitch(Name,OnOff)

prog=CodeGenerator;
if (strcmp(lower(OnOff),'on'))
    prog.GenSeq(Pulse(Name,0,0));
else
    prog.GenSeq(Pulse(Name,0,-1));
end

prog.GenFinish;

dic=Dictator.me;

dic.com.UploadCode(prog);
dic.com.WaitForHostIdle;
dic.com.UpdateFpga;
dic.com.WaitForHostIdle; % wait until host finished it last task
dic.com.Execute(1);
% dic.com.WaitForHostIdle
s=Semaphore.me; 
s.release;