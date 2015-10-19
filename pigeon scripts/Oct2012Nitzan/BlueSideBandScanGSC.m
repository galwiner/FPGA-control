function BlueSideBandScanGSC(Vmodes)

dic=Dictator.me;
PulseTime=(2:5:200)*2;    

if ~exist('Vmodes')
    Vmodes = 2;
end
% Vmodes=[1 2];

%-------------- Set GUI figurdes ---------------------
InitializeAxes (dic.GUI.sca(1),'Photons #','Cases Counted #','Fluorescence Histogram',...
                [0 dic.maxPhotonsNumPerReadout],[],0);

lines =InitializeAxes (dic.GUI.sca(11),...
    'Time [mus]','Dark Counts %','Blue Sideband',...
    [],[0 100],2);
darkCountLine(1) = lines(1);
fitLine(1) = lines(2);
set(darkCountLine(1),'Marker','.','MarkerSize',10,'Color','b');

darkCountLine(2) = lines(2);
set(darkCountLine(2),'Marker','.','MarkerSize',10,'Color','r');
set(dic.GUI.sca(11),'XLim',[PulseTime(1) PulseTime(end)]);

%-------------- main scan loop ---------------------

darkBank =zeros(length(Vmodes),2,length(PulseTime));
dark=zeros(size(PulseTime));
countcheck=0;
CrystalCheckPMT;

% for modeInd=1:length(Vmodes)
    %titlePrefix = dic.vibMode(Vmodes(modeInd)).name;        
    set(dic.GUI.sca(10),'XLim',[PulseTime(1) PulseTime(end)]);
    grid on;
    %title(titlePrefix);
    for index1 = 1:length(PulseTime)
        if countcheck==20
            CrystalCheckPMT;
            countcheck=0;
        else
            countcheck=countcheck+1;
        end
        for lobeIndex = 1:1
            if dic.stop
                return
            end
            dic.setNovatech('DoublePass','freq',dic.updateF674,'amp',1000);
            
            r=experimentSequence(Vmodes,lobeIndex*2-3,PulseTime(index1));
            dic.GUI.sca(1); %get an axis from Dictator GUI to show data
            hist(r,0:1:(1.8*dic.maxPhotonsNumPerReadout));
            ivec=dic.IonThresholds;
            tmpdark=0;
            for tmp=1:dic.NumOfIons
                tmpdark=tmpdark+sum((r>ivec(tmp))&(r<ivec(tmp+1)))*tmp;
            end
            tmpdark=100-tmpdark/length(r)/(dic.NumOfIons)*100;
            dark(index1)=tmpdark;
            AddLinePoint(darkCountLine(lobeIndex),PulseTime(index1),dark(index1));
            darkBank(lobeIndex,index1)=dark(index1);
            pause(0.1);
        end
    end
    % end
    %------------ Save data ------------------

    showData='figure;RSB(:,:)=darkBank(:,2,:);BSB(:,:)=darkBank(:,1,:);plot(PulseTime,RSB,''r'',PulseTime,BSB,''b'');;xlabel(''Detunning [Mhz]'');ylabel(''dark[%]'');';
    dic.save;
%--------------------------------------------------------------------
    function r=experimentSequence(mode,sb,pulsetime)
        prog=CodeGenerator;
        prog.GenDDSPullParametersFromBase;
%         prog.GenWaitExtTrigger;
        prog.GenSeq(Pulse('ExperimentTrigger',0,50));
        prog.GenSeq(Pulse('674DDS1Switch',0,-1,'amp',100));
        % Doppler coolng
        prog.GenSeq(Pulse('OffRes422',0,1));%turn off cooling
        prog.GenSeq(Pulse('OnResCooling',0,dic.Tcooling));
                
        % continuous GSC
        SeqGSC=[]; N=1; Tstart=2;
        Mode2Cool=mode;
        if (~isempty(Mode2Cool))
            for mode=Mode2Cool
                % turn on carrier mode
                SeqGSC=[SeqGSC,Pulse('NoiseEater674',Tstart,dic.vibMode(mode).coolingTime/N),...
                               Pulse('674DoublePass',Tstart,dic.vibMode(mode).coolingTime/N),...
                               Pulse('674DDS1Switch',Tstart,dic.vibMode(mode).coolingTime/N,...
                                     'freq',dic.SinglePass674freq+dic.vibMode(mode).freq+dic.acStarkShift674)];
                Tstart=2+Tstart+dic.vibMode(mode).coolingTime/N;
            end
            prog.GenSeq([Pulse('Repump1033',0,0), Pulse('OpticalPumping',0,0)]);
            prog.GenRepeatSeq(SeqGSC,N);
            prog.GenSeq([Pulse('Repump1033',dic.T1033,-1), Pulse('OpticalPumping',dic.T1033+dic.Toptpump,-1)]);
            % pulsed GSC
%             for mode=fliplr(Mode2Cool)
%             prog.GenRepeatSeq([Pulse('NoiseEater674',2,dic.vibMode(mode).coldPiTime),...
%                                Pulse('674DoublePass',2,dic.vibMode(mode).coldPiTime),...
%                                Pulse('674DDS1Switch',2,dic.vibMode(mode).coldPiTime,'freq',dic.SinglePass674freq+dic.vibMode(mode).freq),...
%                                Pulse('Repump1033',dic.vibMode(mode).coldPiTime,dic.T1033),...
%                                Pulse('OpticalPumping',dic.vibMode(mode).coldPiTime+dic.T1033,dic.Toptpump)],2);                          
%             end
        end         
        % sideband Shelving
        prog.GenSeq([Pulse('674DoublePass',1,pulsetime+1),...
                     Pulse('674DDS1Switch',2,pulsetime,'freq',dic.SinglePass674freq+sb*dic.vibMode(mode).freq)]);
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