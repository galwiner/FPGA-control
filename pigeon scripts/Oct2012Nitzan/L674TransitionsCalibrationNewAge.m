function L674TransitionsCalibrationNewAge
dic=Dictator.me;



rep=100; %repetitions per point
pulseAmp=100;
MMFreq=21.75;

withNoiseEater=1;
MMFreq=21.75;
doGSC=0;Vmodes=1;
DetuningSpinDown=(-2.802*1/2+1.68*3/2)*(dic.FRF/2.802);

MMLineCalibration=1;
Init2SpinDown=0;
TransitionOnMM=0;
FreqScan=0;TimeScan=1;

CrystalCheckPMT;

if MMLineCalibration
    PulseTime=[1:6:300];
end

if FreqScan
    Frequency=[-0.04:0.001:0.015];        
    PulseTime=dic.HiddingInfo.Tmm1;
else
    Frequency=0;    
end

% control the double pass frequency
dic.setNovatech('DoublePass','freq',dic.updateF674,'amp',1000);

CrystalCheckPMT;
valid = 0;
%% -------------- Set GUI figures ---------------------
InitializeAxes (dic.GUI.sca(1),'Photons #','Cases Counted #','Fluorescence Histogram',...
    [0 dic.maxPhotonsNumPerReadout],[],0);
if FreqScan
    lines =InitializeAxes (dic.GUI.sca(9),...
        'Frequency [MHz]','Dark Counts %','Rabi Scan',...
        [Frequency(1) Frequency(end)],[0 100],3);
    grid(dic.GUI.sca(9),'on');
else
    lines =InitializeAxes (dic.GUI.sca(4),...
        'Pulse Time[\mus]','Dark Counts %','Rabi Scan',...
        [PulseTime(1) PulseTime(end)],[0 100],3);
    grid(dic.GUI.sca(4),'on');
end
set(lines(1),'Marker','.','MarkerSize',10,'Color','b');
set(lines(2),'Marker','.','MarkerSize',10,'Color','g');
set(lines(3),'Marker','.','MarkerSize',10,'Color','r');

%% -------------- Main function scan loops ---------------------
dark = zeros(max(length(Frequency),length(PulseTime)),2);
fidelity = zeros(max(length(Frequency),length(PulseTime)),2);

histograms=zeros(rep,length(PulseTime));

if MMLineCalibration
    dark = zeros(max(length(Frequency),length(PulseTime)),1);
    fidelity = zeros(max(length(Frequency),length(PulseTime)),1);
    for index1=1:max(length(Frequency),length(PulseTime))
            if dic.stop                
                return;
            end
            pause(0.1);
            % shelving line starts from s=-1/2
            % third argument is the oscillator, fourth is the spin state   
            if FreqScan
                dic.setNovatech('DoublePassSecond','freq',dic.updateF674+Frequency(index1)/2-Init2SpinDown*DetuningSpinDown/2-MMFreq/2,'amp',1000);
                r=experimentSequence(dic.SinglePass674freq,PulseTime,pulseAmp,'674DDS1Switch',1);
            else
                LightShift=-0.014;                
                dic.setNovatech('DoublePassSecond','freq',dic.updateF674+LightShift/2-Init2SpinDown*DetuningSpinDown/2-MMFreq/2,'amp',1000);                
                r=experimentSequence(dic.SinglePass674freq,PulseTime(index1),pulseAmp,'674DDS1Switch',Init2SpinDown);
            end
            dic.GUI.sca(1);
            hist(r,1:1:dic.maxPhotonsNumPerReadout);

            ivec=dic.IonThresholds;
            tmpdark=0;
            for tmp=1:dic.NumOfIons
                tmpdark=tmpdark+sum((r>ivec(tmp))&(r<ivec(tmp+1)))*tmp;
            end
            tmpdark=100-tmpdark/length(r)/(dic.NumOfIons)*100;
            dark(index1)=tmpdark;
            fidelity(index1)=100-sum( (r>dic.IonThresholds(2))*2+(r<dic.IonThresholds(1))*2)/2/length(r)*100;
            histograms(:,index1)=r;          
                
            if FreqScan
                AddLinePoint(lines(1),Frequency(index1),fidelity(index1));
            else
                AddLinePoint(lines(1),PulseTime(index1),fidelity(index1));
            end
    end
    darktofit=fidelity';
