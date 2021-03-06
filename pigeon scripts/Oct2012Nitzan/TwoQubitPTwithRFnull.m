function TwoQubitPTwithRFnull

dic=Dictator.me;
MMFreq=21.75;
dic.calibRfFlag=1;

Vmodes=2;
repetitions=400;

DoFeedback=1;
doGSC=1;
doGate=1;
doMapping=1;

scanRFnull=1;
loops=3;

% ------------Set GUI axes ---------------
InitializeAxes(dic.GUI.sca(1),'Photons #','Cases Counted #','Fluorescence Histogram',...
                [0 dic.maxPhotonsNumPerReadout],[],0);
InitializeAxes(dic.GUI.sca(11),'measured state','init state','Fluorescence Histogram',...
                [0.5 16.5],[0.5 16.5],0);
feedbackLine =InitializeAxes (dic.GUI.sca(10),...
            'x','y','feedback',[1 15*16],[0 100],1);
% -------- Main function scan loops ------
plotPTMatrix=ones(20,20,loops)*NaN;
for j=1:loops
    plotPTMatrix(1:5:end,1:5:end,j)=1;
end
PTMatrix=ones(16,16,loops);
histograms=zeros(16,16,repetitions-1);

% measure the density matrix in the basis "sigma1 x sigma2'
% experimentSequence takes argument (G1,Lz,G2,ShelvingStyle)
% = G1: global rotation of chosen axis, values 'Gx/Gmx/Gy/Gmy'. 
% If NaN don't do.
% = Lz: local sigmaz rotation, binary variable
% = G2 : second global rotation, same values as G1
% = Shelving Style : 0 regular shelving, 1 only hiding shelving, 2
% both
% CountingStatistics : 0 regular (2 ion), 1 single ion dark
% non-zero value, so that if first argument is zero, then dont do Gx
Gx=0;Gmx=pi;Gy=pi/2;Gmy=3*pi/2;Lz=1;Lmz=-1;

%---------- measured states dictionnay -------------------
MeasuredStateArray=zeros(4,4,4); %[(G1,Lz,G2,DetectionStyle)] CountStat=DetectionStyle>0
MeasuredStateArray(1,1,:)=[NaN,NaN,0,0];     %II (0,0,0,0) 
MeasuredStateArray(1,2,:)=[Gy,NaN,NaN,2];  %IX(Gy,0,0,2);
MeasuredStateArray(1,3,:)=[Gmx,NaN,NaN,2]; %IY(Gmx,0,0,2)
MeasuredStateArray(1,4,:)=[NaN,NaN,NaN,2]; %IZ(0,0,0,2);
MeasuredStateArray(2,1,:)=[Gy,NaN,NaN,1];  %XI(Gy,0,0,1);
MeasuredStateArray(2,2,:)=[Gy,NaN,NaN,0];  %XX(Gy,0,0,0);
MeasuredStateArray(2,3,:)=[NaN,Lmz,Gmx,0]; %XY(0,Lmz,Gmx,0);
MeasuredStateArray(2,4,:)=[Gx,Lmz,Gmx,0];  %XZ(Gx,Lmz,Gmx,0);
MeasuredStateArray(3,1,:)=[Gmx,NaN,NaN,1]; %YI(Gmx,0,0,1);
MeasuredStateArray(3,2,:)=[NaN,Lz,Gy,0];   %YX(0,Lz,Gy,0);
MeasuredStateArray(3,3,:)=[Gmx,NaN,NaN,0]; %YY(Gmx,0,0,0);
MeasuredStateArray(3,4,:)=[Gmy,Lz,Gy,0];   %YZ(Gmy,Lz,Gy,0);
MeasuredStateArray(4,1,:)=[NaN,NaN,NaN,1]; %ZI(0,0,0,1);
MeasuredStateArray(4,2,:)=[Gx,Lz,Gy,0];    %ZX(Gx,Lz,Gy,0);
MeasuredStateArray(4,3,:)=[Gmy,Lmz,Gmx,0]; %ZY(Gmy,Lmz,Gmx,0);
MeasuredStateArray(4,4,:)=[NaN,NaN,NaN,0];  %ZZ(0,0,0,0);

