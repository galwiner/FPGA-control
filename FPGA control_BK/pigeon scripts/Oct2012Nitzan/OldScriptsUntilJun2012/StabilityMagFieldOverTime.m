function StabilityMagFieldOverTime

dic=Dictator.me;

ExptIndex=[1:1:30];

% PulseTime=0.1:10:300;
if dic.curBeam==0 %674 beam horizontal at 45 deg to axial
    PulseTime=(0.1:0.5:20);
elseif dic.curBeam==1             %674 beam vertical at 45 deg to axial
    PulseTime=1:5:250;
else %horizontal , radial
    PulseTime=1:20:600;
end
repetitions=100;
Amplitude=100;

% ------------Set GUI axes ---------------
InitializeAxes(dic.GUI.sca(1),'Photons #','Cases Counted #','Fluorescence Histogram',...
                [0 dic.maxPhotonsNumPerReadout],[],0);

freqstart=FreqScanRFStab;

lines =InitializeAxes (dic.GUI.sca(11),...
    'Expt Index','Center Freq','Zeeman Stability',...
    [ExptIndex(1) ExptIndex(end)],[-2 2],1);
grid(dic.GUI.sca(11),'on');
set(lines(1),'Marker','.','MarkerSize',10,'Color','b');

lines2 =InitializeAxes (dic.GUI.sca(10),...
    'Expt Index','Center Freq','Zeeman Stability (difference)',...
    [ExptIndex(1) ExptIndex(end)],[-2 2],1);
grid(dic.GUI.sca(10),'on');
set(lines(1),'Marker','.','MarkerSize',10,'Color','b');

dic.setNovatech4Freq(0,dic.updateF674);        

% -------- Main function scan loops ------
freqcenter = zeros(size(ExptIndex));
width=zeros(size(ExptIndex));
for index1 = 1:length(ExptIndex)
    if dic.stop || ~CrystalCheckPMT
        return
    end
    [freqcenter(index1)]=FreqScanRFStab;
%     disp(freqcenter(index1));
    AddLinePoint(lines(1),ExptIndex(index1),1000*(freqcenter(index1)-freqstart));
    if index1>1
        AddLinePoint(lines2(1),ExptIndex(index1),1000*(freqcenter(index1)-freqcenter(index1-1)));
    else
        AddLinePoint(lines2(1),ExptIndex(index1),1000*(freqcenter(index1)-freqstart));        
    end
end

%--------------- Save data ------------------
if dic.AutoSaveFlag
    destDir=dic.saveDir;
    thisFile=[mfilename('fullpath') '.m' ];
    [filePath fileName]=fileparts(thisFile);
    scriptText=fileread(thisFile);
    scriptText(find(int8(scriptText)==10))='';
    showData='figure;plot(ExptIndex,freqcenter);xlabel(''Expt'');ylabel(''Position'');';
    saveFileName=fullfile(destDir ,[fileName datestr(now,'-ddmmmyy-HHMMSS')]);
    dicParameters=dic.getParameters;
    save(saveFileName,'freqcenter','showData','dicParameters','scriptText');
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


end