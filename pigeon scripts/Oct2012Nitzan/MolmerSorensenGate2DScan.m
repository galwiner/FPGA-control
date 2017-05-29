function MolmerSorensenGate2DScan

dic=Dictator.me;

if ~exist('Vmodes')
    Vmodes = 1;
end
%-------------- Set GUI figures ---------------------
InitializeAxes (dic.GUI.sca(1),'Photons #','Cases Counted #','Fluorescence Histogram',...
                [0 dic.maxPhotonsNumPerReadout],[],0);

lines =InitializeAxes (dic.GUI.sca(10),...
    'F [MHz]','Dark Counts %','Entangling Gate',...
    [],[0 100],2);
darkCountLine(1) = lines(1);
fitLine(1) = lines(2);
set(darkCountLine(1),'Marker','.','MarkerSize',10,'Color','b');

darkCountLine(2) = lines(2);
set(darkCountLine(2),'Marker','.','MarkerSize',10,'Color','r');

%-------------- main scan loop ---------------------

repetitions=50;

% GateTime=70; 

% GateDetuning=0.0:0.004:0.06;
 SBOffset=(-0.02:0.0005:0.02);
% SBOffset=-0.0004;
GateDetuning=41.7/1000;
% SBOffset=(-0.02:0.0007:0.02);

% GateTime=(1:7:400);
 GateTime=(1:7:400);

% GateDetuning=(-0.01:0.001:0.075);
% GateDetuning=(-0.01:0.01:0.075);

% GateDetuning=(0.00:0.0007:0.06);


dark=zeros(length(SBOffset),length(GateTime));
p0=zeros(length(SBOffset),length(GateTime));
p1=zeros(length(SBOffset),length(GateTime));
p2=zeros(length(SBOffset),length(GateTime));


if dic.SitOnItFlag
    cont=1;
    while (cont)
        if (dic.stop)
            cont=0;
        end
        dic.setNovatech4Amp(1,1000)
        dic.setNovatech4Amp(2,0);

        
        dic.setNovatech4Amp(2,1000);dic.setNovatech4Freq(2,dic.F674);
        dic.setNovatech4Freq(1,Freq674SinglePass-(dic.vibMode(1).freq+LightShift));
        dic.setNovatech4Freq(0,Freq674SinglePass+(dic.vibMode(1).freq+LightShift));
        r=experimentSequence(30,1);
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
    for modeInd=1:length(Vmodes)
        grid on;

        for index2 = 1:length(GateTime)
            CrystalCheckPMT;
            for index1=1:length(SBOffset)
%                 fprintf('%g / %g\n',index1,length(GateDetuning));
                dic.setNovatech('Red','freq',dic.SinglePass674freq-SBOffset(index1)+(dic.vibMode(Vmodes).freq-GateDetuning),'amp',dic.GateInfo.RedAmp);
                dic.setNovatech('Blue','freq',dic.SinglePass674freq-SBOffset(index1)-(dic.vibMode(Vmodes).freq-GateDetuning),'amp',dic.GateInfo.BlueAmp);
                dic.setNovatech('DoublePass','freq',dic.updateF674,'amp',1000);

                if dic.stop
                    return
                end
                
                r=experimentSequence(GateTime(index2),Vmodes(modeInd));
                dic.GUI.sca(1); %get an axis from Dictator GUI to show data
                hist(r,0:1:(1.8*dic.maxPhotonsNumPerReadout));
                if dic.TwoIonFlag
                    dark(index1,index2) =100-sum( (r>dic.TwoIonsCountThreshold)*2+...
                        ((r>dic.darkCountThreshold)&(r<dic.TwoIonsCountThreshold))*1 ...
                        )/2/length(r)*100;
                    %p0(index1)=dark(index1);
                    p2(index1,index2)=sum(r<dic.darkCountThreshold)/length(r)*100;
                    p0(index1,index2)=sum(r>dic.TwoIonsCountThreshold)/length(r)*100;  
                    p1(index1,index2)=100-p0(index1,index2)-p2(index1,index2);
                else
                    dark(index1,index2) = sum( r<dic.darkCountThreshold)/length(r)*100;
                end
                
                %AddLinePoint(darkCountLine(1),PulseTime(index1),p2(index1));
                %AddLinePoint(darkCountLine(2),PulseTime(index1),p1(index1));

                %                darkBank(modeInd,lobeIndex,index1)=dark(index1);
