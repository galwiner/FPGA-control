function L674CarrierRabiScan(varargin)
dic=Dictator.me;

pulseAmp=100;
updateFit=1;
MMFreq=21.75;

InitSpinDown=0;
DetuningSpinDown=(-2.802*1/2+1.68*3/2)*(dic.FRF/2.802);

ScanType=1;
switch ScanType
case 1 % 674DDS carrier
    OscName='674DDS1Switch';
    PulseTime=linspace(0.1,5,30)*1;
case 2%carrier transition with Parity
    OscName='674Parity'; 
    PulseTime=(0.5:0.3:10);
    dic.setNovatech('Parity','freq',dic.SinglePass674freq,'amp',1000);
case 3 
    OscName='674Gate'; % dressing 
    dic.setNovatech('Blue','freq',70,'amp',1000);
    dic.setNovatech('Blue','freq',0,'amp',1000);
    dic.setNovatech('Red','freq',dic.SinglePass674freq,'amp',1000); %multiply by zero
    PulseTime=(1:5:50);
end


%% -------------------options-------------
CrystalCheckPMT;
for i=1:2:size(varargin,2)
    switch lower(char(varargin(i)))
        case 'freq'
            f674List=varargin{i+1};
        case 'duration'
            pulseTime=varargin{i+1};
        case 'amp'
            pulseAmp=varargin{i+1};
        case 'save'
            savedata=varargin{i+1};
        case 'deflectorguaging'
            forDeflectorGuaging = varargin{i+1};
    end; %switch
end;%for loop
valid = 0;
%% -------------- Set GUI figures ---------------------
InitializeAxes (dic.GUI.sca(1),'Photons #','Cases Counted #','Fluorescence Histogram',...
    [0 dic.maxPhotonsNumPerReadout],[],0);
lines =InitializeAxes (dic.GUI.sca(4),...
    'Pulse Time[\mus]','Dark Counts %','Rabi Scan',...
    [PulseTime(1) PulseTime(end)],[0 100],2);
grid(dic.GUI.sca(4),'on');
set(lines(1),'Marker','.','MarkerSize',10,'Color','b');
set(lines(2),'Marker','.','MarkerSize',10,'Color','r');
%% -------------- Main function scan loops ---------------------
rep=200; %repetitions per point
dark = zeros(size(PulseTime));
histograms=zeros(rep,length(PulseTime));

for index1 = 1:length(PulseTime)
    if dic.stop
        return;
    end
    pause(0.1);
    % Update the DoublePass base freq
    dic.setNovatech('DoublePass','freq',dic.F674,'amp',1000);
    r=experimentSequence(dic.SinglePass674freq,PulseTime(index1),pulseAmp,OscName);%(FreqSinglePass,pulseTime,pulseAmp);
    dic.GUI.sca(1);
    hist(r,1:1:dic.maxPhotonsNumPerReadout);
    ivec=dic.IonThresholds;
    tmpdark=0;
    for tmp=1:dic.NumOfIons
        tmpdark=tmpdark+sum((r>ivec(tmp))&(r<ivec(tmp+1)))*tmp;
    end
    tmpdark=100-tmpdark/length(r)/(dic.NumOfIons)*100;
    dark(index1)=tmpdark;
    %         histograms(:,index1)=r;
    AddLinePoint(lines(1),PulseTime(index1),dark(index1));
end
%---------- fitting and updating ---------------------

% in case of two ions, Fourier decompose to find Rabis
if (dic.NumOfIons>2)
    t=(PulseTime)*1e-6; %time vector in seconds
    L=length(t);
    T = t(2)-t(1);% Sample time
    Fs = 1/T; % Sampling frequency
    t = (0:L-1)*T;
    NFFT = 2^nextpow2(L); % Next power of 2 from length of y
    Y = fft(dark-mean(dark),NFFT)/L;
    f = Fs/2*linspace(0,1,NFFT/2+1);
    dic.GUI.sca(6);
    plot(f,2*abs(Y(1:NFFT/2+1)))
    axis([min(f) max(f) 0 max(2*abs(Y(1:NFFT/2+1)))])
    title('Single-Sided Amplitude Spectrum of Rabi')
    xlabel('Freq (Hz)')
    ylabel('|Y(f)|')
end


[Nbar,Omega,y]=fitNbar2CarrierRabi((PulseTime)*1e-6,dark/100,dic.vibMode(1).freq,pi/4);
set(lines(2),'XData',PulseTime,'YData',y*100);

if ScanType==1
    % update T674 if the chi square is small
    if (mean((y*100-dark).^2)<50)&&(updateFit)
        [maxv,maxInd]=max(y);
         rabi=2*pi/Omega/4*1e6;
         if abs(rabi-PulseTime(maxInd))<1
            dic.T674=PulseTime(maxInd);
         else
            dic.T674=rabi;
         end
        disp(sprintf('average n = %.2f  PiTime = %4.2f [mus]',Nbar,dic.T674));
    end
else
    if (mean((y*100-dark).^2)<50)&&(updateFit)
%         eval(sprintf('dic.AddrInfo.T%s=%.2f;',OscName,2*pi/Omega/4*1e6));
        fprintf('dic.AddrInfo.T%s=%.2f',OscName,2*pi/Omega/4*1e6);    
    end
end

%------------ Save data ------------------
showData='figure;plot(PulseTime,dark);xlabel(''F_674 [Mhz]'');ylabel(''dark[%]'');';
dic.save;

%% ------------------------ experiment sequence -----------------

    function r=experimentSequence(pFreq,pTime,pAmp,oscname)
        prog=CodeGenerator;
        prog.GenDDSPullParametersFromBase;

        % set DDS freq and amp
        prog.GenSeq(Pulse('674DDS1Switch',2,-1,'freq',pFreq,'amp',pAmp));
        prog.GenSeq(Pulse('ExperimentTrigger',0,50));
        % Doppler coolng
        prog.GenSeq(Pulse('OffRes422',0,100));%turn off cooling
        prog.GenSeq(Pulse('OnResCooling',10,dic.Tcooling));
        
        %activate noise eater, move it to int hold and repump
        prog.GenSeq([Pulse('674DDS1Switch',1,15),... 
                     Pulse('NoiseEater674',3,13),Pulse('674DoublePass',0,16),...
                     Pulse('Repump1033',16,dic.T1033)]);
        prog.GenSeq(Pulse('OpticalPumping',1,dic.Toptpump));
        if InitSpinDown
                prog.GenSeq(Pulse('RFDDS2Switch',1,dic.TimeRF));
        end        
        % Shelving pulse
        prog.GenSeq([Pulse(oscname,2,pTime),Pulse('674DoublePass',0,pTime+3)]);

        % detection
        prog.GenSeq([Pulse('OnRes422',0,dic.TDetection) Pulse('PhotonCount',0,dic.TDetection)]);
        %resume cooling
        prog.GenSeq(Pulse('Repump1033',0,dic.T1033));
        prog.GenSeq(Pulse('674DDS1Switch',2,-1,'amp',100));
        prog.GenSeq([Pulse('OffRes422',0,0) Pulse('Repump1092',0,0)]);
        prog.GenFinish;    
        dic.com.UploadCode(prog);
        dic.com.UpdateFpga;
        dic.com.WaitForHostIdle; % wait until host finished it last task
        rep=200;
        dic.com.Execute(rep);
        dic.com.WaitForHostIdle;
        r = dic.com.ReadOut(rep);
        r = r(2:end);
    end
end
