function [valfreq width]=FreqScan674Stab
dic=Dictator.me;
silentMode=0;
% Reinitialize the DDS (should be cleaner)
DDSSingleToneInitialization(1,85);DDSSingleToneInitialization(2,3);
% Puts 674 in normal mode
%dic.setNovatech4Amp(1,0); ChannelSwitch('DIO7','on');

% puts 674 in normal mode
% dic.setNovatech4Amp(1,0);dic.setNovatech4Amp(2,0);
ChannelSwitch('DIO7','on');
ChannelSwitch('NovaTechPort2','on');

dic.setNovatech4Amp(2,1000);
dic.setNovatech4Amp(0,0);dic.setNovatech4Amp(1,0);dic.setNovatech4Amp(3,0);
% dic.com.UpdateTrapElectrode(0,0,0,dic.Vdcl,dic.Vcomp); pause(1);
saveVdcl=dic.AVdcl; %dic.AVdcl=1.28;
saveVcomp=dic.HPVcomp; %dic.HPVcomp=0;


    pulseTime=dic.T674*110;
    pulseAmp=0.5;
    valid = 0;
    f674List = dic.F674+(-0.006:0.0003:0.006);    

    %-------------- Set GUI figures ---------------------
if ~(silentMode)
    InitializeAxes (dic.GUI.sca(1),'Photons #','Cases Counted #','Fluorescence Histogram',...
        [0 dic.maxPhotonsNumPerReadout],[],0);
    lines =InitializeAxes (dic.GUI.sca(3),'F_{674} [MHz]','Dark Counts %','Shelving Line',...
        [f674List(1) f674List(end)],[0 100],2);
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
    dic.setNovatech4Freq(2,f674List(index1));
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
       AddLinePoint(lines(1),f674List(index1),dark(index1))
   end
end

InitializeAxes (dic.GUI.sca(1),'Photons #','Cases Counted #','Fluorescence Histogram',...
    [0 dic.maxPhotonsNumPerReadout],[],0);
lines =InitializeAxes (dic.GUI.sca(3),'F_{674} [MHz]','Dark Counts %','Shelving Line',...
    [f674List(1) f674List(end)],[0 100],2);
set(lines(2),'Color',[0 0 0],'XData',[],'YData',[]);

set(lines(1),'XData',f674List,'YData',dark,'Marker','.','MarkerSize',10);

%---------- fitting and updating ---------------------
[peakValue,x0,w,xInterpulated,fittedCurve,isValidFit] = ...
    FitToSincSquared(f674List',dark');
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
        return;
    end
else
    if abs(dic.F674-x0)<3
        dic.F674 = x0;
    else
        FreqScan674New;
        return;
    end
    dic.F674FWHM = 2*0.44295/w;
    dic.DarkMax = peakValue;
    set(lines(2),'XData',xInterpulated,'YData',fittedCurve);
    gca = dic.GUI.sca(3);
    text(f674List(2),0.9*peakValue,{strcat(num2str(round(peakValue)),'%')...
        ,sprintf('%2.3f MHz',x0),sprintf('%d KHz FWHM',round(2*1e3*0.44295/w))})
    grid on
end

valfreq=x0;
width=2*0.44295/w;


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

