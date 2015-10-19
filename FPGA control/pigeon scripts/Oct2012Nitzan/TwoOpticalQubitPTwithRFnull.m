function TwoOpticalQubitPTwithRFnull

dic=Dictator.me;
MMFreq=21.75;
dic.calibRfFlag=1;
LightShift=0.000;
Vmodes=2;
repetitions=400;

doGSC=1;
doGate=1;
DoFeedback=1;
loops=1;

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

Cpi=dic.T674;
CpiHalf=dic.T674/2;

MMpi=dic.HiddingInfo.Tmm1;
MMpiHalf=dic.HiddingInfo.Tmm1/2;

Gx=[CpiHalf,0];
Gmy=[CpiHalf,3*pi/2];
GxPi=[Cpi,0];
Lx=[MMpiHalf,0];
Lmx=[MMpiHalf,pi];
Ly=[MMpiHalf,pi/2];
Lmy=[MMpiHalf,3*pi/2];
LxPi=[MMpi,0];

%---------- measured states dictionnay -------------------
MeasuredStateArray=zeros(4,4,5); %[G_time,G_phase,L_time,L_phase, Detection]
                                                            %null-MM
MeasuredStateArray(1,1,:)=[0,0,0,0,0];                      %I I 
MeasuredStateArray(1,2,:)=[Gmy(1),Gmy(2),0,0,2];            %I X
MeasuredStateArray(1,3,:)=[Gx(1),Gx(2),0,0,2];              %I Y
MeasuredStateArray(1,4,:)=[0,0,0,0,2];                      %I Z
MeasuredStateArray(2,1,:)=[Gmy(1),Gmy(2),0,0,1];            %X I
MeasuredStateArray(2,2,:)=[Gmy(1),Gmy(2),0,0,0];            %X X
MeasuredStateArray(2,3,:)=[Gmy(1),Gmy(2),Lx(1),Lx(2),0];    %X Y
MeasuredStateArray(2,4,:)=[Gmy(1),Gmy(2),Ly(1),Ly(2),0];    %X Z
MeasuredStateArray(3,1,:)=[Gx(1),Gx(2),0,0,1];              %Y I
MeasuredStateArray(3,2,:)=[Gx(1),Gx(2),Lmy(1),Lmy(2),0];    %Y X
MeasuredStateArray(3,3,:)=[Gx(1),Gx(2),0,0,0];              %Y Y
MeasuredStateArray(3,4,:)=[Gx(1),Gx(2),Lmx(1),Lmx(2),0];    %Y Z
MeasuredStateArray(4,1,:)=[0,0,0,0,1];                      %Z I
MeasuredStateArray(4,2,:)=[0,0,Lmy(1),Lmy(2),0];            %Z X
MeasuredStateArray(4,3,:)=[0,0,Lx(1),Lx(2),0];              %Z Y
MeasuredStateArray(4,4,:)=[0,0,0,0,0];                      %Z Z

%---------- Initial states dictionnay -------------------
InitStateArray=zeros(4,4,4);                            %null-MM
InitStateArray(1,1,:)=[0,0,Gmy(1),Gmy(2)];              % X X 
InitStateArray(1,2,:)=[Lx(1),Lx(2),Gmy(1),Gmy(2)];  	% X Y 
InitStateArray(1,3,:)=[Lmy(1),Lmy(2),Gmy(1),Gmy(2)];    % X Z 
InitStateArray(1,4,:)=[Ly(1),Ly(2),Gmy(1),Gmy(2)];      % X Zm
InitStateArray(2,1,:)=[Lmy(1),Lmy(2),Gx(1),Gx(2)];      % Y X
InitStateArray(2,2,:)=[0,0,Gx(1),Gx(2)];                % Y Y 
InitStateArray(2,3,:)=[Lx(1),Lx(2),Gx(1),Gx(2)];        % Y Z
InitStateArray(2,4,:)=[Lmx(1),Lmx(2),Gx(1),Gx(2)];      % Y Zm
InitStateArray(3,1,:)=[Lmy(1),Lmy(2),GxPi(1),GxPi(2)];  % Z X
InitStateArray(3,2,:)=[Lmx(1),Lmx(2),GxPi(1),GxPi(2)];  % Z Y
InitStateArray(3,3,:)=[0,0,GxPi(1),GxPi(2)];            % Z Z
InitStateArray(3,4,:)=[LxPi(1),LxPi(2),GxPi(1),GxPi(2)];% Z Zm
InitStateArray(4,1,:)=[Lmy(1),Lmy(2),0,0];              % Zm X 
InitStateArray(4,2,:)=[Lx(1),Lx(2),0,0];                % Zm Y 
InitStateArray(4,3,:)=[LxPi(1),LxPi(2),0,0];            % Zm Z 
InitStateArray(4,4,:)=[0,0,0,0];                        % Zm Zm: 

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
%      OptimizeRFNullSecond('ScanType',1);
    while InitInd<=16
        InitInd1=floor((InitInd-1)/4)+1;
        InitInd2=mod(InitInd-1,4)+1;
        fprintf('Initialization state %s \n',[InitLabel(InitInd1) InitLabel(InitInd2)]);
        for MeasureInd = 2:16
            MeasureInd1=floor((MeasureInd-1)/4)+1;
            MeasureInd2=mod(MeasureInd-1,4)+1;
