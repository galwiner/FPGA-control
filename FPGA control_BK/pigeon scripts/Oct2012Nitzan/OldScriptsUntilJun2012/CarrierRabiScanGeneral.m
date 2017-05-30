function CarrierRabiGeneral

dic=Dictator.me;
PulseTime=1:5:200;
% radial at -2.0163
% axial at -0.9852
freq=dic.updateF674-0.9852; %go to some sideband and find the Rabi
% ------------Set GUI axes ---------------
InitializeAxes(dic.GUI.sca(1),'Photons #','Cases Counted #','Fluorescence Histogram',...
                [0 dic.maxPhotonsNumPerReadout],[],0);

lines =InitializeAxes (dic.GUI.sca(6),...
    'Pulse Time[\mus]','Dark Counts %','Rabi Scan',...
    [PulseTime(1) PulseTime(end)],[0 100],2);
grid(dic.GUI.sca(6),'on');
set(lines(1),'Marker','.','MarkerSize',10,'Color','b');
set(lines(2),'Marker','.','MarkerSize',10,'Color','r');

% -------- Main function scan loops ------
dark = zeros(size(PulseTime));
for index1 = 1:length(PulseTime)
    if dic.stopRun
        return
    end
    isOptPumpNeeded=1;
    r=experimentSequence(PulseTime(index1),freq,isOptPumpNeeded);
%     r=experimentSequence(PulseTime(index1),dic.updateF674);
    dic.GUI.sca(1); %get an axis from Dictator GUI to show data
    hist(r,0:1:(1.8*dic.maxPhotonsNumPerReadout));
    if dic.TwoIonFlag
        dark(index1) =100-sum( (r>dic.TwoIonsCountThreshold)*2+...
                             ((r>dic.darkCountThreshold)&(r<dic.TwoIonsCountThreshold))*1 ...
                            )/2/length(r)*100;
    else
        dark(index1) = sum( r<dic.darkCountThreshold)/length(r)*100;
    end
    if ~isOptPumpNeeded
        dark = dark*1.5;
    end
    AddLinePoint(lines(1),PulseTime(index1),dark(index1));
    pause(0.1);
end

[Nbar,Omega,y]=fitNbar2CarrierRabi((PulseTime)*1e-6,dark/100,dic.vibMode(1).freq,pi/4);
disp(sprintf('average n = %.2f  PiTime = %4.2f [mus]',Nbar,2*pi/Omega/4*1e6+0.5));
set(lines(2),'XData',PulseTime,'YData',y*100);
fprintf('pi time is %.2f mu s\n',2*pi/Omega/4*1e6);

%--------------------------------------------------------------------
    function r=experimentSequence(pulseTime,freq,withOpticalPumping)
        prog=CodeGenerator;
        prog.GenDDSPullParametersFromBase;
        prog.GenSeq(Pulse('674Switch2NovaTech',0,-1));
        % set DDS freq and amp
        prog.GenSeq(Pulse('674DDS1Switch',0,-1,'freq',freq,'amp',100));
        % Doppler coolng
        prog.GenSeq(Pulse('OffRes422',0,1));%turn off cooling
        prog.GenSeq(Pulse('OnResCooling',0,dic.Tcooling) );
        if withOpticalPumping
            prog.GenSeq(Pulse('OpticalPumping',0,dic.Toptpump));
        end
        %shelving
        if (pulseTime>3)
           prog.GenSeq([Pulse('NoiseEater674',1,pulseTime-2),...
                        Pulse('674DDS1Switch',0,pulseTime,'freq',freq)]);
        else
           prog.GenSeq(Pulse('674DDS1Switch',0,pulseTime,'freq',freq));
        end
        
        prog.GenSeq(Pulse('ExperimentTrigger',0,50));
        % detection
        prog.GenSeq([Pulse('OnRes422',0,dic.TDetection) Pulse('PhotonCount',0,dic.TDetection)]);
        %resume cooling
        prog.GenSeq(Pulse('Repump1033',0,dic.T1033));
        prog.GenSeq(Pulse('OffRes422',0,0));
        prog.GenFinish;

        dic.com.UploadCode(prog);
        dic.com.UpdateFpga;
        dic.com.WaitForHostIdle; % wait until host finished it last task
        dic.com.Execute(200);
        dic.com.WaitForHostIdle;
        r = dic.com.ReadOut(200);
        r = r(2:end);
    end

end