%---------- Initial states dictionnay -------------------
InitStateArray=zeros(4,4,3);
InitStateArray(1,1,:)=[Gmy,NaN,NaN]; % XX : (Gmy,0,0)
InitStateArray(1,2,:)=[Gx,Lz,NaN];   % XY : (Gx,Lz,0)
InitStateArray(1,3,:)=[Gx,Lz,Gmx];   % XZ : (Gx,Lz,Gmx)
InitStateArray(1,4,:)=[Gx,Lz,Gx];    % XZm: (Gx,Lz,Gx)
InitStateArray(2,1,:)=[Gmy,Lmz,NaN]; % YX:  (Gmy,Lmz,0)
InitStateArray(2,2,:)=[Gx,NaN,NaN];  % YY : (Gx,0,0)
InitStateArray(2,3,:)=[Gmy,Lmz,Gy];  % YZ: (Gmy,Lmz,Gy)
InitStateArray(2,4,:)=[Gmy,Lmz,Gmy]; % YZm :(Gmy,Lmz,Gmy)
InitStateArray(3,1,:)=[Gmy,Lmz,Gmx]; % ZX: (Gmy,Lmz,Gmx)
InitStateArray(3,2,:)=[Gx,Lz,Gy];    % ZY: (Gx,Lz,Gy)
InitStateArray(3,3,:)=[NaN,NaN,NaN]; % ZZ : (0,0,0)
InitStateArray(3,4,:)=[Gx,2*Lz,Gx];  % ZZm: (Gx,2*Lz,Gx)
InitStateArray(4,1,:)=[Gmy,Lmz,Gx];  % ZmX: (Gmy,Lmz,Gx)
InitStateArray(4,2,:)=[Gx,Lz,Gmy];   % ZmY: (Gx,Lz,Gmy)
InitStateArray(4,3,:)=[Gx,2*Lz,Gmx]; % ZmZ: (Gx,2*Lz,Gmx)
InitStateArray(4,4,:)=[Gx,NaN,Gx];   % ZmZm : (Gx,0,Gx) or (Gy,0,Gy)

% Gate Beams
dic.setNovatech('Red','freq',dic.SinglePass674freq+(dic.vibMode(Vmodes).freq-dic.GateInfo.GateDetuningkHz/1000),'amp',dic.GateInfo.RedAmp);
dic.setNovatech('Blue','freq',dic.SinglePass674freq-(dic.vibMode(Vmodes).freq-dic.GateInfo.GateDetuningkHz/1000),'amp',dic.GateInfo.BlueAmp);
% ground state cooling beam
dic.setNovatech('Echo','freq',dic.SinglePass674freq+dic.vibMode(Vmodes).freq+dic.acStarkShift674,'amp',1000);
% dic.setNovatech('Parity','freq',dic.SinglePass674freq,'amp',1000,'phase',dic.AddrInfo.P674Parity);
dic.setNovatech('DoublePassSecond','freq',dic.F674DoublePassCarrier-MMFreq/2,'amp',500);
dic.setNovatech('DoublePassCarrier','freq',dic.F674DoublePassCarrier,'amp',500);
dic.setNovatech('DoublePass','amp',1000);
InitLabel=['X','Y','Z','z'];
MeasuredLabel=['I','X','Y','Z'];
feedback=0;
for loopInd=1:loops
    disp(sprintf('taking PT # : %f.1',loopInd));
    InitInd=1;
    if scanRFnull
        OptimizeRFNullSecond('scantype',1);
    end
    while InitInd<=16
        InitInd1=floor((InitInd-1)/4)+1;
        InitInd2=mod(InitInd-1,4)+1;
        fprintf('Initialization state %s \n',[InitLabel(InitInd1) InitLabel(InitInd2)]);
        if dic.calibRfFlag
            RFResScanRamsey;
        end
        notMelted=1;
        for MeasureInd = 2:16
            MeasureInd1=floor((MeasureInd-1)/4)+1;
            MeasureInd2=mod(MeasureInd-1,4)+1;
