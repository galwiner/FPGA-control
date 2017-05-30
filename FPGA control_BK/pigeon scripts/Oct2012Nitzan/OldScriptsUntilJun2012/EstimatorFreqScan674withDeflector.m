function valid=EstimatorFreqScan674
dic=Dictator.me;

pulseTime=dic.T674*40;
pulseAmp=2;
forDeflectorGuaging = dic.deflectorCompenFlag;
valid = 0;
if forDeflectorGuaging
    f674List=dic.switchSetFreq+(-0.02:0.0010:0.020);
else
    f674List=dic.F674+(-0.02:0.0010:0.020);
end
%-------------- Set GUI figures ---------------------
InitializeAxes (dic.GUI.sca(1),'Photons #','Cases Counted #','Fluorescence Histogram',...
    [0 dic.maxPhotonsNumPerReadout],[],0);
lines =InitializeAxes (dic.GUI.sca(3),'F_{674} [MHz]','Dark Counts %','Shelving Line',...
    [f674List(1) f674List(end)],[0 100],2);
set(lines(1),'XData',[],'YData',[],'Marker','.','MarkerSize',10);
set(lines(2),'Color',[0 0 0],'XData',[],'YData',[]);

%-------------- Main function scan loops ---------------------
dark = zeros(size(f674List));

for index1 = 1:length(f674List)
    if dic.stop
        return
    end
    r=experimentSequence(f674List(index1),pulseTime,pulseAmp);
    dic.GUI.sca(1);
    hist(r,1:2:dic.maxPhotonsNumPerReadout);
    if dic.TwoIonFlag
        dark(index1) =100-sum( (r>dic.TwoIonsCountThreshold)*2+...
            ((r>dic.darkCountThreshold)&(r<dic.TwoIonsCountThreshold))*1 ...
            )/2/length(r)*100;
    else
        dark(index1) = sum( r<dic.darkCountThreshold)/length(r)*100;
    end
    AddLinePoint(lines(1),f674List(index1),dark(index1))
end
%---------- fitting and updating ---------------------
[peakValue,x0,w,xInterpulated,fittedCurve,isValidFit] = ...
    FitToSincSquared(f674List',dark');
if (~isValidFit)||(peakValue<=60)||((max(dark)-min(dark))<=60)
    disp('Invalid fit');
else
    dic.F674 = x0;
    dic.F674FWHM = 2*0.44295/w;
    dic.DarkMax = peakValue;
    set(lines(2),'XData',xInterpulated,'YData',fittedCurve);
    gca = dic.GUI.sca(3);
    text(f674List(2),0.9*peakValue,{strcat(num2str(round(peakValue)),'%')...
        ,sprintf('%2.3f MHz',x0),sprintf('%d KHz FWHM',round(2*1e3*0.44295/w))})
    grid on
    % update the ULE
    n=now;
    if ~forDeflectorGuaging
        if ~dic.deflectorCompenFlag
            if (~isempty(dic.ULE.freq))&&(length(dic.ULE.freq.getData)>=1)
                dic.ULE.freqHistory=[dic.ULE.freqHistory x0];
                dic.ULE.estimatedFreqHistory=[dic.ULE.estimatedFreqHistory dic.estimateF674(n)];
                dic.ULE.timeHistory=[dic.ULE.timeHistory n];
            end
            dic.ULE.freq.push(x0);%insert current F674 to ULE freq FIFO
            dic.ULE.timeStamp.push(n);%insert current tim to ULE timeStamp FIFO
        end
    else
        dic.ULE.deflectorFreqHistory = ...
            [dic.ULE.deflectorFreqHistory dic.deflectorCurrentFreq-...
            (x0-dic.switchSetFreq)/2];
        dic.ULE.timeHistory = [dic.ULE.timeHistory n];
        dic.is674LockedFlag=1;
        dic.updateF674;
    end
    valid=1;
end


%%------------------------ experiment sequence -----------------
    function r=experimentSequence(pFreq,pTime,pAmp)
        prog=CodeGenerator;
        prog.GenDDSPullParametersFromBase;
        % update the noiseEater value
        prog.GenSeq([Pulse('674DDS1Switch',0,30,'freq',pFreq,'amp',100),...
                     Pulse('NoiseEater674',2,28)]);
        prog.GenSeq(Pulse('Repump1033',0,dic.T1033));        
        % set DDS freq and amp
        prog.GenSeq(Pulse('674DDS1Switch',0,-1,'freq',pFreq,'amp',pAmp));
        prog.GenSeq(Pulse('ExperimentTrigger',0,50));
        % Doppler coolng
        prog.GenSeq(Pulse('OffRes422',0,1));%turn off cooling
        prog.GenSeq(Pulse('OnResCooling',0,dic.Tcooling));
        % OffResonance/Shelving pulse
        prog.GenSeq(Pulse('OpticalPumping',0,dic.Toptpump));
        prog.GenSeq([Pulse('674DDS1Switch',2,pTime)]);
        % detection
        prog.GenSeq([Pulse('OnRes422',0,dic.TDetection) Pulse('PhotonCount',0,dic.TDetection)]);
        %resume cooling


        prog.GenSeq(Pulse('OffRes422',0,0));
        prog.GenFinish;

        dic.com.UploadCode(prog);
        dic.com.UpdateFpga;
        dic.com.WaitForHostIdle; % wait until host finished it last task
        rep=100;
        dic.com.Execute(rep);
        dic.com.WaitForHostIdle;
        r = dic.com.ReadOut(rep);
        r = r(2:end);
    end
end

