function EntanglingtGateParityScan2(gateTime,epsilon)

dic=Dictator.me;
%eta = 0.028;
%piTime = 5;
%RabiFreq = 1/2/piTime;
%epsilon = RabiFreq*4*eta;
pwr = 1000;
imbalance=-0.00;
epsilon = 0.0008;
beamsDetune = dic.vibMode(2).freq+epsilon;
carrierDetune = 0.0000;
gateTime = 190;
gatePhase = linspace(0,1.95*pi,20);

% ------------Set GUI axes -------------
InitializeAxes(dic.GUI.sca(1),'Photons #','Cases Counted #','Fluorescence Histogram',...
                [0 dic.maxPhotonsNumPerReadout],[],0);

lines =InitializeAxes (dic.GUI.sca(9),...
    'Gate Phase [rad]','Dark Counts %','Entangling Gate',...
    [gatePhase(1) gatePhase(end)],[0 100],3);
linesParity =InitializeAxes (dic.GUI.sca(10),...
    'Gate Phase  [rad]','Parity','Parity',...
    [gatePhase(1) gatePhase(end)],[-1 1],1);

set(lines(1),'Marker','.','MarkerSize',10,'Color','b');
set(lines(2),'Marker','.','MarkerSize',10,'Color','r');
set(lines(3),'Marker','.','MarkerSize',10,'Color','k');
set(linesParity,'Marker','.','MarkerSize',10,'Color','b');

P0 = zeros(size(gatePhase));
P1 = P0;
P2 = P0;
Parity=P0;
dic.handleTimer;
dic.F674=dic.updateF674;
%dic.timerOnOffFlag=0;
dic.setNovatech4Amp(0,pwr*(1+imbalance));
dic.setNovatech4Amp(1,pwr*(1-imbalance));
dic.setNovatech4Amp(2,330);
dic.setNovatech4Freq(0,dic.F674-beamsDetune);
dic.setNovatech4Freq(1,dic.F674+beamsDetune);
dic.setNovatech4Freq(2,dic.F674);
oldF674=dic.F674;
oldDeflectorFreq=dic.deflectorCurrentFreq;
% -------- Main function scan loops -------

for index1 = 1:length(gatePhase)
    if dic.stop
        dic.timerOnOffFlag=1;
        dic.setHPFreq(oldDeflectorFreq);
        return
    end
    % update the deflector freq to follow the estimator
     dic.setHPFreq(dic.deflectorCurrentFreq-0.5*(dic.estimateF674-oldF674));
     oldF674=dic.estimateF674;
     pause(0.5);
    % set the phase of the analysis pulse 
    dic.setNovatech4Phase(2,gatePhase(index1));
    
    r=experimentSequence(gateTime,[1 2]);
    dic.GUI.sca(1); %get an axis from Dictator GUI to show data
    hist(r,0:1:(1.8*dic.maxPhotonsNumPerReadout));
    
    P0(index1) = sum( r<dic.darkCountThreshold)/length(r)*100;
    P1(index1) = sum((r>dic.darkCountThreshold)&(r<dic.TwoIonsCountThreshold))/length(r)*100;
    P2(index1) = sum( r>dic.TwoIonsCountThreshold)/length(r)*100;
    Parity(index1)=(P0(index1)+P2(index1)-P1(index1))/100;
    AddLinePoint(lines(1),gatePhase(index1),P0(index1));
    AddLinePoint(lines(2),gatePhase(index1),P1(index1));
    AddLinePoint(lines(3),gatePhase(index1),P2(index1));
    AddLinePoint(linesParity,gatePhase(index1),Parity(index1));

    pause(0.1);
end

    
%--------------- Save data ------------------
if (dic.AutoSaveFlag)
    destDir=dic.saveDir;
    thisFile=[mfilename('fullpath') '.m' ];
    [filePath fileName]=fileparts(thisFile);
    scriptText=fileread(thisFile);
    showData=['figure;plot(gatePhase,P0,gatePhase,P1,gatePhase,P2);',...
              'xlabel(''Pulse Phase[rad]'');ylabel(''population[%]'');',...
              'figure;plot(gatePhase,Parity);xlabel(''Pulse Phase[rad]'');ylabel(''Parity'');'];
    saveFileName=fullfile(destDir ,[fileName datestr(now,'-ddmmmyy-HHMMSS')]);
    dicParameters=dic.getParameters;
    save(saveFileName,'gatePhase','P0','P1','P2','Parity','showData','gateTime','epsilon','dicParameters','scriptText');
    disp(['Save data in : ' saveFileName]);
end 
%dic.timerOnOffFlag=1;
dic.setHPFreq(oldDeflectorFreq);
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
                'freq',dic.F674+dic.vibMode(mode).freq+dic.acStarkShift674)];
            Tstart=2+Tstart+dic.vibMode(mode).coolingTime/N;
        end
        prog.GenSeq([Pulse('Repump1033',0,0), Pulse('OpticalPumping',0,0)]);
        prog.GenRepeatSeq(SeqGSC,N);
        prog.GenSeq([Pulse('Repump1033',dic.T1033,-1), Pulse('OpticalPumping',dic.T1033,-1)]);
        % ---------- pulsed GSC ----------------
        for mode=fliplr(Mode2Cool)
            prog.GenRepeatSeq([Pulse('NoiseEater674',2,dic.vibMode(mode).coldPiTime),...
                Pulse('674DDS1Switch',2,dic.vibMode(mode).coldPiTime,'freq',dic.F674+dic.vibMode(mode).freq),...
                Pulse('Repump1033',dic.vibMode(mode).coldPiTime,dic.T1033),...
                Pulse('OpticalPumping',dic.vibMode(mode).coldPiTime+dic.T1033,dic.Toptpump)],2);
        end
        
        %---------- Gate Pulse -----------------
        prog.GenSeq(Pulse('NovaTechPort2',0,-1));
        prog.GenSeq([Pulse('674PulseShaper',0,pulseTime),...
                     Pulse('674Switch2NovaTech',0,pulseTime+5)]);
        %----------- analysis pulse -------------

        prog.GenSeq([Pulse('NovaTechPort2',10,20),... 
                     Pulse('674Switch2NovaTech',10,dic.T674)]);
        %---------- detection --------------------
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