else    
    for index2=1:2 %sum on spin states     
        for index1 = 1:max(length(Frequency),length(PulseTime))                                    
            if dic.stop                
                return;
            end
            pause(0.1);
            % third argument is the oscillator, fourth is the spin state
            if FreqScan
                r=experimentSequence(dic.SinglePass674freq,PulseTime,pulseAmp,OscName{index2},index2-1);
            else
                r=experimentSequence(dic.SinglePass674freq,PulseTime(index1),pulseAmp,OscName{index2},index2-1);
            end
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

            histograms(:,index1,index2)=r;
            if TransitionOnMM||MMLineCalibration
                result=fidelity;
            else
                result=dark;
            end
            
            if FreqScan
                AddLinePoint(lines(index2),Frequency(index1),result(index1,index2));
            else
                AddLinePoint(lines(index2),PulseTime(index1),result(index1,index2));
            end
            
        end
        darktofit=dark(:,index2)';
        if TimeScan
            ft=fittype('a*(sin(pi/2*x/b).^2)');
            
            if TransitionOnMM
                fo=fitoptions('Method','NonlinearLeastSquares','Startpoint',[96,100],'Lower',[92 60],'Upper',[105 PulseTime(end)]);
                [curve,goodness]=fit(PulseTime',darktofit',ft,fo);
                set(lines(3),'Color','r','XData',PulseTime,'YData',feval(curve,PulseTime));
                
                if index2==1
                    dic.HiddingInfo.Tmm1=curve.b;
                    eval(sprintf('dic.HiddingInfo.Tmm1=%2.2f;',curve.b));
                else
                    dic.HiddingInfo.Tmm2=curve.b;
                    eval(sprintf('dic.HiddingInfo.Tmm2=%2.2f;',curve.b));
                end
            else
                fo=fitoptions('Method','NonlinearLeastSquares','Startpoint',[96,30],'Lower',[92 10],'Upper',[105 PulseTime(end)]);
                [curve,goodness]=fit(PulseTime',darktofit',ft,fo);
                set(lines(3),'Color','r','XData',PulseTime,'YData',feval(curve,PulseTime));
                
                if index2==1
                    dic.HiddingInfo.Tcarrier1=curve.b;
                    eval(sprintf('dic.HiddingInfo.Tcarrier1=%2.2f;',curve.b));
                else
                    dic.HiddingInfo.Tcarrier2=curve.b;
                    eval(sprintf('dic.HiddingInfo.Tcarrier2=%2.2f;',curve.b));
                end
            end
        end
    end
end   
%---------- fitting and updating ---------------------
if TimeScan
    [Nbar,Omega,y]=fitNbar2CarrierRabi((PulseTime)*1e-6,darktofit/100,dic.vibMode(1).freq,pi/4);
    set(lines(2),'XData',PulseTime,'YData',y*100);
    if mean((y*100-darktofit).^2)<50
        %         dic.HiddingInfo.Tmm1=2*pi/Omega/4*1e6;
        [valuemax indexmax]=max(y);
        fprintf('Nbar=%2.0f;',Nbar);
        dic.HiddingInfo.Tmm1=PulseTime(indexmax);
%         eval(sprintf('dic.HiddingInfo.Tmm1=%.2f',PulseTime(indexmax)));
    else
        fprintf('Warning ! Fit unreliable.');
    end
    %         ft=fittype('a*(sin(pi/2*x/b).^2)');
    %
    %         pause(1);
    %         if MMLineCalibration
    %             fo=fitoptions('Method','NonlinearLeastSquares','Startpoint',[100,100],'Lower',[90 60],'Upper',[105 PulseTime(end)*3/4]);
    %             [curve,goodness]=fit(PulseTime',darktofit',ft,fo);
    %             set(lines(3),'Color','r','XData',PulseTime,'YData',feval(curve,PulseTime));
    %
    %             dic.HiddingInfo.Tshelving=curve.b;
    %             eval(sprintf('dic.HiddingInfo.Tmm1=%2.2f;',curve.b));
    %         end
