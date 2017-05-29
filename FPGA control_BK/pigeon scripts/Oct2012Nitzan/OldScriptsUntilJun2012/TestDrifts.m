function TestDrifts(varargin)

dic=Dictator.me;
mode2Cool=[1 2];
num=1:500;

%-------------- Set GUI figures ---------------------
InitializeAxes (dic.GUI.sca(1),'Photons #','Cases Counted #','Fluorescence Histogram',...
                [0 dic.maxPhotonsNumPerReadout],[],0);

lines =InitializeAxes (dic.GUI.sca(9),...
    'Pulse Time[\mus]','Dark Counts %','Rabi Scan',...
    [],[0 100],2);

set(lines(1),'Marker','.','MarkerSize',10,'Color','b');
set(lines(2),'Marker','.','MarkerSize',10,'Color','r');

%-------------- main scan loop ---------------------
dark = zeros(length(num),2);
time = zeros(size(num));
tic;
for index1 = 1:length(num)
    if dic.stop
        return
    end
    time(index1)=toc;
    r=experimentSequence(10,33,dic.updateF674-0.013,mode2Cool);
    dic.GUI.sca(1); %get an axis from Dictator GUI to show data
    hist(r,0:1:(1.8*dic.maxPhotonsNumPerReadout));
    if dic.TwoIonFlag
        dark(index1,1) =100-sum( (r>dic.TwoIonsCountThreshold)*2+...
                             ((r>dic.darkCountThreshold)&(r<dic.TwoIonsCountThreshold))*1 ...
                            )/2/length(r)*100;
    else
        dark(index1,1) = sum( r<dic.darkCountThreshold)/length(r)*100;
    end
    AddLinePoint(lines(1),time(index1),dark(index1,1));
    
    pause(0.1);
    r=experimentSequence(100,dic.vibMode(2).coldPiTime,dic.updateF674-dic.vibMode(2).freq-0.003,mode2Cool);
    dic.GUI.sca(1); %get an axis from Dictator GUI to show data
    hist(r,0:1:(1.8*dic.maxPhotonsNumPerReadout));
    if dic.TwoIonFlag
        dark(index1,2) =100-sum( (r>dic.TwoIonsCountThreshold)*2+...
                             ((r>dic.darkCountThreshold)&(r<dic.TwoIonsCountThreshold))*1 ...
                            )/2/length(r)*100;
    else
        dark(index1,2) = sum( r<dic.darkCountThreshold)/length(r)*100;
    end
    AddLinePoint(lines(2),time(index1),dark(index1,2));
    pause(0.1);
    time(index1)=toc;
end
%--------------- Save data ------------------
if (dic.AutoSaveFlag)
    destDir=dic.saveDir;
    thisFile=[mfilename('fullpath') '.m' ];
    [filePath fileName]=fileparts(thisFile);
    scriptText=fileread(thisFile);
    showData='figure;plot(time,dark);xlabel(''Pulse Time[\mus]'');ylabel(''dark[%]'');';
    saveFileName=fullfile(destDir ,[fileName datestr(now,'-ddmmmyy-HHMMSS')]);
    dicParameters=dic.getParameters;
    save(saveFileName,'time','dark','mode2Cool','showData','dicParameters','scriptText');
    disp(['Save data in : ' saveFileName]);
end 
% --------------------------------------------------------------------
    function r=experimentSequence(amp,pulseTime,freq,Mode2Cool)

        prog=CodeGenerator;
        prog.GenDDSPullParametersFromBase;
        prog.GenSeq(Pulse('ExperimentTrigger',0,50));
        prog.GenSeq(Pulse('674DDS1Switch',0,-1,'freq',freq,'amp',100));
        % Doppler coolng
        prog.GenSeq(Pulse('OffRes422',0,100));%turn off cooling
        prog.GenSeq(Pulse('OnResCooling',0,dic.Tcooling));
        
        % ---------continuous GSC -----------
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
        % pulsed GSC
        for mode=fliplr(Mode2Cool)
        prog.GenRepeatSeq([Pulse('NoiseEater674',2,dic.vibMode(mode).coldPiTime),...
                           Pulse('674DDS1Switch',2,dic.vibMode(mode).coldPiTime,'freq',dic.updateF674+dic.vibMode(mode).freq),...
                           Pulse('Repump1033',dic.vibMode(mode).coldPiTime,dic.T1033),...
                           Pulse('OpticalPumping',dic.vibMode(mode).coldPiTime+dic.T1033,dic.Toptpump)],2);                          
        end
        
        %----------sideband Shelving ------------
        prog.GenSeq(Pulse('674DDS1Switch',2,-1,'amp',amp));

        prog.GenSeq([Pulse('NoiseEater674',2,pulseTime),...
                     Pulse('674DDS1Switch',2,pulseTime,'freq',freq)]);
        % detection
        prog.GenSeq([Pulse('OnRes422',0,dic.TDetection) Pulse('PhotonCount',0,dic.TDetection)]);
        %resume cooling
        prog.GenSeq(Pulse('Repump1033',0,dic.T1033));
        prog.GenSeq(Pulse('OffRes422',0,0));
        prog.GenFinish;

        dic.com.UploadCode(prog);
        dic.com.UpdateFpga;
        dic.com.WaitForHostIdle; % wait until host finished it last task
        rep=200;
        dic.com.Execute(rep);
        dic.com.WaitForHostIdle;
        r = dic.com.ReadOut(rep);
        r = r(2:end);
    end

end