function TwoIonsCarrierRabi

dic=Dictator.me;
dic.numOfPigeonCodeRepetitions=200;


PulseTime=1:1:30;
% Set GUI axes
InitializeAxes (dic.GUI.sca(1),...
    'Photons #','Cases Counted #','Fluorescence Hist',...
    [0 1.2*dic.maxPhotonsNumPerReadout],[],0);
lines =InitializeAxes (dic.GUI.sca(4),...
    'Pulse time[\mus]','Dark Counts %','Rabi Scan',...
    [PulseTime(1) PulseTime(end)],[0 100],3);

set(lines(1),'Marker','.','MarkerSize',10,'color','b');
set(lines(2),'Marker','.','MarkerSize',10,'color','k');
set(lines(3),'Marker','.','MarkerSize',10,'color','r');

P0 = zeros(size(PulseTime));
P1=P0;
P2=P0;
for index1 = 1:length(PulseTime)
    if dic.stop
        return
    end
    r=experimentSequence(PulseTime(index1));
    dic.GUI.sca(1); %get an axis from Dictator GUI to show data
    hist(r,0:2:(1.2*dic.maxPhotonsNumPerReadout));
    P0(index1) = sum( r<dic.darkCountThreshold)/length(r)*100;
    P1(index1) = sum((r>dic.darkCountThreshold)&(r<dic.TwoIonsCountThreshold))/length(r)*100;
    P2(index1) = sum( r>dic.TwoIonsCountThreshold)/length(r)*100;
    AddLinePoint(lines(1),PulseTime(index1),P0(index1));
    AddLinePoint(lines(2),PulseTime(index1),P1(index1));
    AddLinePoint(lines(3),PulseTime(index1),P2(index1));
    pause(0.1);
end

%--------------------------------------------------------------------
    function r=experimentSequence(pulseTime)
        prog=CodeGenerator;
        prog.GenDDSPullParametersFromBase;
        prog.GenSeq(Pulse('ExperimentTrigger',0,50));
        % Doppler coolng
        prog.GenSeq(Pulse('OffRes422',0,100));%turn off cooling
        prog.GenSeq(Pulse('OnResCooling',0,dic.Tcooling));
        prog.GenSeq(Pulse('OpticalPumping',0,dic.Toptpump));
        %Shelving
        %prog.GenSeq(Pulse('674DDS1',2,pulseTime,'freq',dic.updateF674));
        prog.GenSeq([Pulse('NoiseEater674',2,pulseTime),...
                     Pulse('674DDS1',2,pulseTime,'freq',dic.updateF674)]);

        % detection
        prog.GenSeq([Pulse('OnRes422',0,dic.TDetection) Pulse('PhotonCount',0,dic.TDetection)]);
        %resume cooling
        prog.GenSeq(Pulse('Repump1033',0,dic.T1033));
        prog.GenSeq(Pulse('OffRes422',0,0));
        prog.GenFinish;

        dic.com.UploadCode(prog);
        dic.com.UpdateFpga;
        dic.com.WaitForHostIdle; % wait until host finished it last task
        dic.com.Execute(dic.numOfPigeonCodeRepetitions);
        dic.com.WaitForHostIdle;
        r = dic.com.ReadOut(dic.numOfPigeonCodeRepetitions);
        r = r(2:end);
    end

end