%           fprintf('Measurement basis %s \n',[MeasuredLabel(MeasureInd1) MeasuredLabel(MeasureInd2)]);
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
                CrystalCheckPMT;
            end
            if (length(r)==repetitions-1)
                histograms(InitInd,MeasureInd,:)=r;
            end
            if DoFeedback
                AddLinePoint(feedbackLine,15*(InitInd-1)+MeasureInd-1,fb);
                feedback=feedback-(fb-50)*10e-7;
            end

            projector=(-1*sum( r<dic.IonThresholds(2)&r>dic.IonThresholds(1) )...
                +1*sum( r>dic.IonThresholds(2) )...
                +1*sum( r<dic.IonThresholds(1) ) )/length(r);
            if MeasuredStateArray(MeasureInd1,MeasureInd2,5)>0
                projector=-projector;
            end
            plotPTMatrix((InitInd1-1)*5+MeasureInd1,(InitInd2-1)*5+MeasureInd2,loopInd)=projector;
            PTMatrix(InitInd,MeasureInd,loopInd)=projector;
            dic.GUI.sca(11);
            pcolor(1:20,1:20,plotPTMatrix(:,:,loopInd));shading flat;
            %         axis([0.5 16.5 0.5 16.5]);
            caxis([-1 1]);
            %         ylabel('x'); xlabel('y'); title('Density Matrix Projections');
            pause(1)
        end
        [iscrystal notMelted]=CrystalCheckPMT;
        if notMelted 
            InitInd=InitInd+1;
        end
    end
    Chi=processTomographyAnalysis(PTMatrix(:,:,loopInd));
    disp(sprintf('II element = %.2f',Chi(1,1)));  
end
%--------------- Save data ------------------
showData='figure; pcolor(1:20,1:20,plotPTMatrix(:,:,loopInd));shading flat;caxis([-1 1]);';
dic.save;

%--------------------------------------------------------------------
    function [r,tmpdark]=experimentSequence(InitState,MeasuredState)
        prog=CodeGenerator;
        prog.GenDDSPullParametersFromBase;
        % set DDS freq and amp
        prog.GenSeq(Pulse('ExperimentTrigger',0,50));
        % Doppler coolng
        prog.GenSeq(Pulse('OffRes422',0,1));%turn off cooling
        prog.GenSeq(Pulse('OnResCooling',10,dic.Tcooling));
        
        prog.GenSeq(Pulse('RFDDS2Switch',2,-1,'freq',dic.FRF,'amp',dic.ampRF));
        prog.GenSeq(Pulse('674DDS1Switch',2,-1,'freq',dic.SinglePass674freq,'amp',100,'phase',0));        
        
        %activate noise eater, move it to int hold and repump
        prog.GenSeq([Pulse('674DDS1Switch',2,20),...
            Pulse('NoiseEater674',3,15),Pulse('674DoublePass',0,23),...
            Pulse('Repump1033',23,dic.T1033),...
            Pulse('OpticalPumping',23+dic.T1033,dic.Toptpump)]);
        
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
        if InitState(1)>0 % local rotation on the MM ion
            prog.GenSeq(Pulse('674DDS1Switch',2,InitState(1),'phase',InitState(2)));
        end
        if InitState(3)>0 % Global rotation on both ion
            prog.GenSeq([Pulse('674DDS1Switch',1,InitState(3),'phase',InitState(4)),...
                         Pulse('674DoublePass',0,InitState(3)+2)]);
        end
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

        % Analysis Pulses
        if MeasuredState(1)>0 % Global rotation on both ion
            prog.GenSeq([Pulse('674DDS1Switch',1,MeasuredState(1),'phase',MeasuredState(2)),...
                         Pulse('674DoublePass',0,MeasuredState(1)+2)]);
        end
        if MeasuredState(3)>0 % local rotation on the MM ion
            prog.GenSeq(Pulse('674DDS1Switch',2,MeasuredState(3),'phase',MeasuredState(4)));
        end
        
%         prog.GenSeq([Pulse('674DDS1Switch',1,20,'phase',10),...
%                      Pulse('674DoublePass',0,20+2)]);
        % Detection scheme
        switch MeasuredState(5)
            case 0 % Measure both ions 
                   % DONT do anything,  we use optical qubit
            case 1 % measure the rfnull-ion by making the MM-ion bright
                prog.GenSeq(Pulse('RFDDS2Switch',1,dic.TimeRF));
                prog.GenSeq(Pulse('674DDS1Switch',2,dic.HiddingInfo.Tmm1));
            case 2 % measure MM-ion by making the rfnull-ion bright
                prog.GenSeq(Pulse('RFDDS2Switch',1,dic.TimeRF));
                prog.GenSeq([Pulse('674DDS1Switch',1,dic.T674),...
                             Pulse('674DoublePass',0,dic.T674+2)]);
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
