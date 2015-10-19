function SingleQubitAddressingScan(varargin)
dic=Dictator.me;
savedata=1;
pulseTime=dic.T674;
pulseAmp=100;
updateFit=1;
rep=400;

phaselastpulse=pi/2; %0 is sigma y, pi/2 sigmax
MMFreq=21.75;

%%%% OPTIONS %%%%
ScanPhase=0;
ScanFrequency=1;
%%%%%%%%%%%%%%%%%


BeatingFrequency=1:0.3:30; % in kHz
PhaseToSx=0:0.2:2*pi;

if ScanPhase==1
    ScanParameter=PhaseToSx;
    BeatingFrequency=0;
elseif ScanFrequency==1
    ScanParameter=BeatingFrequency;
    PhaseToSx=3.21;
end 

%%%% DRESSING %%%%%%%
DoSx=1;
SxPower=700;
SxTime=260;
%%% END DRESSING %%%%%


%%%%% RAP PARAMETERS %%%%%%%
DDSToUse=2; % 1 is 674 ; 2 is the one for RF (temporarily on double pass)
% SweepTime=10:50:1400;
RAPWindow=100; % in kHz
DoHalfRAP=1;
DoRAPBack=1;
RAPTime=900;
RAPonMM=1;
TimePerStep=0.02; % in microsec
FakeRAP=0; %in case of a Fake RAP, the sweep is done on the opposite side
SweepPower=100; % in %
SpinLockTest=1;
SpinLockWait=1000; %Wait Time in the equatorial plane
%%%%% RAP PARAMETERS %%%%%%%%%%%%%%%


% % Reinitialize DDS
% DDSSingleToneInitialization(1,85);DDSSingleToneInitialization(2,3);

MMFreq=21.75;

dic.setNovatech('Red','amp',0);
dic.setNovatech('Blue','amp',0); %multiply by zero
dic.setNovatech('Parity','amp',0);
dic.setNovatech('Echo','amp',0);
% control the double pass frequency
dic.setNovatech('DoublePass','freq',dic.updateF674+MMFreq/2,'amp',1000);

pause(1);

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
lines =InitializeAxes (dic.GUI.sca(9),...
    'Single Qubit Addressing Frequency [kHz]','Population %','Single Qubit Addressing Frequency Scan',...
    [ScanParameter(1) ScanParameter(end)],[0 100],2);
set(lines(1),'Marker','.','MarkerSize',10,'Color','b');
set(lines(2),'Marker','.','MarkerSize',10,'Color','g');

dic.setNovatech('DoublePass','freq',dic.updateF674+RAPonMM*MMFreq/2,'amp',1000);


%-------------- Main function scan loops ---------------------
dark = zeros(length(ScanParameter));
fidelity = zeros(length(ScanParameter));

countcheck=0;
if dic.SitOnItFlag
    cont=1;
    while (cont)
        if (dic.stop)
            cont=0;
        end
        r=experimentSequence(dic.SinglePass674freq,RAPTime,pulseAmp);
        dic.GUI.sca(1); %get an axis from Dictator GUI to show data
        hist(r,1:1:dic.maxPhotonsNumPerReadout);
        xlabel(num2str(sum( r<dic.darkCountThreshold)/length(r)*100,2),...
            'FontSize',100);
    end
else
    for index2=1:length(ScanParameter)
        if dic.stop
            DDSSingleToneInitialization(1,dic.SinglePass674freq);DDSSingleToneInitialization(2,dic.F674/2);
            return;
        end
        if countcheck==10
            CrystalCheckPMT;
            DDSSingleToneInitialization(1,dic.SinglePass674freq);DDSSingleToneInitialization(2,dic.F674/2);
            dic.setNovatech('DoublePass','freq',dic.updateF674+RAPonMM*MMFreq/2,'amp',1000);
            countcheck=0;
        else
            countcheck=countcheck+1;
        end
        
        if DDSToUse==1
            dic.setNovatech('DoublePass','freq',dic.estimateF674+RAPonMM*MMFreq/2,'amp',1000);
        else
            dic.setNovatech('DoublePass','amp',0);
            dic.setNovatech('Echo','freq',dic.SinglePass674freq,'amp',1000);
            if ScanPhase==1
                dic.setNovatech('Blue','freq',dic.SinglePass674freq,'amp',SxPower,'phase',ScanParameter(index2));
                dic.setNovatech('Red','freq',BeatingFrequency/1000,'amp',SxPower);
            elseif ScanFrequency==1
                dic.setNovatech('Blue','freq',dic.SinglePass674freq,'amp',SxPower,'phase',PhaseToSx);
                dic.setNovatech('Red','freq',ScanParameter(index2)/1000,'amp',SxPower);
            end
        end
        
        pause(0.1);
        if DDSToUse==1
            FreqToRAP=dic.SinglePass674freq; %RAP on Single Pass
        else
            % notice the factor 1/2, because of the multipler after the DDS
            FreqToRAP=(dic.estimateF674+RAPonMM*MMFreq/2)/2; % RAP on Double Pass
            RAPWindow=RAPWindow;
        end
        
        pause(0.1);
        r=experimentSequence(FreqToRAP,RAPTime,pulseAmp,SxTime);%(FreqSinglePass,pulseTime,pulseAmp);
        dic.GUI.sca(1);
        hist(r,1:1:dic.maxPhotonsNumPerReadout);
        if dic.TwoIonFlag
            dark(index2) =100-sum( (r>dic.TwoIonsCountThreshold)*2+...
                ((r>dic.darkCountThreshold)&(r<dic.TwoIonsCountThreshold))*1 ...
                )/2/length(r)*100;
            fidelity(index2)=100-sum( (r>dic.TwoIonsCountThreshold)*2+(r<dic.darkCountThreshold)*2)/2/length(r)*100;
        else
            dark(index2) = sum( r<dic.darkCountThreshold)/length(r)*100;
            fidelity(index2)=dark(index2);
        end
        AddLinePoint(lines(1),ScanParameter(index2),dark(index2));
        AddLinePoint(lines(2),ScanParameter(index2),fidelity(index2));
        
    end
    %         disp(sprintf('At DiffCap = %2.2f  Max Fidelity = %2.2f [mus]\n',dic.HPVcomp,max(fidelity)));
    
    %------------ Save data ------------------
    DDSSingleToneInitialization(1,dic.SinglePass674freq);DDSSingleToneInitialization(2,dic.F674/2);
    dic.setNovatech('Echo','amp',0);
    
    showData='figure;plot(ScanParameter,fidelity,''b'',ScanParameter,dark,''r'');axis([min(ScanParameter) max(ScanParameter) 0 100]);colorbar;xlabel(''Addressing Frequency (kHz)''); ylabel(''Population''); title(''Single Qubit Addressing Frequency Scan'');';
    dic.save;
    
