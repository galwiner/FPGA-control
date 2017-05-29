function RamseyZeemanHidingTest

dic=Dictator.me;

piPhase=0:pi/5:2*pi;

doEcho=0;

repetitions=200;

doHide=1;
HideOnMM=1;

doBlast=1;  %shine 422 during the hide phase
DetuningSpinDown=(-2.802*1/2+1.68*3/2)*(dic.FRF/2.802);

novatechAmp1=363;novatechAmp2=1000;
CrystalCheckPMT;
LightShift=14.5;

if doHide
    %     WaitTime=1:20:100;
    WaitTime=1:10:50;
    armTime=1;
    ScanParameter=WaitTime;
    if HideOnMM
        dic.setNovatech('Echo','freq',dic.SinglePass674freq-dic.MMFreq,'amp',novatechAmp2);
        dic.setNovatech('Parity','freq',dic.SinglePass674freq-dic.MMFreq+DetuningSpinDown+LightShift/1000,'amp',novatechAmp2);
        OscName{1}='674Echo';OscName{2}='674Parity';     
    else
        dic.setNovatech('Blue','freq',dic.SinglePass674freq,'amp',novatechAmp1);
        dic.setNovatech('Red','freq',dic.SinglePass674freq+DetuningSpinDown+LightShift/1000,'amp',novatechAmp2);
        OscName{1}='674Gate';OscName{2}='674Gate';     
    end
    
else
    WaitTime=1;
    armTime=0:100:500;
    ScanParameter=armTime;
end

% armTime=0:50:2000;
% piPhase=0:pi/10:2*pi;


%  PulseTime=0.1:0.3:4;
% ------------Set GUI axes ---------------
cla(dic.GUI.sca(7));
InitializeAxes(dic.GUI.sca(1),'Photons #','Cases Counted #','Fluorescence Histogram',...
                [0 dic.maxPhotonsNumPerReadout],[],0);

if HideOnMM
    minvalue=25;
    maxvalue=75;
else
    minvalue=0;
    maxvalue=100;
end

lines =InitializeAxes (dic.GUI.sca(6),...
    'Pi Phase','Dark Counts %','Rabi Scan',...
    [piPhase(1) piPhase(end)],[minvalue maxvalue],2);
grid(dic.GUI.sca(6),'on');
set(lines(1),'Marker','.','MarkerSize',10,'Color','b');
set(lines(2),'Marker','.','MarkerSize',10,'Color','r');

% -------- Main function scan loops ------
dark = zeros(length(ScanParameter),length(piPhase));
for index1 = 1:length(ScanParameter)
    set(lines(1),'XData',[],'YData',[]);
    dic.setNovatech('DoublePass','freq',dic.updateF674,'amp',1000);
    CrystalCheckPMT;
    for index2=1:length(piPhase)
        if dic.stop
            return
        end
        pause(0.1);
        if doHide
            r=experimentSequence(armTime,piPhase(index2),ScanParameter(index1));
        else
            r=experimentSequence(ScanParameter(index1),piPhase(index2),WaitTime);
        end
        %     r=experimentSequence(PulseTime(index1),dic.updateF674);
        dic.GUI.sca(1); %get an axis from Dictator GUI to show data
        hist(r,0:1:(1.8*dic.maxPhotonsNumPerReadout));
        ivec=dic.IonThresholds;
        tmpdark=0;
        for tmp=1:dic.NumOfIons
            tmpdark=tmpdark+sum((r>ivec(tmp))&(r<ivec(tmp+1)))*tmp;
        end
        tmpdark=100-tmpdark/length(r)/(dic.NumOfIons)*100;
        dark(index1,index2)=tmpdark;
        AddLinePoint(lines(1),piPhase(index2),dark(index1,index2));
        %         pause(0.1);
    end
    dic.GUI.sca(7);
    imagesc(piPhase,ScanParameter,dark);
    axis([min(piPhase) max(piPhase) min(ScanParameter) max(ScanParameter)]);
    colorbar;
    ylabel('ScanParameter(mus)'); xlabel('piPhase'); title('Dark');
    
end


%--------------- Save data ------------------

showData='figure;plot(ScanParameter,dark);xlabel(''Pulse Time[\mus]'');ylabel(''dark[%]'');';
dic.save;


%--------------------------------------------------------------------
    function r=experimentSequence(armTime,piPhase,waittime)
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

        prog.GenSeq([Pulse('674Echo',0,15),... % NoiseEater Initialization
                Pulse('NoiseEater674',2,10),Pulse('674DoublePass',0,15),...
                Pulse('Repump1033',15,dic.T1033),...
                Pulse('OpticalPumping',16+dic.T1033,dic.Toptpump)]);
                
        prog.GenSeq(Pulse('OpticalPumping',10,dic.Toptpump));
        ZeemanPiTime=dic.piHalfRF;        
        prog.GenSeq(Pulse('RFDDS2Switch',0,ZeemanPiTime));    

        prog.GenPause(armTime);
        if doEcho
            prog.GenSeq(Pulse('RFDDS2Switch',2,dic.TimeRF));% echo Pulse
        end
        if doHide
            % Perform hiding pulses, either on MM or on carrier
            if HideOnMM
                prog.GenSeq([Pulse('674Echo',0,dic.HiddingInfo.Tmm1),Pulse('674Parity',dic.HiddingInfo.Tmm1,dic.HiddingInfo.Tmm2),...
                    Pulse('674DoublePass',0,dic.HiddingInfo.Tmm1+dic.HiddingInfo.Tmm2)]);
                prog.GenSeq([Pulse('674DoublePass',0,dic.HiddingInfo.Tmm2)]);
            else
                
                prog.GenSeq([Pulse('674Gate',2,dic.HiddingInfo.Tcarrier1),Pulse('674DoublePass',2,dic.HiddingInfo.Tcarrier1)]);
            end
             if doBlast
                 prog.GenSeq(Pulse('OffRes422',2,3)); % blast him !
             end
             prog.GenPause(2*waittime);
             
            % Recovery pulses.
             if HideOnMM
                 prog.GenSeq([Pulse('674Echo',0,dic.HiddingInfo.Tmm1),Pulse('674Parity',dic.HiddingInfo.Tmm1,dic.HiddingInfo.Tmm2),...
                     Pulse('674DoublePass',0,dic.HiddingInfo.Tmm1+dic.HiddingInfo.Tmm2)]);                 
             else
                 
                 prog.GenSeq([Pulse('674Gate',2,dic.HiddingInfo.Tcarrier1),Pulse('674DoublePass',2,dic.HiddingInfo.Tcarrier1)]);
             end
             
        end
        
        prog.GenPause(armTime);        
        
        
        %second pi/2 Pulse
        prog.GenSeq([Pulse('RFDDS2Switch',0,ZeemanPiTime,'phase',piPhase)]);            
                 
        % detection
        prog.GenSeq([Pulse('674DDS1Switch',0,dic.T674),Pulse('674DoublePass',0,dic.T674)]); %first pi/2 Pulse
                 
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