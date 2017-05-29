function QubitAddrScans(varargin)
dic=Dictator.me;
softwareUpdateNE=0;

OscName{1}='674Parity'; %responsible for carrier pi/2 pulses
OscName{2}='674Echo';   %responsible for mm-spin locking
OscName{3}='674Gate';   %responsible for mm-sigma_x

piTime(1)=eval(sprintf('dic.AddrInfo.T%s',OscName{1}));
piTime(2)=eval(sprintf('dic.AddrInfo.T%s',OscName{2}));
piTime(3)=eval(sprintf('dic.AddrInfo.T%s',OscName{3}));

rep=50; %repetitions per data point
MMFreq=-21.75; %micromotion frequency
% addrFreq= 31.0535;% sigma_x addressing frequency
addrFreq=18.2;%18.79;% sigma_x addressing frequency
novatechAmp=1000;
sigma_xAmp=150;
probeTime=300;%450 at 100 sigmaxamp;

useCamera=0;    if useCamera   sigma_xAmp=200*0; probeTime=10; end;
DoInvertBrightAndDark=0;

optimizePhase    =0;
scanRabi         =0;
scanRabiFreqTime =1;
scanRabiTime     =0; if scanRabiTime==1  sigma_xAmp=250; end;
scanMultipleRabiTime=0;
scanSxPhase      =0;
scanFreq         =0;

myPi=3.1415;

if ~useCamera
    updateF674OrNot='dic.updateF674';
    CrystalCheckPMT;
else
    updateF674OrNot='dic.F674';
end
for t=1:3
    switch OscName{t}
        case '674Gate' %mm sideband: sigma_x
            dic.setNovatech('Blue','freq',addrFreq/1000,'amp',sigma_xAmp);
            dic.setNovatech('Red','freq',dic.SinglePass674freq,'amp',1000,'phase',dic.AddrInfo.P674Gate); %multiply by zero
        case '674Parity' %carrier transition
            dic.setNovatech('Parity','freq',dic.SinglePass674freq+MMFreq,'amp',novatechAmp);
        case '674Echo' %mm-sideband: dressing
            dic.setNovatech('Echo','freq',dic.SinglePass674freq,'amp',novatechAmp,'phase',mod(dic.AddrInfo.P674Echo+pi/2,2*pi));
    end
end

% control the double pass frequency
%softwareUpdateNoiseEater;
dic.setNovatech('DoublePass','freq',dic.F674+MMFreq/2,'amp',1000);

if ~useCamera
    CrystalCheckPMT;
end
%% ------------- If use Camera - init the camera -------------------
if useCamera
    par1=libpointer('int32Ptr',0);
    par2=libpointer('int32Ptr',0);
    par3=libpointer('singlePtr',0);
    DRV_NOT_INITIALIZED=20075;
    DRV_IDLE=20073;
    DRV_SUCCESS=20002;
    addpath('C:\Program Files\Andor Luca\Drivers');
    if (~libisloaded('ATMCD32D'))
        loadlibrary('ATMCD32D','ATMCD32D.H');
    end
    if (calllib('ATMCD32D','GetStatus',par1)==DRV_NOT_INITIALIZED)
        calllib('ATMCD32D','Initialize','');
        calllib('ATMCD32D','CoolerON');
        calllib('ATMCD32D','SetTemperature',-20);
    else
        disp(sprintf('Already Initialized.'));
    end   
    pause(1);
    calllib('ATMCD32D','SetAcquisitionMode',1);
    calllib('ATMCD32D','SetReadMode',4);
    calllib('ATMCD32D','SetHSSpeed',0,0);
    calllib('ATMCD32D','GetNumberVSSpeeds',par1);
    calllib('ATMCD32D','SetVSSpeed',0);
    calllib('ATMCD32D','SetTriggerMode',7); %0 internal, 1 external 7 ext exposure
    calllib('ATMCD32D','SetFastExtTrigger',0); %0 wait until keep clean cycle ends before snapshot, 1 - dont wait
    calllib('ATMCD32D','SetEMCCDGain',255);
    exposureTime=20; %in miliseconds
    calllib('ATMCD32D','SetExposureTime',exposureTime/1000);
    calllib('ATMCD32D','SetShutter',0,0,100,0);% type,mode,close time[ms],opentime
    calllib('ATMCD32D','GetDetector',par1,par2);
    %     NumOfXpixels=100;%get(par1,'Value');
    %     NumOfYpixels=50;%get(par2,'Value');
    NumOfXpixels=150;%get(par1,'Value');
    NumOfYpixels=150;%get(par2,'Value');
    minX=90+170;
    minY=90+110;
    binX=1;
    IntegrateLine=0;
    if IntegrateLine
        binY=NumOfYpixels;
    else
        binY=1;
    end
    error=calllib('ATMCD32D','SetImage',binX,binY,minX,minX+NumOfXpixels-1,minY,minY+NumOfYpixels-1);  %int hbin, int vbin, int hstart, int hend, int vstart, int vend
    NumOfYpixels=NumOfYpixels/binY;
    NumOfXpixels=NumOfXpixels/binX;
    im=uint16(zeros(NumOfXpixels,NumOfYpixels));
    imPtr=libpointer('uint16Ptr',im);
   
    
