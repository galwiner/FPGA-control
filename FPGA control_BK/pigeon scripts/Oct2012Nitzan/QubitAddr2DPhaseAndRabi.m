function QubitAddr2DPhaseAndRabi(varargin)
dic=Dictator.me;
savedata=1;
pulseTime=dic.T674;
pulseAmp=100;
updateFit=1;
rep=50;
PhaseForSx=[0:2*pi/14:2*pi];
PulseTime=1:5:100;

DoCarrier=1;

if DoCarrier==1
    PiTimeDDS=25.3/2;
else
    PiTimeDDS=40/2;
end

SxPower=1000;
phaselastpulse=pi/2; %0 is sigma y, pi/2 sigmax

DoSx=0;

%%%%% RAP PARAMETERS %%%%%%%
useRAP=0;
RAPWindow=100; % in kHz
DoHalfRAP=1;
DoRAPBack=0;
RAPTime=1200;
%StepFreq=5; %in kHz
TimePerStep=0.01; % in microsec
FakeRAP=0; %in case of a Fake RAP, the sweep is done on the opposite side
SweepPower=100; % in %
%%%%% END: RAP PARAMETERS %%%%%%%%%%%%%%%

% % Reinitialize DDS
% DDSSingleToneInitialization(1,dic.SinglePass674freq);DDSSingleToneInitialization(2,3);

dic.setNovatech('Red','amp',0);
dic.setNovatech('Blue','amp',0); %multiply by zero
dic.setNovatech('Parity','amp',0);
dic.setNovatech('Echo','amp',0);
% control the double pass frequency
dic.setNovatech('DoublePass','freq',dic.F674,'amp',1000);

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
% lines =InitializeAxes (dic.GUI.sca(7),...
%     'Pulse Time[\mus]','Dark Counts %','Micromotion Rabi Scan',...
%     [PulseTime(1) PulseTime(end)],[0 100],2);

lines =InitializeAxes (dic.GUI.sca(7),...
    'Phase','Dark Counts %','Micromotion Rabi Scan',...
    [PhaseForSx(1) PhaseForSx(end)],[0 100],2);

grid(dic.GUI.sca(10),'on');
set(lines(1),'Marker','.','MarkerSize',10,'Color','b');
set(lines(2),'Marker','.','MarkerSize',10,'Color','g');


%-------------- Main function scan loops ---------------------
dark = zeros(length(PulseTime),length(PhaseForSx));
fidelity = zeros(length(PulseTime),length(PhaseForSx));

countcheck=0;
if dic.SitOnItFlag
    cont=1;
    while (cont)
        if (dic.stop)
            cont=0;
        end
        r=experimentSequence(dic.SinglePass674freq,SweepTime,pulseAmp);
        dic.GUI.sca(1); %get an axis from Dictator GUI to show data
        hist(r,1:1:dic.maxPhotonsNumPerReadout);
        xlabel(num2str(sum( r<dic.darkCountThreshold)/length(r)*100,2),...
            'FontSize',100);
    end
else
            for index1 = 1:length(PulseTime)

    set(lines(1),'XData',[],'YData',[]);
            set(lines(2),'XData',[],'YData',[]);        
            
    for index2=1:length(PhaseForSx)
            
            if dic.stop
                return;
            end
            if countcheck==15
                CrystalCheckPMT;
                countcheck=0;
            else
                countcheck=countcheck+1;
            end
            
            dic.setNovatech('DoublePass','freq',dic.updateF674+dic.MMFreq/2,'amp',1000);
            dic.setNovatech('Blue','freq',0,'amp',1000);
            dic.setNovatech('Red','freq',dic.SinglePass674freq,'amp',SxPower,'phase',PhaseForSx(index2));
            dic.setNovatech('Parity','freq',dic.SinglePass674freq+dic.MMFreq,'amp',SxPower,'phase',0);
            dic.setNovatech('Echo','freq',dic.SinglePass674freq,'amp',1000,'phase',PhaseForSx(index2)+pi/2);
            
            pause(0.1);
            r=experimentSequence(dic.SinglePass674freq,PulseTime(index1),pulseAmp);%(FreqSinglePass,pulseTime,pulseAmp);
            dic.GUI.sca(1);
            hist(r,1:1:dic.maxPhotonsNumPerReadout);
            if dic.TwoIonFlag
                dark(index1,index2) =100-sum( (r>dic.TwoIonsCountThreshold)*2+...
                    ((r>dic.darkCountThreshold)&(r<dic.TwoIonsCountThreshold))*1 ...
                    )/2/length(r)*100;
                fidelity(index1,index2)=100-sum( (r>dic.TwoIonsCountThreshold)*2+(r<dic.darkCountThreshold)*2)/2/length(r)*100;
            else
                dark(index1,index2) = sum( r<dic.darkCountThreshold)/length(r)*100;
                fidelity(index1,index2)=dark(index1,index2);

            end
%             AddLinePoint(lines(1),PulseTime(index1),dark(index1,index2));
%             AddLinePoint(lines(2),PulseTime(index1),fidelity(index1,index2));

                  AddLinePoint(lines(1),PhaseForSx(index2),dark(index1,index2));
                 AddLinePoint(lines(2),PhaseForSx(index2),fidelity(index1,index2));
 
            
            dic.GUI.sca(11);cla;
            imagesc(PhaseForSx,PulseTime,fidelity);
            axis([min(PhaseForSx) max(PhaseForSx) min(PulseTime) max(PulseTime)]);
            colorbar;
            xlabel('Phase'); ylabel('PulseTime (mus)'); title('Micromotion Cap Scan');
        end
    end
