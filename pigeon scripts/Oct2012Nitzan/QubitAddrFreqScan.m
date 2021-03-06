function QubitAddrFreqScan(varargin)
dic=Dictator.me;

OscName{1}='674Parity'; %responsible for carrier pi/2 pulses
OscName{2}='674Echo';   %responsible for mm-spin locking
OscName{3}='674Gate';   %responsible for mm-sigma_x

piTime(1)=eval(sprintf('dic.AddrInfo.T%s',OscName{1}));
piTime(2)=eval(sprintf('dic.AddrInfo.T%s',OscName{2}));
piTime(3)=eval(sprintf('dic.AddrInfo.T%s',OscName{3}));

addrFreq=linspace(7,20,2*(20-7)+1); % sigma_x addressing frequency
sigma_xAmp=300;
novatechAmp=1000;
probeTime=260;
changeFrequencies=1; %change the frequencies, but only once. Otherwise phase relation will disappear

for t=1:3
    if changeFrequencies
        switch OscName{t}
            case '674Gate' %mm sideband: sigma_x
                dic.setNovatech('Blue','freq',0,'amp',sigma_xAmp);
                dic.setNovatech('Red','freq',dic.SinglePass674freq,'amp',novatechAmp,'phase',dic.AddrInfo.P674Gate); %multiply by zero
            case '674Parity' %carrier transition
                dic.setNovatech('Parity','freq',dic.SinglePass674freq+dic.MMFreq,'amp',novatechAmp);
            case '674Echo' %mm-sideband: dressing
                dic.setNovatech('Echo','freq',dic.SinglePass674freq,'amp',novatechAmp,'phase',dic.AddrInfo.P674Echo+pi/2);
        end
    else
        switch OscName{t}
            case '674Gate' %mm sideband: sigma_x
                dic.setNovatech('Blue','amp',sigma_xAmp);
                dic.setNovatech('Red','amp',novatechAmp,'phase',dic.AddrInfo.P674Echo+dic.AddrInfo.P674Gate); %multiply by zero
            case '674Parity' %carrier transition
                dic.setNovatech('Parity','freq','amp',novatechAmp);
            case '674Echo' %mm-sideband: dressing
                dic.setNovatech('Echo','amp',novatechAmp,'phase',dic.AddrInfo.P674Echo+pi/2);
        end
    end
end

% control the double pass frequency
softwareUpdateNoiseEater;
dic.setNovatech('DoublePass','freq',dic.F674+dic.MMFreq/2,'amp',1000);

CrystalCheckPMT;

%-------------- Set GUI figures ---------------------
InitializeAxes (dic.GUI.sca(1),'Photons #','Cases Counted #','Fluorescence Histogram',...
    [0 dic.maxPhotonsNumPerReadout],[],0);