end

% -------------- Set GUI figures ---------------------
InitializeAxes (dic.GUI.sca(1),'Photons #','Cases Counted #','Fluorescence Histogram',...
    [0 dic.maxPhotonsNumPerReadout],[],0);


%-------------- Main function scan loops ---------------------
    %% take a snapshot of the ions
if useCamera
    InitializeAxes (dic.GUI.sca(11),'Photons #','Cases Counted #','Fluorescence Histogram',...
    [],[],0);

    snapshotNum=50;
    r=zeros(snapshotNum,NumOfXpixels,NumOfYpixels);
    for t=1:snapshotNum
        if dic.stop
            return;
        end
        tmp=experimentSequence(OscName{1},OscName{2},OscName{3},piTime(1),probeTime);
        dic.GUI.sca(11);plot(sum(tmp(:,50:end-50),2));
        dic.GUI.sca(7);
        %imshow(tmp); %pcolor(double(r)); shading flat;
        r(t,:,:)=tmp;
        if t>1
            tmp=reshape(mean(r(1:t,:,:)),NumOfXpixels,NumOfYpixels);
        end
        m=min(min(tmp));
        M=max(max(tmp));
        imshow(tmp'); 
        caxis([m M]);
    end
    showData='tmp=reshape(mean(r(1:snapshotNum,:,:)),NumOfXpixels,NumOfYpixels);figure;imshow(tmp'');title(''MM addressing'');m=min(min(tmp));M=max(max(tmp));caxis([m M]);';
    dic.save;
else
%% optimize the relative phases of the pi/2 pulse and the dressing pulse
if optimizePhase 
    dic.setNovatech('Blue','amp',0); %sigma_x freq in the dressed picture->off res
    phaseVec=0:0.2:2*pi;
    dark = zeros(size(phaseVec));
    histograms=zeros(length(phaseVec),rep);
    lines=InitializeAxes (dic.GUI.sca(11),...
        'Dressed Phase[rad]','Dark Counts %','Micromotion Single Qubit Addressing',...
        [phaseVec(1) phaseVec(end)],[0 100],1);
    set(lines(1),'Marker','.','MarkerSize',10,'Color','b');
    for index1 = 1:length(phaseVec)
        if dic.stop
            return;
        end
        %softwareUpdateNoiseEater;
        dic.setNovatech('DoublePass','freq',eval(updateF674OrNot)+MMFreq/2,'amp',1000);
        dic.setNovatech('Echo','phase',phaseVec(index1));
        pause(0.1);
        r=experimentSequence(OscName{1},OscName{2},OscName{3},piTime(1),probeTime);
        dic.GUI.sca(1);
        hist(r,1:1:dic.maxPhotonsNumPerReadout);
        ivec=dic.IonThresholds;
        tmpdark=0;
        for tmp=1:dic.NumOfIons
            tmpdark=tmpdark+sum((r>ivec(tmp))&(r<ivec(tmp+1)))*tmp;
        end
        tmpdark=100-tmpdark/length(r)/(dic.NumOfIons)*100;
        dark(index1)=tmpdark;            
        histograms(index1,:)=r;
        AddLinePoint(lines(1),phaseVec(index1),dark(index1));
    end
    %---------- fitting and updating ---------------------
    pguess=phaseVec(find(dark==max(dark),1));
    ft=fittype('a*cos(x-b)+c');
    fo=fitoptions('Method','NonlinearLeastSquares',...
            'Startpoint',[30 pguess 70],...
            'MaxFunEvals',20000,'MaxIter',20000);
    [curve,goodness]=fit(phaseVec',dark',ft,fo);
    dic.GUI.sca(5); hold on; plot(curve); hold off; legend off;
    eval(sprintf('dic.AddrInfo.P%s=%.2f',OscName{2},curve.b));
%     fprintf('phase of %s w.r. to %s is %.2f rad\n',OscName{1}(4:end),OscName{2}(4:end),curve.b);

    % Just by pointing the maximum
    [maxval maxind]=max(dark);
    phasemax=phaseVec(maxind)-pi/2;
    eval(sprintf('dic.AddrInfo.P%s=%.2f',OscName{2},phasemax));
    fprintf('phase of %s w.r. to %s is %.2f rad\n',OscName{1}(4:end),OscName{2}(4:end),phasemax);
    
end
%% Scan Sx Rabi amplitude, fix pulse duration
if scanRabi
  
    rabiVec=linspace(0,5000,11);
    dark = zeros(size(rabiVec));
    histograms=zeros(length(rabiVec),rep);
    lines=InitializeAxes (dic.GUI.sca(11),...
        'Dressed Simga_x amp(novatech)','Dark Counts %','Micromotion Single Qubit Addressing',...
        [rabiVec(1) rabiVec(end)],[0 100],1);
    set(lines(1),'Marker','.','MarkerSize',10,'Color','b');
    for index1 = 1:length(rabiVec)
        if dic.stop
            return;
        end
        %softwareUpdateNoiseEater;
        dic.setNovatech('DoublePass','freq',eval(updateF674OrNot)+MMFreq/2,'amp',1000); 
        dic.setNovatech('Blue','amp',rabiVec(index1),'freq',addrFreq/1000); %sigma_x amp in the dressed picture
        pause(0.1);
        r=experimentSequence(OscName{1},OscName{2},OscName{3},piTime(1),probeTime);
        histograms(index1,:)=r;
        dic.GUI.sca(1);
        hist(r,1:1:dic.maxPhotonsNumPerReadout);
        if dic.TwoIonFlag
            dark(index1) =100-sum( (r>dic.TwoIonsCountThreshold)*2+...
                ((r>dic.darkCountThreshold)&(r<dic.TwoIonsCountThreshold))*1 ...
                )/2/length(r)*100;
        else
            dark(index1) = sum( r<dic.darkCountThreshold)/length(r)*100;
        end
        
        AddLinePoint(lines(1),rabiVec(index1),dark(index1));
    end
    showData='figure;plot(rabiVec,dark);xlabel(''Dressed Simga_x amp(novatech)'');ylabel(''dark[%]''); title(''Micromotion Single Qubit Addressing'')';
    dic.save;
end
%% Two Dimensional scan Sx Phase and Rabi Time
if scanRabiTime&&scanSxPhase
 
    pulseTime=1:80:1001;
    SxPhase=0:0.3:2*pi;
    dark = zeros(length(pulseTime),length(SxPhase));
    histograms=zeros(length(pulseTime),length(SxPhase),rep);
    lines=InitializeAxes (dic.GUI.sca(7),...
        'Sx Phase[rad]','Sx time(mus)','MM Addressing',...
        [SxPhase(1) SxPhase(end)],[pulseTime(1) pulseTime(end)],1);
    for index2=1:length(SxPhase)
        for index1 = 1:length(pulseTime)
            if dic.stop
                return;
            end
            %softwareUpdateNoiseEater;
            dic.setNovatech('DoublePass','freq',eval(updateF674OrNot)+MMFreq/2,'amp',1000);
            dic.setNovatech('Red','phase',SxPhase(index2));
            pause(0.1);
            r=experimentSequence(OscName{1},OscName{2},OscName{3},piTime(1),pulseTime(index1));
            histograms(index1,index2,:)=r;
            dic.GUI.sca(1);
            hist(r,1:1:dic.maxPhotonsNumPerReadout);
            if dic.TwoIonFlag
                dark(index1,index2) =100-sum( (r>dic.TwoIonsCountThreshold)*2+...
                    ((r>dic.darkCountThreshold)&(r<dic.TwoIonsCountThreshold))*1 ...
                    )/2/length(r)*100;
            else
                dark(index1,index2) = sum( r<dic.darkCountThreshold)/length(r)*100;
            end
            
            dic.GUI.sca(7);
            mypcolor(SxPhase,pulseTime,dark); colorbar;
        end
    end
    showData='figure;mypcolor(SxPhase,pulseTime,dark); colorbar;xlabel(''Sx Phase[rad]'');ylabel(''Sx time(mus)''); title(''MM Addressing'')';
    dic.save;
end
%% Scan both SigmaX Time and the Addressing Frequency
if scanRabiFreqTime
     pulseTime=10:60:2200;
%         pulseTime=405:0.5:430;

%      addrFreq=5:0.4:30;
      addrFreq=5:0.5:30;
    
    dark = zeros(length(pulseTime),length(addrFreq));
    fidelity = zeros(length(pulseTime),length(addrFreq));

    histograms=zeros(length(pulseTime),length(addrFreq),rep);
    lines=InitializeAxes (dic.GUI.sca(7),...
        'Addr Freq[kHz]','Sx time(mus)','MM Addressing',...
        [addrFreq(1) addrFreq(end)],[pulseTime(1) pulseTime(end)],1);
    countcheck=0;
        for index2=1:length(addrFreq)
        for index1 = 1:length(pulseTime)

            if countcheck==3
                CrystalCheckPMT;countcheck=0;
            else
                countcheck=countcheck+1;
            end
            
            if dic.stop
                return;
            end
            %softwareUpdateNoiseEater;
            dic.setNovatech('DoublePass','freq',dic.updateF674+MMFreq/2,'amp',1000);
            dic.setNovatech('Blue','freq',addrFreq(index2)/1000,'amp',sigma_xAmp); %sigma_x freq in the dressed picture
            pause(0.5);
            r=experimentSequence(OscName{1},OscName{2},OscName{3},piTime(1),pulseTime(index1));
            dic.GUI.sca(1);
            hist(r,1:1:dic.maxPhotonsNumPerReadout);
            if dic.TwoIonFlag
                ivec=dic.IonThresholds;
                tmpdark=0;
                for tmp=1:dic.NumOfIons
                    tmpdark=tmpdark+sum((r>ivec(tmp))&(r<ivec(tmp+1)))*tmp;
                end
                tmpdark=100-tmpdark/length(r)/(dic.NumOfIons)*100;
                dark(index1,index2)=tmpdark;
                fidelity(index1,index2)=sum((r<ivec(2)&(r>ivec(1))))/length(r)*100;
            else
                dark(index1) = sum( r<dic.darkCountThreshold)/length(r)*100;
            end
            histograms(index1,index2,:)=r;
            dic.GUI.sca(7);
            mypcolor(addrFreq,pulseTime,fidelity); colorbar;
        end
    end
    showData='figure;mypcolor(addrFreq,pulseTime,dark); colorbar;xlabel(''Addr Freq[kHz]'');ylabel(''Sx time(mus)''); title(''MM Addressing'')';
    dic.save;  
    
end
%% scan Sx Rabi Time
if scanRabiTime&&~scanSxPhase
    pulseTime=1:40:2000;
    fidelity=zeros(length(pulseTime),1);

    dark = zeros(size(pulseTime));
    histograms=zeros(length(pulseTime),rep);
    lines=InitializeAxes (dic.GUI.sca(10),...
        'Dressed Simga_x time(mus)','Dark Counts %','Micromotion Single Qubit Addressing',...
        [pulseTime(1) pulseTime(end)],[0 100],2);
    set(lines(1),'Marker','.','MarkerSize',10,'Color','b');
    set(lines(2),'Marker','.','MarkerSize',10,'Color','g');

    %dic.setNovatech('Echo','amp',0);
    for index1 = 1:length(pulseTime)
        if dic.stop
            return;
        end
        %softwareUpdateNoiseEater;
        dic.setNovatech('Blue','freq',addrFreq/1000,'amp',round(sigma_xAmp)); %sigma_x freq in the dressed picture        
        dic.setNovatech('DoublePass','freq',dic.estimateF674+MMFreq/2,'amp',1000); 
        pause(0.5);
        r=experimentSequence(OscName{1},OscName{2},OscName{3},piTime(1),pulseTime(index1));
        histograms(index1,:)=r;
        dic.GUI.sca(1);
        hist(r,1:1:dic.maxPhotonsNumPerReadout);

        ivec=dic.IonThresholds;
        tmpdark=0;
        for tmp=1:dic.NumOfIons
            tmpdark=tmpdark+sum((r>ivec(tmp))&(r<ivec(tmp+1)))*tmp;
        end
        tmpdark=100-tmpdark/length(r)/(dic.NumOfIons)*100;
        dark(index1)=tmpdark;
        fidelity(index1)=sum((r<ivec(2)&(r>ivec(1))))/length(r)*100;

        AddLinePoint(lines(1),pulseTime(index1),dark(index1));
        AddLinePoint(lines(2),pulseTime(index1),fidelity(index1));
    end
    showData='figure;plot(pulseTime,dark);xlabel(''Dressed Simga_x time(mus)'');ylabel(''dark[%]''); title(''Micromotion Single Qubit Addressing'')';
    dic.save;
end
%% scan Sx Rabi Time on Multiple Ions
if scanMultipleRabiTime
    pulseTime=1:40:2000;
    fidelity=zeros(length(pulseTime),1);

    dark = zeros(size(pulseTime));
    histograms=zeros(length(pulseTime),rep);
    lines=InitializeAxes (dic.GUI.sca(10),...
        'Dressed Simga_x time(mus)','Dark Counts %','Micromotion Single Qubit Addressing',...
        [pulseTime(1) pulseTime(end)],[0 100],dic.NumOfIons);
    colorIon=['b' 'r' 'g' 'k'];
    addrFreq=[10.51 15.5 20.22];
    for indexIon=1:dic.NumOfIons
        set(lines(indexIon),'Marker','.','MarkerSize',10,'Color',colorIon(indexIon));
    end
    
    %dic.setNovatech('Echo','amp',0);
    for index1 = 1:length(pulseTime)
        for indexIon=1:dic.NumOfIons
            
            if dic.stop
                return;
            end
            %softwareUpdateNoiseEater;
            dic.setNovatech('Blue','freq',addrFreq(indexIon)/1000,'amp',round(sigma_xAmp)); %sigma_x freq in the dressed picture
            dic.setNovatech('DoublePass','freq',dic.F674+MMFreq/2,'amp',1000);
            pause(0.5);
            r=experimentSequence(OscName{1},OscName{2},OscName{3},piTime(1),pulseTime(index1));
            histograms(index1,:)=r;
            dic.GUI.sca(1);
            hist(r,1:1:dic.maxPhotonsNumPerReadout);
            
            ivec=dic.IonThresholds;
            tmpdark=0;
            for tmp=1:dic.NumOfIons
                tmpdark=tmpdark+sum((r>ivec(tmp))&(r<ivec(tmp+1)))*tmp;
            end
            tmpdark=100-tmpdark/length(r)/(dic.NumOfIons)*100;
            dark(index1,indexIon)=tmpdark;
            fidelity(index1,indexIon)=sum((r<ivec(2)&(r>ivec(1))))/length(r)*100;
            
            %         AddLinePoint(lines(1),pulseTime(index1),dark(index1));
            AddLinePoint(lines(indexIon),pulseTime(index1),fidelity(index1,indexIon));
        end
    end
    showData='figure;plot(pulseTime,dark);xlabel(''Dressed Simga_x time(mus)'');ylabel(''dark[%]''); title(''Micromotion Single Qubit Addressing'')';
    dic.save;
end
%% scan the Sx phase (carrier of the AM modulated beam)
if scanSxPhase&&~scanRabiTime
    SxPhase=0:0.3:2*pi;
    dark = zeros(size(SxPhase));
    histograms=zeros(length(SxPhase),rep);
    lines=InitializeAxes (dic.GUI.sca(11),...
        'Sigma_x phase(rad)','Dark Counts %','Micromotion Single Qubit Addressing',...
        [SxPhase(1) SxPhase(end)],[0 100],1);
    set(lines(1),'Marker','.','MarkerSize',10,'Color','b');
%     dic.setNovatech('Blue','freq',0);
%     dic.setNovatech('Echo','amp',0); %turn off dressing
    for index1 = 1:length(SxPhase)
        if dic.stop
            return;
        end
        %softwareUpdateNoiseEater;
        dic.setNovatech('DoublePass','freq',eval(updateF674OrNot)+MMFreq/2); 
        dic.setNovatech('Red','phase',SxPhase(index1));
        pause(0.1);
        r=experimentSequence(OscName{1},OscName{2},OscName{3},piTime(1),probeTime);
        histograms(index1,:)=r;
        dic.GUI.sca(1);
        hist(r,1:1:dic.maxPhotonsNumPerReadout);
        if dic.TwoIonFlag
            dark(index1) =100-sum( (r>dic.TwoIonsCountThreshold)*2+...
                ((r>dic.darkCountThreshold)&(r<dic.TwoIonsCountThreshold))*1 ...
                )/2/length(r)*100;
            
        else
            dark(index1) = sum( r<dic.darkCountThreshold)/length(r)*100;
            
        end
        AddLinePoint(lines(1),SxPhase(index1),dark(index1));
    end
    showData='figure;plot(SxPhase,dark);xlabel(''Sigma_x phase(rad)'');ylabel(''dark[%]''); title(''Micromotion Single Qubit Addressing'')';
    dic.save;
end
%% scan freq of sigma_x in the dressed frame
if scanFreq 
%   addrFreq=linspace(0,40,40+1); 
    addrFreq=5:0.5:35;   
    fidelity=zeros(length(addrFreq),1);
    lines=InitializeAxes (dic.GUI.sca(9),...
        'Addressing Freq (kHz)','Dark Counts %','Micromotion Single Qubit Addressing',...
        [addrFreq(1) addrFreq(end)],[0 100],2);
    set(lines(1),'Marker','.','MarkerSize',10,'Color','b');
    set(lines(2),'Marker','.','MarkerSize',10,'Color','g');
    dark = zeros(size(addrFreq));
    histograms=zeros(length(addrFreq),rep);
    for index1 = 1:length(addrFreq)
        if dic.stop
            return;
        end
        %softwareUpdateNoiseEater;  
%         dic.setNovatech('Blue','freq',addrFreq(index1)/1000,'amp',round(sigma_xAmp*20/addrFreq(index1))); %sigma_x freq in the dressed picture        
        dic.setNovatech('Blue','freq',addrFreq(index1)/1000,'amp',round(sigma_xAmp)); %sigma_x freq in the dressed picture        

        dic.setNovatech('DoublePass','freq',eval(updateF674OrNot)+MMFreq/2,'amp',1000); 
        pause(0.5);
        r=experimentSequence(OscName{1},OscName{2},OscName{3},piTime(1),probeTime);        
%         r=experimentSequence(OscName{1},OscName{2},OscName{3},piTime(1),probeTime/addrFreq(index1)*20);
        histograms(index1,:)=r;
        dic.GUI.sca(1);
        hist(r,1:1:dic.maxPhotonsNumPerReadout);
        ivec=dic.IonThresholds;
        tmpdark=0;
        for tmp=1:dic.NumOfIons
            tmpdark=tmpdark+sum((r>ivec(tmp))&(r<ivec(tmp+1)))*tmp;
        end
        tmpdark=100-tmpdark/length(r)/(dic.NumOfIons)*100;
        dark(index1)=tmpdark;

        fidelity(index1)=sum((r<ivec(2)&(r>ivec(1))))/length(r)*100;            
        AddLinePoint(lines(1),addrFreq(index1),dark(index1));
        AddLinePoint(lines(2),addrFreq(index1),fidelity(index1));
    end
    showData='figure;plot(addrFreq,dark);xlabel(''addressing freq(kHz)'');ylabel(''dark[%]''); title(''Micromotion Single Qubit Addressing'')';
    dic.save;
    
end
end

%% ------------------------ experiment sequence -----------------
    function r=experimentSequence(osc1,osc2,osc3,piTime1,probetime)
        if useCamera
            calllib('ATMCD32D','StartAcquisition');
        end
        prog=CodeGenerator;
        prog.GenDDSPullParametersFromBase;

        % set DDS freq and amp
        prog.GenSeq(Pulse('ExperimentTrigger',0,50));
        % Doppler coolng
        prog.GenSeq(Pulse('OffRes422',0,1));%turn off cooling
        prog.GenSeq(Pulse('OnResCooling',10,dic.Tcooling));
        %calibrate noise eater + optical pumping
         if ~softwareUpdateNE
            prog.GenSeq([Pulse('674Echo',0,15),...
                Pulse('NoiseEater674',2,10),Pulse('674DoublePass',0,15),...
                Pulse('Repump1033',15,dic.T1033),...
                Pulse('OpticalPumping',16+dic.T1033,dic.Toptpump)]);
        else
            prog.GenSeq([Pulse('Repump1033',0,dic.T1033),...
            Pulse('OpticalPumping',dic.T1033,dic.Toptpump)]);
         end
         
        if DoInvertBrightAndDark
            prog.GenSeq([Pulse(osc1,0,piTime1), Pulse('674DoublePass',0,piTime1)]);
        end 
        
        % carrier pi/2                      
        prog.GenSeq([Pulse(osc1,0,piTime1/2), Pulse('674DoublePass',0,piTime1/2)]);
        % dressing+sigma_x
        prog.GenSeq([Pulse(osc2,0,probetime),Pulse(osc3,0,probetime),Pulse('674DoublePass',0,probetime)]);
%         carrier pi/2                      
         prog.GenSeq([Pulse(osc1,0,piTime1/2), Pulse('674DoublePass',0,piTime1/2)]);
        
        % detection
        if useCamera
            prog.GenSeq([Pulse('CameraTrigger',1,exposureTime*1000),...
                Pulse('OnRes422',1,exposureTime*1000)]);
            prog.GenPause(1000);
        else
            prog.GenSeq([Pulse('OnRes422',0,dic.TDetection) Pulse('PhotonCount',0,dic.TDetection)]);
        end
        % resume cooling
        prog.GenSeq(Pulse('Repump1033',0,dic.T1033));

        prog.GenSeq([Pulse('OffRes422',0,0) Pulse('Repump1092',0,0)]);
        prog.GenFinish;    
        dic.com.UploadCode(prog);
        dic.com.UpdateFpga;
        dic.com.WaitForHostIdle; % wait until host finished it last task
        if useCamera
            dic.com.Execute(1);
            dic.com.WaitForHostIdle;
            stam=dic.com.ReadOut(1);
            pause(0.5);
            calllib('ATMCD32D','GetStatus',par1); %fprintf('%s\n',get(par1,'Value')); 
            pause(1);
            [error,Image]=calllib('ATMCD32D','GetAcquiredData16',imPtr,int32(NumOfXpixels*NumOfYpixels));
            r=Image;
        else
            dic.com.Execute(rep);
            dic.com.WaitForHostIdle;
            r = dic.com.ReadOut(rep);
        end
    end
end