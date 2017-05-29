function valid=EstimatorFreqScan674
dic=Dictator.me;
silentMode=0;
if dic.timerOnOffFlag
    silentMode=1;
end
% Reinitialize the DDS (should be cleaner)
DDSSingleToneInitialization(1,85);DDSSingleToneInitialization(2,3);
% Puts 674 in normal mode
%dic.setNovatech4Amp(1,0); ChannelSwitch('DIO7','on');

% puts 674 in normal mode
% dic.setNovatech4Amp(1,0);dic.setNovatech4Amp(2,0);
ChannelSwitch('DIO7','on');
ChannelSwitch('NovaTechPort2','on');

dic.setNovatech4Amp(2,1000);

% dic.com.UpdateTrapElectrode(0,0,0,dic.Vdcl,dic.Vcomp); pause(1);
saveVdcl=dic.AVdcl; %dic.AVdcl=1.28;
saveVcomp=dic.HPVcomp; %dic.HPVcomp=0;
if dic.curBeam==0 %674 beam horizontal at 45 deg to axial
    pulseTime=dic.T674*150;
    pulseAmp=0.5;
    valid = 0;
%   f674List = dic.F674+(-0.004:0.0002:0.004);    
    f674List = (-0.006:0.0003:0.006);    
    
% %  %%% regular scan parameters
%    f674List = dic.F674+(-0.1:0.005:0.1);
%    pulseAmp=50;
%    pulseTime=dic.T674;
%    %%%%%%%%%%%%%%
    
elseif dic.curBeam==1              %674 beam vertical
    pulseTime=dic.T674*7;%30
    pulseAmp=10;%2;
    valid = 0;
    f674List=(-0.02:0.0010:0.020);  
elseif dic.curBeam==2
    pulseTime=dic.T674*9;%30
    pulseAmp=10;%2;
    valid = 0;
    f674List=(-0.02:0.0005:0.020);  
end
% f674List=dic.F674+(-0.01:0.0005:0.010);
%-------------- Set GUI figures ---------------------
if ~(silentMode)
    InitializeAxes (dic.GUI.sca(1),'Photons #','Cases Counted #','Fluorescence Histogram',...
        [0 dic.maxPhotonsNumPerReadout],[],0);
    lines =InitializeAxes (dic.GUI.sca(3),'F_{674} [MHz]','Dark Counts %','Shelving Line',...
        2*[f674List(1) f674List(end)],[0 100],2);
    set(lines(2),'Color',[0 0 0],'XData',[],'YData',[]);
else
    disp('silent');
end
%-------------- Main function scan loops ---------------------
dark = zeros(size(f674List));
dic.LasersLockedFlag=dic.com.GetLasersStatus;

if dic.TwoIonFlag && ~CrystalCheckPMT
    dic.timerOnOffFlag=0;
    dic.AVdcl=saveVdcl;
    dic.HPVcomp=saveVcomp;
    return
end

for index1 = 1:length(f674List)
    if dic.stp %check stop button without resetting it
        dic.AVdcl=saveVdcl;
        dic.HPVcomp=saveVcomp;
        return;
    end
    FreqSinglePass=77;
    % control the double pass frequency
    dic.setNovatech4Freq(2,f674List(index1)+dic.F674);
    r=experimentSequence(FreqSinglePass,pulseTime,pulseAmp);
   
    if dic.TwoIonFlag
        dark(index1) =100-sum( (r>dic.TwoIonsCountThreshold)*2+...
            ((r>dic.darkCountThreshold)&(r<dic.TwoIonsCountThreshold))*1 ...
            )/2/length(r)*100;
    else
        dark(index1) = sum( r<dic.darkCountThreshold)/length(r)*100;
    end
   if ~(silentMode)
       dic.GUI.sca(1);
       hist(r,1:2:dic.maxPhotonsNumPerReadout);
       AddLinePoint(lines(1),2*f674List(index1),dark(index1))
   end
end

if (silentMode)
    InitializeAxes (dic.GUI.sca(1),'Photons #','Cases Counted #','Fluorescence Histogram',...
        [0 dic.maxPhotonsNumPerReadout],[],0);
    lines =InitializeAxes (dic.GUI.sca(3),'F_{674} [MHz]','Dark Counts %','Shelving Line',...
        [f674List(1)*2 f674List(end)*2],[0 100],2);
    set(lines(2),'Color',[0 0 0],'XData',[],'YData',[]);
