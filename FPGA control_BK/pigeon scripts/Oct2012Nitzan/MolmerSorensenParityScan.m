function MolmerSorensenParityScan

dic=Dictator.me;

ParityPhase=0:pi/5:2*pi;  
% ParityPhase=0:1/30:1;  

% ParityPhase=0:0.03:1;  

%GateDetuning=-0.013;
repetitions=200;
DoZeemanMapping=0;

%SBoffset=-0.006;
%GateDetuning=0.0128; "working"

if DoZeemanMapping==0
    ParityTime=5.9;
else
    ParityTime=dic.piHalfRF;
end

ParityAmplitude=200;

SBoffset=-0.4/1000;
BeamBalance=0;
GateDetuning=(22.7+2)/1000; 


doEcho=0;
% echostart=100/sqrt(2);
echostart=round(110/sqrt(2));
echoduration=3.3;
% echoduration=0.1;

if ~exist('Vmodes')
    Vmodes = [2];
end
%-------------- Set GUI figures ---------------------
InitializeAxes (dic.GUI.sca(1),'Photons #','Cases Counted #','Fluorescence Histogram',...
                [0 dic.maxPhotonsNumPerReadout],[],0);

lines =InitializeAxes (dic.GUI.sca(6),...
    'Gate Phase','Populations %','Parity Scan',...
    [ParityPhase(1) ParityPhase(end)],[-1 1],4);
darkCountLine(1) = lines(1);
fitLine(1) = lines(2);
set(darkCountLine(1),'Marker','.','MarkerSize',10,'Color','b');

darkCountLine(2) = lines(2);
set(darkCountLine(2),'Marker','.','MarkerSize',10,'Color','g');

darkCountLine(3) = lines(3);
set(darkCountLine(3),'Marker','.','MarkerSize',10,'Color','k');

darkCountLine(4) = lines(4);
set(darkCountLine(4),'Marker','.','MarkerSize',10,'Color','r');

%-------------- main scan loop ---------------------


%f674Span=-0.07:0.007:0.07;    
% set(dic.GUI.sca(10),'XLim',[PulseTime(1) PulseTime(end)]);

% darkBank = zeros(length(Vmodes),2,length(PulseTime));
dark=zeros(length(ParityPhase));
p0=zeros(length(ParityPhase));
p1=zeros(length(ParityPhase));
p2=zeros(length(ParityPhase));


dic.setNovatech('Red','freq',dic.SinglePass674freq-SBoffset+(dic.vibMode(Vmodes).freq-dic.GateInfo.GateDetuningkHz/1000),'amp',dic.GateInfo.RedAmp+BeamBalance/2);
dic.setNovatech('Blue','freq',dic.SinglePass674freq-SBoffset-(dic.vibMode(Vmodes).freq-dic.GateInfo.GateDetuningkHz/1000),'amp',dic.GateInfo.BlueAmp-BeamBalance/2,'phase',0.86);

dic.setNovatech('Parity','freq',dic.SinglePass674freq-SBoffset,'amp',ParityAmplitude);
dic.setNovatech('Echo','freq',dic.SinglePass674freq-SBoffset,'amp',1000);
CrystalCheckPMT;

if dic.SitOnItFlag
    cont=1;
    dic.setNovatech('Parity','freq',dic.SinglePass674freq,'phase',2.1,'amp',ParityAmplitude);
    while (cont)
        if (dic.stop)
            cont=0;
            return
        end
        dic.setNovatech('DoublePass','freq',dic.updateF674,'amp',1000);
        r=experimentSequence(Vmodes);
        dic.GUI.sca(1); %get an axis from Dictator GUI to show data
        hist(r,0:1:(1.8*dic.maxPhotonsNumPerReadout));
        dark=100-sum( (r>dic.TwoIonsCountThreshold)*2+...
            ((r>dic.darkCountThreshold)&(r<dic.TwoIonsCountThreshold))*1 ...
            )/2/length(r)*100;
        %p0(index1)=dark(index1);
        p0=sum(r<dic.darkCountThreshold)/length(r)*100;
        p2=sum(r>dic.TwoIonsCountThreshold)/length(r)*100;
        p1=100-p0-p2;
        disp(sprintf('P0= %f P2= %f P1= %f',p0,p2,p1));  
 
    end
