function OptimizeRFNullSecond(varargin)
dic=Dictator.me;

rep=100; %repetitions per point
MMFreq=21.75;
%  LightShift=-0.014; %for spindowninit
 LightShift=+0.000;
doGSC=1;

DetuningSpinDown=(-2.802*1/2+1.68*3/2)*(dic.FRF/2.802);
DiffCapLInit=dic.AVdcl;
DiffCapRInit=dic.AVdcr;
calibRFinit=dic.calibRfFlag;
dic.calibRfFlag=0;

scanTypeNum=2;
for i=1:2:size(varargin,2)
    switch lower(char(varargin(i)))
        case 'scantype'
            scanTypeNum=varargin{i+1};
    end; %switch
end;%for loop

switch scanTypeNum
    case 1
        scanType='scanDiffcap';
        DiffCap=linspace(-0.07,0.07,5);
        PulseTime=1:5:150;
        Init2SpinDown=0;
    case 2
        scanType='scanMMHidingTime';
        PulseTime=(2:3:100)*1;
        Init2SpinDown=0;
        rep=100; %repetitions per point

end
dic.setNovatech('DoublePass','amp',1000);
% ground state cooling beam
dic.setNovatech('Echo','freq',dic.SinglePass674freq+dic.vibMode(1).freq+dic.acStarkShift674,'amp',1000);

%%  --------------- scanDiffcap ----------------- 
if  strcmp(scanType,'scanDiffcap')
    DiffEndcap=DiffCapLInit-DiffCapRInit;
    %-------------- Set GUI figures ---------------------
    InitializeAxes (dic.GUI.sca(1),'Photons #','Cases Counted #','Fluorescence Histogram',...
        [0 dic.maxPhotonsNumPerReadout],[],0);
    
    lines =InitializeAxes (dic.GUI.sca(4),...
        'Pulse Time[\mus]','Dark Counts %','Rabi Scan',...
        [PulseTime(1) PulseTime(end)],[0 100],2);
    grid(dic.GUI.sca(4),'on');
    lines2 =InitializeAxes (dic.GUI.sca(6),...
        'DiffCap [V]','Nbar fitted %','Single Addressing',...
        [DiffEndcap+2*DiffCap(1) DiffEndcap+2*DiffCap(end)],[],2);
    grid(dic.GUI.sca(6),'on');
    
    set(lines(1),'Marker','.','MarkerSize',10,'Color','b');
    set(lines(2),'Marker','.','MarkerSize',10,'Color','r');
    
    set(lines2(1),'Marker','.','MarkerSize',10,'Color','b');
    set(lines2(2),'Marker','.','MarkerSize',10,'Color','r');
    % -------------- Main function scan loops ---------------------
    dark = zeros(length(PulseTime),1);
    darktot=zeros(length(PulseTime),length(DiffCap));
    fidelitytot=zeros(length(PulseTime),length(DiffCap));
    fidelity = zeros(length(PulseTime),1);
    beatAmp=zeros(length(DiffCap),1);
    
    CrystalCheckPMT;
    % The micromotion transition freq 
%     dic.setNovatech('DoublePassSecond','freq',dic.F674DoublePassCarrier+LightShift/2-Init2SpinDown*DetuningSpinDown/2-MMFreq/2,'amp',500);
    dic.setNovatech('DoublePassSecond','freq',dic.F674DoublePassCarrier-MMFreq/2);
    for index2=1:length(DiffCap)
        dic.AVdcl=DiffCapLInit+DiffCap(index2);
        dic.AVdcr=DiffCapRInit-DiffCap(index2);
        pause(1);
        set(lines(2),'XData',[],'YData',[]);
        set(lines(1),'XData',[],'YData',[]);
        CrystalCheckPMT;
        for index1=1:length(PulseTime)
            if dic.stop
                dic.AVdcl=DiffCapLInit;
                dic.AVdcr=DiffCapRInit;
                return;
            end
            pause(0.1);
            % Update the DoublePass base freq 
            dic.setNovatech('DoublePass','freq',dic.updateF674);
            r=experimentSequence(PulseTime(index1),Init2SpinDown);
            
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
            AddLinePoint(lines(1),PulseTime(index1),fidelity(index1));
