function testing_template

dic=Dictator.me;
    prog=CodeGenerator; 
    prog.GenDDSPullParametersFromBase;
    prog.GenRegOp('RegD=AI1+par1',-100);
    prog.GenRegOp('RegD=RegD*par2*2^par1',0,1);
    prog.GenSeq(Pulse('ExperimentTrigger',0,10));
    prog.GenSeq(Pulse('PhotonCount',0,10));
    prog.GenPause(1000000)
    prog.GenFinish;
    %prog.DisplayCode;

dic.com.UploadCode(prog);
dic.com.UpdateFpga;

rep=1;
%while (~dic.stop)
    dic.com.Execute(rep);
    dic.com.WaitForHostIdle;
    r=dic.com.ReadOut(-1);
    pause(0.1);
%end

end