end
set(lines(1),'XData',2*f674List,'YData',dark,'Marker','.','MarkerSize',10);

%---------- fitting and updating ---------------------
[peakValue,x0,w,xInterpulated,fittedCurve,isValidFit] = ...
    FitToSincSquared(dic.F674+f674List(3:end)',dark(3:end)');
if dic.TwoIonFlag==1 
    [iscrystal initialstatus]=CrystalCheckPMT;
    if ~initialstatus 
        disp('Warning: crystal melted during 674 calibration');
         EstimatorFreqScan674;
    end
    if ~iscrystal
        disp('during 674 scan: Catastrophic loss, I have to stop.');
        dic.timerOnOffFlag=0;   
        dic.AVdcl=saveVdcl;
        dic.HPVcomp=saveVcomp;
        return;
    end;
else
    disp('Certified crystal for 674 calibration');
    initialstatus=1;
end

DecrystalMid=length(find(dark>75));
if (~isValidFit)||(peakValue<=60)||((max(dark)-min(dark))<=60)||(~initialstatus)||(DecrystalMid>10);
    disp('Invalid fit');
    Successful=FreqScan674New;
    if Successful==0
        disp('Damn it ! 674 is out of the game.');
        dic.timerOnOffFlag=0;
        return; return;
    end
else
    set(lines(2),'XData',(xInterpulated-dic.F674)*2,'YData',fittedCurve);
    if abs(dic.F674-x0)<3
        dic.F674 = x0;
    else
        FreqScan674New;            
        return;
    end
    dic.F674FWHM = 2*0.44295/w *2;% the second 2 factor is for the double-pass
    dic.DarkMax = peakValue;
    if (silentMode)
        set(lines(2),'XData',xInterpulated,'YData',fittedCurve);
        gca = dic.GUI.sca(3);
        text(f674List(2),0.9*peakValue,{strcat(num2str(round(peakValue)),'%')...
        ,sprintf('%2.3f MHz',x0),sprintf('%d KHz FWHM',round(2*1e3*0.44295/w))})
        grid on
    end;
    % update the ULE
    n=now;
    if (~isempty(dic.ULE.freq))&&(length(dic.ULE.freq.getData)>=1)
        dic.ULE.freqHistory=[dic.ULE.freqHistory x0];
        dic.ULE.estimatedFreqHistory=[dic.ULE.estimatedFreqHistory dic.estimateF674(n)];
        dic.ULE.timeHistory=[dic.ULE.timeHistory n];
    end
    dic.ULE.freq.push(x0);%insert current F674 to ULE freq FIFO
    dic.ULE.timeStamp.push(n);%insert current tim to ULE timeStamp FIFO
    valid=1;
    %update the RF
    if dic.calibRfFlag
        ScanRfRes;
    end
end
dic.AVdcl=saveVdcl;
dic.HPVcomp=saveVcomp;
%%------------------------ experiment sequence -----------------
    function r=experimentSequence(pFreq,pTime,pAmp)
        prog=CodeGenerator;

        prog.GenDDSPullParametersFromBase;
        
        % update the noiseEater value
        prog.GenSeq([Pulse('674DDS1Switch',0,30,'freq',pFreq,'amp',100),...
                     Pulse('NoiseEater674',2,28)]);
        prog.GenSeq(Pulse('Repump1033',0,dic.T1033));        
        % set DDS freq and amp
        prog.GenSeq(Pulse('674DDS1Switch',2,-1,'amp',pAmp));
        prog.GenSeq(Pulse('ExperimentTrigger',0,50));
        % Doppler coolng
        prog.GenSeq(Pulse('OffRes422',0,1));%turn off cooling
        prog.GenSeq(Pulse('OnResCooling',0,dic.Tcooling));


        % OffResonance/Shelving pulse
        prog.GenSeq(Pulse('OpticalPumping',0,dic.Toptpump));
        prog.GenSeq(Pulse('Repump1092',0,1));
        prog.GenSeq([Pulse('674DDS1Switch',2,pTime)]);
        prog.GenSeq(Pulse('Repump1092',0,0));
        
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