end
    
    %---------- fitting and updating ---------------------
    
    %
    %     % update T674 if the chi square is small
    %     if (mean((y*100-dark).^2)<50)&&(updateFit)
    %         eval(sprintf('dic.AddrInfo.T%s=%.2f;',OscName,2*pi/Omega/4*1e6+0.1));
    %         fprintf('dic.AddrInfo.T%s=%.2f',OscName,2*pi/Omega/4*1e6+0.1');
    %         if strcmp(OscName,'674DDS1Switch')
    %             dic.T674=2*pi/Omega/4*1e6+0.1;% the 0.5 is a correction
    %             rabi=dic.T674;
    %             disp(sprintf('average n = %.2f  PiTime = %4.2f [mus]',Nbar,2*pi/Omega/4*1e6+0.1));
    %         end
    %     end
    
    %------------ Save data ------------------
    showData='figure;plot(PulseTime,dark);xlabel(''F_674 [Mhz]'');ylabel(''dark[%]'');';
    dic.save;
    % if flop degrades too much, readjust the RF null.
%     if Nbar>45*sqrt(dic.vibMode(1).freq/(-1))
%         OptimizeRFNullSecond;
%     end
    
    %% ------------------------ experiment sequence -----------------
    function r=experimentSequence(pFreq,pTime,pAmp,oscname,spinselected)
        prog=CodeGenerator;
        prog.GenDDSPullParametersFromBase;
        
        % set DDS freq and amp
        prog.GenSeq(Pulse('ExperimentTrigger',0,50));
        % Doppler coolng
        prog.GenSeq(Pulse('OffRes422',0,1));%turn off cooling
        prog.GenSeq(Pulse('OnResCooling',10,dic.Tcooling));
        
        prog.GenSeq(Pulse('RFDDS2Switch',2,-1,'freq',dic.FRF,'amp',dic.ampRF));
        
        if strcmp(oscname,'674DDS1Switch')
            prog.GenSeq(Pulse('674DDS1Switch',2,-1,'freq',pFreq,'amp',pAmp));
        end
        %          prog.GenSeq([Pulse('OpticalPumping',5,500)]);
        
        %activate noise eater, move it to int hold and repump
        prog.GenSeq([Pulse('674DDS1Switch',0,15),... %Echo is our choice for NE calib
            Pulse('NoiseEater674',2,10),Pulse('674DoublePass',0,15),...
            Pulse('Repump1033',15,dic.T1033),...
            Pulse('OpticalPumping',16+dic.T1033,dic.Toptpump)]);
        
        %         % continuous GSC
        %         prog.GenSeq([Pulse('674DDS1Switch',5,dic.vibMode(1).coolingTime,'freq',dic.SinglePass674freq+dic.vibMode(1).freq+dic.acStarkShift674),...
        %                      Pulse('674DoublePass',0,dic.vibMode(1).coolingTime+5),...
        %                      Pulse('Repump1033',5,dic.vibMode(1).coolingTime+dic.T1033),...
        %                      Pulse('OpticalPumping',5,dic.vibMode(1).coolingTime+dic.T1033+dic.Toptpump)]);
        %         if strcmp(oscname,'674DDS1Switch')
        %             prog.GenSeq(Pulse('674DDS1Switch',2,-1,'freq',pFreq,'amp',pAmp));
        %         end
        
        if doGSC
            % GSC
            SeqGSC=[]; N=1; Tstart=2;
            Mode2Cool=Vmodes;
            if (~isempty(Mode2Cool))
                for mode=Mode2Cool
                    SeqGSC=[SeqGSC,Pulse('674DoublePass',Tstart,dic.vibMode(mode).coolingTime/N),...
                        Pulse('674DDS1Switch',Tstart,dic.vibMode(mode).coolingTime/N,...
                        'freq',dic.SinglePass674freq+dic.vibMode(mode).freq+dic.acStarkShift674)];
                    
                    Tstart=2+Tstart+dic.vibMode(mode).coolingTime/N;
                end
                prog.GenSeq([Pulse('Repump1033',0,0), Pulse('OpticalPumping',0,0)]);
                prog.GenRepeatSeq(SeqGSC,N);
                prog.GenSeq([Pulse('Repump1033',dic.T1033,-1), Pulse('OpticalPumping',dic.T1033,-1)]);
                % pulsed GSC
                for mode=fliplr(Mode2Cool)
                    prog.GenRepeatSeq([Pulse('674DoublePass',2,dic.vibMode(mode).coldPiTime),...
                        Pulse('674DDS1Switch',2,dic.vibMode(mode).coldPiTime,'freq',dic.SinglePass674freq+dic.vibMode(mode).freq),...
                        Pulse('Repump1033',dic.vibMode(mode).coldPiTime,dic.T1033),...
                        Pulse('OpticalPumping',dic.vibMode(mode).coldPiTime+dic.T1033,dic.Toptpump)],2);
                end
            end
            prog.GenSeq(Pulse('674DDS1Switch',2,-1,'freq',dic.SinglePass674freq,'amp',100,'phase',0));
            prog.GenSeq(Pulse('OpticalPumping',0,dic.Toptpump));
        end
        
        %Do pi pulse RF $prepare to -1/2
        if spinselected==1
            prog.GenSeq(Pulse('RFDDS2Switch',1,dic.TimeRF));
        end
        
        %drive the pi pulse
        if strcmp(oscname,'674Gate')
            prog.GenSeq([Pulse('674Gate',2,pTime),Pulse('674DoublePass',2,pTime)]);
        else
            prog.GenSeq([Pulse(oscname,2,pTime)]);
        end
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

