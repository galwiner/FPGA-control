function RFspectrum
dic=Dictator.me;
SecondpulseTime=7;
freqshift=1.2046*dic.FRF;

InitializeAxes (dic.GUI.sca(1),'Photons #','Cases Counted #','Fluorescence Histogram',...
                [0 dic.maxPhotonsNumPerReadout],[],0);

    freqList=-0.050:0.001:0.050;
    %-------------- set GUI ---------------
    lines =InitializeAxes (dic.GUI.sca(9),...
    'RF detune[MHz]','Pup','RF spectrum',...
    [freqList(1) freqList(end)],[],1);
    set(lines,'XData',[],'YData',[],...
              'LineWidth',0.5,'Marker','.','MarkerSize',10);

     %-------------- main scan loop -----------
    
    for index =1:length(freqList)
        if (dic.stop)
            return;
        end
        r = experimentSeq(freqList(index));
        Pup(index)=mean(r(2:2:end)>dic.darkCountThreshold);
        pause(0.2);
        gca = dic.GUI.sca(1);
        hist(r(2:2:end),1:2:dic.maxPhotonsNumPerReadout);
        AddLinePoint(lines,freqList(index),Pup(index));

    end
    %------------ Save data ------------------
    if (dic.AutoSaveFlag)
        destDir=dic.saveDir;
        thisFile=[mfilename('fullpath') '.m' ];
        [filePath fileName]=fileparts(thisFile);
        scriptText=fileread(thisFile);
        scriptText(find(int8(scriptText)==10))='';
        showData='figure;plot(freqList,Pup;xlabel(''RF freq[MHz]'');ylabel(''Pup'');';
        saveFileName=fullfile(destDir ,[fileName datestr(now,'-ddmmmyy-HHMMSS')]);
        dicParameters=dic.getParameters;
        save(saveFileName,'freqList','Pup','showData','dicParameters','scriptText');
        disp(['Save data in : ' saveFileName]);
    end 

%% ------------------------- Experiment sequence ------------------------------------    
    function [r,rep]=experimentSeq(par)%create and run a single sequence of detection
        prog=CodeGenerator; 
        prog.GenDDSPullParametersFromBase;

        prog.GenSeq( Pulse('674DDS1Switch',2,-1,'freq',dic.updateF674,'amp',100) );
        prog.GenSeq(Pulse('OnRes422',0,-1,'Amp',dic.weakOnResAmp));      
        prog.GenSeq(Pulse('RFDDS2Switch',0,-1,'freq',dic.FRF+par));
        prog.GenSeq(Pulse('OffRes422',0,500));
        prog.GenSeq(Pulse('OnResCooling',0,dic.Tcooling));
        
        prog.GenRegOp('RegA=',0);
        prog.GenRegOp('RegB=',0);
        prog.GenRegOp('RegC=',0);
        prog.GenSeq(Pulse('ExperimentTrigger',0,10));
        prog.GenRepeat
            prog.GenIfDo('RegC=',25)
                prog.GenRegOp('RegC=',0);
                prog.GenSeq([Pulse('Repump1092',0,50),...
                             Pulse('Repump1033',0,10)...
                             Pulse('OnResCooling',0,50)]);
                prog.GenRegOp('RegA=+1',0);
            prog.GenElseDo
                prog.GenPauseMemoryBlock;
                prog.GenSeq([Pulse('Repump1092',1,8),...
                             Pulse('OpticalPumping',2,5)]);
                prog.GenSeq([Pulse('674PulseShaper',1,dic.piHalfRF-1),...
                             Pulse('RFDDS2Switch',2,dic.piHalfRF)]);
                prog.GenSeq([Pulse('OnRes422',2,0.175),...
                             Pulse('PMTsAccumulate',3.00,0.125)]);
            prog.GenElseEnd;
            prog.GenRegOp('RegC=+1',0);
        prog.GenRepeatEnd('RegA>',100);
        %prog.GenRepeatEnd('RegB>0');
        prog.GenSeq(Pulse('Repump1092',0,0))
        prog.GenSeq(Pulse('OpticalPumping',2,dic.Toptpump));
        prog.GenSeq(Pulse('OnRes422',0,-1,'amp',dic.OnResAmp));      
        prog.GenRegOp('FIFO<-RegB',0);  
        % fisrt shelving pulse
        prog.GenSeq([Pulse('NoiseEater674',2,dic.T674-2) Pulse('674DDS1Switch',0,dic.T674)]);
        % second shelving pulse
        %prog.GenSeq(Pulse('674DDS1Switch',5,SecondpulseTime,'freq',dic.updateF674+freqshift));

        prog.GenSeq([Pulse('OnRes422',0,dic.TDetection)...
                     Pulse('PhotonCount',0,dic.TDetection)]);
        prog.GenSeq([Pulse('Repump1033',0,dic.T1033) Pulse('OffRes422',0,0)]);

        prog.GenFinish;
        %prog.DisplayCode;

        % FPGA/Host control
        n=dic.com.UploadCode(prog,20*(1:25));
        dic.com.UpdateFpga;
        dic.com.WaitForHostIdle;
        rep=100;
        dic.com.Execute(rep);
        dic.com.WaitForHostIdle;
        r=dic.com.ReadOut(-1);
       % r=reshape(typecast(uint16(r),'uint8'),2,[]);
    end
end


