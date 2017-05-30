function EntanglingtGateTimeAndDetuneAndPower

dic=Dictator.me;
pwrList = 200:100:700;
beamsDetuneList =0.010:0.0005:0.0145;
gateTimeList = 200:10:500;
offset=0.0000;

% ------------Set GUI axes -------------
InitializeAxes(dic.GUI.sca(1),'Photons #','Cases Counted #','Fluorescence Histogram',...
    [0 dic.maxPhotonsNumPerReadout],[],0);

InitializeAxes (dic.GUI.sca(10),'Time','detuning','PO',...
    [gateTimeList(1) gateTimeList(end)],[beamsDetuneList(1) beamsDetuneList(end)],0);
InitializeAxes (dic.GUI.sca(11),'Time','detuning','P1',...
    [gateTimeList(1) gateTimeList(end)],[beamsDetuneList(1) beamsDetuneList(end)],0);

P0 = zeros(length(beamsDetuneList),length(gateTimeList),length(pwrList));
P1 = P0;
P2 = P0;

destDir=dic.saveDir;
thisFile=[mfilename('fullpath') '.m' ];
[filePath fileName]=fileparts(thisFile);
scriptText=fileread(thisFile);
showData='disp(''No figures to display'')';
saveFileName=fullfile(destDir ,[fileName datestr(now,'-ddmmmyy-HHMMSS')]);


% -------- Main function scan loops -------
for index1 = 1:length(pwrList)
    dic.setNovatech4Amp(0,pwrList(index1));
    dic.setNovatech4Amp(1,pwrList(index1));
    char(strcat({'Current DDS power:'},{' '},{num2str(pwrList(index1))}))
    for index2 = 1:length(beamsDetuneList)
        for index3 = 1:length(gateTimeList)

            dic.setNovatech4Freq(0,dic.updateF674-beamsDetuneList(index2)-dic.vibMode(2).freq+offset);
            dic.setNovatech4Freq(1,dic.updateF674+beamsDetuneList(index2)+dic.vibMode(2).freq+offset);
            pause(0.1);
            if dic.stop
                return
            end
            r=experimentSequence(gateTimeList(index3),[1 2]);
            dic.GUI.sca(1); %get an axis from Dictator GUI to show data
            hist(r,0:1:(1.8*dic.maxPhotonsNumPerReadout));

            P0(index2,index3,index1) = sum( r<dic.darkCountThreshold)/length(r)*100;
            P1(index2,index3,index1) = sum((r>dic.darkCountThreshold)&(r<dic.TwoIonsCountThreshold))/length(r)*100;
            P2(index2,index3,index1) = sum( r>dic.TwoIonsCountThreshold)/length(r)*100;

            dic.GUI.sca(10);
            imagesc(gateTimeList,beamsDetuneList,P0(:,:,index1));
            dic.GUI.sca(11);
            imagesc(gateTimeList,beamsDetuneList,P1(:,:,index1));
            pause(0.1);
        end
    end
    dicParameters=dic.getParameters;
    save(saveFileName,'gateTimeList','beamsDetuneList','pwrList','P0','P1','P2','showData','dicParameters','scriptText');
    disp(['Saved data in : ' saveFileName]);

end

%--------------------------------------------------------------------
    function r=experimentSequence(pulseTime,Mode2Cool)

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