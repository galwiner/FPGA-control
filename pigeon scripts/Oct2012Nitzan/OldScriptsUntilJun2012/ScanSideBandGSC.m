function ScanSideBandGSC(Vmodes)

dic=Dictator.me;

if ~exist('Vmodes')
    Vmodes = 1;
end
%-------------- Set GUI figures ---------------------
InitializeAxes (dic.GUI.sca(1),'Photons #','Cases Counted #','Fluorescence Histogram',...
                [0 dic.maxPhotonsNumPerReadout],[],0);

lines =InitializeAxes (dic.GUI.sca(5),...
    'F [MHz]','Dark Counts %','Blue Sideband',...
    [],[0 100],2);
darkCountLine(1) = lines(1);
fitLine(1) = lines(2);
set(darkCountLine(1),'Marker','.','MarkerSize',10,'Color','b');
set(fitLine(1),'Color',[0 0 0]);

lines =InitializeAxes (dic.GUI.sca(6),...S
    'F [MHz]','Dark Counts %','Red Sideband',...
    [],[0 100],2);
darkCountLine(2) = lines(1);
fitLine(2) = lines(2);
% set(darkCountLine(2),'Color',get(darkCountLine(1),'Color'));
set(darkCountLine(2),'Marker','.','MarkerSize',10,'Color','r');
set(fitLine(2),'Color',[0 0 0]);
%-------------- main scan loop ---------------------
f674Span=-0.07:0.004:0.07;    
%f674Span=-0.07:0.007:0.07;    

darkBank = zeros(length(Vmodes),2,length(f674Span));
dark=zeros(size(f674Span));
for modeInd=1:length(Vmodes)
    %titlePrefix = dic.vibMode(Vmodes(modeInd)).name;
    for lobeIndex = 1:2
        f674List = f674Span+dic.updateF674+(lobeIndex-1.5)*2*dic.vibMode(Vmodes(modeInd)).freq;
        set(dic.GUI.sca(4+lobeIndex),'XLim',[f674Span(1) f674Span(end)]);
        grid on;
        %title(titlePrefix);
        set(darkCountLine(lobeIndex),'XData',[],'YData',[]);
        for index1 = 1:length(f674List)
            if dic.stop
                return
            end
            r=experimentSequence(f674List(index1),Vmodes(modeInd));
            dic.GUI.sca(1); %get an axis from Dictator GUI to show data
            hist(r,0:1:(1.8*dic.maxPhotonsNumPerReadout));
            if dic.TwoIonFlag
                dark(index1) =100-sum( (r>dic.TwoIonsCountThreshold)*2+...
                                     ((r>dic.darkCountThreshold)&(r<dic.TwoIonsCountThreshold))*1 ...
                                    )/2/length(r)*100;
            else
                dark(index1) = sum( r<dic.darkCountThreshold)/length(r)*100;
            end
            AddLinePoint(darkCountLine(lobeIndex),f674Span(index1),dark(index1));
            darkBank(modeInd,lobeIndex,index1)=dark(index1);
            pause(0.1);
        end
    end
end
%------------ Save data ------------------
if (dic.AutoSaveFlag)
    destDir=dic.saveDir;
    thisFile=[mfilename('fullpath') '.m' ];
    [filePath fileName]=fileparts(thisFile);
    scriptText=fileread(thisFile);
    showData='figure;RSB(:,:)=darkBank(:,2,:);BSB(:,:)=darkBank(:,1,:);plot(f674Span,RSB,''r'',f674Span,BSB,''b'');;xlabel(''Detunning [Mhz]'');ylabel(''dark[%]'');';
    saveFileName=fullfile(destDir ,[fileName datestr(now,'-ddmmmyy-HHMMSS')]);
    dicParameters=dic.getParameters;
    save(saveFileName,'f674Span','darkBank','Vmodes','showData','dicParameters','scriptText');
    disp(['Save data in : ' saveFileName]);
end
%--------------------------------------------------------------------
    function r=experimentSequence(pulseFreq,mode)
        prog=CodeGenerator;
        prog.GenDDSPullParametersFromBase;
        prog.GenSeq(Pulse('ExperimentTrigger',0,50));
        prog.GenSeq(Pulse('674DDS1Switch',0,-1,'amp',100));
        % Doppler coolng
        prog.GenSeq(Pulse('OffRes422',0,1));%turn off cooling
        prog.GenSeq(Pulse('OnResCooling',0,dic.Tcooling));
         % continuous GSC
        SeqGSC=[]; N=4; Tstart=2;
        Mode2Cool=mode;
        if (~isempty(Mode2Cool))
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
        end         
%         prog.GenSeq([Pulse('NoiseEater674',2,dic.vibMode(mode).coolingTime),...
%                      Pulse('674DDS1Switch',2,dic.vibMode(mode).coolingTime,'freq',dic.updateF674+dic.vibMode(mode).freq+dic.acStarkShift674),...
%                      Pulse('Repump1033',0,dic.vibMode(mode).coolingTime+dic.T1033),...
%                      Pulse('OpticalPumping',0,dic.vibMode(mode).coolingTime+dic.T1033+dic.Toptpump)]);        
%         % pulsed GSC
%         prog.GenRepeatSeq([Pulse('NoiseEater674',2,dic.vibMode(mode).coldPiTime),...
%                            Pulse('674DDS1Switch',2,dic.vibMode(mode).coldPiTime,'freq',dic.updateF674+dic.vibMode(mode).freq),...
%                            Pulse('Repump1033',dic.vibMode(mode).coldPiTime,dic.T1033),...
%                            Pulse('OpticalPumping',dic.vibMode(mode).coldPiTime+dic.T1033,dic.Toptpump)],2);                          
        % sideband Shelving
        prog.GenSeq([Pulse('NoiseEater674',2,dic.vibMode(mode).coldPiTime),...
                     Pulse('674DDS1Switch',2,dic.vibMode(mode).coldPiTime,'freq',pulseFreq)]);
        % detection
        prog.GenSeq([Pulse('OnRes422',0,dic.TDetection) Pulse('PhotonCount',0,dic.TDetection)]);
        %resume cooling
        prog.GenSeq(Pulse('Repump1033',0,dic.T1033));
        prog.GenSeq(Pulse('OffRes422',0,0));
        prog.GenFinish;
        
        dic.com.UploadCode(prog);
        dic.com.UpdateFpga;
        dic.com.WaitForHostIdle; % wait until host finished it last task
        dic.com.Execute(100);
        dic.com.WaitForHostIdle;
        r = dic.com.ReadOut(100);
        r = r(2:end);
    end 

end