%-------------- Main function scan loops ---------------------
optimizePhase=0;
scanRabi=0;
scanRabiTime=0;
if optimizePhase %optimize the relative phases of the pi/2 pulse and the dressing pulse
    dic.setNovatech('Blue','freq',0,'amp',0); %sigma_x freq in the dressed picture->off res
    phaseVec=linspace(0,2*pi,21);
    dark = zeros(size(phaseVec));
    lines=InitializeAxes (dic.GUI.sca(5),...
        'Dressed Phase[rad]','Dark Counts %','Micromotion Single Qubit Addressing',...
        [phaseVec(1) phaseVec(end)],[0 100],1);
    set(lines(1),'Marker','.','MarkerSize',10,'Color','b');
    for index1 = 1:length(phaseVec)
        if dic.stop
            return;
        end
        softwareUpdateNoiseEater;
        dic.setNovatech('DoublePass','freq',dic.updateF674+dic.MMFreq/2,'amp',1000);
        dic.setNovatech('Echo','amp',200,'phase',phaseVec(index1)+pi/2);
        pause(0.1);
        r=experimentSequence(OscName{1},OscName{2},OscName{3},piTime(1),probeTime);
        dic.GUI.sca(1);
        hist(r,1:1:dic.maxPhotonsNumPerReadout);
        if dic.TwoIonFlag
            dark(index1) =100-sum( (r>dic.TwoIonsCountThreshold)*2+...
                ((r>dic.darkCountThreshold)&(r<dic.TwoIonsCountThreshold))*1 ...
                )/2/length(r)*100;
        else
            dark(index1) = sum( r<dic.darkCountThreshold)/length(r)*100;
        end
        AddLinePoint(lines(1),phaseVec(index1),dark(index1));
    end
    %---------- fitting and updating ---------------------
    pguess=phaseVec(find(dark==max(dark),1));
    ft=fittype('a*cos(x-b)+c');
    fo=fitoptions('Method','NonlinearLeastSquares',...
            'Startpoint',[50 pguess 50],...
            'MaxFunEvals',20000,'MaxIter',20000);
    [curve,goodness]=fit(phaseVec',dark',ft,fo);
    dic.GUI.sca(5); hold on; plot(curve); hold off; legend off;
    eval(sprintf('dic.AddrInfo.P%s=%.2f',OscName{2},curve.b));
    fprintf('phase of %s w.r. to %s is %.2f rad\n',OscName{1}(4:end),OscName{2}(4:end),curve.b);

elseif scanRabi
    addrFreq=13; %kHz
    rabiVec=linspace(0,1000,21);
    dark = zeros(size(rabiVec));
    lines=InitializeAxes (dic.GUI.sca(11),...
        'Dressed Simga_x amp(novatech)','Dark Counts %','Micromotion Single Qubit Addressing',...
        [rabiVec(1) rabiVec(end)],[0 100],1);
    set(lines(1),'Marker','.','MarkerSize',10,'Color','b');
    for index1 = 1:length(rabiVec)
        if dic.stop
            return;
        end
        softwareUpdateNoiseEater;
        dic.setNovatech('DoublePass','freq',dic.updateF674+dic.MMFreq/2,'amp',1000); 
        dic.setNovatech('Blue','amp',rabiVec(index1),'freq',addrFreq/1000); %sigma_x amp in the dressed picture
        pause(0.1);
        r=experimentSequence(OscName{1},OscName{2},OscName{3},piTime(1),probeTime);
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
elseif scanRabiTime
    addrFreq=15.4250; %kHz
    pulseTime=linspace(1,301,11);
    dark = zeros(size(pulseTime));
    lines=InitializeAxes (dic.GUI.sca(10),...
        'Dressed Simga_x time(mus)','Dark Counts %','Micromotion Single Qubit Addressing',...
        [pulseTime(1) pulseTime(end)],[0 100],1);
    set(lines(1),'Marker','.','MarkerSize',10,'Color','b');
    dic.setNovatech('Blue','amp',sigma_xAmp,'freq',addrFreq/1000); %sigma_x amp in the dressed picture
    %dic.setNovatech('Echo','amp',0);
    for index1 = 1:length(pulseTime)
        if dic.stop
            return;
        end
        softwareUpdateNoiseEater;
        dic.setNovatech('DoublePass','freq',dic.updateF674+dic.MMFreq/2,'amp',1000); 
        pause(0.1);
        r=experimentSequence(OscName{1},OscName{2},OscName{3},piTime(1),pulseTime(index1));
        dic.GUI.sca(1);
        hist(r,1:1:dic.maxPhotonsNumPerReadout);
        if dic.TwoIonFlag
            dark(index1) =100-sum( (r>dic.TwoIonsCountThreshold)*2+...
                ((r>dic.darkCountThreshold)&(r<dic.TwoIonsCountThreshold))*1 ...
                )/2/length(r)*100;
        else
            dark(index1) = sum( r<dic.darkCountThreshold)/length(r)*100;
        end
        AddLinePoint(lines(1),pulseTime(index1),dark(index1));
    end
    showData='figure;plot(pulseTime,dark);xlabel(''Dressed Simga_x time(mus)'');ylabel(''dark[%]''); title(''Micromotion Single Qubit Addressing'')';
    dic.save;    
