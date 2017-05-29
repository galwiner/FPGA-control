function MolmerSorensenBeamPowerCheck

dic=Dictator.me;
repetitions=40;

SBmode=2;

% PulseTime=12:0.4:20;  
PulseTime=8:1:50;  

% PulseTime=15:0.7:27;  
DoPowerCalibration=1;
CrystalCheckPMT;

%-------------- Set GUI figures ---------------------
InitializeAxes (dic.GUI.sca(1),'Photons #','Cases Counted #','Fluorescence Histogram',...
                [0 dic.maxPhotonsNumPerReadout],[],0);

lines =InitializeAxes (dic.GUI.sca(11),...
    'Time [mus]','Dark Counts %','Rabi Scan with Modulated Beams',...
    [PulseTime(1) PulseTime(end)],[0 100],2);
darkCountLine(1) = lines(1);
fitLine(1) = lines(2);
set(darkCountLine(1),'Marker','.','MarkerSize',10,'Color','b');

darkCountLine(2) = lines(2);
set(darkCountLine(2),'Marker','.','MarkerSize',10,'Color','r');

%-------------- main scan loop ---------------------
  

SeparationFactor=0.8;

% dic.GateInfo.RedAmp=250;
% dic.GateInfo.BlueAmp=250;

dic.setNovatech('Red','freq',dic.SinglePass674freq+SeparationFactor*dic.vibMode(SBmode).freq,'amp',dic.GateInfo.RedAmp);
dic.setNovatech('Blue','freq',dic.SinglePass674freq-SeparationFactor*dic.vibMode(SBmode).freq,'amp',dic.GateInfo.BlueAmp);


dark=zeros(2,size(PulseTime));
for index1 = 1:length(PulseTime)
    for lobeIndex = 1:2
        %select sideband
        if dic.stop
            return
        end
        dic.setNovatech('DoublePass','freq',dic.F674+SeparationFactor*(lobeIndex*2-3)*dic.vibMode(SBmode).freq/2,'amp',1000);
        r=experimentSequence(PulseTime(index1));
        dic.GUI.sca(1); %get an axis from Dictator GUI to show data
        hist(r,0:1:(1.8*dic.maxPhotonsNumPerReadout));
        ivec=dic.IonThresholds;
        tmpdark=0;
        for tmp=1:dic.NumOfIons
            tmpdark=tmpdark+sum((r>ivec(tmp))&(r<ivec(tmp+1)))*tmp;
        end
        tmpdark=100-tmpdark/length(r)/(dic.NumOfIons)*100;
        dark(lobeIndex,index1)=tmpdark;
        AddLinePoint(darkCountLine(lobeIndex),PulseTime(index1),dark(lobeIndex,index1));
        pause(0.1);
    end
end


%------------ Save data ------------------
showData='figure;plot(PulseTime,dark(1,:),''r'',PulseTime,dark(2,:),''b'');xlabel(''Detunning [Mhz]'');ylabel(''dark[%]'');';
dic.save;

%--------------------------------------------------------------------
%%------------------------ experiment sequence -----------------
    function r=experimentSequence(pTime)
        prog=CodeGenerator;
        prog.GenDDSPullParametersFromBase;

        % set DDS freq and amp
        prog.GenSeq(Pulse('ExperimentTrigger',0,50));
        % Doppler coolng
        prog.GenSeq(Pulse('OffRes422',0,1));%turn off cooling
        prog.GenSeq(Pulse('OnResCooling',10,dic.Tcooling));
        % update the noiseEater value
        prog.GenSeq([Pulse('674DDS1Switch',1,15,'amp',100),...
                     Pulse('NoiseEater674',2,10),Pulse('674DoublePass',0,15),...        
                     Pulse('Repump1033',15,15+dic.T1033)]);
        prog.GenSeq(Pulse('674DDS1Switch',2,-1,'amp',100));
        prog.GenSeq(Pulse('OpticalPumping',1,dic.Toptpump));
        % Gate pulse
        prog.GenSeq([Pulse('674PulseShaper',2,pTime+10),...
                     Pulse('674Gate',10,pTime),...
                     Pulse('674DoublePass',9,pTime+2)]);                 
        % detection
        prog.GenSeq([Pulse('OnRes422',0,dic.TDetection) Pulse('PhotonCount',0,dic.TDetection)]);
        %resume cooling
        prog.GenSeq(Pulse('Repump1033',0,dic.T1033));

        prog.GenSeq([Pulse('OffRes422',0,0) Pulse('Repump1092',0,0)]);
        prog.GenFinish;    
        dic.com.UploadCode(prog);
        dic.com.UpdateFpga;
        dic.com.WaitForHostIdle; % wait until host finished it last task
        rep=100;
        dic.com.Execute(rep);
        dic.com.WaitForHostIdle;
        r = dic.com.ReadOut(rep);
        r = r(2:end);
    end

end