function CrystalCooling
dic=Dictator.me;
dic.Vkeith=1;
pause(2);
experimentSeq;
pause(2);
dic.Vkeith=1.7;
 
%% ------------------------- Experiment sequence ------------------------------------    
    function experimentSeq%create and run a single sequence of detection
        prog=CodeGenerator; 
        prog.GenSeq(Pulse('ExperimentTrigger',0,50));
        %set-up detection(also=optical repump), 1092 and on-res cooling freq. 
        prog.GenSeq(Pulse('OnRes422',0,-1,'freq',180));
        prog.GenSeq(Pulse('Repump1092',0,0));
        prog.GenSeq(Pulse('OffRes422',0,5000));
        prog.GenSeq(Pulse('OnRes422',0,100000));
        prog.GenSeq([Pulse('OnRes422',100,dic.TDetection) Pulse('PhotonCount',100,dic.TDetection)]);
        prog.GenSeq(Pulse('OnRes422',0,-1,'freq',dic.F422onRes));
        prog.GenFinish;
        %prog.DisplayCode;

        % FPGA/Host control
        n=dic.com.UploadCode(prog);
        dic.com.UpdateFpga;
        dic.com.WaitForHostIdle;
        rep=1;
        dic.com.Execute(rep);
        dic.com.WaitForHostIdle;
        r=dic.com.ReadOut(rep);
    end
end


