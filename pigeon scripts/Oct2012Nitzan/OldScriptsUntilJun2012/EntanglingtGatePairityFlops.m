function EntanglingtGatePairityFlops

% without active magnetic field stabilization (line trigger).


dic=Dictator.me;
pwr = 1000;


beamsDetune = 0.0016;
gateTime = 190;
phaseScanList = [0:pi/10:2*pi];
offset=0;

% ------------Set GUI axes -------------
InitializeAxes(dic.GUI.sca(1),'Photons #','Cases Counted #','Fluorescence Histogram',...
    [0 dic.maxPhotonsNumPerReadout],[],0);

lines =InitializeAxes (dic.GUI.sca(9),...
    '\pi/2 Pulse Phase [radians]','Dark Counts %',...
    strcat({'Entangling Gate Pairity Flipping @'},{' '},{'\epsilon='},{num2str(beamsDetune*1e3)},{'kHz, '},...
    {'T_{gate}='},{num2str(gateTime)},{'\musec'}),...
    [phaseScanList(1) phaseScanList(end)],[0 100],3);
set(lines(1),'Marker','.','MarkerSize',10,'Color','b');
set(lines(2),'Marker','.','MarkerSize',10,'Color','r');
set(lines(3),'Marker','.','MarkerSize',10,'Color','k');

P0 = zeros(1,length(phaseScanList));
P1 = P0;
P2 = P0;

dic.setNovatech4Amp(0,pwr);
dic.setNovatech4Amp(1,pwr*1);
dic.setNovatech4Amp(1,1023);
updatedF674 = dic.updateF674;
updatedF674 = 85;
dic.setNovatech4Freq(0,updatedF674-beamsDetune-dic.vibMode(2).freq+offset);
dic.setNovatech4Freq(1,updatedF674+beamsDetune+dic.vibMode(2).freq+offset);
dic.setNovatech4Freq(2,updatedF674);
        
destDir=dic.saveDir;
thisFile=[mfilename('fullpath') '.m' ];
[filePath fileName]=fileparts(thisFile);
scriptText=fileread(thisFile);
showData=['figure;imagesc(gateTimeList,beamsDetuneList,P0);colorbar;xlabel(''time[\mus]'');ylabel(''detunning'');title(''P0'');',...
    'figure;imagesc(gateTimeList,beamsDetuneList,P1);colorbar;xlabel(''time[\mus]'');ylabel(''detunning'');title(''P1'');'];
saveFileName=fullfile(destDir ,[fileName datestr(now,'-ddmmmyy-HHMMSS')]);

% -------- Main function scan loops -------

for index1 = 1:length(phaseScanList)
        dic.setNovatech4Phase(2,phaseScanList(index1));
        pause(0.1);
        if dic.stop
            return
        end
        r=experimentSequence(gateTime,[1 2]);
        dic.GUI.sca(1); %get an axis from Dictator GUI to show data
        hist(r,0:1:(1.8*dic.maxPhotonsNumPerReadout));

        P0(index1) = sum( r<dic.darkCountThreshold)/length(r)*100;
        P1(index1) = sum((r>dic.darkCountThreshold)&(r<dic.TwoIonsCountThreshold))/length(r)*100;
        P2(index1) = sum( r>dic.TwoIonsCountThreshold)/length(r)*100;
        AddLinePoint(lines(1),phaseScanList(index1),P0(index1));
        AddLinePoint(lines(2),phaseScanList(index1),P1(index1));
        AddLinePoint(lines(3),phaseScanList(index1),P2(index1));
        pause(0.1); 
end
if (dic.AutoSaveFlag)
        dicParameters=dic.getParameters;
        save(saveFileName,'gateTime','beamsDetune','phaseScanList','P0','P1','P2','showData','dicParameters','scriptText');
        disp(['Save data in : ' saveFileName]);
end

%--------------------------------------------------------------------
    function r=experimentSequence(pulseTime,Mode2Cool)

        prog=CodeGenerator;
        prog.GenDDSPullParametersFromBase;
%        prog.GenWaitExtTrigger;
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
         
        prog.GenSeq(Pulse('674Switch2NovaTech',0,0));
        prog.GenSeq(Pulse('DO12',0,-1));
        prog.GenPause(pulseTime+200);
        prog.GenSeq(Pulse('DO12',0,0));
        prog.GenSeq(Pulse('674Switch2NovaTech',0,-1));
        prog.GenPause(10);
        prog.GenSeq(Pulse('NovaTechPort2',0,0));
        prog.GenSeq(Pulse('674Switch2NovaTech',0,dic.port2T674/2));
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