end

%%------------------------ experiment sequence -----------------
    function r=experimentSequence(pFreq,pTime,pAmp,sxTime)
        
        prog=CodeGenerator;
        prog.GenDDSPullParametersFromBase;
        
        % set DDS freq and amp
        prog.GenSeq(Pulse('ExperimentTrigger',0,50));
        % Doppler coolng
        prog.GenSeq(Pulse('OffRes422',0,1));%turn off cooling
        prog.GenSeq(Pulse('OnResCooling',10,dic.Tcooling));
        % update the noiseEater value
        if DDSToUse==1            
            prog.GenSeq([Pulse('674DDS1Switch',0,15,'amp',100),...
                Pulse('NoiseEater674',2,10),Pulse('674DoublePass',0,15),...
                Pulse('Repump1033',15,dic.T1033),...
                Pulse('OpticalPumping',16+dic.T1033,dic.Toptpump)]);
            prog.GenSeq(Pulse('674DDS1Switch',2,-1));
        else
            prog.GenSeq([Pulse('RFDDS2Switch',0,15,'amp',100),...
                Pulse('NoiseEater674',2,10),Pulse('674DoublePass',0,15),Pulse('674Echo',0,15),...
                Pulse('Repump1033',15,dic.T1033),...
                Pulse('OpticalPumping',16+dic.T1033,dic.Toptpump)]);
            prog.GenSeq(Pulse('674DDS1Switch',2,-1));
        end
        
        % experiment based on RAP
        if FakeRAP %if fake RAP, put the window off resonance
            StartFreq=pFreq+RAPWindow/1000/2;
            StopFreq=StartFreq+RAPWindow/1000;
        else
            StartFreq=pFreq-RAPWindow/1000/2;
            if DoHalfRAP
                StopFreq=StartFreq+RAPWindow/1000/2;
            else
                StopFreq=StartFreq+RAPWindow/1000;         
            end
        end
        if DDSToUse==1
            prog.GenSeq(Pulse('674DDS1Switch',0,-1,'freq',StartFreq,'phase',0));
        else
            prog.GenSeq(Pulse('RFDDS2Switch',0,-1,'freq',StartFreq,'phase',0));
        end
        StepFreq=(StopFreq-StartFreq)/(pTime/TimePerStep);
        % set DDS freq and amp
        prog.GenDDSResetPulse;
        prog.GenDDSInitialization(DDSToUse,2);
        prog.GenDDSFrequencyWord(DDSToUse,1,StartFreq);
        prog.GenDDSFrequencyWord(DDSToUse,2,StopFreq);
        prog.GenDDSSweepParameters (DDSToUse,StepFreq,TimePerStep);
        prog.GenDDSIPower(DDSToUse,0); prog.GenPause(200);
        prog.GenDDSIPower(DDSToUse,SweepPower); prog.GenPause(100);
        
        %sweep forward
        prog.GenDDSFSKState(DDSToUse,1);
        if DDSToUse==1
            prog.GenSeq([Pulse('674DDS1Switch',0,0,'amp',SweepPower),Pulse('674DoublePass',0,0)]);
        else
            prog.GenSeq([Pulse('RFDDS2Switch',0,0,'amp',SweepPower),Pulse('674DoublePass',0,0),Pulse('674Echo',0,0)]);
        end
        prog.GenPause(RAPTime);
        prog.GenPause(10);
        
        
        if DoRAPBack
            % WaitTime in the equatorial plane;
            if SpinLockTest==1
                prog.GenPause(SpinLockWait);
            end            
            
            if ScanPhase==1
                % Turn off the RAP beam
                prog.GenSeq(Pulse('674Echo',0,1));                
            end
            
            if DoSx
                % do Sx in the interaction picture
                prog.GenSeq(Pulse('674Gate',2,sxTime));
            end
            
            if ScanPhase==1
                % Turn on again
                prog.GenSeq(Pulse('674Echo',0,0));                
            end
            
            %sweep backwards
            prog.GenDDSFSKState(DDSToUse,0);
            prog.GenPause(RAPTime);
        end
        
        % turn 674 off
        if DDSToUse==1
            prog.GenSeq([Pulse('674DDS1Switch',0,-1,'amp',0),Pulse('674DoublePass',0,-1)]);
        else
            prog.GenSeq([Pulse('RFDDS2Switch',0,-1,'amp',0),Pulse('674DoublePass',0,-1)]);
        end
        prog.GenDDSFSKState(DDSToUse,0);
        prog.GenDDSInitialization(DDSToUse,0);
        
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