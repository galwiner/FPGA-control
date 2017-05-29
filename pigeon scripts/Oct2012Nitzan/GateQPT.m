function GateQPT

dic=Dictator.me;


dic.calibRfFlag=1;

MMFreq=21.75;
doEcho=0;

doGSC=1;
doGate=1;
doIdentity=0;

% ZeemanMappingTime=dic.T674;
ZeemanMappingTime=dic.T674;

repetitions=200;

DetuningSpinDown=(-2.802*1/2+1.68*3/2)*(dic.FRF/2.802);

Vmodes=1;

% ------------Set GUI axes ---------------
InitializeAxes(dic.GUI.sca(1),'Photons #','Cases Counted #','Fluorescence Histogram',...
                [0 dic.maxPhotonsNumPerReadout],[],0);

% -------- Main function scan loops ------
dark = zeros(4,4,16);
spin=zeros(4,4,16);
x=0.1; %phase 0 for sx
histograms=zeros(4,4,16,repetitions-1);
vec=[1:4];
CrystalCheckPMT;
for indexin=1:16

%     indexin=11; 
    
    fprintf('Matrix %2.0f/16\n',indexin);
    
%     if mod(indexin-1,2)==0
%         L674TransitionsCalibrationNewAge;
%     end
    
    
    % measure the density matrix in the basis "sigma1 x sigma2'
    % experimentSequence takes argument (G1,Lz,G2,ShelvingStyle)
    % = G1: global rotation of chosen axis, values 'Gx/Gmx/Gy/Gmy'. If 0,
    % don't do.
    % = Lz: local sigmaz rotation, binary variable
    % = G2 : second global rotation, same values as G1
    
    % = Shelving Style : 0 regular shelving, 1 only hiding shelving, 2
    % both
    % CountingStatistics : 0 regular (2 ion), 1 single ion dark
    %non-zero value, so that if first argument is zero, then dont do Gx
    Gx=x;Gmx=x+pi;Gy=x+pi/2;Gmy=x+3*pi/2;Lz=1;Lmz=-1;
    
    StatePreparation=1;
    % Tomographic dictionnay
    switch indexin
        case 1         % XX : (Gmy,0,0)
            g1p=Gmy;lzp=0;g2p=0;
        case 2         % XY: (Gx,Lz,0)
            g1p=Gx;lzp=Lz;g2p=0;
        case 3         % XZ: (Gx,Lz,Gmx)
            g1p=Gx;lzp=Lz;g2p=Gmx;
        case 4        % XZm: (Gx,Lz,Gx)
            g1p=Gx;lzp=Lz;g2p=Gx;
        case 5        % YX: (Gmy,Lmz,0)
            g1p=Gmy;lzp=Lmz;g2p=0;
        case 6        % YY : (Gx,0,0)
            g1p=Gx;lzp=0;g2p=0;
        case 7        % YZ: (Gmy,Lmz,Gy)
            g1p=Gmy;lzp=Lmz;g2p=Gy;
        case 8        % YZm :(Gmy,Lmz,Gmy)
            g1p=Gmy;lzp=Lmz;g2p=Gmy;
        case 9        % ZX: (Gmy,Lmz,Gmx)
            g1p=Gmy;lzp=Lmz;g2p=Gmx;
        case 10        % ZY: (Gx,Lz,Gy)
            g1p=Gx;lzp=Lz;g2p=Gy;
        case 11        % ZZ : (0,0,0)
            g1p=0;lzp=0;g2p=0;
        case 12        % ZZm: (Gx,2*Lz,Gx)
            g1p=Gx;lzp=2*Lz;g2p=Gx;
        case 13        % ZmX: (Gmy,Lmz,Gx)
            g1p=Gmy;lzp=Lmz;g2p=Gx;
        case 14        % ZmY: (Gx,Lz,Gmy)
            g1p=Gx;lzp=Lz;g2p=Gmy;
        case 15        % ZmZ: (Gx,2*Lz,Gmx)
            g1p=Gx;lzp=2*Lz;g2p=Gmx;
        case 16        % ZmZm : (Gx,0,Gx) or (Gy,0,Gy)
            g1p=Gx;lzp=0;g2p=Gx;
    end
    
    for index1 = 1:4
        %         SigmaZCalibration;
            CrystalCheckPMT;

        for index2=1:4
            %             RFResScanRamsey;
            
            if dic.stop
                return;
            end
            pause(0.1);
            
            matrixindex=[index1 index2];
            
            % QST Beams
            LightShift=-0.014;
            dic.setNovatech('DoublePassSecond','freq',dic.updateF674+LightShift/2-DetuningSpinDown/2-MMFreq/2,'amp',1000);
            dic.setNovatech('DoublePass','freq',dic.updateF674,'amp',1000);
            % Gate Beams
            SBoffset=-0.0/1000;
            dic.setNovatech('Red','freq',dic.SinglePass674freq-SBoffset+(dic.vibMode(Vmodes).freq-dic.GateInfo.GateDetuningkHz/1000),'amp',dic.GateInfo.RedAmp);
            dic.setNovatech('Blue','freq',dic.SinglePass674freq-SBoffset-(dic.vibMode(Vmodes).freq-dic.GateInfo.GateDetuningkHz/1000),'amp',dic.GateInfo.BlueAmp);
            % Beam for the Zeeman mapping
            dic.setNovatech('Echo','freq',dic.SinglePass674freq-SBoffset,'amp',1000,'phase',dic.AddrInfo.P674Echo);
            dic.setNovatech('Parity','freq',dic.SinglePass674freq-SBoffset,'amp',1000);
            if isequal(matrixindex,[1 1])
                %             r=experimentSequence(0,0,0,0);CountStat=0;
                %             spin(index1,index2)=1;
            elseif isequal(matrixindex,[1 2])  %%% CHECKED
                r=experimentSequence(Gy,0,0,2);CountStat=1;
            elseif isequal(matrixindex,[1 3]) %CHECKED%
                r=experimentSequence(Gmx,0,0,2);CountStat=1;
            elseif isequal(matrixindex,[1 4]) %% CHECKED
                r=experimentSequence(0,0,0,2);CountStat=1;
                
            elseif isequal(matrixindex,[2 1]) %% CHECKED %
                r=experimentSequence(Gy,0,0,1);CountStat=1;
            elseif isequal(matrixindex,[3 1]) %% CHECKED
                r=experimentSequence(Gmx,0,0,1);CountStat=1;
            elseif isequal(matrixindex,[4 1]) %% CHECKED
                r=experimentSequence(0,0,0,1);CountStat=1;
                
            elseif isequal(matrixindex,[2 2])  % CHECKED
                r=experimentSequence(Gy,0,0,0);CountStat=0;
            elseif isequal(matrixindex,[3 3]) % CHECKED
                r=experimentSequence(Gmx,0,0,0);CountStat=0;
            elseif isequal(matrixindex,[4 4])
                r=experimentSequence(0,0,0,0);CountStat=0;
                
            elseif isequal(matrixindex,[2 3]) %% CHECKED %%
                r=experimentSequence(0,Lmz,Gmx,0);CountStat=0;
            elseif isequal(matrixindex,[3 2])%% CHECKED %%
                r=experimentSequence(0,Lz,Gy,0);CountStat=0;
            elseif isequal(matrixindex,[2 4]) %%% CHECKED?
                r=experimentSequence(Gx,Lmz,Gmx,0);CountStat=0;
            elseif isequal(matrixindex,[4 2]) %% CHECKED
                r=experimentSequence(Gx,Lz,Gy,0);CountStat=0;
            elseif isequal(matrixindex,[3 4]) %%   CHECKED
                r=experimentSequence(Gmy,Lz,Gy,0);CountStat=0;
            elseif isequal(matrixindex,[4 3]) % CHECKED
                r=experimentSequence(Gmy,Lmz,Gmx,0);CountStat=0;
            end
            
            if ((index1==1)&(index2==1))
                spin(index1,index2,indexin)=1; % Trace constraint on the density matrix
            else
                dic.GUI.sca(1); %get an axis from Dictator GUI to show data
                hist(r,0:1:(1.8*dic.maxPhotonsNumPerReadout));
                ivec=dic.IonThresholds;
                histograms(index1,index2,indexin,:)=r;
                
                tmpdark=0;
                for tmp=1:dic.NumOfIons
                    tmpdark=tmpdark+sum((r>ivec(tmp))&(r<ivec(tmp+1)))*tmp;
                end
                tmpdark=100-tmpdark/length(r)/(dic.NumOfIons)*100;
                dark(index1,index2,indexin)=tmpdark;
                darktoplot=dark(:,:,indexin);
                
                % Counting according to the CountStat
                switch CountStat
                    case 0
                        % regular two ion statistics
                        spin(index1,index2,indexin)=(-1*sum((r<dic.IonThresholds(2))&r>dic.IonThresholds(1))+1*sum(r>dic.IonThresholds(2))+1*sum(r<dic.IonThresholds(1)))/length(r);
                    case 1
                        % one is hidden.
                        % central blob is the proportional for the visible ion to be
                        % down
                        spin(index1,index2,indexin)=(-1*sum((r<dic.IonThresholds(2))&r>dic.IonThresholds(1))+1*sum(r>dic.IonThresholds(2))+1*sum(r<dic.IonThresholds(1)))/length(r);
                end
                spintoplot=spin(:,:,indexin);
            end
        end
        %         dic.GUI.sca(7);
        %         imagesc(vec,vec,darktoplot);
        %         axis([min(vec) max(vec) min(vec) max(vec)]);
        %         colorbar;
        %         ylabel('x'); xlabel('y'); title('Dark Counts');
        
        dic.GUI.sca(11);
        imagesc(vec,vec,spintoplot);
        axis([min(vec) max(vec) min(vec) max(vec)]);
        colorbar;
        ylabel('x'); xlabel('y'); title('Density Matrix Projections');
        pause(1)
    end
    spin(:,:,indexin)
    pause(2)    
    dic.ExtractAxesToFigure(11);
