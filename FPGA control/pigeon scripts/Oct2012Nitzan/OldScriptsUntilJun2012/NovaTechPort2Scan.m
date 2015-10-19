function NovaTechPort2Scan
% preforms time scan of the S-D line be the novatech port 2 generator.
dic=Dictator.me;

PulseTime=0.1:0.3:10;

% ------------Set GUI axes ---------------
InitializeAxes(dic.GUI.sca(1),'Photons #','Cases Counted #','Fluorescence Histogram',...
    [0 dic.maxPhotonsNumPerReadout],[],0);

lines =InitializeAxes (dic.GUI.sca(4),...
    'Pulse Time[\mus]','Dark Counts %','NovaTech Port 2 Rabi Scan',...
    [PulseTime(1) PulseTime(end)],[0 100],2);
grid(dic.GUI.sca(4),'on');
set(lines(1),'Marker','.','MarkerSize',10,'Color','b');
set(lines(2),'Marker','.','MarkerSize',10,'Color','r');

dic.setNovatech4Amp(0,0);
dic.setNovatech4Amp(1,0);
dic.setNovatech4Amp(2,1023);
dic.setNovatech4Freq(2,dic.F674);
% -------- Main function scan loops ------
dark = zeros(size(PulseTime));
for index1 = 1:length(PulseTime)
    if dic.stop
        return
    end
    r=experimentSequence(PulseTime(index1));
    dic.GUI.sca(1); %get an axis from Dictator GUI to show data
    hist(r,0:1:(1.8*dic.maxPhotonsNumPerReadout));
    if dic.TwoIonFlag
        dark(index1) =100-sum( (r>dic.TwoIonsCountThreshold)*2+...
            ((r>dic.darkCountThreshold)&(r<dic.TwoIonsCountThreshold))*1 ...
            )/2/length(r)*100;
    else
        dark(index1) = sum( r<dic.darkCountThreshold)/length(r)*100;
    end
    AddLinePoint(lines(1),PulseTime(index1),dark(index1));
    pause(0.1);
end

[Nbar,Omega,y]=fitNbar2CarrierRabi((PulseTime)*1e-6,dark/100,dic.vibMode(1).freq,pi/4);
disp(sprintf('average n = %.2f  PiTime = %4.2f [mus]',Nbar,2*pi/Omega/4*1e6));
set(lines(2),'XData',PulseTime,'YData',y*100);
if mean((y*100-dark).^2)<50
    dic.port2T674=2*pi/Omega/4*1e6;
end


%--------------------------------------------------------------------
    function r=experimentSequence(pulseTime)
        prog=CodeGenerator;
        prog.GenDDSPullParametersFromBase;
        prog.GenSeq(Pulse('ExperimentTrigger',0,50));
        % switching to NovaTech
        prog.GenSeq([Pulse('674Switch2NovaTech',0,0),...
            Pulse('674PulseShaper',0,-1)]);

        prog.GenPause(30);
        % Doppler coolng
        prog.GenSeq(Pulse('OffRes422',0,1));%turn off cooling
        prog.GenSeq(Pulse('OnResCooling',0,dic.Tcooling) );
        prog.GenSeq(Pulse('OpticalPumping',0,dic.Toptpump));
        %sideband Shelving
        prog.GenSeq(Pulse('NovaTechPort2',0,pulseTime));

        % detection
        prog.GenSeq([Pulse('OnRes422',0,dic.TDetection) Pulse('PhotonCount',0,dic.TDetection)]);
        %resume cooling
        prog.GenSeq(Pulse('Repump1033',0,dic.T1033));
        prog.GenSeq(Pulse('OffRes422',0,0));
        prog.GenSeq(Pulse('674Switch2NovaTech',0,-1));
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