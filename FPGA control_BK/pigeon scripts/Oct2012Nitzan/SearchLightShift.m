function SearchLightShift

dic=Dictator.me;
%dic.numOfPigeonCodeRepetitions=200;
%ShiftSpan=-0.05:0.004:0.1;

% ShiftSpan=-0.3:0.02:0.25;
%  ShiftSpan=-0.4:0.015:0.4;
 ShiftSpan=-0.25:0.02:0.25;

repetitions=100;
Mode2Cool=2;

%-------------- Set GUI figures ---------------------
InitializeAxes (dic.GUI.sca(1),'Photons #','Cases Counted #','Fluorescence Histogram',...
                [0 dic.maxPhotonsNumPerReadout],[],0);
lines =InitializeAxes (dic.GUI.sca(7),...
    'F [MHz]','Dark Counts %','Searching for light shift',...
    [ShiftSpan(1) ShiftSpan(end)],[0 100],2);
set(lines(1),'Marker','.','MarkerSize',10,'Color','b');
set(lines(2),'Color','k');

%-------------- Main function scan loops ---------------------
dark=zeros(size(ShiftSpan));
for index1 = 1:length(ShiftSpan)
    if dic.stop
        return
    end
    dic.setNovatech('DoublePass','freq',dic.updateF674,'amp',1000);                    
    r=experimentSequence(ShiftSpan(index1),Mode2Cool);
    ivec=dic.IonThresholds;
    tmpdark=0;
    for tmp=1:dic.NumOfIons
        tmpdark=tmpdark+sum((r>ivec(tmp))&(r<ivec(tmp+1)))*tmp;
    end
    tmpdark=100-tmpdark/length(r)/(dic.NumOfIons)*100;
    dark(index1)=tmpdark;
    AddLinePoint(lines(1),ShiftSpan(index1),dark(index1));
    pause(0.1);
end
[mainMeanFreq,mainFWHM,mainPeak,fittedCurve] = ...
    FitToGaussian(ShiftSpan,median(dark)-dark);
set(lines(2),'XData',ShiftSpan,'YData',median(dark)-fittedCurve);
dic.acStarkShift674 = mainMeanFreq;
%--------------- Save data ------------------

showData='figure;plot(ShiftSpan,dark);xlabel(''Shift freq [MHz]'');ylabel(''dark[%]'');';
dic.save;

%--------------------------------------------------------------------
    function r=experimentSequence(freqShift,mode)
        prog=CodeGenerator;
        prog.GenDDSPullParametersFromBase;
        prog.GenSeq(Pulse('ExperimentTrigger',0,50));
        prog.GenSeq(Pulse('674DDS1Switch',0,-1,'amp',100));
        % Doppler coolng
        prog.GenSeq(Pulse('OffRes422',0,1));%turn off cooling
        prog.GenSeq(Pulse('OnResCooling',0,dic.Tcooling));
        
        prog.GenSeq([Pulse('NoiseEater674',2,16),...
                     Pulse('674DoublePass',2,16),...
                     Pulse('674DDS1Switch',0,20)]); %NoiseEater initialization
        prog.GenSeq(Pulse('Repump1033',0,dic.T1033)); %cleaning D state
        
        % continuous GSC 
        prog.GenSeq([Pulse('674DDS1Switch',1,dic.vibMode(mode).coolingTime,'freq',dic.SinglePass674freq+dic.vibMode(mode).freq+freqShift),...
                     Pulse('674DoublePass',1,dic.vibMode(mode).coolingTime),...
                     Pulse('Repump1033',0,dic.vibMode(mode).coolingTime+dic.T1033),...
                     Pulse('OpticalPumping',0,dic.vibMode(mode).coolingTime+dic.T1033+dic.Toptpump)]);        
        % Red sideband Shelving
        prog.GenSeq([Pulse('674DDS1Switch',2,dic.vibMode(mode).hotPiTime,'freq',dic.SinglePass674freq+dic.vibMode(mode).freq),...
                     Pulse('674DoublePass',2,dic.vibMode(mode).hotPiTime)]);
        % detection
        prog.GenSeq([Pulse('OnRes422',0,dic.TDetection) Pulse('PhotonCount',0,dic.TDetection)]);
        %resume cooling
        prog.GenSeq(Pulse('Repump1033',0,dic.T1033));
        prog.GenSeq(Pulse('OffRes422',0,0));
        prog.GenFinish;
        
        dic.com.UploadCode(prog);
        dic.com.UpdateFpga;
        dic.com.WaitForHostIdle; % wait until host finished it last task
        dic.com.Execute(repetitions);
        dic.com.WaitForHostIdle;
        r = dic.com.ReadOut(repetitions);
        r = r(2:end);
    end 

end