else
    for index2 = 1:length(ParityPhase)
                
        if dic.stop
            return
        end
        dic.setNovatech('DoublePass','freq',dic.updateF674,'amp',1000);
        
        if DoZeemanMapping==1
            dic.setNovatech('Parity','phase',0);
            dic.setNovatech('Echo','freq',dic.SinglePass674freq,'amp',1000);

        else
            dic.setNovatech('Parity','phase',mod(ParityPhase(index2),2*pi));
        end
        r=experimentSequence(Vmodes,mod(ParityPhase(index2),2*pi));
        
        dic.GUI.sca(1); %get an axis from Dictator GUI to show data
        hist(r,0:1:(1.8*dic.maxPhotonsNumPerReadout));
        if dic.TwoIonFlag
            dark(index2) =100-sum( (r>dic.TwoIonsCountThreshold)*2+...
                ((r>dic.darkCountThreshold)&(r<dic.TwoIonsCountThreshold))*1 ...
                )/2/length(r)*100;
            %p0(index1)=dark(index1);
            p0(index2)=sum(r<dic.darkCountThreshold)/length(r)*100;
            p2(index2)=sum(r>dic.TwoIonsCountThreshold)/length(r)*100;
            p1(index2)=100-p0(index2)-p2(index2);
        else
            dark(index2) = sum( r<dic.darkCountThreshold)/length(r)*100;
        end
        parity(index2)=(p0(index2)+p2(index2)-p1(index2))/100;
        %         disp(sprintf('%f %f %f %f',p0(index2),p1(index2),p2(index2),parity(index2)));
        AddLinePoint(darkCountLine(1),ParityPhase(index2),parity(index2));
        
%         AddLinePoint(darkCountLine(2),ParityPhase(index2),p0(index2)/100);
%         AddLinePoint(darkCountLine(3),ParityPhase(index2),p2(index2)/100);
        
        pause(0.1);
        
        %         end
    end
    
    s = fitoptions('Method','NonlinearLeastSquares',...
        'Startpoint',[1.0 0]);
    %     f = fittype('a*sin(d*x-b)+c','options',s);
    f = fittype('a*sin(2*x-b)','options',s);
    
    [c2,gof2] = fit(ParityPhase',parity',f);
    ParityContrast=abs(c2.a);
    %     disp(sprintf('Parity Contrast = %.3f  Phase Shift = %1.2f  Offset = %.2f',c2.a,c2.b,c2.c));
    disp(sprintf('Parity Contrast = %.3f  Phase Shift = %1.2f',c2.a,c2.b));
    
    set(lines(4),'XData',ParityPhase,'YData',c2(ParityPhase));
end
%------------ Save data ------------------
    showData='figure;plot(ParityPhase,parity);xlabel(''Parity Phase'');ylabel(''Parity'');s = fitoptions(''Method'',''NonlinearLeastSquares'',''Startpoint'',[1.01 0]);f = fittype(''a*sin(2*x-b)'',''options'',s);[c2,gof2] = fit(ParityPhase'',parity'',f);   ParityContrast=abs(c2.a);disp(sprintf(''Parity Contrast = %.3f  Phase Shift = %1.2f'',c2.a,c2.b)); hold on; plot(c2); hold off;';
    dic.save;
%--------------------------------------------------------------------
%--------------------------------------------------------------------
    function r=experimentSequence(mode,parityphase)
        prog=CodeGenerator;
        prog.GenDDSPullParametersFromBase;
%          prog.GenWaitExtTrigger;
        
        prog.GenSeq(Pulse('ExperimentTrigger',0,50));