%         disp(sprintf('At DiffCap = %2.2f  Max Fidelity = %2.2f [mus]\n',dic.HPVcomp,max(fidelity)));      

    %------------ Save data ------------------
    
        showData='figure;imagesc(PhaseForSx,PulseTime,dark);axis([min(PhaseForSx) max(PhaseForSx) min(PulseTime) max(PulseTime)]);colorbar;xlabel(''Phase''); ylabel(''PulseTime (mus)''); title(''Micromotion Cap Scan'');';
        dic.save;
    
end
%%------------------------ experiment sequence -----------------
    function r=experimentSequence(pFreq,pTime,pAmp)
        prog=CodeGenerator;
        prog.GenDDSPullParametersFromBase;

        % set DDS freq and amp
        prog.GenSeq(Pulse('ExperimentTrigger',0,50));
        % Doppler coolng
        prog.GenSeq(Pulse('OffRes422',0,1));%turn off cooling
        prog.GenSeq(Pulse('OnResCooling',10,dic.Tcooling));
%         % update the noiseEater value
%         prog.GenDDSIPower(1,100);
        prog.GenSeq([Pulse('674DDS1Switch',0,15,'freq',dic.SinglePass674freq),...
            Pulse('NoiseEater674',2,10),Pulse('674DoublePass',0,15),...
            Pulse('Repump1033',15,dic.T1033),...
            Pulse('OpticalPumping',16+dic.T1033,dic.Toptpump)]);
        prog.GenSeq(Pulse('674DDS1Switch',2,-1,'amp',pAmp));

        if useRAP
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
            prog.GenSeq(Pulse('674DDS1Switch',0,-1,'freq',StartFreq,'amp',100,'phase',0));
            StepFreq=(StopFreq-StartFreq)/(RAPTime/TimePerStep);
            % set DDS freq and amp
            prog.GenDDSResetPulse;
            prog.GenDDSInitialization(1,2);
            prog.GenDDSFrequencyWord(1,1,StartFreq);
            prog.GenDDSFrequencyWord(1,2,StopFreq);
            prog.GenDDSSweepParameters (1,StepFreq,TimePerStep);
            prog.GenDDSIPower(1,0); prog.GenPause(200);
            prog.GenDDSIPower(1,SweepPower); prog.GenPause(100);
            %sweep forward
            prog.GenDDSFSKState(1,1); 
            prog.GenSeq([Pulse('674DDS1Switch',0,0,'amp',SweepPower),Pulse('674DoublePass',0,0)]);
            prog.GenPause(RAPTime);
            
            if DoSx
                % do Sx in the interaction picture
                prog.GenSeq(Pulse('674Gate',2,pTime));
            end
            
            if DoRAPBack
               %sweep backwards
               prog.GenDDSFSKState(1,0);
               prog.GenPause(RAPTime);
            end
            
            % tuen 674 off
            prog.GenSeq([Pulse('674DDS1Switch',0,-1,'amp',0),Pulse('674DoublePass',0,-1)]);
            prog.GenDDSFSKState(1,0);
        else
%             % experiment based on Pi pulses
%             prog.GenSeq(Pulse('674DDS1Switch',2,-1,'amp',100,'freq',dic.SinglePass674freq));
%             prog.GenSeq(Pulse('674PulseShaper',0,0));prog.GenPause(10);
%             prog.GenSeq([Pulse('674DDS1Switch',2,PiTimeDDS,'phase',phaselastpulse),...
%                 Pulse('NoiseEater674',3,PiTimeDDS),...
%                 Pulse('674DoublePass',2,2*PiTimeDDS+pTime+5),...
%                 Pulse('674Gate',PiTimeDDS+1,pTime),...
%                 Pulse('674DDS1Switch',PiTimeDDS+3,pTime,'phase',phaselastpulse+pi/2,'amp',0),...
%                 Pulse('NoiseEater674',PiTimeDDS+pTime+5,PiTimeDDS-1),...
%                 Pulse('674DDS1Switch',PiTimeDDS+pTime+4,PiTimeDDS,'phase',phaselastpulse,'amp',100)]);
%             prog.GenSeq(Pulse('674PulseShaper',0,1));

            % experiment based on Pi pulses
            prog.GenSeq(Pulse('674DDS1Switch',2,-1,'amp',100,'freq',dic.SinglePass674freq));
            prog.GenSeq(Pulse('674PulseShaper',0,0));prog.GenPause(10);
            prog.GenSeq([Pulse('674DDS1Switch',2,PiTimeDDS,'phase',phaselastpulse),...
                Pulse('674DoublePass',2,2*PiTimeDDS+pTime+5),...
                Pulse('674Gate',PiTimeDDS+1,pTime),...
                Pulse('674DDS1Switch',PiTimeDDS+3,pTime,'phase',phaselastpulse+pi/2,'amp',0),...
                Pulse('674DDS1Switch',PiTimeDDS+pTime+4,PiTimeDDS,'phase',phaselastpulse,'amp',100)]);
            prog.GenSeq(Pulse('674PulseShaper',0,1));


        end
        
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

