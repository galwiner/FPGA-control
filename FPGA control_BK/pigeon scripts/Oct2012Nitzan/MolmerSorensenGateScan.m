function MolmerSorensenGateScan(Vmodes)

dic=Dictator.me;
if ~exist('Vmodes')
    Vmodes = 1;
end

GateTime=(1:5:300); 


%GateDetuning=-0.013;
repetitions=400;

%GateDetuning=0.0128; "working"
BeamBalance=0;
SBoffset=-0.5/1000;

DoZeemanMapping=0;

if DoZeemanMapping
    panelc=10;
else
    panelc=7;
end

% dic.GateInfo.GateDetuningkHz=14+6.5; %Stretch
dic.GateInfo.GateDetuningkHz=18; 

doEcho=0;
Echoduration=2.92;
Echostart=dic.GateInfo.GateTime_mus/2;

EchoPhase=3.22+3.14/2;
EchoAmplitude=1000;
% dic.setNovatech('Parity','clock','external');
% dic.setNovatech('Red','clock','external');

%-------------- Set GUI figures ---------------------
InitializeAxes (dic.GUI.sca(1),'Photons #','Cases Counted #','Fluorescence Histogram',...
                [0 dic.maxPhotonsNumPerReadout],[],0);

darkCountLine =InitializeAxes (dic.GUI.sca(panelc),...
    'Gate Time [mus]','Populations %','Entangling Gate',...
    [GateTime(1) GateTime(end)],[0 100],3);
set(darkCountLine(1),'Marker','.','MarkerSize',10,'Color','b');
set(darkCountLine(2),'Marker','.','MarkerSize',10,'Color','r');
set(darkCountLine(3),'Marker','.','MarkerSize',10,'Color','g');

%-------------- main scan loop ---------------------

dark=zeros(length(GateTime));
p0=zeros(length(GateTime));
p1=zeros(length(GateTime));
p2=zeros(length(GateTime));
CrystalCheckPMT;
if dic.SitOnItFlag
    cont=1;
    while (cont)
        if (dic.stop)
            cont=0;
        end
        dic.setNovatech('Red','freq',dic.SinglePass674freq-SBoffset+(dic.vibMode(Vmodes).freq-dic.GateInfo.GateDetuningkHz/1000),'amp',dic.GateInfo.RedAmp+BeamBalance/2);
        dic.setNovatech('Blue','freq',dic.SinglePass674freq-SBoffset-(dic.vibMode(Vmodes).freq-dic.GateInfo.GateDetuningkHz/1000),'amp',dic.GateInfo.BlueAmp-BeamBalance/2);
        dic.setNovatech('Echo','freq',dic.SinglePass674freq,'amp',1000);       
        r=experimentSequence(10,Vmodes);
        dic.GUI.sca(1); %get an axis from Dictator GUI to show data
        hist(r,0:1:(1.8*dic.maxPhotonsNumPerReadout));
        if dic.TwoIonFlag
            darkf =100-sum( (r>dic.TwoIonsCountThreshold)*2+...
                ((r>dic.darkCountThreshold)&(r<dic.TwoIonsCountThreshold))*1 ...
                )/2/length(r)*100;
        else
            darkf = sum( r<dic.darkCountThreshold)/length(r)*100;
        end
        xlabel(num2str(round(darkf)),'FontSize',100);
    end
else
    dic.setNovatech('Red','freq',dic.SinglePass674freq-SBoffset+(dic.vibMode(Vmodes).freq-dic.GateInfo.GateDetuningkHz/1000),'amp',dic.GateInfo.RedAmp+BeamBalance/2);
    dic.setNovatech('Blue','freq',dic.SinglePass674freq-SBoffset-(dic.vibMode(Vmodes).freq-dic.GateInfo.GateDetuningkHz/1000),'amp',dic.GateInfo.BlueAmp-BeamBalance/2);
    dic.setNovatech('Echo','freq',dic.SinglePass674freq,'amp',1000);
    for index2 = 1:length(GateTime)        
        if dic.stop
            return
        end
        dic.setNovatech('DoublePass','freq',dic.updateF674,'amp',1000);
        r=experimentSequence(GateTime(index2),Vmodes);
        dic.GUI.sca(1); %get an axis from Dictator GUI to show data
        hist(r,0:1:(1.8*dic.maxPhotonsNumPerReadout));
        
        p0(index2)=sum(r<dic.darkCountThreshold)/length(r)*100;
        p2(index2)=sum(r>dic.TwoIonsCountThreshold)/length(r)*100;
        p1(index2)=100-p0(index2)-p2(index2);

        dic.GUI.sca(panelc);
        AddLinePoint(darkCountLine(1),GateTime(index2),p0(index2));
        AddLinePoint(darkCountLine(2),GateTime(index2),p2(index2));
        AddLinePoint(darkCountLine(3),GateTime(index2),p1(index2));
        pause(0.1);
        %         end
    end
end
showData='figure;plot(GateTime,p0,''g'',GateTime,p1,''b'',GateTime,p2,''r'');xlabel(''Gate Time[\mus]'');ylabel(''Populations'');';
dic.save;
%--------------------------------------------------------------------
    function r=experimentSequence(pulsetime,mode)
        prog=CodeGenerator;
        prog.GenDDSPullParametersFromBase;
