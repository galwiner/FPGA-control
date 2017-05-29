function S2PlineScan
dic=Dictator.me;

InitializeAxes (dic.GUI.sca(1),'Photons #','Cases Counted #','Fluorescence Histogram',...
                [0 dic.maxPhotonsNumPerReadout],[],0);

if (dic.SitOnItFlag)
    cont=1;
    while (cont)
        if (dic.stop)
            cont=0;
        end
        r = experimentSeq(dic.F422onRes);
        r=sum(r);
        pause(0.01);
        dic.GUI.sca(1); %get an axis from Dictator GUI to show data
        hist(r,1:2:dic.maxPhotonsNumPerReadout);
        xlabel(num2str(round(mean(r)*10)/10),'FontSize',250);
    end
else
    freqList=200:1:220;
    %-------------- set GUI ---------------
    lines =InitializeAxes (dic.GUI.sca(9),...
    'F_{422} [MHz]','Photons Counts #','S_{1/2}-P_{1/2} Fluorescence',...
    [freqList(1) freqList(end)],[],2);
    set(lines(1),'XData',[],'YData',[],'Color','b',...
              'LineWidth',0.5,'Marker','.','MarkerSize',10);
    set(lines(2),'XData',[],'YData',[],'Color','r',...
              'LineWidth',0.5,'Marker','.','MarkerSize',10);

     %-------------- main scan loop -----------

    count1=zeros(size(freqList));
    count2=count1;
    grid on ;
    for index =1:length(freqList)
        if (dic.stop)
            return;
        end
        r = experimentSeq(freqList(index));
        sr=sum(r);
        count1(index)=mean(r(1,:));
        count2(index)=mean(r(2,:));
        pause(0.01);
        gca = dic.GUI.sca(1);
        hist(sr,1:2:dic.maxPhotonsNumPerReadout);
        AddLinePoint(lines(1),freqList(index),count1(index)+count2(index))
        %AddLinePoint(lines(2),freqList(index),count2(index))
    end
    dic.refresh('F422onRes'); %restore information prior to the scan.
    %------------ Save data ------------------
    if (dic.AutoSaveFlag)
        destDir=dic.saveDir;
        thisFile=[mfilename('fullpath') '.m' ];
        [filePath fileName]=fileparts(thisFile);
        scriptText=fileread(thisFile);
        showData='figure;plot(freqList,count1,freqList,count2);xlabel(''AOM freq[Mhz]'');ylabel(''photons'');';
        saveFileName=fullfile(destDir ,[fileName datestr(now,'-ddmmmyy-HHMMSS')]);
        dicParameters=dic.getParameters;
        save(saveFileName,'freqList','count1','count2','showData','dicParameters','scriptText');
        disp(['Save data in : ' saveFileName]);
    end 
end
%% ------------------------- Experiment sequence ------------------------------------    
    function [r,rep]=experimentSeq(freq)%create and run a single sequence of detection
        prog=CodeGenerator; 
        prog.GenDDSPullParametersFromBase;
        prog.GenSeq(Pulse('ExperimentTrigger',0,50));
        %set-up detection(also=optical repump), 1092 and on-res cooling
        %freq. 
        prog.GenSeq(Pulse('OffRes422',0,300));
        prog.GenSeq(Pulse('OnResCooling',0,dic.Tcooling));
       
        prog.GenRegOp('RegB=',0);
        prog.GenSeq(Pulse('OnRes422',3,-1,'freq',freq,'amp',1000));
        prog.GenPause(100);
        prog.GenRepeatSeq([Pulse('Repump1092',0,12),...
                           Pulse('OnResCooling',0,10),...
                           Pulse('OnRes422',15,0.5),...
                           Pulse('PMTsAccumulate',16,1)],2000);

        prog.GenRegOp('FIFO<-RegB',0);       
        prog.GenSeq(Pulse('OnRes422',3,-1,'freq',freq,'amp',dic.OnResAmp));
        prog.GenSeq([Pulse('OffRes422',100,0) Pulse('Repump1092',0,0)]);
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


