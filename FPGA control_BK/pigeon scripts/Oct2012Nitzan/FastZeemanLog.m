function valid=FastZeemanLog(varargin)
dic=Dictator.me;
savedata=1;

pulseTime=dic.TimeRF*7;
pulseAmp=10;
timeList=1:500;

%-------------- Set GUI figures ---------------------
InitializeAxes (dic.GUI.sca(1),'Photons #','Cases Counted #','Fluorescence Histogram',...
    [0 dic.maxPhotonsNumPerReadout],[],0);
lines =InitializeAxes (dic.GUI.sca(9),'FRF [MHz]','Dark Counts %','Shelving Line',...
    [timeList(1) timeList(end)],[0 100],3);
set(lines(1),'XData',[],'YData',[],'Marker','.','MarkerSize',10,'Color','b');
set(lines(2),'XData',[],'YData',[],'Marker','.','MarkerSize',10,'Color','r');
set(lines(3),'XData',[],'YData',[],'Marker','.','MarkerSize',10,'Color','k');
%-------------- Main function scan loops ---------------------
dark = zeros(length(timeList),2);
ULETrans=zeros(length(timeList),1);
    for index1 = 1:length(timeList)
%         CrystalCheckPMT;
        if dic.stop
            return
        end             
        % control the double pass frequency
        dic.setNovatech('DoublePass','freq',dic.updateF674,'amp',1000);
        pause(0.1);
        
        r=experimentSequence(dic.FRF-7.0e-3,pulseTime,pulseAmp);
        dic.GUI.sca(1);
        h=hist(r,1:1:dic.maxPhotonsNumPerReadout);
        
        ivec=dic.IonThresholds;
        tmpdark=0;
        for tmp=1:dic.NumOfIons
            tmpdark=tmpdark+sum((r>ivec(tmp))&(r<ivec(tmp+1)))*tmp;
        end
        tmpdark=100-tmpdark/length(r)/(dic.NumOfIons)*100;
        dark(index1,1)=tmpdark;
        AddLinePoint(lines(1),timeList(index1),dark(index1,1));       
        % check histogram for crystal melting
        if dic.NumOfIons>1
            if sum((r>3)&(r<50))/length(r)*100>25
                CrystalCheckPMT;
            end
        end

        r=experimentSequence(dic.FRF-3e-3,pulseTime,pulseAmp);
        dic.GUI.sca(1);
        hist(r,1:1:dic.maxPhotonsNumPerReadout);
        ivec=dic.IonThresholds;
        tmpdark=0;
        for tmp=1:dic.NumOfIons
            tmpdark=tmpdark+sum((r>ivec(tmp))&(r<ivec(tmp+1)))*tmp;
        end
        tmpdark=100-tmpdark/length(r)/(dic.NumOfIons)*100;
        dark(index1,2)=tmpdark;
        AddLinePoint(lines(2),timeList(index1),dark(index1,2));
%         % add laser 674 intensitiy
%         ULETrans(index1)=getLasersSnapshot('T674');
%         AddLinePoint(lines(3),timeList(index1),ULETrans(index1)/20);
        %------------ Save data ------------------
        
    end
    showData='figure;plot(timeList,dark); xlabel(''Time'');ylabel(''dark[%]'');';
    dic.save;
%%------------------------ experiment sequence -----------------
    function r=experimentSequence(pFreq,pTime,pAmp)
        prog=CodeGenerator;
        prog.GenDDSPullParametersFromBase;

        % set DDS freq and amp


        
        prog.GenSeq(Pulse('ExperimentTrigger',0,50));
        % Doppler coolng
        prog.GenSeq(Pulse('OffRes422',0,-1));%turn off cooling
        prog.GenSeq(Pulse('OnResCooling',10,dic.Tcooling));
        % update the noiseEater value
        prog.GenSeq([Pulse('674DDS1Switch',0,15,'freq',dic.SinglePass674freq,'amp',100),...
                     Pulse('NoiseEater674',2,12),...
                     Pulse('674DoublePass',0,15),...
                     Pulse('Repump1033',15,dic.T1033)]);
        prog.GenSeq(Pulse('RFDDS2Switch',2,-1,'freq',pFreq,'amp',pAmp)); 
        % Optical pumping
        prog.GenSeq(Pulse('OpticalPumping',1,dic.Toptpump));
        
        % RF pulse
        prog.GenSeq(Pulse('RFDDS2Switch',0,pTime));

        % Shelving pulse
        prog.GenSeq([Pulse('674DDS1Switch',2,dic.T674),Pulse('674DoublePass',0,dic.T674+2)]);

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