%       prog.GenWaitExtTrigger;
        
        prog.GenSeq(Pulse('ExperimentTrigger',0,50));

        prog.GenSeq(Pulse('674DDS1Switch',0,-1,'amp',100));
        prog.GenSeq(Pulse('RFDDS2Switch',2,-1,'freq',dic.FRF,'amp',dic.ampRF));
        
        % Doppler coolng
        prog.GenSeq(Pulse('OffRes422',0,1));%turn off cooling
        prog.GenSeq(Pulse('OnResCooling',0,dic.Tcooling));
        
        %activate noise eater, move it to int hold and repump
        prog.GenSeq([Pulse('674DDS1Switch',1,15),... 
            Pulse('NoiseEater674',2,10),Pulse('674DoublePass',0,16),...
            Pulse('Repump1033',16,dic.T1033)]);
        
        prog.GenSeq(Pulse('OpticalPumping',0,dic.Toptpump));
%         prog.GenSeq(Pulse('Shutters',0,0)); %shut down all lasers (takes <=3ms)
        
        %%%%%%%%%%%%% SIDEBAND COOLING %%%%%%%%%%%%%%%%
        SeqGSC=[]; N=1; Tstart=2;
        Mode2Cool=mode;
        if (~isempty(Mode2Cool))
            for mode=Mode2Cool
                % turn on carrier mode
                SeqGSC=[SeqGSC,Pulse('NoiseEater674',Tstart,dic.vibMode(mode).coolingTime/N),...
                               Pulse('674DoublePass',Tstart,dic.vibMode(mode).coolingTime/N),... 
                               Pulse('674DDS1Switch',Tstart,dic.vibMode(mode).coolingTime/N,...
                                     'freq',dic.SinglePass674freq+dic.vibMode(mode).freq+dic.acStarkShift674)];
            end
            prog.GenSeq([Pulse('Repump1033',0,0), Pulse('OpticalPumping',0,0)]);
            prog.GenRepeatSeq(SeqGSC,N);
            prog.GenSeq([Pulse('Repump1033',dic.T1033,-1), Pulse('OpticalPumping',dic.T1033,-1)]);
            % pulsed GSC
%             for mode=fliplr(Mode2Cool)
%             prog.GenRepeatSeq([Pulse('674DoublePass',2,dic.vibMode(mode).coldPiTime),... 
%                                Pulse('674DDS1Switch',2,dic.vibMode(mode).coldPiTime,'freq',dic.SinglePass674freq+dic.vibMode(mode).freq),...
%                                Pulse('Repump1033',dic.vibMode(mode).coldPiTime,dic.T1033),...
%                                Pulse('OpticalPumping',dic.vibMode(mode).coldPiTime+dic.T1033,dic.Toptpump)],2);                          
%             end
        end        
        %%%%%%%%%% END OF GROUND STATE COOLING %%%%%%%%%%
        prog.GenSeq(Pulse('674DDS1Switch',0,-1,'freq',dic.SinglePass674freq));        
        prog.GenSeq(Pulse('OpticalPumping',0,dic.Toptpump));
                
        if (doEcho && (pulsetime>Echostart+Echoduration+1))
        %  Gate Pulse With Echo while Gate beams switched off
        prog.GenSeq([Pulse('674PulseShaper',1,pulsetime-5),...
                         Pulse('674Echo',3+Echostart,Echoduration),...
                         Pulse('674Gate',3,Echostart),Pulse('674DoublePass',3,pulsetime),...
                         Pulse('674Gate',3+Echostart+Echoduration,pulsetime-Echostart-Echoduration)]);
        else
%             prog.GenSeq([Pulse('674PulseShaper',1,pulsetime-5),...
%                          Pulse('674Gate',3,pulsetime),Pulse('674DoublePass',3,pulsetime)]);            
            prog.GenSeq([Pulse('674Gate',1,pulsetime),Pulse('674DoublePass',0,pulsetime+1)]);            
        end

        % Zeeman mapping of the optical qubit
         if DoZeemanMapping
            prog.GenSeq(Pulse('RFDDS2Switch',0,dic.TimeRF));
            prog.GenSeq([Pulse('674Echo',1,dic.T674),Pulse('674DoublePass',0,dic.T674+1)]);
         end
        
        % Shelving detection
        if DoZeemanMapping
             prog.GenSeq([Pulse('674DDS1Switch',1,dic.T674),Pulse('674DoublePass',0,dic.T674+1)]);
        end
        
        % detection
        prog.GenSeq([Pulse('OnRes422',0,dic.TDetection) Pulse('PhotonCount',0,dic.TDetection)]);
        %resume cooling
        prog.GenSeq(Pulse('Repump1033',0,dic.T1033));
        prog.GenSeq(Pulse('OffRes422',0,0));
        prog.GenFinish;
        
        dic.com.UploadCode(prog);
        dic.com.UpdateFpga;
        dic.com.WaitForHostIdle; % wait until host finished it last task
        dic.com.Execute(repetitions);
        dic.com.WaitForHostIdle;
        r = dic.com.ReadOut(repetitions);
        r = r(2:end);
    end

end