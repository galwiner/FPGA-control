function SigmaZCalibration

dic=Dictator.me;

piPhase=0:pi/5:2*pi;
% piPhase=pi/2-0.01:0.01:pi/2+0.01;

doEcho=0;

repetitions=100;

doHide=1;
doSingleIonDetection=1;
doOtherSingleIonDetection=0;
phaseFirstPulse=0;
phaseSecondPulse=pi/2;

DetuningSpinDown=(-2.802*1/2+1.68*3/2)*(dic.FRF/2.802);

CrystalCheckPMT;


MMFreq=21.75;

% ------------Set GUI axes ---------------
cla(dic.GUI.sca(7));
InitializeAxes(dic.GUI.sca(1),'Photons #','Cases Counted #','Fluorescence Histogram',...
                [0 dic.maxPhotonsNumPerReadout],[],0);

minvalue=0;
maxvalue=100;

lines =InitializeAxes (dic.GUI.sca(6),...
    'Pi Phase','Dark Counts %','Rabi Scan',...
    [piPhase(1) piPhase(end)],[minvalue maxvalue],2);
grid(dic.GUI.sca(6),'on');
set(lines(1),'Marker','.','MarkerSize',10,'Color','b');
set(lines(2),'Marker','.','MarkerSize',10,'Color','r');

% -------- Main function scan loops ------
dark = zeros(length(piPhase),1);
fidelity= zeros(length(piPhase),1);
result= zeros(length(piPhase),1);
spin= zeros(length(piPhase),1);

set(lines(2),'XData',[],'YData',[]);
set(lines(1),'XData',[],'YData',[]);

    LightShift=-0.0139;
    dic.setNovatech('DoublePassSecond','freq',dic.updateF674+LightShift/2-DetuningSpinDown/2-MMFreq/2,'amp',1000);
    dic.setNovatech('DoublePass','freq',dic.updateF674,'amp',1000);

    for index2=1:length(piPhase)
        if dic.stop
            return
        end
        pause(0.1);
        r=experimentSequence(piPhase(index2));
        %     r=experimentSequence(PulseTime(index1),dic.updateF674);
%         dic.GUI.sca(1); %get an axis from Dictator GUI to show data
%         hist(r,0:1:(1.8*dic.maxPhotonsNumPerReadout));
        ivec=dic.IonThresholds;
        tmpdark=0;
        for tmp=1:dic.NumOfIons
            tmpdark=tmpdark+sum((r>ivec(tmp))&(r<ivec(tmp+1)))*tmp;
        end
        tmpdark=100-tmpdark/length(r)/(dic.NumOfIons)*100;
        dark(index2)=tmpdark;
        result=dark;
        spin(index2)=(-1*sum((r<dic.IonThresholds(2))&r>dic.IonThresholds(1))+1*sum(r>dic.IonThresholds(2))+1*sum(r<dic.IonThresholds(1)))/length(r);
        
        %         pause(0.1);
        if doSingleIonDetection||doOtherSingleIonDetection
            fidelity(index2)=sum((r>dic.IonThresholds(1))&(r<dic.IonThresholds(2)))/length(r)*100;
            result=fidelity;
            spin(index2)=(-1*sum((r<dic.IonThresholds(2))&r>dic.IonThresholds(1))+1*sum(r>dic.IonThresholds(2))+1*sum(r<dic.IonThresholds(1)))/length(r);
        end
        resulttofit=result;
        AddLinePoint(lines(1),piPhase(index2),result(index2));                
    end
    
    ft=fittype('a*cos(x-b)+c');
