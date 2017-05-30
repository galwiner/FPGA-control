function TwoOscillatorRamsey(varargin)
dic=Dictator.me;

novatechAmp=1000;
MMFreq=21.75;

OscName{1}='674DDS1Switch';
% OscName{2}='674DDS1Switch';
OscName{2}='MMsideband';
phaseVec=linspace(0,2*pi-0.1,20);
novatechAmp=1000;

for t=1:2
    switch OscName{t}
        case '674DDS1Switch'
            piTime(t)=dic.T674;
        case '674Gate'
            dic.setNovatech('Blue','amp',1000);
            dic.setNovatech('Red','amp',novatechAmp); %multiply by zero
            piTime(t)=dic.AddrInfo.T674Gate;
        case '674Parity'
            dic.setNovatech('Parity','freq',dic.SinglePass674freq,'amp',novatechAmp);
            piTime(t)=dic.AddrInfo.T674Parity;
        case '674Echo'
            dic.setNovatech('Echo','freq',dic.SinglePass674freq,'amp',novatechAmp);
            piTime(t)=dic.AddrInfo.T674Echo;
        case 'MMsideband'
            dic.setNovatech('DoublePassSecond','freq',dic.F674DoublePassCarrier-MMFreq/2);
            piTime(t)=dic.HiddingInfo.Tmm1;
            phaseVec=linspace(0,2*pi,25);

    end
    pause(0.2);
end


CrystalCheckPMT;

%-------------- Set GUI figures ---------------------
InitializeAxes (dic.GUI.sca(1),'Photons #','Cases Counted #','Fluorescence Histogram',...
    [0 dic.maxPhotonsNumPerReadout],[],0);
lines =InitializeAxes (dic.GUI.sca(7),...
    'Phase[rad]','Dark Counts %',sprintf('Two Osc Ramsey:%s,%s',OscName{1},OscName{2}),...
    [phaseVec(1) phaseVec(end)],[0 100],1);
set(lines(1),'Marker','.','MarkerSize',10,'Color','b');

%-------------- Main function scan loops ---------------------
dark = zeros(size(phaseVec));
for index1 = 1:length(phaseVec)
    if dic.stop
        return;
    end
    switch OscName{2}
        case '674Gate'
            dic.setNovatech('Red','phsae',phaseVec(index1));
        case '674Parity'
            dic.setNovatech('Parity','phase',phaseVec(index1));
        case '674Echo'
            dic.setNovatech('Echo','phase',phaseVec(index1));
        case 'MMsideband'
            dic.setNovatech('DoublePassSecond','phase',phaseVec(index1));
    end

    dic.setNovatech('DoublePass','freq',dic.updateF674,'amp',1000);
    pause(0.1);
    r=experimentSequence(OscName{1},OscName{2},piTime(1),piTime(2),phaseVec(index1));
    dic.GUI.sca(1);
    hist(r,1:1:dic.maxPhotonsNumPerReadout);
    ivec=dic.IonThresholds;
    tmpdark=0;
    for tmp=1:dic.NumOfIons
        tmpdark=tmpdark+sum((r>ivec(tmp))&(r<ivec(tmp+1)))*tmp;
    end
    tmpdark=100-tmpdark/length(r)/(dic.NumOfIons)*100;
    dark(index1)=tmpdark;
    AddLinePoint(lines(1),phaseVec(index1),dark(index1));
end
%---------- fitting and updating ---------------------
pguess=phaseVec(find(dark==max(dark),1));
ft=fittype('a*cos(x-b)+c');
fo=fitoptions('Method','NonlinearLeastSquares',...
    'Startpoint',[50 pguess 50],...
    'MaxFunEvals',20000,'MaxIter',20000);
[curve,goodness]=fit(phaseVec',dark',ft,fo);
dic.GUI.sca(7); hold on; plot(curve); hold off; legend off;
eval(sprintf('dic.AddrInfo.P%s=%.2f',OscName{2},curve.b));
fprintf('phase of %s w.r. to %s is %.2f rad\n',OscName{1}(4:end),OscName{2}(4:end),curve.b);
fprintf('Contrast is %.2f \n',curve.a*2);

