function RamseyZeeman

dic=Dictator.me;

% armTime=4000:1000:10000;
armTime=0:100:1000;

piPhase=0:pi/6:2*pi;

doEcho=0;

repetitions=100;

% ------------Set GUI axes ---------------
cla(dic.GUI.sca(7));
InitializeAxes(dic.GUI.sca(1),'Photons #','Cases Counted #','Fluorescence Histogram',...
                [0 dic.maxPhotonsNumPerReadout],[],0);
% 
lines =InitializeAxes (dic.GUI.sca(6),...
    'Pi Phase','Dark Counts %','Rabi Scan',...
    [piPhase(1) piPhase(end)],[0 100],2);
grid(dic.GUI.sca(6),'on');
set(lines(1),'Marker','.','MarkerSize',10,'Color','b');
set(lines(2),'Marker','.','MarkerSize',10,'Color','r');

% -------- Main function scan loops ------
dark = zeros(length(armTime),length(piPhase));
for index1 = 1:length(armTime)
    set(lines(1),'XData',[],'YData',[]);
    for index2=1:length(piPhase)
        if dic.stop
            return
        end
        dic.setNovatech('DoublePass','freq',dic.updateF674,'amp',1000);
        pause(0.1);
        r=experimentSequence(armTime(index1),piPhase(index2));
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
         dic.GUI.sca(7);
        imagesc(piPhase,armTime*2,dark);
        axis([min(piPhase) max(piPhase) min(armTime*2) max(armTime*2)]);
        colorbar;
        ylabel('armTime x2(mus)'); xlabel('piPhase'); title('Dark');
        AddLinePoint(lines(1),piPhase(index2),dark(index1,index2));
        pause(0.1);
    end
end


%--------------- Save data ------------------

showData='figure;plot(armTime,dark);xlabel(''Pulse Time[\mus]'');ylabel(''dark[%]'');';
dic.save;


%--------------------------------------------------------------------
    function r=experimentSequence(armTime,piPhase)
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

        prog.GenSeq([Pulse('NoiseEater674',2,16),...
                     Pulse('674DDS1Switch',0,20)]); %NoiseEater initialization
        prog.GenSeq(Pulse('Repump1033',0,dic.T1033)); %cleaning D state
                
        prog.GenSeq(Pulse('OpticalPumping',10,dic.Toptpump));

        prog.GenSeq(Pulse('RFDDS2Switch',0,dic.TimeRF/2));    

        prog.GenPause(armTime);
        if doEcho
            prog.GenSeq(Pulse('RFDDS2Switch',2,dic.TimeRF));% echo Pulse
        end
        prog.GenPause(armTime);        
            
        %second pi/2 Pulse
        prog.GenSeq([Pulse('RFDDS2Switch',0,dic.TimeRF/2,'phase',piPhase)]);    
                 
        % detection
        prog.GenSeq([Pulse('674DDS1Switch',1,dic.T674),Pulse('674DoublePass',0,dic.T674+2)]); %first pi/2 Pulse
                 
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