%             AddLinePoint(lines(2),PulseTime(index1),dark(index1));
            fidelitytot(index1,index2)=fidelity(index1);
            darktot(index1,index2)=dark(index1);
        end
        darktofit=fidelity';
        
        %---------- fitting and updating ---------------------
        ft=fittype('50-25*(cos(a*x)+cos((a+b)*x))');
        fo=fitoptions('Method','NonlinearLeastSquares',...
                      'StartPoint',[0.13 0.00],'Lower',[0.03 0],'Upper',[0.2 0.1],'DiffMinChange',0.001,'MaXIter',2000);
        Rsquare=0;
        while (Rsquare<0.90)
            fo.startPoint=[0.15 abs(rand)/5];
            [curve,goodness]=fit(PulseTime',fidelitytot(:,index2),ft,fo);
            Rsquare=Rsquare+0.02+(goodness.rsquare>0.9);
        end
        set(lines(2),'XData',PulseTime,'YData',curve(PulseTime));
        beatAmp(index2)=curve.b;
        AddLinePoint(lines2(1),2*DiffCap(index2)+DiffEndcap,curve.b);
    end
    
    % find RF null
    s = fitoptions('Method','NonlinearLeastSquares','Startpoint',[0.1 0 0]);
    f = fittype('a*abs(x-b)+c','options',s);
    [curve] = fit(DiffCap',beatAmp,f);
    disp(sprintf('Diff Endacp=%.5f',curve.b));
    set(lines2(2),'XData',2*DiffCap+DiffEndcap,'YData',curve(DiffCap));
    
    [minval indexmin]=min(beatAmp);
    
    dic.AVdcl=DiffCapLInit+DiffCap(indexmin);
    dic.AVdcr=DiffCapRInit-DiffCap(indexmin);       

showData='figure;plot(DiffCap+DiffEndcap,beatAmp);xlabel(''endcap diff voltage'');ylabel(''beat amp'');';
end
%% ---------------- scanMMHidingTime ------------
if  strcmp(scanType,'scanMMHidingTime')
    %-------------- Set GUI figures ---------------------
    InitializeAxes (dic.GUI.sca(1),'Photons #','Cases Counted #','Fluorescence Histogram',...
        [0 dic.maxPhotonsNumPerReadout],[],0);
    
    lines =InitializeAxes (dic.GUI.sca(4),...
        'Pulse Time[\mus]','Dark Counts %','Rabi Scan',...
        [PulseTime(1) PulseTime(end)],[0 100],2);
    grid(dic.GUI.sca(4),'on');
    set(lines(1),'Marker','.','MarkerSize',10,'Color','b');
    set(lines(2),'Marker','.','MarkerSize',10,'Color','r');
     
    % -------------- Main function scan loops ---------------------
    dark = zeros(1,length(PulseTime));
    fidelity = zeros(1,length(PulseTime));
    CrystalCheckPMT;  
%   dic.setNovatech('DoublePassSecond','freq',dic.F674DoublePassCarrier+LightShift/2-Init2SpinDown*DetuningSpinDown/2-MMFreq/2,'amp',500);
    dic.setNovatech('DoublePassSecond','freq',dic.F674DoublePassCarrier-MMFreq/2);
    for index1=1:length(PulseTime)
        if dic.stop
            return;
        end
        dic.setNovatech('DoublePass','freq',dic.updateF674);
        pause(0.1);      
        r=experimentSequence(PulseTime(index1),Init2SpinDown);      
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
        AddLinePoint(lines(1),PulseTime(index1),fidelity(index1));
    end
    %---------- fitting and updating ---------------------
    [Nbar,Omega,y]=fitNbar2CarrierRabi((PulseTime)*1e-6,fidelity/100,dic.vibMode(1).freq,pi/4);
     set(lines(2),'XData',PulseTime,'YData',y*100);
     if (mean((y*100-fidelity).^2)<50)
         dic.HiddingInfo.Tmm1=2*pi/Omega/4*1e6;
         disp(sprintf('Nbar =%.2f ;setting HiddingInfo.Tmm1 = %.3f',Nbar,dic.HiddingInfo.Tmm1));
     else
         disp('WARNNING : invalid fit');
     end
    showData='figure;plot(PulseTime,fidelity);xlabel(''Pulse time'');ylabel(''P1'');';
end
%% end of scans 
dic.save;
dic.calibRfFlag=calibRFinit;

%% ------------------------ experiment sequence -----------------
    function r=experimentSequence(pTime,spinselected)
        prog=CodeGenerator;
        prog.GenDDSPullParametersFromBase;

        % set DDS freq and amp
        prog.GenSeq(Pulse('ExperimentTrigger',0,50));
        % Doppler coolng
        prog.GenSeq(Pulse('OffRes422',0,1));%turn off cooling
        prog.GenSeq(Pulse('OnResCooling',10,dic.Tcooling));
        
        prog.GenSeq(Pulse('RFDDS2Switch',2,-1,'freq',dic.FRF,'amp',dic.ampRF));
        prog.GenSeq(Pulse('674DDS1Switch',2,-1,'freq',dic.SinglePass674freq,'amp',100));        
        
        %activate noise eater, move it to int hold and repump
        prog.GenSeq([Pulse('674DDS1Switch',2,20),...
            Pulse('NoiseEater674',3,15),Pulse('674DoublePass',0,23),...
            Pulse('Repump1033',23,dic.T1033),...
            Pulse('OpticalPumping',23+dic.T1033,dic.Toptpump)]);
        
        if doGSC
            prog.GenSeq([Pulse('Repump1033',0,0), Pulse('OpticalPumping',0,0)]);
            % cooling the Stretch
            prog.GenSeq([Pulse('674DoublePass',0,dic.vibMode(2).coolingTime+4),...
                         Pulse('674Echo',2,dic.vibMode(2).coolingTime)]);
            % cooling the COM
            %         prog.GenSeq([Pulse('674DoublePass',0,dic.vibMode(1).coolingTime+4),...
            %                      Pulse('674Parity',2,dic.vibMode(1).coolingTime)]);
            prog.GenSeq([Pulse('Repump1033',dic.T1033,-1), Pulse('OpticalPumping',dic.T1033,-1)]);
        end
        
       %Do pi pulse RF $prepare to -1/2
        if spinselected==1
            prog.GenSeq(Pulse('RFDDS2Switch',1,dic.TimeRF));
        end
        
        % no double pass because it is on the MM side band allready
        prog.GenSeq(Pulse('674DDS1Switch',2,pTime));
        
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