else %scan freq of sigma_x in the dressed frame
    lines=InitializeAxes (dic.GUI.sca(9),...
        'Addressing Freq (kHz)','Dark Counts %','Micromotion Single Qubit Addressing',...
        [addrFreq(1) addrFreq(end)],[0 100],1);
    set(lines(1),'Marker','.','MarkerSize',10,'Color','b');
    dark = zeros(size(addrFreq));
    for index1 = 1:length(addrFreq)
        if dic.stop
            return;
        end
        softwareUpdateNoiseEater;
        dic.setNovatech('DoublePass','freq',dic.updateF674+dic.MMFreq/2,'amp',1000); 
        dic.setNovatech('Blue','freq',addrFreq(index1)/1000); %sigma_x freq in the dressed picture
        pause(0.1);
        r=experimentSequence(OscName{1},OscName{2},OscName{3},piTime(1),probeTime);
        dic.GUI.sca(1);
        hist(r,1:1:dic.maxPhotonsNumPerReadout);
        if dic.TwoIonFlag
            dark(index1) =100-sum( (r>dic.TwoIonsCountThreshold)*2+...
                ((r>dic.darkCountThreshold)&(r<dic.TwoIonsCountThreshold))*1 ...
                )/2/length(r)*100;
        else
            dark(index1) = sum( r<dic.darkCountThreshold)/length(r)*100;
        end
        AddLinePoint(lines(1),addrFreq(index1),dark(index1));
    end
    showData='figure;plot(addrFreq,dark);xlabel(''addressing freq(kHz)'');ylabel(''dark[%]''); title(''Micromotion Single Qubit Addressing'')';
    dic.save;
    
end

%%------------------------ experiment sequence -----------------
    function r=experimentSequence(osc1,osc2,osc3,piTime1,probeTime)
        prog=CodeGenerator;
        prog.GenDDSPullParametersFromBase;

        % set DDS freq and amp
        prog.GenSeq(Pulse('ExperimentTrigger',0,50));
        % Doppler coolng
        prog.GenSeq(Pulse('OffRes422',0,1));%turn off cooling
        prog.GenSeq(Pulse('OnResCooling',10,dic.Tcooling));
        %optical pumping
        prog.GenSeq([Pulse('Repump1033',0,dic.T1033),...
                    Pulse('OpticalPumping',dic.T1033,dic.Toptpump)]);
        % carrier pi/2                      
        prog.GenSeq([Pulse(osc1,0,piTime1/2), Pulse('674DoublePass',0,piTime1/2)]);
        % dressing+sigma_x
        prog.GenSeq([Pulse(osc2,0,probeTime),Pulse(osc3,0,probeTime),Pulse('674DoublePass',0,probeTime)]);
        % carrier pi/2                      
         prog.GenSeq([Pulse(osc1,0,piTime1/2), Pulse('674DoublePass',0,piTime1/2)]);
        
        % detection
        prog.GenSeq([Pulse('OnRes422',0,dic.TDetection) Pulse('PhotonCount',0,dic.TDetection)]);
        % resume cooling
        prog.GenSeq(Pulse('Repump1033',0,dic.T1033));

        prog.GenSeq([Pulse('OffRes422',0,0) Pulse('Repump1092',0,0)]);
        prog.GenFinish;    
        dic.com.UploadCode(prog);
        dic.com.UpdateFpga;
        dic.com.WaitForHostIdle; % wait until host finished it last task
        rep=200;
        dic.com.Execute(rep);
        dic.com.WaitForHostIdle;
        r = dic.com.ReadOut(rep);
    end
end

