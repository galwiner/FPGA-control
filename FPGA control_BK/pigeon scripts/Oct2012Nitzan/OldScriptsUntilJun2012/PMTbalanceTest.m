function PMTbalanceTest
dic=Dictator.me;

InitializeAxes (dic.GUI.sca(1),'Photons #','Cases Counted #','Fluorescence Histogram',...
                [0 dic.maxPhotonsNumPerReadout],[],0);

    TimeList=0.025:0.050:0.9;
    %TimeList=1:1:10;
    %-------------- set GUI ---------------
    lines =InitializeAxes (dic.GUI.sca(9),...
    'Detection Window [\mus]','Photons Counts #','S_{1/2}-P_{1/2} Fluorescence',...
    [TimeList(1) TimeList(end)],[],2);
    set(lines(1),'XData',[],'YData',[],'Color','b',...
              'LineWidth',0.5,'Marker','.','MarkerSize',10);
    set(lines(2),'XData',[],'YData',[],'Color','r',...
              'LineWidth',0.5,'Marker','.','MarkerSize',10);

     %-------------- main scan loop -----------
    count1=zeros(size(TimeList));
    count2=count1;
    grid on ;
    for index =1:length(TimeList)
        if (dic.stop)
            return;
        end
        r = experimentSeq(TimeList(index));
        sr=sum(r);
        count1(index)=mean(r(1,:));
        count2(index)=mean(r(2,:));
        pause(0.5);
        gca = dic.GUI.sca(1);
        hist(sr,1:2:dic.maxPhotonsNumPerReadout);
        AddLinePoint(lines(1),TimeList(index),count1(index));
        AddLinePoint(lines(2),TimeList(index),count2(index));

    end
    dic.refresh('F422onRes'); %restore information prior to the scan.
    %------------ Save data ------------------
    if (dic.AutoSaveFlag)
        destDir=dic.saveDir;
        thisFile=[mfilename('fullpath') '.m' ];
        [filePath fileName]=fileparts(thisFile);
        scriptText=fileread(thisFile);
        scriptText(find(int8(scriptText)==10))='';
        showData='figure;plot(TimeList,count1,TimeList,count2);xlabel(''AOM freq[Mhz]'');ylabel(''photons'');';
        saveFileName=fullfile(destDir ,[fileName datestr(now,'-ddmmmyy-HHMMSS')]);
        dicParameters=dic.getParameters;
        save(saveFileName,'TimeList','count1','count2','showData','dicParameters','scriptText');
        disp(['Save data in : ' saveFileName]);
    end 

%% ------------------------- Experiment sequence ------------------------------------    
    function [r,rep]=experimentSeq(DetectionTime)%create and run a single sequence of detection
        prog=CodeGenerator; 
        prog.GenDDSPullParametersFromBase;
        %prog.GenSeq(Pulse('OnRes422',0,-1,'Amp',dic.weakOnResAmp));      
        prog.GenSeq(Pulse('ExperimentTrigger',0,50));
        prog.GenSeq(Pulse('RFDDS2',0,-1,'freq',dic.FRF));
        %set-up detection(also=optical repump), 1092 and on-res cooling freq. 
        %prog.GenSeq(Pulse('Repump1092',0,0,'freq',dic.F1092) );
        prog.GenSeq(Pulse('OffRes422',0,500));
        prog.GenSeq(Pulse('OnResCooling',0,dic.Tcooling));
        
        prog.GenRegOp('RegB=',0);
                       
        prog.GenSeq([Pulse('OnRes422',1,dic.TDetection),...
                    Pulse('PMTsAccumulate',1,dic.TDetection)]);

        prog.GenRegOp('FIFO<-RegB',0);       
        prog.GenSeq([Pulse('OffRes422',100,0) Pulse('Repump1092',0,0)]);
        prog.GenSeq(Pulse('OnRes422',0,-1,'amp',dic.OnResAmp));      
        prog.GenFinish;
        %prog.DisplayCode;

        % FPGA/Host control
        n=dic.com.UploadCode(prog);
        dic.com.UpdateFpga;
        dic.com.WaitForHostIdle;
        rep=100;
        dic.com.Execute(rep);
        dic.com.WaitForHostIdle;
        r=dic.com.ReadOut(-1);
        r=reshape(typecast(uint16(r),'uint8'),2,[]);
    end
end