%     fo=fitoptions('Method','NonlinearLeastSquares',...
%             'Startpoint',[(max(dark)-min(dark))/2 piPhase(find(dark==max(dark))) mean(dark)],...
%             'MaxFunEvals',20000,'MaxIter',20000);
    fo=fitoptions('Method','NonlinearLeastSquares',...
            'Startpoint',[50 4.7 50],...
            'MaxFunEvals',20000,'MaxIter',20000);
        [curve,goodness]=fit(piPhase',dark,ft,fo);
    dic.GUI.sca(6); hold on; plot(curve); hold off; legend off;
    cf=diff(confint(curve))*100/2;
    fprintf('Phase Shift=%2.2f(%.0f)\n',curve.b-pi/2,cf(2));
    dic.HiddingInfo.PhaseHide=curve.b-pi/2;
    if doOtherSingleIonDetection
        fprintf('Offset=%2.0f(%.0f)',curve.c,cf(3)/100);
        fprintf('Contrast=%2.0f(%.0f)\n',curve.a,cf(1)/100);
    end
    clear curve; clear goodness;
    

%--------------- Save data ------------------

% showData='figure;plot(armTime,dark);xlabel(''Pulse Time[\mus]'');ylabel(''dark[%]'');';
% dic.save;

%--------------------------------------------------------------------
    function r=experimentSequence(piPhase)
        prog=CodeGenerator;
        prog.GenDDSPullParametersFromBase;
        prog.GenSeq(Pulse('ExperimentTrigger',0,50));
        % prog.GenWaitExtTrigger;
        % set DDS freq and amp
        prog.GenSeq(Pulse('674DDS1Switch',0,-1,'freq',dic.SinglePass674freq,'amp',100));
        prog.GenSeq(Pulse('RFDDS2Switch',3,-1,'amp',dic.ampRF,'freq',dic.FRF,'phase',0));

        % Doppler coolng
        prog.GenSeq(Pulse('OffRes422',0,500));%turn off cooling
        prog.GenSeq(Pulse('OnResCooling',0,dic.Tcooling) );

        prog.GenSeq([Pulse('674DDS1Switch',0,15),... % NoiseEater Initialization
                Pulse('NoiseEater674',2,10),Pulse('674DoublePass',0,15),...
                Pulse('Repump1033',15,dic.T1033),...
                Pulse('OpticalPumping',16+dic.T1033,dic.Toptpump)]);


        prog.GenSeq(Pulse('OpticalPumping',10,dic.Toptpump));
        ZeemanPiTime=dic.piHalfRF;        
        prog.GenSeq(Pulse('RFDDS2Switch',0,ZeemanPiTime,'phase',phaseFirstPulse));    

%         prog.GenSeq(Pulse('RFDDS2Switch',0,ZeemanPiTime,'phase',phaseFirstPulse+pi/2));    
                
        if doEcho
            prog.GenSeq(Pulse('RFDDS2Switch',2,dic.TimeRF));% echo Pulse
        end
        
        if doHide
            % Perform hiding pulses, either on MM or on carrier
            prog.GenSeq([Pulse('674DDS1Switch',3,dic.HiddingInfo.Tmm1,'phase',0)]);
            prog.GenSeq([Pulse('674DDS1Switch',1,dic.HiddingInfo.Tmm1,'phase',piPhase)]);                         
%             prog.GenPause(100);
            %              prog.GenPause(2*dic.HiddingInfo.Tmm1);       
        end
        
        %second pi/2 Pulse
        prog.GenSeq([Pulse('RFDDS2Switch',0,ZeemanPiTime,'phase',phaseSecondPulse)]);            
        
        %shelve non-null ion to the hiding state and count the dark
        %probability, which is solely due to the non-null ion.
        if doSingleIonDetection
            prog.GenSeq([Pulse('674DDS1Switch',10,dic.HiddingInfo.Tmm1)]);
        elseif doOtherSingleIonDetection
            prog.GenSeq([Pulse('674DDS1Switch',10,dic.HiddingInfo.Tmm1)]);
            prog.GenSeq([Pulse('674DDS1Switch',5,dic.T674),Pulse('674DoublePass',0,dic.T674+5)]); %first pi/2 Pulse
        else
            % regular detection
            prog.GenSeq([Pulse('674DDS1Switch',2,dic.T674),Pulse('674DoublePass',0,dic.T674+2)]); %first pi/2 Pulse
        end
        
                 
        prog.GenSeq([Pulse('OnRes422',0,dic.TDetection) Pulse('PhotonCount',0,dic.TDetection)]);
        %resume cooling
        prog.GenSeq(Pulse('Repump1033',0,dic.T1033));
        prog.GenSeq(Pulse('OffRes422',0,0));
        prog.GenFinish;

        dic.com.UploadCode(prog);
        dic.com.UpdateFpga;
        dic.com.WaitForHostIdle; % wait until host finished it last task
        dic.com.Execute(repetitions);
        dic.com.WaitForHostIdle;
        r = dic.com.ReadOut(repetitions);
        r = r(2:end);
    end

end