end


%--------------- Save data ------------------
showData='figure;plot(ScanParameter,dark);xlabel(''Pulse Time[\mus]'');ylabel(''dark[%]'');';
dic.save;
dic.calibRfFlag=0;


%--------------------------------------------------------------------
    function r=experimentSequence(g1,lz,g2,shelvingstyle)
        prog=CodeGenerator;
        prog.GenDDSPullParametersFromBase;
        prog.GenSeq(Pulse('ExperimentTrigger',0,50));
        %          prog.GenWaitExtTrigger;
        % set DDS freq and amp
        prog.GenSeq(Pulse('674DDS1Switch',2,-1,'freq',dic.SinglePass674freq,'amp',100,'phase',0));
        prog.GenSeq(Pulse('RFDDS2Switch',3,-1,'amp',dic.ampRF,'freq',dic.FRF,'phase',max(g1,x)));
        
        % Doppler coolng
        prog.GenSeq(Pulse('OffRes422',0,500));%turn off cooling
        prog.GenSeq(Pulse('OnResCooling',0,dic.Tcooling) );
        
        prog.GenSeq([Pulse('674DDS1Switch',0,15),... %Echo is our choice for NE calib
            Pulse('NoiseEater674',2,10),Pulse('674DoublePass',0,15),...
            Pulse('Repump1033',15,dic.T1033),...
            Pulse('OpticalPumping',16+dic.T1033,dic.Toptpump)]);
        
        %%%%%%%%%%%% GSC %%%%%%%%%%%%%%%%%%
        if doGSC
            % GSC
            SeqGSC=[]; N=1; Tstart=2;
            Mode2Cool=Vmodes;
            if (~isempty(Mode2Cool))
                for mode=Mode2Cool
                    SeqGSC=[SeqGSC,Pulse('674DoublePass',Tstart,dic.vibMode(mode).coolingTime/N),...
                        Pulse('674DDS1Switch',Tstart,dic.vibMode(mode).coolingTime/N,...
                        'freq',dic.SinglePass674freq+dic.vibMode(mode).freq+dic.acStarkShift674)];
                    
                    Tstart=2+Tstart+dic.vibMode(mode).coolingTime/N;
                end
                prog.GenSeq([Pulse('Repump1033',0,0), Pulse('OpticalPumping',0,0)]);
                prog.GenRepeatSeq(SeqGSC,N);
                prog.GenSeq([Pulse('Repump1033',dic.T1033,-1), Pulse('OpticalPumping',dic.T1033,-1)]);
                %             % pulsed GSC
                %             for mode=fliplr(Mode2Cool)
                %                 prog.GenRepeatSeq([Pulse('674DoublePass',2,dic.vibMode(mode).coldPiTime),...
                %                     Pulse('674DDS1Switch',2,dic.vibMode(mode).coldPiTime,'freq',dic.SinglePass674freq+dic.vibMode(mode).freq),...
                %                     Pulse('Repump1033',dic.vibMode(mode).coldPiTime,dic.T1033),...
                %                     Pulse('OpticalPumping',dic.vibMode(mode).coldPiTime+dic.T1033,dic.Toptpump)],2);
                %             end
            end
            prog.GenSeq(Pulse('674DDS1Switch',2,-1,'freq',dic.SinglePass674freq,'amp',100,'phase',0));
            prog.GenSeq(Pulse('OpticalPumping',0,dic.Toptpump));
        end
        %%%% End of GSC %%%%%%%%%%
        
        
        %%% Input State Preparation %%%
        if StatePreparation
            if g1p~=0
                prog.GenSeq(Pulse('RFDDS2Switch',0,dic.piHalfRF,'phase',g1p));
            end
            if lzp~=0
                prog.GenSeq([Pulse('674DDS1Switch',0,dic.HiddingInfo.Tmm1,'phase',0)]);
                prog.GenSeq([Pulse('674DDS1Switch',0,dic.HiddingInfo.Tmm1,'phase',pi/2-(lzp-1)/2*pi)]);
            end
            if g2p~=0
                prog.GenSeq(Pulse('RFDDS2Switch',0,dic.piHalfRF,'phase',g2p));
            end
        end
        
        if ~doIdentity
            %%% Mapping on the optical qubit of the Zeeman one %%
            prog.GenSeq([Pulse('674Parity',1,ZeemanMappingTime),Pulse('674DoublePass',0,ZeemanMappingTime+1)]);
            prog.GenSeq([Pulse('RFDDS2Switch',0,dic.TimeRF,'phase',0)]);
            
            %%%% Gate %%%
            if doGate
                prog.GenSeq([Pulse('674Gate',1,dic.GateInfo.GateTime_mus),Pulse('674DoublePass',0,dic.GateInfo.GateTime_mus+1)]);
            else
                prog.GenPause(dic.GateInfo.GateTime_mus);
            end
            
            % Mapping to the Zeeman qubit back
            prog.GenSeq([Pulse('RFDDS2Switch',0,dic.TimeRF,'phase',0)]);
            prog.GenSeq([Pulse('674Echo',1,ZeemanMappingTime),Pulse('674DoublePass',0,ZeemanMappingTime+1)]);
        end
        
        %%%% Analysis Pulses %%%%
        % Phase preparation after the state initialization
        if g1~=0
            prog.GenSeq(Pulse('RFDDS2Switch',0,dic.piHalfRF,'phase',g1));
        end
        
        if lz~=0
            % Perform local sigmaz rotation
            prog.GenSeq([Pulse('674DDS1Switch',0,dic.HiddingInfo.Tmm1,'phase',0)]);
            prog.GenSeq([Pulse('674DDS1Switch',0,dic.HiddingInfo.Tmm1,'phase',pi/2-(lz-1)/2*pi)]);
            
        end
        % Second global g2 rotation
        if g2~=0
            prog.GenSeq(Pulse('RFDDS2Switch',0,dic.piHalfRF,'phase',g2));
        end
        %%%%%%%%%%%%%%%%
        switch shelvingstyle
            case 0 % Regular global shelving pulse
                prog.GenSeq([Pulse('674DDS1Switch',2,dic.T674),Pulse('674DoublePass',0,dic.T674+2)]);
            case 1 % Single ion shelving
                prog.GenSeq([Pulse('674DDS1Switch',2,dic.HiddingInfo.Tmm1)]);
            case 2 % Single ion + global shelving
                prog.GenSeq([Pulse('674DDS1Switch',2,dic.HiddingInfo.Tmm1)]);
                prog.GenSeq([Pulse('674DDS1Switch',2,dic.T674),Pulse('674DoublePass',0,dic.T674+2)]);
        end
        
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