%                 pause(0.1);
            end
                dic.GUI.sca(7);
                imagesc(GateTime,SBOffset,p0);
                axis([min(GateTime) max(GateTime) min(SBOffset) max(SBOffset)]);
                colorbar;
                ylabel('SBOffset( kHz)'); xlabel('GateTime(mus)'); title('P0');
                dic.GUI.sca(6);
                imagesc(GateTime,SBOffset,p1);
                axis([min(GateTime) max(GateTime) min(SBOffset) max(SBOffset)]);
                colorbar;
                ylabel('SBOffset( kHz)'); xlabel('GateTime(mus)'); title('P1');
                dic.GUI.sca(11);
                imagesc(GateTime,SBOffset,p2);
                axis([min(GateTime) max(GateTime) min(SBOffset) max(SBOffset)]);
                colorbar;
                ylabel('SBOffset( kHz)'); xlabel('GateTime(mus)'); title('P2');
            
        end
    end
end

dic.save;
showData=['figure; imagesc(GateTime,SBOffset,p0(index1,index2)); axis([min(SBOffset) max(SBOffset) min(GateTime) max(GateTime)]);colorbar; ylabel(''SBOffset( kHz)''); xlabel(''GateTime(mus)''); title(''P0'');' ...
            'figure; imagesc(GateTime,SBOffset,p1(index1,index2)); axis([min(SBOffset) max(SBOffset) min(GateTime) max(GateTime)]);colorbar; ylabel(''SBOffset( kHz)''); xlabel(''GateTime(mus)''); title(''P1'');' ... 
            'figure; imagesc(GateTime,SBOffset,p2(index1,index2)); axis([min(SBOffset) max(SBOffset) min(GateTime) max(GateTime)]);colorbar; ylabel(''SBOffset( kHz)''); xlabel(''GateTime(mus)''); title(''P2'');'];
%--------------------------------------------------------------------
    function r=experimentSequence(pulsetime,mode)
        prog=CodeGenerator;
        prog.GenDDSPullParametersFromBase;
        prog.GenSeq(Pulse('ExperimentTrigger',0,50));
        prog.GenSeq(Pulse('674DDS1Switch',2,-1,'freq',dic.SinglePass674freq,'amp',100));
        % Doppler coolng
        prog.GenSeq(Pulse('OffRes422',0,1));%turn off cooling
        prog.GenSeq(Pulse('OnResCooling',0,dic.Tcooling));

        prog.GenSeq([Pulse('674DDS1Switch',1,15),... %Echo is our choice for NE calib
            Pulse('NoiseEater674',2,10),Pulse('674DoublePass',0,16),...
            Pulse('Repump1033',15,dic.T1033),...
            Pulse('OpticalPumping',16+dic.T1033,dic.Toptpump)]);
        
        %%%%%%%%%%%%% SIDEBAND COOLING %%%%%%%%%%%%%%%%
        SeqGSC=[]; N=4; Tstart=2;
        Mode2Cool=mode;
         % continuous GSC
        if (~isempty(Mode2Cool))
            for mode=Mode2Cool
                % turn on carrier mode
                SeqGSC=[SeqGSC,Pulse('NoiseEater674',Tstart,dic.vibMode(mode).coolingTime/N),...
                               Pulse('674DDS1Switch',Tstart,dic.vibMode(mode).coolingTime/N,...
                                     'freq',dic.SinglePass674freq+dic.vibMode(mode).freq+dic.acStarkShift674),...
                               Pulse('674DoublePass',Tstart,dic.vibMode(mode).coolingTime/N)];
                Tstart=2+Tstart+dic.vibMode(mode).coolingTime/N;
            end
            prog.GenSeq([Pulse('Repump1033',0,0), Pulse('OpticalPumping',0,0)]);
            prog.GenRepeatSeq(SeqGSC,N);
            prog.GenSeq([Pulse('Repump1033',dic.T1033,-1), Pulse('OpticalPumping',dic.T1033,-1)]);
            % pulsed GSC
            for mode=fliplr(Mode2Cool)
            prog.GenRepeatSeq([Pulse('NoiseEater674',2,dic.vibMode(mode).coldPiTime),...
                               Pulse('674DDS1Switch',2,dic.vibMode(mode).coldPiTime,'freq',dic.SinglePass674freq+dic.vibMode(mode).freq),...
                               Pulse('674DoublePass',Tstart,dic.vibMode(mode).coolingTime/N),...
                               Pulse('Repump1033',dic.vibMode(mode).coldPiTime,dic.T1033),...
                               Pulse('OpticalPumping',dic.vibMode(mode).coldPiTime+dic.T1033,dic.Toptpump)],2);                          
            end
        end         
        %%%%%%%%%% END OF GROUND STATE COOLING %%%%%%%%%%
        
        % Gate Pulse 
%         prog.GenSeq([Pulse('NoiseEater674',2,pulsetime),...
%                      Pulse('674DDS1Switch',0,pulsetime)]);
        prog.GenSeq([Pulse('674Gate',1,pulsetime),Pulse('674DoublePass',0,pulsetime)]);

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