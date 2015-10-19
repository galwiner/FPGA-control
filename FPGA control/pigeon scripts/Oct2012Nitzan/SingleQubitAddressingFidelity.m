function SingleQubitAddressingFidelity(varargin)
dic=Dictator.me;
savedata=1;
pulseTime=dic.T674;
pulseAmp=100;
updateFit=1;
rep=50;
%  PulseTime=2:12:850;        
%  DiffCap=0:0.6:20;

  PulseTime=(2:20:1200)/2;        
%       DiffCap=0:1:0;
     DiffCap=0:1:10;

% AVdcltab=1.04:0.01:1.2;
 xlab='Differential Cap (V)';

% xlab='AVdcl (V)';


OscName='674DDS1Switch';
novatechAmp=round(300/sqrt(2));

dic.setNovatech('Red','amp',0);
dic.setNovatech('Blue','amp',0); %multiply by zero
dic.setNovatech('Parity','amp',0);
dic.setNovatech('Echo','amp',0);

pause(1);

switch OscName
    case '674Gate'
        dic.setNovatech('Blue','freq',dic.SinglePass674freq,'amp',novatechAmp);
        dic.setNovatech('Red','freq',dic.SinglePass674freq+1.2*dic.vibMode(1).freq,'amp',novatechAmp*1); %multiply by zero
    case '674Parity'
        dic.setNovatech('Parity','freq',dic.SinglePass674freq,'amp',novatechAmp);
    case '674Echo'
        dic.setNovatech('Echo','freq',dic.SinglePass674freq,'amp',novatechAmp);
end


%--------options-------------
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
%-------------- Set GUI figures ---------------------
InitializeAxes (dic.GUI.sca(1),'Photons #','Cases Counted #','Fluorescence Histogram',...
    [0 dic.maxPhotonsNumPerReadout],[],0);
lines =InitializeAxes (dic.GUI.sca(7),...
    'Pulse Time[\mus]','Dark Counts %','Micromotion Rabi Scan',...
    [PulseTime(1) PulseTime(end)],[0 100],2);
grid(dic.GUI.sca(10),'on');
set(lines(1),'Marker','.','MarkerSize',10,'Color','b');
set(lines(2),'Marker','.','MarkerSize',10,'Color','g');

%-------------- Main function scan loops ---------------------
dark = zeros(length(PulseTime),length(DiffCap));
fidelity = zeros(length(PulseTime),length(DiffCap));
frequencies = zeros(length(PulseTime),length(DiffCap));

countcheck=0;
if dic.SitOnItFlag
    cont=1;
    while (cont)
        if (dic.stop)
            cont=0;
        end
        r=experimentSequence(dic.SinglePass674freq,pulseTime,pulseAmp);
        dic.GUI.sca(1); %get an axis from Dictator GUI to show data
        hist(r,1:1:dic.maxPhotonsNumPerReadout);
        xlabel(num2str(sum( r<dic.darkCountThreshold)/length(r)*100,2),...
            'FontSize',100);
    end
else 
    for index2=1:length(DiffCap)
                dic.setNovatech('DoublePass','freq',dic.updateF674-dic.MMFreq/2,'amp',1000);
%                dic.setNovatech('DoublePass','freq',dic.updateF674,'amp',1000);
        
        dic.HPVcomp=DiffCap(index2);
%         dic.AVdcl=AVdcltab(index2);
        set(lines(1),'XData',[],'YData',[]);
        set(lines(2),'XData',[],'YData',[]);
        for index1 = 1:length(PulseTime)
            if dic.stop
                return;
            end
            if countcheck==60
                CrystalCheckPMT;
                countcheck=0;
            else
                countcheck=countcheck+1;
            end
            
            
            pause(0.1);
             r=experimentSequence(dic.SinglePass674freq,PulseTime(index1),pulseAmp);%(FreqSinglePass,pulseTime,pulseAmp);
            dic.GUI.sca(1);
            hist(r,1:1:dic.maxPhotonsNumPerReadout);
            if dic.TwoIonFlag
                ivec=dic.IonThresholds;
                tmpdark=0;
                for tmp=1:dic.NumOfIons
                    tmpdark=tmpdark+sum((r>ivec(tmp))&(r<ivec(tmp+1)))*tmp;
                end
                tmpdark=100-tmpdark/length(r)/(dic.NumOfIons)*100;
                dark(index1,index2)=tmpdark;
                fidelity(index1,index2)=100-sum( (r>dic.TwoIonsCountThreshold)*2+(r<dic.darkCountThreshold)*2)/2/length(r)*100;
            else
                dark(index1,index2) = sum( r<dic.darkCountThreshold)/length(r)*100;
                fidelity(index1,index2)=dark(index1,index2);

            end
            AddLinePoint(lines(1),PulseTime(index1),dark(index1,index2));
             AddLinePoint(lines(2),PulseTime(index1),fidelity(index1,index2));
            
        end
    
        temp=dark(:,index2);
        
        %%%%%%%%% FFT %%%%%%%%%%
        t=(PulseTime)*1e-6; %time vector in seconds
        L=length(t);
        T = t(2)-t(1);% Sample time
        Fs = 1/T; % Sampling frequency
        t = (0:L-1)*T;
        NFFT = 2^nextpow2(L); % Next power of 2 from length of y
        Y = fft(temp-mean(temp),NFFT)/L;
        f = Fs/2*linspace(0,1,NFFT/2+1);
        dic.GUI.sca(6);
        plot(f,2*abs(Y(1:NFFT/2+1)))
        axis([min(f) max(f) 0 max(2*abs(Y(1:NFFT/2+1)))])
        title('Single-Sided Amplitude Spectrum of Rabi');
        xlabel('Freq (Hz)');
        ylabel('|Y(f)|');
        
        FFTtab(:,index2)=2*abs(Y(1:NFFT/2+1));
        dic.GUI.sca(11);
        imagesc(DiffCap,f,FFTtab);
        axis([min(DiffCap) max(DiffCap) min(f) max(f)]);
        colorbar;
        xlabel(xlab); ylabel('Freq (Hz)'); title('Fourier analysis Micromotion');

            dic.GUI.sca(10);
            imagesc(DiffCap,PulseTime,fidelity);
            axis([min(DiffCap) max(DiffCap) min(PulseTime) max(PulseTime)]);
            colorbar;
            xlabel(xlab); ylabel('PulseTime (mus)'); title('Micromotion Cap Scan');
        