%------------ Save data ------------------
showData='figure;plot(phaseVec,dark);xlabel(''Phase [rad]'');ylabel(''dark[%]''); title(sprintf(''Two Osc Ramsey:%s,%s'',OscName{1},OscName{2}))';
dic.save;

%%------------------------ experiment sequence -----------------
    function r=experimentSequence(osc1,osc2,pTime1,pTime2,pPhase)
        prog=CodeGenerator;
        prog.GenDDSPullParametersFromBase;
        prog.GenSeq(Pulse('674DDS1Switch',2,-1,'freq',dic.SinglePass674freq,'amp',100));
       
        % set DDS freq and amp
        % Doppler coolng
        prog.GenSeq(Pulse('OffRes422',0,500));%turn off cooling
        prog.GenSeq(Pulse('OnResCooling',10,dic.Tcooling));
        prog.GenSeq(Pulse('ExperimentTrigger',0,50));
        
        %calibrate noise eater + optical pumping
        
        prog.GenSeq([Pulse('674DDS1Switch',1,15),...
                     Pulse('NoiseEater674',3,10),Pulse('674DoublePass',0,15),...
                     Pulse('Repump1033',15,dic.T1033),...
                     Pulse('OpticalPumping',16+dic.T1033,dic.Toptpump)]);
        
        switch osc1
            case '674DDS1Switch'
                prog.GenSeq([Pulse('674DDS1Switch',2,pTime1/2,'phase',0,'freq',dic.SinglePass674freq),Pulse('674DoublePass',0,pTime1/2+3)]);
            case '674Gate'
                prog.GenSeq([Pulse('674Gate',2,pTime1/2), Pulse('674DoublePass',0,pTime1/2+3)]);
            case '674Parity'
                prog.GenSeq([Pulse('674Parity',2,pTime1/2), Pulse('674DoublePass',0,pTime1/2+3)]);
            case '674Echo'
                prog.GenSeq([Pulse('674Echo',2,pTime1/2), Pulse('674DoublePass',0,pTime1/2+3)]);
            case 'MMsideband'
                prog.GenSeq(Pulse('674DDS1Switch',2,pTime1/2,'phase',0,'freq',dic.SinglePass674freq));

        end
        
        prog.GenPause(10);
        %drive the second pi/2 pulse
        switch osc2
            case '674DDS1Switch'
                prog.GenSeq([Pulse('674DDS1Switch',2,pTime2/2,'phase',pPhase),Pulse('674DoublePass',2,pTime2/2+3)]);
            case '674Gate'
                prog.GenSeq([Pulse('674Gate',2,pTime2/2), Pulse('674DoublePass',0,pTime2/2+3)]);
            case '674Parity'
                prog.GenSeq([Pulse('674Parity',2,pTime2/2), Pulse('674DoublePass',0,pTime2/2+3)]);
            case '674Echo'
                prog.GenSeq([Pulse('674Echo',2,pTime2/2), Pulse('674DoublePass',0,pTime2/2+3)]);
            case 'MMsideband'
                prog.GenSeq(Pulse('674DDS1Switch',2,pTime2/2));
        end
        
        % detection
        prog.GenSeq([Pulse('OnRes422',10,dic.TDetection) Pulse('PhotonCount',10,dic.TDetection)]);
        % resume cooling
        prog.GenSeq(Pulse('Repump1033',0,dic.T1033));
        
        prog.GenSeq([Pulse('OffRes422',0,0) Pulse('Repump1092',0,0)]);
        prog.GenFinish;
        dic.com.UploadCode(prog);
        dic.com.UpdateFpga;
        dic.com.WaitForHostIdle; % wait until host finished it last task
        rep=400;
        dic.com.Execute(rep);
        dic.com.WaitForHostIdle;
        r = dic.com.ReadOut(rep);
    end
end

