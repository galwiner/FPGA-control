function EntanglingtGateDetuneScan

dic=Dictator.me;
pwr = 600;
eta = 0.04;

piTime = 7.82;
RabiFreq = 1/2/piTime;
epsilon = RabiFreq*4*eta;
% epsilon = 0;
beamsDetune = dic.vibMode(2).freq+epsilon;
% beamsDetune =0.5;
gateTime = 2/epsilon;
beamsShiftList = -0.03:0.002:0.03;
beamsShiftList = -0.00:0.0005:0.015;

% ------------Set GUI axes -------------
InitializeAxes(dic.GUI.sca(1),'Photons #','Cases Counted #','Fluorescence Histogram',...
    [0 dic.maxPhotonsNumPerReadout],[],0);

lines =InitializeAxes (dic.GUI.sca(9),...
    'Line Detune [MHz]','Dark Counts %','Entangling Gate',...
    [beamsShiftList(1) beamsShiftList(end)],[0 100],3);

set(lines(1),'Marker','.','MarkerSize',10,'Color','b');
set(lines(2),'Marker','.','MarkerSize',10,'Color','k');
set(lines(3),'Marker','.','MarkerSize',10,'Color','r');

P0 = zeros(size(beamsShiftList));
P1 = P0;
P2 = P0;

dic.setNovatech4Amp(0,pwr);
dic.setNovatech4Amp(1,pwr*1.08);
% -------- Main function scan loops -------

for index1 = 1:length(beamsShiftList)
    dic.setNovatech4Freq(0,dic.updateF674+beamsShiftList(index1)-beamsDetune);
    dic.setNovatech4Freq(1,dic.updateF674+beamsShiftList(index1)+beamsDetune);
    if dic.stop
        return
    end
    r=experimentSequence(gateTime,[1 2]);
    dic.GUI.sca(1); %get an axis from Dictator GUI to show data
    hist(r,0:1:(1.8*dic.maxPhotonsNumPerReadout));

    P0(index1) = sum( r<dic.darkCountThreshold)/length(r)*100;
    P1(index1) = sum((r>dic.darkCountThreshold)&(r<dic.TwoIonsCountThreshold))/length(r)*100;
    P2(index1) = sum( r>dic.TwoIonsCountThreshold)/length(r)*100;
    AddLinePoint(lines(1),beamsShiftList(index1),P0(index1));
    AddLinePoint(lines(2),beamsShiftList(index1),P1(index1));
    AddLinePoint(lines(3),beamsShiftList(index1),P2(index1));
    pause(0.1);
end


%--------------- Save data ------------------
if (dic.AutoSaveFlag)
    destDir=dic.saveDir;
    thisFile=[mfilename('fullpath') '.m' ];
    [filePath fileName]=fileparts(thisFile);
    scriptText=fileread(thisFile);
    showData='figure;plot(beamsShiftList,PO,beamsShiftList,P1,beamsShiftList,P2);xlabel(''Line Detune [MHz]'');ylabel(''population[%]'');';
    saveFileName=fullfile(destDir ,[fileName datestr(now,'-ddmmmyy-HHMMSS')]);
    dicParameters=dic.getParameters;
    save(saveFileName,'beamsShiftList','P0','P1','P2','showData','dicParameters','scriptText');
    disp(['Save data in : ' saveFileName]);
end


%--------------------------------------------------------------------
    function r=experimentSequence(pulseTime,Mode2Cool)

        prog=CodeGenerator;
        prog.GenDDSPullParametersFromBase;
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
        prog.GenSeq(Pulse('674Switch2NovaTech',0,pulseTime));

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