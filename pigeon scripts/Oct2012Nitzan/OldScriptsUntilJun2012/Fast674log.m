function valid=Fast674log(varargin)
dic=Dictator.me;
savedata=1;


ChannelSwitch('NovaTechPort2','on');
dic.setNovatech4Amp(0,0);dic.setNovatech4Amp(1,0);ChannelSwitch('DIO7','on');
dic.setNovatech4Amp(2,1000);      
pulseTime=dic.T674*90;
%pulseTime=10;
pulseAmp=1;
lineNum=3;
FreqSinglePass=77;
% puts 674 in normal mode
% dic.setNovatech4Amp(1,0);dic.setNovatech4Amp(2,0);
timeList=1:500;

%-------------- Set GUI figures ---------------------
InitializeAxes (dic.GUI.sca(1),'Photons #','Cases Counted #','Fluorescence Histogram',...
    [0 dic.maxPhotonsNumPerReadout],[],0);
lines =InitializeAxes (dic.GUI.sca(9),'F_{674} [MHz]','Dark Counts %','Shelving Line',...
    [timeList(1) timeList(end)],[0 100],2);
set(lines(1),'XData',[],'YData',[],'Marker','.','MarkerSize',10,'Color','b');
set(lines(2),'XData',[],'YData',[],'Marker','.','MarkerSize',10,'Color','r');

%-------------- Main function scan loops ---------------------
dark = zeros(length(timeList),2);

    for index1 = 1:length(timeList)
        if dic.stop
            return
        end
                
        % control the double pass frequency
        dic.setNovatech4Freq(2,dic.updateF674);
        pause(0.1);
        r=experimentSequence(FreqSinglePass-0.75e-3,pulseTime,pulseAmp);
        dic.GUI.sca(1);
        hist(r,1:1:dic.maxPhotonsNumPerReadout);
        if dic.TwoIonFlag
            dark(index1,1) =100-sum( (r>dic.TwoIonsCountThreshold)*2+...
                ((r>dic.darkCountThreshold)&(r<dic.TwoIonsCountThreshold))*1 ...
                )/2/length(r)*100;
        else
            dark(index1,1) = sum( r<dic.darkCountThreshold)/length(r)*100;
        end
        AddLinePoint(lines(1),timeList(index1),dark(index1,1));
        %freqShift=-(dark(index1,1)-50)/60*1e-3 ;
        freqShift=0;
        r=experimentSequence(FreqSinglePass-1.25e-3+freqShift,pulseTime,pulseAmp);
        dic.GUI.sca(1);
        hist(r,1:1:dic.maxPhotonsNumPerReadout);
        if dic.TwoIonFlag
            dark(index1,2) =100-sum( (r>dic.TwoIonsCountThreshold)*2+...
                ((r>dic.darkCountThreshold)&(r<dic.TwoIonsCountThreshold))*1 ...
                )/2/length(r)*100;
        else
            dark(index1,2) = sum( r<dic.darkCountThreshold)/length(r)*100;
        end
        AddLinePoint(lines(2),timeList(index1),dark(index1,2));
    end

    %------------ Save data ------------------
    if (dic.AutoSaveFlag&&savedata)
        destDir=dic.saveDir;
        thisFile=[mfilename('fullpath') '.m' ];
        [filePath fileName]=fileparts(thisFile);
        scriptText=fileread(thisFile);
        scriptText(find(int8(scriptText)==10))='';
        showData='figure;plot(timeList,dark);xlabel(''Time'');ylabel(''dark[%]'');';
        saveFileName=fullfile(destDir ,[fileName datestr(now,'-ddmmmyy-HHMMSS')]);
        dicParameters=dic.getParameters;
        save(saveFileName,'timeList','dark','showData','dicParameters','scriptText');
        disp(['Save data in : ' saveFileName]);
    end

%%------------------------ experiment sequence -----------------
    function r=experimentSequence(pFreq,pTime,pAmp)
        prog=CodeGenerator;
        prog.GenDDSPullParametersFromBase;

        % set DDS freq and amp
        prog.GenSeq(Pulse('674Switch2NovaTech',0,-1));        

        prog.GenSeq(Pulse('674DDS1Switch',2,-1,'freq',pFreq,'amp',100));
        prog.GenSeq([Pulse('NoiseEater674',4,15),...
                        Pulse('674DDS1Switch',2,20)]);
        prog.GenSeq(Pulse('Repump1033',0,dic.T1033));
        prog.GenSeq(Pulse('674DDS1Switch',2,-1,'amp',pAmp));           
        prog.GenSeq(Pulse('ExperimentTrigger',0,50));
        % Doppler coolng
        prog.GenSeq(Pulse('OffRes422',0,-1));%turn off cooling
        prog.GenSeq(Pulse('OnResCooling',10,dic.Tcooling));
        prog.GenSeq(Pulse('OpticalPumping',1,dic.Toptpump));
 
        prog.GenSeq(Pulse('674DDS1Switch',2,pTime));

         % detection
        prog.GenSeq([Pulse('OnRes422',0,dic.TDetection) Pulse('PhotonCount',0,dic.TDetection)]);
        %resume cooling
        prog.GenSeq(Pulse('Repump1033',0,dic.T1033));

        prog.GenSeq([Pulse('OffRes422',0,0) Pulse('Repump1092',0,0)]);
        prog.GenFinish;    
        dic.com.UploadCode(prog);
        dic.com.UpdateFpga;
        dic.com.WaitForHostIdle; % wait until host finished it last task
        rep=400;
        dic.com.Execute(rep);
        dic.com.WaitForHostIdle;
        r = dic.com.ReadOut(rep);
        r = r(2:end);
    end
end