%         disp(sprintf('At DiffCap = %2.2f  Max Fidelity = %2.2f [mus]',dic.AVdcl,max(fidelity(:,index2))));      
    end
    %---------- fitting and updating ---------------------
    
%     [Nbar,Omega,y]=fitNbar2CarrierRabi((PulseTime)*1e-6,dark/100,dic.vibMode(1).freq,pi/4);
%     set(lines(2),'XData',PulseTime,'YData',y*100);
    % update T674 if the chi square is small
%     if (mean((y*100-dark).^2)<50)&&(updateFit)&&(strcmp(OscName,'674DDS1Switch'))
%         dic.T674=2*pi/Omega/4*1e6+0.1;% the 0.5 is a correction
%         rabi=dic.T674;   
%     end
%     disp(sprintf('average n = %.2f  PiTime = %4.2f [mus]',Nbar,2*pi/Omega/4*1e6+0.1));

    %------------ Save data ------------------
        showData='figure;imagesc(DiffCap,PulseTime,dark);axis([min(DiffCap) max(DiffCap) min(PulseTime) max(PulseTime)]);colorbar;xlabel(''AVdcl (V)''); ylabel(''PulseTime (mus)''); title(''Micromotion Cap Scan'');';
        dic.save;
end
%%------------------------ experiment sequence -----------------
    function r=experimentSequence(pFreq,pTime,pAmp)
        prog=CodeGenerator;
        prog.GenDDSPullParametersFromBase;

        % set DDS freq and amp
        prog.GenSeq(Pulse('674DDS1Switch',2,-1,'freq',pFreq,'amp',100));        
        prog.GenSeq(Pulse('ExperimentTrigger',0,50));
        % Doppler coolng        
        prog.GenSeq(Pulse('OffRes422',0,100));%turn off cooling
        prog.GenSeq(Pulse('OnResCooling',10,dic.Tcooling));
        % update the noiseEater value

%         prog.GenSeq(Pulse('674PulseShaper',0,0));
        
        if pAmp<50
            if strcmp(OscName,'674DDS1Switch')
                prog.GenSeq(Pulse('674DDS1Switch',2,-1,'freq',pFreq,'amp',100));            
            end
            prog.GenSeq([Pulse(OscName,0,15),...
                         Pulse('NoiseEater674',2,10),Pulse('674DoublePass',0,15),...        
                         Pulse('Repump1033',15,dic.T1033),...
                         Pulse('OpticalPumping',16+dic.T1033,dic.Toptpump)]);
            prog.GenSeq(Pulse('674DDS1Switch',2,-1,'amp',pAmp));
            prog.GenSeq([Pulse(OscName,2,pTime),...
                         Pulse('NoiseEater674',3,pTime-1),...
                         Pulse('674DoublePass',2,pTime)]);
        else         
%             if strcmp(OscName,'674DDS1Switch')
%                 prog.GenSeq(Pulse('674DDS1Switch',2,-1,'freq',pFreq,'amp',pAmp)); 
%             end
            %activate noise eater, move it to int hold and repump
            prog.GenSeq([Pulse('674DDS1Switch',2,15),...
                         Pulse('NoiseEater674',2,10),Pulse('674DoublePass',0,15),...        
                         Pulse('Repump1033',15,dic.T1033),...
                         Pulse('OpticalPumping',16+dic.T1033,dic.Toptpump)]);
  
            %drive the pi pulse
            prog.GenSeq([Pulse(OscName,2,pTime),...
                         Pulse('674DoublePass',0,pTime)]);
        end
        
%         prog.GenSeq(Pulse('674PulseShaper',0,1));
        
        % detection
        prog.GenSeq([Pulse('OnRes422',0,dic.TDetection) Pulse('PhotonCount',0,dic.TDetection)]);
        % resume cooling
        prog.GenSeq(Pulse('Repump1033',0,dic.T1033));

        prog.GenSeq([Pulse('OffRes422',0,0) Pulse('Repump1092',0,0)]);
        prog.GenFinish;    
        dic.com.UploadCode(prog);
        dic.com.UpdateFpga;
        dic.com.WaitForHostIdle; % wait until host finished it last task
        dic.com.Execute(rep);
        dic.com.WaitForHostIdle;
        r = dic.com.ReadOut(rep);
        r = r(2:end);
    end
end