%             fprintf('Measurement basis %s \n',[MeasuredLabel(MeasureInd1) MeasuredLabel(MeasureInd2)]);
            
            if dic.stop
                return;
            end
            pause(0.1);
            % Update doublepass frequency
            dic.setNovatech('DoublePass','freq',dic.updateF674+feedback);
            
            [r,fb]=experimentSequence(reshape(InitStateArray(InitInd1,InitInd2,:),1,[]),...
                                  reshape(MeasuredStateArray(MeasureInd1,MeasureInd2,:),1,[]));
            
            dic.GUI.sca(1); %get an axis from Dictator GUI to show data
            hist(r,0:1:(1.8*dic.maxPhotonsNumPerReadout));
            if mean(r.*(r<40))>2
                [iscrystal CurrentNotMelted]=CrystalCheckPMT;
                notMelted=notMelted*CurrentNotMelted;
            end
            histograms(InitInd,MeasureInd,:)=r;
            if DoFeedback
                AddLinePoint(feedbackLine,15*(InitInd-1)+MeasureInd-1,fb);
                feedback=feedback-(fb-50)*10e-7;
            end

            projector=(-1*sum( r<dic.IonThresholds(2)&r>dic.IonThresholds(1) )...
                +1*sum( r>dic.IonThresholds(2) )...
                +1*sum( r<dic.IonThresholds(1) ) )/length(r);
            switch MeasuredStateArray(MeasureInd1,MeasureInd2,4)
                case 1
                    projector=-projector;
                case 2 
                    projector=-projector;
            end
            plotPTMatrix((InitInd1-1)*5+MeasureInd1,(InitInd2-1)*5+MeasureInd2,loopInd)=projector;
            PTMatrix(InitInd,MeasureInd,loopInd)=projector;
            dic.GUI.sca(11);
            pcolor(1:20,1:20,plotPTMatrix(:,:,loopInd));shading flat;
            caxis([-1 1]);
            pause(1)
        end
        if notMelted 
            InitInd=InitInd+1;
        end
    end
    Chi=processTomographyAnalysis(PTMatrix(:,:,loopInd));
    disp(sprintf('II element = %f.2',Chi(1,1)));  
end
%--------------- Save data ------------------
showData='figure; pcolor(1:20,1:20,plotPTMatrix(:,:,loopInd));shading flat;caxis([-1 1]);';
dic.save;

%--------------------------------------------------------------------
    function [r,tmpdark]=experimentSequence(InitState,MeasuredState)
        prog=CodeGenerator;
        prog.GenDDSPullParametersFromBase;
        prog.GenSeq(Pulse('ExperimentTrigger',0,50));
