function OptimizeRFNullNew(varargin)
dic=Dictator.me;


rep=200; %repetitions per point
pulseAmp=100;
withNoiseEater=1;

DiffCapInit=dic.HPVcomp;
DiffCap=DiffCapInit-0.3:0.03:DiffCapInit+0.3;

DetuningSpinDown=(-2.802*1/2+1.68*3/2)*(dic.FRF/2.802);
% DetuningSpinDown=-2*4.9443;


CrystalCheckPMT;


%% -------------------options-------------
CrystalCheckPMT;
for i=1:2:size(varargin,2)
    switch lower(char(varargin(i)))
        case 'freq'
            f674List=varargin{i+1};
        case 'duration'
            pulseTime=varargin{i+1};
        case 'amp'
            pulseAmp=varargin{i+1};
        case 'save'
            savedata=varargin{i+1};
        case 'deflectorguaging'
            forDeflectorGuaging = varargin{i+1};
    end; %switch
end;%for loop
valid = 0;

%% -------------- Set GUI figures ---------------------
InitializeAxes (dic.GUI.sca(1),'Photons #','Cases Counted #','Fluorescence Histogram',...
    [0 dic.maxPhotonsNumPerReadout],[],0);
lines =InitializeAxes (dic.GUI.sca(4),...
    'DiffCap [V]','Dark Counts %','Rabi Scan',...
    [DiffCap(1) DiffCap(end)],[0 100],3);

grid(dic.GUI.sca(4),'on');
set(lines(1),'Marker','.','MarkerSize',10,'Color','b');
set(lines(2),'Marker','.','MarkerSize',10,'Color','g');
set(lines(3),'Marker','.','MarkerSize',10,'Color','r');

%% -------------- Main function scan loops ---------------------
dark = zeros(length(DiffCap),2);
fidelity = zeros(length(DiffCap),2);
maxfid=zeros(length(DiffCap),1);
histograms=zeros(rep,length(DiffCap));

%     for index2=1:2 %sum on spin states

for index1 = 1:length(DiffCap)
    for index2=1:2  % one shot pi pulse, the next, 2*pi pulse
        
        if dic.stop
            return;
        end
        dic.HPVcomp=DiffCap(index1);
        pause(0.1);

        LightShift=-0.014;                
        dic.setNovatech('DoublePassSecond','freq',dic.updateF674+LightShift/2-DetuningSpinDown/2-dic.MMFreq/2,'amp',1000);                
        PulseTime=dic.HiddingInfo.Tmm1;

        % third argument is the oscillator, fourth is the spin state
        r=experimentSequence(dic.SinglePass674freq,PulseTime+(index2-1)*PulseTime,pulseAmp);
        dic.GUI.sca(1);
        hist(r,1:1:dic.maxPhotonsNumPerReadout);
        ivec=dic.IonThresholds;
        tmpdark=0;
        for tmp=1:dic.NumOfIons
            tmpdark=tmpdark+sum((r>ivec(tmp))&(r<ivec(tmp+1)))*tmp;
        end
        tmpdark=100-tmpdark/length(r)/(dic.NumOfIons)*100;
        dark(index1,index2)=tmpdark;
        fidelity(index1,index2)=100-sum( (r>dic.IonThresholds(2))*2+(r<dic.IonThresholds(1))*2)/2/length(r)*100;
        maxfid=fidelity(:,1);
        histograms(:,index1,index2)=r;
        
        AddLinePoint(lines(index2),DiffCap(index1),fidelity(index1,index2));
    end
end
%         darktofit=dark(:,index2)';
        
        
    
%---------- fitting and updating ---------------------

[maxval maxindex]=max(maxfid);
if abs(DiffCap(maxindex)-DiffCapInit)>2
    fprintf('Warning ! RF null determination in trouble.');
else    
    dic.HPVcomp=DiffCap(maxindex);
end
    
    %------------ Save data ------------------
    showData='figure;plot(PulseTime,dark);xlabel(''F_674 [Mhz]'');ylabel(''dark[%]'');';
    dic.save;
    
%% ------------------------ experiment sequence -----------------
    function r=experimentSequence(pFreq,pTime,pAmp)
        prog=CodeGenerator;
        prog.GenDDSPullParametersFromBase;

        % set DDS freq and amp
        prog.GenSeq(Pulse('ExperimentTrigger',0,50));
        % Doppler coolng
        prog.GenSeq(Pulse('OffRes422',0,1));%turn off cooling
        prog.GenSeq(Pulse('OnResCooling',10,dic.Tcooling));
        
        prog.GenSeq(Pulse('RFDDS2Switch',2,-1,'freq',dic.FRF,'amp',dic.ampRF));
        
        prog.GenSeq(Pulse('674DDS1Switch',2,-1,'freq',pFreq,'amp',pAmp)); 
        
        if withNoiseEater
            %activate noise eater, move it to int hold and repump
            prog.GenSeq([Pulse('674Echo',0,15),... %Echo is our choice for NE calib
                Pulse('NoiseEater674',2,10),Pulse('674DoublePass',0,15),...
                Pulse('Repump1033',15,dic.T1033),...
                Pulse('OpticalPumping',16+dic.T1033,dic.Toptpump)]);
        else
            prog.GenSeq([Pulse('Repump1033',0,dic.T1033),...
                Pulse('OpticalPumping',1+dic.T1033,dic.Toptpump)]);                
        end
        
        %Do pi pulse RF $prepare to -1/2
        prog.GenSeq(Pulse('RFDDS2Switch',1,dic.TimeRF));
        
        prog.GenSeq([Pulse('674DDS1Switch',2,pTime)]);

        % detection
        prog.GenSeq([Pulse('OnRes422',0,dic.TDetection) Pulse('PhotonCount',0,dic.TDetection)]);
        % resume cooling
        prog.GenSeq(Pulse('Repump1033',0,dic.T1033));

        prog.GenSeq([Pulse('OffRes422',0,0) Pulse('Repump1092',0,0)]);
        prog.GenFinish;    
        dic.com.UploadCode(prog);
        dic.com.UpdateFpga;
        dic.com.WaitForHostIdle; % wait until host finished it last task
        dic.com.Execute(rep);
        dic.com.WaitForHostIdle;
        r = dic.com.ReadOut(rep);
        
    end
end

