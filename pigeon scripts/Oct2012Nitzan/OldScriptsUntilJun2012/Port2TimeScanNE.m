function Port2TimeScanNE
dic = Dictator.me;

timeScanList = 1:50;

InitializeAxes(dic.GUI.sca(1),'Photons #','Cases Counted #','Fluorescence Histogram',...
    [0 dic.maxPhotonsNumPerReadout],[],0);

line =InitializeAxes (dic.GUI.sca(9),...
    'Time [\musec]','Dark Counts %','\pi Time Scan',...
    [min(timeScanList) max(timeScanList)],[0 100],1);
set(line,'Marker','.','MarkerSize',10,'Color','b');

dic.setNovatech4Amp(2,1000);
for index = 1:length(timeScanList)
    if dic.stop
        return
    end
    dic.setNovatech4Freq(2,dic.updateF674);
    r=experimentSequence([],[1 2],timeScanList(index));
    darkCounts = sum( r<dic.darkCountThreshold)/length(r)*100;
    AddLinePoint(line,timeScanList(index),darkCounts);
    pause(0.1);
end
%--------------------------------------------------------------------
    function r=experimentSequence(pulseTime,Mode2Cool,validationPulseTime)

        prog=CodeGenerator;
        prog.GenDDSPullParametersFromBase;
        prog.GenWaitExtTrigger;
        prog.GenSeq(Pulse('ExperimentTrigger',0,50));
        prog.GenSeq(Pulse('674DDS1Switch',0,-1,'amp',100));
        % Doppler coolng
        prog.GenSeq(Pulse('OffRes422',0,100));%turn off cooling
        prog.GenSeq(Pulse('OnResCooling',0,dic.Tcooling));

        % ---------continuous GSC -------------
        SeqGSC=[]; N=4; Tstart=2;
        for mode=Mode2Cool
            SeqGSC=[SeqGSC,Pulse('NoiseEater674',Tstart,dic.vibMode(mode).coolingTime/N),...
                Pulse('674DDS1Switch',Tstart,dic.vibMode(mode).coolingTime/N,...
                'freq',dic.updateF674+dic.vibMode(mode).freq+dic.acStarkShift674)];
            Tstart=2+Tstart+dic.vibMode(mode).coolingTime/N;
        end
        prog.GenSeq([Pulse('Repump1033',0,0), Pulse('OpticalPumping',0,0)]);
        prog.GenRepeatSeq(SeqGSC,N);
        prog.GenSeq([Pulse('Repump1033',dic.T1033,-1), Pulse('OpticalPumping',dic.T1033,-1)]);
        % ---------- pulsed GSC ----------------
        for mode=fliplr(Mode2Cool)
            prog.GenRepeatSeq([Pulse('NoiseEater674',2,dic.vibMode(mode).coldPiTime),...
                Pulse('674DDS1Switch',2,dic.vibMode(mode).coldPiTime,'freq',dic.updateF674+dic.vibMode(mode).freq),...
                Pulse('Repump1033',dic.vibMode(mode).coldPiTime,dic.T1033),...
                Pulse('OpticalPumping',dic.vibMode(mode).coldPiTime+dic.T1033,dic.Toptpump)],2);
        end

        %---------- Gate Pulse -----------------
%         prog.GenSeq(Pulse('674Switch2NovaTech',0,0));
%         prog.GenSeq(Pulse('DO12',0,-1));
%         prog.GenPause(pulseTime+110);
%         prog.GenSeq(Pulse('DO12',0,0));
%         prog.GenSeq(Pulse('674Switch2NovaTech',0,-1));

        prog.GenSeq(Pulse('NovaTechPort2',0,0));
        prog.GenSeq(Pulse('DO12',0,-1));
        prog.GenSeq(Pulse('674Switch2NovaTech',0,validationPulseTime));
        prog.GenSeq(Pulse('DO12',0,0));
        prog.GenSeq(Pulse('NovaTechPort2',0,-1));

        % detection
        prog.GenSeq([Pulse('OnRes422',0,dic.TDetection) Pulse('PhotonCount',0,dic.TDetection)]);
        %resume cooling
        prog.GenSeq(Pulse('Repump1033',0,dic.T1033));
        prog.GenSeq(Pulse('OffRes422',0,0));
        prog.GenFinish;

        dic.com.UploadCode(prog);
        dic.com.UpdateFpga;
        dic.com.WaitForHostIdle;
        rep=200;
        dic.com.Execute(rep);
        dic.com.WaitForHostIdle;
        r = dic.com.ReadOut(rep);
        r = r(2:end);
    end

end