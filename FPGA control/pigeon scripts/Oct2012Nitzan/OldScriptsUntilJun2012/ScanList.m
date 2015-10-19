% Main Scan list
dic.AutoSaveFlag=1;
dic.noiseEater674=-3267*0.6;
%getSpectrumAnalyzer;
Detection;
freqScan674;
CarrierRabiScan674;
Spectrum674Scan('freq',-3:0.02:3,'duration',[dic.T674 50 100 300 600]);
SpectrumIntensity674Scan
%sidebands
scanSideBand([1 2]);
ScanSideBandGSC([1 2]);
ScanRabiWithGSC('mode',0,'duration',1:1:100);
ScanRabiWithGSC('mode',1,'duration',1:20:1500);
%Ramsey
RamseyZeeman('phase',linspace(0,2*pi,10),'armtime',linspace(10,3000,15),'type',0);
Ramsey674('phase',linspace(0,2*pi,10),'armtime',linspace(10,3000,15),'type',0);
%echo
RamseyZeeman('phase',linspace(0,2*pi,10),'armtime',linspace(10,10000,11),'type',1);
Ramsey674('phase',linspace(0,2*pi,10),'armtime',linspace(10,10000,11),'type',1);
