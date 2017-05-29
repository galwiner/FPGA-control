function single408Photon
dic=Dictator.me;

InitializeAxes (dic.GUI.sca(1),'Photons #','Cases Counted #','Fluorescence Histogram',...
                [0 dic.maxPhotonsNumPerReadout],[],0);

dic.SitOnItFlag=1;
if (dic.SitOnItFlag)
    cont=1;
    while (cont)
        if (dic.stop)
            cont=0;
        end
        r = experimentSeq(dic.updateF674,dic.T674);
        %r=sum(r);
%        r5_2 = experimentSeq(dic.updateF674-5.655,dic.T674);

        pause(0.01);
        dic.GUI.sca(1); %get an axis from Dictator GUI to show data
%        hist(r,1:1:);
        xlabel(['        H:' num2str(round(mean(r(1,:))*10)/10) ' V:' num2str(round(mean(r(2,:))*10)/10) ],'FontSize',150);

    end
    dic.SitOnItFlag=0;
else
%     %-------------- set GUI ---------------
%     lines =InitializeAxes (dic.GUI.sca(2),...
%     'F_{422} [MHz]','Photons Counts #','S_{1/2}-P_{1/2} Fluorescence',...
%     [dic.detection422ScanList(1) dic.detection422ScanList(end)],[],2);
%     set(lines(1),'XData',[],'YData',[],'Color','b',...
%               'LineWidth',0.5,'Marker','.','MarkerSize',10);
%     set(lines(2),'XData',[],'YData',[],'Color','r',...
%               'LineWidth',0.5,'Marker','.','MarkerSize',10);
% 
%      %-------------- main scan loop -----------
%     freqList=1:10;
%     count1=zeros(size(freqList));
%     count2=count1;
%     grid on ;
%     for index =1:length(freqList)
%         if (dic.stop)
%             return;
%         end
%         r = experimentSeq;
%         sr=sum(r);
%         count1(index)=mean(r(1,:));
%         count2(index)=mean(r(2,:));
%         pause(0.01);
%         gca = dic.GUI.sca(1);
%         hist(sr,1:2:dic.maxPhotonsNumPerReadout);
%         AddLinePoint(lines(1),freqList(index),count1(index))
%         AddLinePoint(lines(2),freqList(index),count2(index))
%     end
%     dic.refresh('F422onRes'); %restore information prior to the scan.
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
    function [r,rep]=experimentSeq(pFreq,pTime)%create and run a single sequence of detection
        prog=CodeGenerator; 
        prog.GenDDSPullParametersFromBase;
        prog.GenSeq(Pulse('674DDS1Switch',0,-1,'freq',pFreq,'amp',100));
        prog.GenSeq(Pulse('ExperimentTrigger',0,50));
        prog.GenSeq(Pulse('OffRes422',0,100));
        prog.GenSeq(Pulse('OnResCooling',0,dic.Tcooling));
       
        prog.GenRegOp('RegB=',0);
                       
        prog.GenRepeatSeq([Pulse('Repump1033',5,10),...
                           Pulse('OpticalPumping',5,5),...
                           Pulse('NoiseEater674',16,pTime),...
                           Pulse('674DDS1Switch',16,pTime),...
                           Pulse('Repump1033',18+pTime,1),...
                           Pulse('PMTsAccumulate',18.5+pTime,1)],1000);

        prog.GenRegOp('FIFO<-RegB',0);       
        prog.GenSeq([Pulse('OffRes422',100,0)]);

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


