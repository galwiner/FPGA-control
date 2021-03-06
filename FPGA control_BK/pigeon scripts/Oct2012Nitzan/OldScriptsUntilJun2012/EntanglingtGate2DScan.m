function EntanglingtGateDetuneScan

dic=Dictator.me;
pwr = 800;
eta = 0.028;

piTime = 6.32;

RabiFreq = 1/2/piTime;
epsilon = RabiFreq*4*eta;


beamsDetuneList =(-0.003:0.0003:0.000);
beamsShiftList = -0.001:0.0001:0.001;


% ------------Set GUI axes -------------
InitializeAxes(dic.GUI.sca(1),'Photons #','Cases Counted #','Fluorescence Histogram',...
    [0 dic.maxPhotonsNumPerReadout],[],0);

lines =InitializeAxes (dic.GUI.sca(9),...
    'Line Detune [MHz]','Dark Counts %','Entangling Gate',...
    [beamsDetuneList(1) beamsDetuneList(end)],[0 100],3);
% InitializeAxes (dic.GUI.sca(10),'detune','shift','PO',...
%     [beamsDetuneList(1) beamsDetuneList(end)],[beamsShiftList(1) beamsShiftList(end)],0);
% InitializeAxes (dic.GUI.sca(11),'detune','shift','P1',...
%     [beamsDetuneList(1) beamsDetuneList(end)],[beamsShiftList(1) beamsShiftList(end)],0);
InitializeAxes (dic.GUI.sca(10),'detune','shift','PO',...
    [beamsDetuneList(1) beamsDetuneList(end)],[],0);
InitializeAxes (dic.GUI.sca(11),'detune','shift','P1',...
    [beamsDetuneList(1) beamsDetuneList(end)],[],0);
set(lines(1),'Marker','.','MarkerSize',10,'Color','b');
set(lines(2),'Marker','.','MarkerSize',10,'Color','r');
set(lines(3),'Marker','.','MarkerSize',10,'Color','k');

P0 = zeros(length(beamsShiftList),length(beamsDetuneList));
P1 = P0;
P2 = P0;

dic.setNovatech4Amp(0,pwr);
dic.setNovatech4Amp(1,pwr);


% -------- Main function scan loops -------

for index1 = 1:length(beamsShiftList)
    set(lines(1),'Xdata',[],'Ydata',[]);
    set(lines(2),'Xdata',[],'Ydata',[]);
    set(lines(3),'Xdata',[],'Ydata',[]);
    for index2 = 1:length(beamsDetuneList)
        gateTime=abs(1/(beamsDetuneList(index2)-2.5e-3));
        dic.setNovatech4Freq(0,dic.updateF674+beamsShiftList(index1)-beamsDetuneList(index2)-dic.vibMode(1).freq);
        dic.setNovatech4Freq(1,dic.updateF674+beamsShiftList(index1)+beamsDetuneList(index2)+dic.vibMode(1).freq);
        pause(0.1);
        if dic.stop
            return
        end
        r=experimentSequence(gateTime,[1 2]);
        dic.GUI.sca(1); %get an axis from Dictator GUI to show data
        hist(r,0:1:(1.8*dic.maxPhotonsNumPerReadout));

        P0(index1,index2) = sum( r<dic.darkCountThreshold)/length(r)*100;
        P1(index1,index2) = sum((r>dic.darkCountThreshold)&(r<dic.TwoIonsCountThreshold))/length(r)*100;
        P2(index1,index2) = sum( r>dic.TwoIonsCountThreshold)/length(r)*100;
        AddLinePoint(lines(1),beamsDetuneList(index2),P0(index1,index2));
        AddLinePoint(lines(2),beamsDetuneList(index2),P1(index1,index2));
        AddLinePoint(lines(3),beamsDetuneList(index2),P2(index1,index2));
        dic.GUI.sca(10); 
        imagesc(beamsDetuneList,beamsShiftList,P0);
        dic.GUI.sca(11); 
        imagesc(beamsDetuneList,beamsShiftList,P1);
        pause(0.1);
    end
end

%--------------- Save data ------------------
if (dic.AutoSaveFlag)
    destDir=dic.saveDir;
    thisFile=[mfilename('fullpath') '.m' ];
    [filePath fileName]=fileparts(thisFile);
    scriptText=fileread(thisFile);
    %showData='figure;plot(beamsShiftList,PO,beamsShiftList,P1,beamsShiftList,P2);xlabel(''Line Detune [MHz]'');ylabel(''population[%]'');';
    showData='disp(''no display for now'');';
    saveFileName=fullfile(destDir ,[fileName datestr(now,'-ddmmmyy-HHMMSS')]);
    dicParameters=dic.getParameters;
    save(saveFileName,'beamsShiftList','beamsDetuneList','P0','P1','P2','showData','dicParameters','scriptText');
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
        rep=200;
        dic.com.Execute(rep);
        dic.com.WaitForHostIdle;
        r = dic.com.ReadOut(rep);
        r = r(2:end);
    end

end