function RFResScanRamsey

dic=Dictator.me;

% armTime=4000:1000:10000;
armTime=400; %mus

fastScan=0;

if fastScan==1
    [-300 -150 0 150 300]*1e-6;
else
    detuning=[-1000:200:1000]*1e-6;
end

doEcho=0;

repetitions=200;


%  PulseTime=0.1:0.3:4;
% ------------Set GUI axes ---------------
InitializeAxes(dic.GUI.sca(1),'Photons #','Cases Counted #','Fluorescence Histogram',...
                [0 dic.maxPhotonsNumPerReadout],[],0);
 
% lines =InitializeAxes (dic.GUI.sca(9),...
%     'Index','Dark Counts %','Ramsey Detuning Scan',...
%     [1 expnum],[-600 600],2);
lines =InitializeAxes (dic.GUI.sca(9),...
    'Index','Frequency Shift','Ramsey Detuning Scan',...
    [detuning(1) detuning(end)],[0 100],2);

% grid(dic.GUI.sca(9),'on');
set(lines(1),'Marker','.','MarkerSize',10,'Color','b');
set(lines(2),'Marker','.','MarkerSize',10,'Color','r');

% -------- Main function scan loops ------
dark = zeros(length(detuning),1);
% set(lines(1),'XData',[],'YData',[]);
if dic.stop
    return
end

for index1 = 1:length(detuning)
    if dic.stop
        return
    end
    r=experimentSequence(armTime,detuning(index1));
    ivec=dic.IonThresholds;
    tmpdark=0;
    for tmp=1:dic.NumOfIons
        tmpdark=tmpdark+sum((r>ivec(tmp))&(r<ivec(tmp+1)))*tmp;
    end
    tmpdark=100-tmpdark/length(r)/(dic.NumOfIons)*100;
    dark(index1)=tmpdark;
    AddLinePoint(lines(1),detuning(index1),dark(index1));
    pause(0.1);
end

%--------- Fitting --------
if fastScan==0
    ft=fittype(sprintf('50+50*sin((x-a)*2*pi*%.0f)',armTime));
    fo=fitoptions('Method','NonlinearLeastSquares',...
        'Startpoint',detuning(find(dark>50,1)),...
        'MaxFunEvals',20000,'MaxIter',20000);
    [curve,goodness]=fit(detuning',dark,ft,fo);
    set(lines(2),'XData',detuning,'YData',curve(detuning));
    cf=diff(confint(curve))/2;
    fprintf('Phase Shift=%3.0f(%.0f)Hz\n',curve.a*1e6,cf(1)*1e6);
    
    if abs(curve.a)<500e-6
        dic.FRF=dic.FRF+curve.a;
    else
        RFResScan;
    end
else
    ft=fittype('50+a*(x-b)');
    fo=fitoptions('Method','NonlinearLeastSquares',...
        'Startpoint',[10 0],...
        'MaxFunEvals',20000,'MaxIter',20000);
    [curve,goodness]=fit(detuning',dark,ft,fo);
    set(lines(2),'XData',detuning,'YData',curve(detuning));
    cf=diff(confint(curve))/2;
    fprintf('Phase Shift=%3.0f(%.0f)Hz\n',curve.b*1e6,cf(2)*1e6);
    dic.FRF=dic.FRF+curve.b;
end
% %     AddLinePoint(lines(1),toc,curve.a*1e6);
% %     pause(0.01);
% %      dic.FRF=dic.FRF+curve.a;
% if abs(curve.a)<100e-6
%     dic.FRF=dic.FRF+curve.a;
%     count=0;
% else
%     if abs(curve.a)>500e-6
%         RFResScan;
%     elseif abs(curve.a)>200e-6
%         dic.FRF=dic.FRF+curve.a;
%         RFResScanRamsey;
%     end
% end
% 

%--------------- Save data ------------------

showData='figure;plot(detuning,dark);xlabel(''Detuning [Hz]'');ylabel(''dark[%]'');';
% dic.save;


%--------------------------------------------------------------------
    function r=experimentSequence(armTime,detuning)
        prog=CodeGenerator;
        prog.GenDDSPullParametersFromBase;
        prog.GenSeq(Pulse('ExperimentTrigger',0,50));
        % prog.GenWaitExtTrigger;
        % set DDS freq and amp
        prog.GenSeq(Pulse('674DDS1Switch',0,-1,'freq',dic.SinglePass674freq,'amp',100));
        prog.GenSeq(Pulse('RFDDS2Switch',3,-1,'amp',dic.ampRF,'freq',dic.FRF+detuning,'phase',0));

        % Doppler coolng
        prog.GenSeq(Pulse('OffRes422',0,500));%turn off cooling
        prog.GenSeq(Pulse('OnResCooling',0,dic.Tcooling) );

        %activate noise eater, move it to int hold and repump
        prog.GenSeq([Pulse('674DDS1Switch',0,15),... 
                    Pulse('NoiseEater674',2,10),Pulse('674DoublePass',0,15),...
                    Pulse('Repump1033',15,dic.T1033),...
                    Pulse('OpticalPumping',16+dic.T1033,dic.Toptpump)]);

        prog.GenSeq(Pulse('RFDDS2Switch',1,dic.piHalfRF));    

        prog.GenPause(armTime);        
        
        %second pi/2 Pulse
        prog.GenSeq([Pulse('RFDDS2Switch',1,dic.piHalfRF,'phase',pi/2)]);    
             
        % detection
        prog.GenSeq([Pulse('674DDS1Switch',2,dic.T674),Pulse('674DoublePass',0,dic.T674+4)]); %first pi/2 Pulse
                 
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