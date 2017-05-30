function SearchLightShiftNew

dic=Dictator.me;
%dic.numOfPigeonCodeRepetitions=200;
%ShiftSpan=-0.05:0.004:0.1;

% ShiftSpan=-0.3:0.02:0.25;
%  ShiftSpan=-0.4:0.015:0.4;
 ShiftSpan=-0.25:0.015:0.25;

repetitions=200;
Mode2Cool=1;
dic.setNovatech4Amp(1,0);dic.setNovatech4Amp(0,0);ChannelSwitch('DIO7','on');
ChannelSwitch('NovaTechPort2','on'); % DDS on
dic.setNovatech4Amp(3,0);

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
    
    Freq674SinglePass=77;

    r=experimentSequence(ShiftSpan(index1),Mode2Cool);
    if dic.TwoIonFlag
        dark(index1) =100-sum( (r>dic.TwoIonsCountThreshold)*2+...
                             ((r>dic.darkCountThreshold)&(r<dic.TwoIonsCountThreshold))*1 ...
                            )/2/length(r)*100;
    else
        dark(index1) = sum( r<dic.darkCountThreshold)/length(r)*100;
    end
    AddLinePoint(lines(1),ShiftSpan(index1),dark(index1));
    pause(0.1);
end
[mainMeanFreq,mainFWHM,mainPeak,fittedCurve] = ...
    FitToGaussian(ShiftSpan,median(dark)-dark);
set(lines(2),'XData',ShiftSpan,'YData',median(dark)-fittedCurve);
dic.acStarkShift674 = mainMeanFreq;
%--------------- Save data ------------------
if (dic.AutoSaveFlag)
    destDir=dic.saveDir;
    thisFile=[mfilename('fullpath') '.m' ];
    [filePath fileName]=fileparts(thisFile);
    scriptText=fileread(thisFile);
    showData='figure;plot(ShiftSpan,dark);xlabel(''Shift freq [MHz]'');ylabel(''dark[%]'');';
    saveFileName=fullfile(destDir ,[fileName datestr(now,'-ddmmmyy-HHMMSS')]);
    dicParameters=dic.getParameters;
    save(saveFileName,'ShiftSpan','dark','showData','dicParameters','scriptText');
    disp(['Save data in : ' saveFileName]);
end

%--------------------------------------------------------------------
    function r=experimentSequence(freqShift,mode)
        prog=CodeGenerator;
        prog.GenDDSPullParametersFromBase;
        prog.GenSeq(Pulse('ExperimentTrigger',0,50));
        prog.GenSeq(Pulse('674DDS1Switch',0,-1,'amp',100));
        % Doppler coolng
        prog.GenSeq(Pulse('OffRes422',0,1));%turn off cooling
        prog.GenSeq(Pulse('OnResCooling',0,dic.Tcooling));
        % continuous GSC 
        prog.GenSeq([Pulse('674DDS1Switch',1,dic.vibMode(mode).coolingTime,'freq',Freq674SinglePass+dic.vibMode(mode).freq+freqShift),...
                     Pulse('Repump1033',0,dic.vibMode(mode).coolingTime+dic.T1033),...
                     Pulse('OpticalPumping',0,dic.vibMode(mode).coolingTime+dic.T1033+dic.Toptpump)]);        
        % Red sideband Shelving
        prog.GenSeq(Pulse('674DDS1Switch',2,dic.vibMode(mode).hotPiTime,'freq',Freq674SinglePass+dic.vibMode(mode).freq));
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