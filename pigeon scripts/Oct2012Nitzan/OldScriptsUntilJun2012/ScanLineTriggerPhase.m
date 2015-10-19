function ScanLineTriggerPhase

dic=Dictator.me;
pwr = 300;
beamsDetune =0.013;
gateTimeList = 350:10:410;
triggerDelayTimeList = [0:3:36]*1e3;
numOfMeasPerPoint = 10;


% ------------Set GUI axes -------------
InitializeAxes(dic.GUI.sca(1),'Photons #','Cases Counted #','Fluorescence Histogram',...
    [0 dic.maxPhotonsNumPerReadout],[],0);

InitializeAxes (dic.GUI.sca(10),'T_{gate}','T_{trigger}','Mean P1',...
    [gateTimeList(1) gateTimeList(end)],[triggerDelayTimeList(1) triggerDelayTimeList(end)],0);
InitializeAxes (dic.GUI.sca(11),'T_{gate}','T_{trigger}','P1 STD',...
    [gateTimeList(1) gateTimeList(end)],[triggerDelayTimeList(1) triggerDelayTimeList(end)],0);

meanMap = zeros(length(triggerDelayTimeList),length(gateTimeList));
stdMap = zeros(length(triggerDelayTimeList),length(gateTimeList));

destDir=dic.saveDir;
thisFile=[mfilename('fullpath') '.m' ];
[filePath fileName]=fileparts(thisFile);
scriptText=fileread(thisFile);
showData='disp(''No figures to display'')';
saveFileName=fullfile(destDir ,[fileName datestr(now,'-ddmmmyy-HHMMSS')]);

dic.setNovatech4Amp(0,pwr);
dic.setNovatech4Amp(1,pwr);
dic.setNovatech4Freq(0,dic.updateF674-beamsDetune-dic.vibMode(2).freq);
dic.setNovatech4Freq(1,dic.updateF674+beamsDetune+dic.vibMode(2).freq);
pause(0.1);

dic.GUI.sca(10);
imagesc(gateTimeList,triggerDelayTimeList,meanMap);
colorbar
dic.GUI.sca(11);
imagesc(gateTimeList,triggerDelayTimeList,stdMap);
colorbar

% -------- Main function scan loops -------
for index1 = 1:length(gateTimeList)

    for index2 = 1:length(triggerDelayTimeList)
        P1Measurements = zeros(1,numOfMeasPerPoint);
        for index3 = 1:numOfMeasPerPoint
            if dic.stop
                return
            end
            r=experimentSequence(gateTimeList(index1),[1 2],triggerDelayTimeList(index2));
            dic.GUI.sca(1); %get an axis from Dictator GUI to show data
            hist(r,0:1:(1.8*dic.maxPhotonsNumPerReadout));
            P1Measurements(index3) = sum((r>dic.darkCountThreshold)&(r<dic.TwoIonsCountThreshold))/length(r)*100;
        end
        meanMap(index2,index1) = mean(P1Measurements);
        stdMap(index2,index1) = std(P1Measurements);
        dic.GUI.sca(10);
        imagesc(gateTimeList,triggerDelayTimeList,meanMap);
        dic.GUI.sca(11);
        imagesc(gateTimeList,triggerDelayTimeList,stdMap);
        pause(0.1);

    end
    dicParameters=dic.getParameters;
    save(saveFileName,'gateTimeList','triggerDelayTimeList','pwr','numOfMeasPerPoint','beamsDetune','meanMap','stdMap','showData','dicParameters','scriptText');
    disp(['Saved data in : ' saveFileName]);

end

%--------------------------------------------------------------------
    function r=experimentSequence(pulseTime,Mode2Cool,triggerDelayTime)

        prog=CodeGenerator;
        prog.GenDDSPullParametersFromBase;
        prog.GenWaitExtTrigger;
        prog.GenPause(triggerDelayTime);
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
        prog.GenSeq([Pulse('674PulseShaper',0,pulseTime),...
            Pulse('674Switch2NovaTech',0,pulseTime+5)]);

        % detection
        prog.GenSeq([Pulse('OnRes422',0,dic.TDetection) Pulse('PhotonCount',0,dic.TDetection)]);
        %resume cooling
        prog.GenSeq(Pulse('Repump1033',0,dic.T1033));
        prog.GenSeq(Pulse('OffRes422',0,0));
        prog.GenFinish;

        dic.com.UploadCode(prog);
        dic.com.UpdateFpga;
        dic.com.WaitForHostIdle;
        rep=400;
        dic.com.Execute(rep);
        dic.com.WaitForHostIdle;
        r = dic.com.ReadOut(rep);
        r = r(2:end);
    end

end