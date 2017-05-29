function StabilityMagFieldOnRes

dic=Dictator.me;

ExptIndex=[1:1:500];

% PulseTime=0.1:10:300;
if dic.curBeam==0 %674 beam horizontal at 45 deg to axial
    PulseTime=(0.1:0.5:20);
elseif dic.curBeam==1             %674 beam vertical at 45 deg to axial
    PulseTime=1:5:250;
else %horizontal , radial
    PulseTime=1:20:600;
end
repetitions=50;
Amplitude=100;
Freq674SinglePass=77;

% ------------Set GUI axes ---------------
InitializeAxes(dic.GUI.sca(1),'Photons #','Cases Counted #','Fluorescence Histogram',...
                [0 dic.maxPhotonsNumPerReadout],[],0);

% freqstart=FreqScanRFStab;

lines2 =InitializeAxes (dic.GUI.sca(10),...
    'Expt Index','Center Freq','Zeeman Stability (difference)',...
    [ExptIndex(1) ExptIndex(end)],[0 100],1);
grid(dic.GUI.sca(10),'on');
set(lines2(1),'Marker','.','MarkerSize',10,'Color','b');

dic.setNovatech4Freq(0,dic.updateF674);        

% -------- Main function scan loops ------
% freqcenter = zeros(size(ExptIndex));
% width=zeros(size(ExptIndex));
dark=zeros(size(ExptIndex));
for index1 = 1:length(ExptIndex)
    if dic.stop || ~CrystalCheckPMT
        return
    end
%     [freqcenter(index1)]=FreqScanRFStab;
    
    r=experimentSequence(12.3836);
    dic.GUI.sca(1);
    hist(r,1:2:dic.maxPhotonsNumPerReadout);
    if dic.TwoIonFlag
        dark(index1) =100-sum( (r>dic.TwoIonsCountThreshold)*2+...
            ((r>dic.darkCountThreshold)&(r<dic.TwoIonsCountThreshold))*1 ...
            )/2/length(r)*100;
    else
        dark(index1) = sum( r<dic.darkCountThreshold)/length(r)*100;
    end
     AddLinePoint(lines2(1),ExptIndex(index1),dark(index1));
    
%     %     disp(freqcenter(index1));
%     AddLinePoint(lines(1),ExptIndex(index1),1000*(freqcenter(index1)-freqstart));
%     if index1>1
%         AddLinePoint(lines2(1),ExptIndex(index1),1000*(freqcenter(index1)-freqcenter(index1-1)));
%     else
%         AddLinePoint(lines2(1),ExptIndex(index1),1000*(freqcenter(index1)-freqstart));        
%     end
end

%--------------- Save data ------------------
if dic.AutoSaveFlag
    destDir=dic.saveDir;
    thisFile=[mfilename('fullpath') '.m' ];
    [filePath fileName]=fileparts(thisFile);
    scriptText=fileread(thisFile);
    scriptText(find(int8(scriptText)==10))='';
    showData='figure;plot(ExptIndex,dark);xlabel(''Expt'');ylabel(''Position'');';
    saveFileName=fullfile(destDir ,[fileName datestr(now,'-ddmmmyy-HHMMSS')]);
    dicParameters=dic.getParameters;
    save(saveFileName,'dark','ExptIndex','showData','dicParameters','scriptText');
    disp(['Save data in : ' saveFileName]);
end 

%dic.vibMode(1).freq=0.99;
% [Nbar,Omega,y]=fitNbar2CarrierRabi((PulseTime)*1e-6,dark/100,dic.vibMode(1).freq,pi/4);
% disp(sprintf('average n = %.2f  PiTime = %4.2f [mus]',Nbar,2*pi/Omega/4*1e6+0.5));
% set(lines(2),'XData',PulseTime,'YData',y*100);
% update T674 if the chi square is small
% if mean((y*100-dark).^2)<50
%     dic.T674=2*pi/Omega/4*1e6+0.1;% the 0.5 is a correction 
% rabi=dic.T674;
function r=experimentSequence(freq)
    prog=CodeGenerator; 
    prog.GenDDSPullParametersFromBase;
    prog.GenSeq(Pulse('ExperimentTrigger',0,50));
    prog.GenSeq(Pulse('674DDS1Switch',2,-1,'freq',Freq674SinglePass,'amp',100) );
    prog.GenSeq(Pulse('RFDDS2Switch',2,-1,'freq',freq,'amp',2));
    prog.GenSeq(Pulse('OffRes422',0,100));
    prog.GenSeq(Pulse('OnResCooling',0,200));
    
%     prog.GenRepeatSeq([Pulse('OpticalPumping',0,7),...
%                        Pulse('674PulseShaper',10,dic.TimeRF-2),...
%                        Pulse('RFDDS2Switch',11,dic.TimeRF)],50);
    
    prog.GenSeq(Pulse('OpticalPumping',0,dic.Toptpump));
    %Do pi pulse RF
    
%     prog.GenSeq([Pulse('674PulseShaper',1,dic.TimeRF-1),...
%                      Pulse('RFDDS2Switch',2,dic.TimeRF)]);
     prog.GenSeq([Pulse('RFDDS2Switch',0,dic.TimeRF*30)]);

    prog.GenSeq([Pulse('674DDS1Switch',0,dic.T674)]);

             %second shelving Pulse 
%     prog.GenSeq(Pulse('674DDS1Switch',5,10,'freq',dic.FRF*1.2046));
    
    prog.GenSeq([Pulse('OnRes422',0,dic.TDetection)...
                 Pulse('PhotonCount',0,dic.TDetection)]);
    %resume cooling
    prog.GenSeq(Pulse('Repump1033',0,dic.T1033));
    prog.GenSeq(Pulse('OffRes422',0,0));

    prog.GenFinish;
    %prog.DisplayCode;


    % FPGA/Host control
    n=dic.com.UploadCode(prog);
    dic.com.UpdateFpga;
    dic.com.WaitForHostIdle;

    dic.com.Execute(repetitions);
    dic.com.WaitForHostIdle;
    r=dic.com.ReadOut(repetitions);
    r=r(2:end);
end

end