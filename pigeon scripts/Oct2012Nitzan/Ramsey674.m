function Ramsey674

dic=Dictator.me;

%  armTime=50:250:3000;
armTime=10:100:1000;
piPhase=0:pi/6:2*pi;

doEcho=0;
doSpinLock=0;
InitSpinDownd=0;
DoMagneticEcho=0;

ScanTimeAndPhase=1;
ScanTimeAndDetuning=0;
RamseyOnMM=0;

repetitions=100;

if InitSpinDownd==0
    PiTime=dic.T674;
else
    PiTime=dic.T674+0.6;
end


% ------------Set GUI axes ---------------
InitializeAxes(dic.GUI.sca(1),'Photons #','Cases Counted #','Fluorescence Histogram',...
                [0 dic.maxPhotonsNumPerReadout],[],0);
%% -------- ScanTimeAndPhase Main function scan loops ------
if ScanTimeAndPhase
    lines =InitializeAxes (dic.GUI.sca(6),...
    'Pi Phase','Dark Counts %','Rabi Scan',...
    [piPhase(1) piPhase(end)],[0 100],2);
    grid(dic.GUI.sca(6),'on');
    set(lines(1),'Marker','.','MarkerSize',10,'Color','b');
    set(lines(2),'Marker','.','MarkerSize',10,'Color','r');
        lines2 =InitializeAxes (dic.GUI.sca(10),...
        'Time','Contrast','Ramsey',...
        [armTime(1) armTime(end)],[0 100],2);
    grid(dic.GUI.sca(6),'on');
    set(lines2(1),'Marker','.','MarkerSize',10,'Color','b');
    set(lines2(2),'Marker','.','MarkerSize',10,'Color','r');
    dark = zeros(length(armTime),length(piPhase));
    contrast=zeros(length(armTime));
    minmax=zeros(length(armTime));
    for index1 = 1:length(armTime)

        CrystalCheckPMT;
        set(lines(1),'XData',[],'YData',[]);
        for index2=1:length(piPhase)
            if dic.stop
                return
            end

            dic.setNovatech('DoublePass','freq',dic.updateF674-InitSpinDownd*(dic.FRF/2.8*(0.56*2))/2);  % work on the S-1/2 -> D+1/2 tansition    
            r=experimentSequence(armTime(index1),piPhase(index2));
            dic.GUI.sca(1); %get an axis from Dictator GUI to show data
            hist(r,0:1:(1.8*dic.maxPhotonsNumPerReadout));
            
            ivec=dic.IonThresholds;
            tmpdark=0;
            for tmp=1:dic.NumOfIons
                tmpdark=tmpdark+sum((r>ivec(tmp))&(r<ivec(tmp+1)))*tmp;
            end
            tmpdark=100-tmpdark/length(r)/(dic.NumOfIons)*100;
            dark(index1,index2)=tmpdark;
            
            dic.GUI.sca(7);
            axis([min(piPhase) max(piPhase) min(armTime) max(armTime)]);
            imagesc(piPhase,armTime,dark);
            colorbar;
            ylabel('armTime(mus)'); xlabel('piPhase'); title('Dark');
            AddLinePoint(lines(1),piPhase(index2),dark(index1,index2));

            pause(0.1);
        end    %---------- fitting and updating ---------------------
            %pguess=phaseVec(find(dark==max(dark),1));
            ft=fittype('a*cos(x-b)+c');
            fo=fitoptions('Method','NonlinearLeastSquares',...
                    'Startpoint',[50 0 50],...
                    'MaxFunEvals',20000,'MaxIter',20000);
            [curve,goodness]=fit(piPhase',dark(index1,:)',ft,fo);
            set(lines(2),'XData',piPhase','YData',feval(curve,piPhase));       
            fprintf('Contrast is %.2f \n',curve.a*2);
            pause(1);
            contrast(index1)=abs(curve.a*2);
            minmax(index1)=max(dark(index1,:))-min(dark(index1,:));
            AddLinePoint(lines2(1),armTime(index1),contrast(index1));
            AddLinePoint(lines2(2),armTime(index1),minmax(index1));
    end    
end
%% -------- ScanTimeAndDetuning Main function scan loops ------
if ScanTimeAndDetuning
    detuning=1e-3*linspace(-1,1,50);
    armTime=300:100:1000;
    dark = zeros(length(armTime),length(detuning));
    detuningList=zeros(length(armTime),length(detuning));
    disp(dic.updateF674);
    for index1 = 1:length(armTime)
        %CrystalCheckPMT;
        for index2=1:length(detuning)
            if dic.stop
                return
            end
            detune674=detuning(index2)*(300/armTime(index1));
            detuningList(index1,index2)=detune674;
            dic.setNovatech('DoublePass','freq',dic.estimateF674-(dic.FRF/2.8*(0.56*2))/2+detune674);  % work on the S-1/2 -> D+1/2 tansition    
            r=experimentSequence(armTime(index1),0);
            dic.GUI.sca(1); %get an axis from Dictator GUI to show data
            hist(r,0:1:(1.8*dic.maxPhotonsNumPerReadout));
            if (dic.TwoIonFlag||(dic.NumOfIons>2))
                ivec=dic.IonThresholds;
                tmpdark=0;
                for tmp=1:dic.NumOfIons
                    tmpdark=tmpdark+sum((r>ivec(tmp))&(r<ivec(tmp+1)))*tmp;
                end
                tmpdark=100-tmpdark/length(r)/(dic.NumOfIons)*100;
                dark(index1,index2)=tmpdark;
            else
                dark(index1,index2) = sum( r<dic.darkCountThreshold)/length(r)*100;
            end
            dic.GUI.sca(7);
            axis([min(detuning) max(detuning) min(armTime) max(armTime)]);
            pcolor(detuningList,armTime,dark);shading flat;
            colorbar;
            ylabel('armTime(mus)'); xlabel('detuning'); title('Dark');
            pause(0.1);
        end   
    end    
end

showData='figure;plot(armTime,dark);xlabel(''Pulse Time[\mus]'');ylabel(''dark[%]'');';
dic.save;
%% --------------------------------------------------------------------
    function r=experimentSequence(armTime,piPhase)
        prog=CodeGenerator;
        prog.GenDDSPullParametersFromBase;
        %          prog.GenWaitExtTrigger;
        prog.GenSeq(Pulse('ExperimentTrigger',0,50));
        % set DDS freq and amp
        prog.GenSeq(Pulse('674DDS1Switch',0,-1,'freq',dic.SinglePass674freq,'amp',100));
        prog.GenSeq(Pulse('RFDDS2Switch',1,-1,'freq',dic.FRF,'amp',dic.ampRF));
        % Doppler coolng
        
        prog.GenSeq(Pulse('OffRes422',0,500));%turn off cooling
        prog.GenSeq(Pulse('OnResCooling',0,dic.Tcooling) );
        % noise eater calibration and preperation
        prog.GenSeq([Pulse('674DDS1Switch',0,15),...
                     Pulse('NoiseEater674',2,10),Pulse('674DoublePass',0,15),...
                     Pulse('Repump1033',15,dic.T1033),...
                     Pulse('OpticalPumping',16+dic.T1033,dic.Toptpump)]);   prog.GenSeq(Pulse('OpticalPumping',10,dic.Toptpump));
        if InitSpinDownd
                prog.GenSeq(Pulse('RFDDS2Switch',1,dic.TimeRF));
        end
        % First Ramsey Pulse  
        prog.GenSeq([Pulse('674DDS1Switch',1,PiTime/2,'phase',0),Pulse('674DoublePass',0,PiTime/2+2)]); %first pi/2 Pulse
        % Stuff during the Ramsey time
        if doSpinLock
           %prog.GenSeq(Pulse('674DDS1Switch',5,-1,'amp',75));         
            prog.GenSeq([Pulse('674DDS1Switch',5,armTime*2,'phase',pi/2),Pulse('674DoublePass',5,armTime*2)]);% echo Pulse            
           %prog.GenSeq(Pulse('674DDS1Switch',5,-1,'amp',100));
        elseif DoMagneticEcho
            prog.GenPause(2*armTime*0.2);% the time in the -1/2 is (0.56)/(1.68+0.56+0.56)
            prog.GenSeq(Pulse('RFDDS2Switch',1,dic.TimeRF));
            prog.GenPause(2*armTime*0.8); % the time in the +1/2 is (1.68+0.56)/(1.68+0.56+0.56)           
            prog.GenSeq(Pulse('RFDDS2Switch',1,dic.TimeRF));
        else      
            prog.GenPause(armTime);
            if doEcho
                prog.GenSeq([Pulse('674DDS1Switch',0,PiTime,'phase',pi/2),Pulse('674DoublePass',0,PiTime)]);% echo Pulse
            end
            prog.GenPause(armTime);
        end
        % Second Ramsey Pulse
        prog.GenSeq([Pulse('674DDS1Switch',1,PiTime/2,'phase',piPhase),Pulse('674DoublePass',0,PiTime/2+2)]); %first pi/2 Pulse
                
        % Detection
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