%         prog.GenWaitExtTrigger;
        % set DDS freq and amp
        prog.GenSeq(Pulse('674DDS1Switch',2,-1,'freq',dic.SinglePass674freq,'amp',100,'phase',0));
        prog.GenSeq(Pulse('RFDDS2Switch',3,-1,'amp',dic.ampRF,'freq',dic.FRF,'phase',0));
        
        % Doppler coolng
        prog.GenSeq(Pulse('OffRes422',0,500));%turn off cooling
        prog.GenSeq(Pulse('OnResCooling',0,dic.Tcooling) );
        
        % Activate noise eater, move it to int hold and repump
        prog.GenSeq([Pulse('674DDS1Switch',2,15),... 
                     Pulse('NoiseEater674',3,13),Pulse('674DoublePass',0,18),...
                     Pulse('Repump1033',18,dic.T1033)]);
        
        % Ground state cooling using the echo pulse %
        if doGSC
            prog.GenSeq([Pulse('Repump1033',0,0), Pulse('OpticalPumping',0,0)]);
            % cooling the Stretch
            prog.GenSeq([Pulse('674DoublePass',0,dic.vibMode(Vmodes).coolingTime+4),... 
                         Pulse('674Echo',2,dic.vibMode(Vmodes).coolingTime)]);
            % cooling the COM
    %         prog.GenSeq([Pulse('674DoublePass',0,dic.vibMode(1).coolingTime+4),... 
    %                      Pulse('674Parity',2,dic.vibMode(1).coolingTime)]);
             prog.GenSeq([Pulse('Repump1033',dic.T1033,-1), Pulse('OpticalPumping',dic.T1033,-1)]);
        end
        % End of GSC 
        prog.GenSeq(Pulse('OpticalPumping',0,dic.Toptpump));
   
        % Input State Preparation 
        if ~isnan(InitState(1))
            prog.GenSeq(Pulse('RFDDS2Switch',1,dic.piHalfRF,'phase',InitState(1)));
        end
        if ~isnan(InitState(2))
            prog.GenSeq(Pulse('674DDS1Switch',1,dic.HiddingInfo.Tmm1,'phase',0));
            prog.GenSeq(Pulse('674DDS1Switch',1,dic.HiddingInfo.Tmm1,'phase',pi/2+(InitState(2)+1)/2*pi));
        end
        if ~isnan(InitState(3))
            prog.GenSeq(Pulse('RFDDS2Switch',1,dic.piHalfRF,'phase',InitState(3)));
        end

        
        if doMapping
            % Mapping on the optical qubit of the Zeeman one 
            prog.GenSeq([Pulse('674DDS1Switch',2,dic.T674,'phase',0),Pulse('674DoublePass',0,dic.T674+3)]);
            prog.GenSeq(Pulse('RFDDS2Switch',2,dic.TimeRF,'phase',0));
            
            % Gate
            if doGate
                prog.GenSeq(Pulse('674PulseShaper',0,-1));
                prog.GenPause(10);
                prog.GenSeq([Pulse('674Gate',1,dic.GateInfo.GateTime_mus),...
                    Pulse('674DoublePass',0,dic.GateInfo.GateTime_mus+2),...
                    Pulse('674PulseShaper',2,dic.GateInfo.GateTime_mus-10)]);
                prog.GenSeq(Pulse('674PulseShaper',0,0));
                prog.GenPause(20);
            else
                prog.GenSeq(Pulse('674PulseShaper',0,-1));
                prog.GenPause(10);
                prog.GenSeq(Pulse('674PulseShaper',2,dic.GateInfo.GateTime_mus-10));
                prog.GenSeq(Pulse('674PulseShaper',0,0));
                prog.GenPause(10);
            end
            
            % Mapping to the Zeeman qubit back
            prog.GenSeq(Pulse('RFDDS2Switch',2,dic.TimeRF,'phase',pi));
            prog.GenSeq([Pulse('674DDS1Switch',2,dic.T674,'phase',pi),Pulse('674DoublePass',0,dic.T674+3)]);
       end
        
        % Analysis Pulses 
        % Phase preparation after the state initialization
        if ~isnan(MeasuredState(1))
            prog.GenSeq(Pulse('RFDDS2Switch',0,dic.piHalfRF,'phase',MeasuredState(1)));
        end      
        if ~isnan(MeasuredState(2))
            % Perform local sigmaz rotation
            prog.GenSeq(Pulse('674DDS1Switch',0,dic.HiddingInfo.Tmm1,'phase',0));
            prog.GenSeq(Pulse('674DDS1Switch',0,dic.HiddingInfo.Tmm1,'phase',pi/2+(MeasuredState(2)+1)/2*pi));
        end
        % Second global g2 rotation
        if ~isnan(MeasuredState(3))
            prog.GenSeq(Pulse('RFDDS2Switch',0,dic.piHalfRF,'phase',MeasuredState(3)));
        end
        
        % Detection scheme
        switch MeasuredState(4)
            case 0 % Regular global shelving pulse
                prog.GenSeq([Pulse('674DDS1Switch',2,dic.T674),Pulse('674DoublePass',0,dic.T674+2)]);
            case 1 % Measureing the MM-ion and the rfnull-ion is always bright
                prog.GenSeq(Pulse('674DDS1Switch',2,dic.HiddingInfo.Tmm1));
            case 2 % Measureing the rfnull-ion and the MM-ion is always bright
                prog.GenSeq([Pulse('674DDS1Switch',2,dic.T674),...
                             Pulse('674DoublePass',1,dic.T674+2)]);
                prog.GenSeq(Pulse('674DDS1Switch',2,dic.HiddingInfo.Tmm1));
        end        
        prog.GenSeq([Pulse('OnRes422',0,dic.TDetection),... 
                     Pulse('PhotonCount',0,dic.TDetection)]);
        
        % ------another sequence for fast 674 freq  feedback------ 
        if DoFeedback
            prog.GenSeq(Pulse('OnResCooling',0,dic.Tcooling));
            prog.GenSeq(Pulse('OpticalPumping',0,dic.Toptpump));
            
            prog.GenSeq([Pulse('674DoublePass',0,dic.T674/2+2),...
                Pulse('674DDS1Switch',1,dic.T674/2,'phase',0)]);
            prog.GenPause(800);
            prog.GenSeq([Pulse('674DoublePass',0,dic.T674/2+2),...
                Pulse('674DDS1Switch',1,dic.T674/2,'phase',pi/2)]);
            
            prog.GenSeq([Pulse('OnRes422',0,dic.TDetection),...
                Pulse('PhotonCount',0,dic.TDetection)]);
        end
        
        
        % resume off-resonance cooling
        prog.GenSeq(Pulse('Repump1033',0,dic.T1033));
        prog.GenSeq(Pulse('OffRes422',0,0));
        prog.GenFinish;
        
        dic.com.UploadCode(prog);
        dic.com.UpdateFpga;
        dic.com.WaitForHostIdle; 
        dic.com.Execute(repetitions);
        dic.com.WaitForHostIdle;
        r = dic.com.ReadOut(repetitions*(1+DoFeedback));
        if DoFeedback
            y=r(2:2:end);
            r = r(3:2:end);
            tmpdark=0;
            for tmp=1:dic.NumOfIons
                tmpdark=tmpdark+sum((y>dic.IonThresholds(tmp))&(y<dic.IonThresholds(tmp+1)))*tmp;
            end
            tmpdark=100-tmpdark/length(y)/(dic.NumOfIons)*100;
        else
            r = r(2:end);
            tmpdark=0;
        end
    end

end
