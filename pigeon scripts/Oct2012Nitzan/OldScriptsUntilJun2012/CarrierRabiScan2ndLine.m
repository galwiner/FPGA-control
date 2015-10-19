function CarrierRabiScan2ndLine

dic=Dictator.me;
lineNum = 1;
% PulseTime=0.1:10:300;
PulseTime=0.1:1:50;
if dic.curBeam==0 %674 beam horizontal at 45 deg to axial
    PulseTime=(0.1:5:60);
elseif dic.curBeam==1             %674 beam vertical at 45 deg to axial
    PulseTime=1:3:150;
else %horizontal , radial
    PulseTime=1:20:600;
end

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
    [secondLineFreq,secondLineTime,isOptPumpNeeded]=S2DTransFreqAndPiTime(lineNum);
    secondLineFreq=dic.updateF674-dic.FRF*(0+1/2.802*1.68*(-1/2-3/2)); %-1/2 to +1/2s
    r=experimentSequence(PulseTime(index1),secondLineFreq,isOptPumpNeeded);
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
% update T674 if the chi square is small
global quadTrans;
quadTrans(lineNum).piTime=2*pi/Omega/4*1e6;

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
%         prog.GenSeq([Pulse('674PulseShaper',1,dic.TimeRF-2),...
%              Pulse('RFDDS2Switch',2,dic.TimeRF)]);
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