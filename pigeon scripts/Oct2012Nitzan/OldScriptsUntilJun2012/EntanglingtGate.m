function EntanglingtGate

dic=Dictator.me;
pwr = 365;

epsilon = 0.0094;
beamsDetune = dic.vibMode(2).freq+epsilon;
carrierDetune = -0.0000;

%gateTime = 2/epsilon;
gateTimeList = 270:2:370;
gateTimeList = [100*ones(1,100) 2e3];
imbalance =0;
% ------------Set GUI axes -------------
InitializeAxes(dic.GUI.sca(1),'Photons #','Cases Counted #','Fluorescence Histogram',...
                [0 dic.maxPhotonsNumPerReadout],[],0);

lines =InitializeAxes (dic.GUI.sca(9),...
    'Gate Time [\mus]','Dark Counts %','Entangling Gate',...
    [gateTimeList(1) gateTimeList(end)],[0 100],3);

set(lines(1),'Marker','.','MarkerSize',10,'Color','b');
set(lines(2),'Marker','.','MarkerSize',10,'Color','r');
set(lines(3),'Marker','.','MarkerSize',10,'Color','k');

P0 = zeros(size(gateTimeList));
P1 = P0;
P2 = P0;

dic.setNovatech4Amp(0,pwr*(1+imbalance));
dic.setNovatech4Amp(1,pwr*(1-imbalance));
dic.setNovatech4Freq(0,dic.updateF674+carrierDetune-beamsDetune);
dic.setNovatech4Freq(1,dic.updateF674+carrierDetune+beamsDetune);
% -------- Main function scan loops -------

for index1 = 1:length(gateTimeList)
    if dic.stop
        return
    end
    r=experimentSequence(gateTimeList(index1),[1 2]);
    dic.GUI.sca(1); %get an axis from Dictator GUI to show data
    hist(r,0:1:(1.8*dic.maxPhotonsNumPerReadout));
    
    P0(index1) = sum( r<dic.darkCountThreshold)/length(r)*100;
    P1(index1) = sum((r>dic.darkCountThreshold)&(r<dic.TwoIonsCountThreshold))/length(r)*100;
    P2(index1) = sum( r>dic.TwoIonsCountThreshold)/length(r)*100;
    AddLinePoint(lines(1),gateTimeList(index1),P0(index1));
    AddLinePoint(lines(2),gateTimeList(index1),P1(index1));
    AddLinePoint(lines(3),gateTimeList(index1),P2(index1));
    pause(0.1);
end

    
%--------------- Save data ------------------
if (dic.AutoSaveFlag)
    destDir=dic.saveDir;
    thisFile=[mfilename('fullpath') '.m' ];
    [filePath fileName]=fileparts(thisFile);
    scriptText=fileread(thisFile);
    showData='figure;plot(gateTimeList,P0,gateTimeList,P1,gateTimeList,P2);xlabel(''Pulse Time[\mus]'');ylabel(''population[%]'');';
    saveFileName=fullfile(destDir ,[fileName datestr(now,'-ddmmmyy-HHMMSS')]);
    dicParameters=dic.getParameters;
    save(saveFileName,'gateTimeList','P0','P1','P2','showData','dicParameters','scriptText');
    disp(['Save data in : ' saveFileName]);
end 


%--------------------------------------------------------------------
     function r=experimentSequence(pulseTime,Mode2Cool)

        prog=CodeGenerator;
        prog.GenDDSPullParametersFromBase;
        prog.GenWaitExtTrigger;
%          prog.GenPause(5e3);
        prog.GenSeq(Pulse('ExperimentTrigger',0,5000));
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
        prog.GenSeq(Pulse('DO12',0,-1));
        prog.GenSeq([Pulse('674PulseShaper',0,pulseTime),...
                     Pulse('674Switch2NovaTech',0,pulseTime+5)]);
        prog.GenSeq(Pulse('DO12',0,0));
        prog.GenSeq(Pulse('DO12',0,-1));
        prog.GenSeq([...
                     Pulse('674Switch2NovaTech',0,pulseTime)...
                     ]);
        prog.GenSeq(Pulse('DO12',0,0));
      
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