%         prog.GenWaitExtTrigger;
        
        prog.GenSeq(Pulse('674DDS1Switch',0,-1,'amp',100));
        prog.GenSeq(Pulse('RFDDS2Switch',2,-1,'freq',dic.FRF,'amp',dic.ampRF,'phase',0));
        
        % Doppler coolng
        prog.GenSeq(Pulse('OffRes422',0,500));%turn off cooling
        prog.GenSeq(Pulse('OnResCooling',0,dic.Tcooling));
        
        %activate noise eater, move it to int hold and repump
        prog.GenSeq([Pulse('674DDS1Switch',0,15),... 
            Pulse('NoiseEater674',2,10),Pulse('674DoublePass',0,15),...
            Pulse('Repump1033',15,dic.T1033)]);
        
        prog.GenSeq(Pulse('OpticalPumping',0,dic.Toptpump));
%         prog.GenSeq(Pulse('Shutters',0,0)); %shut down all lasers (takes <=3ms)
        
        %%%%%%%%%%%%% SIDEBAND COOLING %%%%%%%%%%%%%%%%
        SeqGSC=[]; N=1; Tstart=2;
        Mode2Cool=mode;
        if (~isempty(Mode2Cool))
            for mode=Mode2Cool
                % turn on carrier mode
                SeqGSC=[SeqGSC,Pulse('674DoublePass',Tstart,dic.vibMode(mode).coolingTime/N),... 
                               Pulse('674DDS1Switch',Tstart,dic.vibMode(mode).coolingTime/N,...
                                     'freq',dic.SinglePass674freq+dic.vibMode(mode).freq+dic.acStarkShift674)];
                                 Tstart=2+Tstart+dic.vibMode(mode).coolingTime/N;
            end
            prog.GenSeq([Pulse('Repump1033',0,0), Pulse('OpticalPumping',0,0)]);
            prog.GenRepeatSeq(SeqGSC,N);
            prog.GenSeq([Pulse('Repump1033',dic.T1033,-1), Pulse('OpticalPumping',dic.T1033,-1)]);
            % pulsed GSC
            for mode=fliplr(Mode2Cool)
            prog.GenRepeatSeq([Pulse('674DoublePass',2,dic.vibMode(mode).coldPiTime),... 
                               Pulse('674DDS1Switch',2,dic.vibMode(mode).coldPiTime,'freq',dic.SinglePass674freq+dic.vibMode(mode).freq),...
                               Pulse('Repump1033',dic.vibMode(mode).coldPiTime,dic.T1033),...
                               Pulse('OpticalPumping',dic.vibMode(mode).coldPiTime+dic.T1033,dic.Toptpump)],2);                          
            end
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
            prog.GenSeq([Pulse('674Gate',1,dic.GateInfo.GateTime_mus),Pulse('674DoublePass',0,dic.GateInfo.GateTime_mus+1)]);            
        end
        prog.GenSeq(Pulse('Repump1092',0,0));

        
        % Zeeman mapping of the optical qubit
        if DoZeemanMapping==1
            prog.GenSeq(Pulse('RFDDS2Switch',0,dic.TimeRF,'phase',0));
            prog.GenSeq([Pulse('674Echo',1,0.84*dic.T674),Pulse('674DoublePass',0,0.84*dic.T674+1)]);
        end
                
        % Parity Pulse, either optical or RF
        if DoZeemanMapping==1
            % RF parity pulse
            prog.GenSeq(Pulse('RFDDS2Switch',0,ParityTime,'phase',parityphase));
            % Shelving detection
            prog.GenSeq([Pulse('674DDS1Switch',1,dic.T674),Pulse('674DoublePass',0,dic.T674+1)]);
            
        else
            prog.GenSeq([Pulse('674DoublePass',0,ParityTime+1),...
                Pulse('674Parity',1,ParityTime)]);
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
