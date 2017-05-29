function QuantumStateTomographyNew

dic=Dictator.me;


dic.calibRfFlag=1;

MMFreq=21.75;
doEcho=0;

repetitions=500;

DetuningSpinDown=(-2.802*1/2+1.68*3/2)*(dic.FRF/2.802);
   

% ------------Set GUI axes ---------------
cla(dic.GUI.sca(7));
InitializeAxes(dic.GUI.sca(1),'Photons #','Cases Counted #','Fluorescence Histogram',...
                [0 dic.maxPhotonsNumPerReadout],[],0);

% -------- Main function scan loops ------
dark = zeros(4);
spin=zeros(4);
x=0.1; %phase 0 for sx
histograms=zeros(4,4,repetitions-1);
vec=[1:4];
LightShift=-0.014;
dic.setNovatech('DoublePassSecond','freq',dic.updateF674+LightShift/2-DetuningSpinDown/2-MMFreq/2,'amp',1000);
dic.setNovatech('DoublePass','freq',dic.updateF674,'amp',1000);

for index1 = 1:4
    CrystalCheckPMT;
%     SigmaZCalibration;
    for index2=1:4
%            RFResScanRamsey;
        if dic.stop
            return
        end
%        pause(0.1);

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
        matrixindex=[index1 index2];

        StatePreparation=1;
        g1p=Gmy;
        lzp=0;
        g2p=0;
        
        % Tomographic dictionnary
        
        % XX : (Gmy,0,0)
        % YY : (Gx,0,0)   
        % ZZ : (0,0,0)   
        % ZmZm : (Gx,0,Gx) or (Gy,0,Gy)   
        
        
        % XY: (Gx,Lz,0)
        % YX: (Gmy,Lmz,0)
        
        % XZ: (Gx,Lz,Gmx)   
        % XZm: (Gx,Lz,Gx)    
        
        % ZX: (Gmy,Lmz,Gmx) 
        % ZmX: (Gmy,Lmz,Gx) 
        
        % YZ: (Gmy,Lmz,Gy)  
        % YZm :(Gmy,Lmz,Gmy) 
        
        % ZY: (Gx,Lz,Gy)  
        % ZmY: (Gx,Lz,Gmy)  
        
        if isequal(matrixindex,[1 1])
            StatePreparation=0;
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
            spin(index1,index2)=1; % Trace constraint on the density matrix
        else
            dic.GUI.sca(1); %get an axis from Dictator GUI to show data
            hist(r,0:1:(1.8*dic.maxPhotonsNumPerReadout));
            ivec=dic.IonThresholds;
            histograms(index1,index2,:)=r;
            
            tmpdark=0;
            for tmp=1:dic.NumOfIons
                tmpdark=tmpdark+sum((r>ivec(tmp))&(r<ivec(tmp+1)))*tmp;
            end
            tmpdark=100-tmpdark/length(r)/(dic.NumOfIons)*100;
            dark(index1,index2)=tmpdark;
            
            
            % Counting according to the CountStat
            switch CountStat
                case 0
                    % regular two ion statistics
                    spin(index1,index2)=(-1*sum((r<dic.IonThresholds(2))&r>dic.IonThresholds(1))+1*sum(r>dic.IonThresholds(2))+1*sum(r<dic.IonThresholds(1)))/length(r);
                case 1
                    % one is hidden.
                    % central blob is the proportional for the visible ion to be
                    % down
                    spin(index1,index2)=(-1*sum((r<dic.IonThresholds(2))&r>dic.IonThresholds(1))+1*sum(r>dic.IonThresholds(2))+1*sum(r<dic.IonThresholds(1)))/length(r);
            end
        end
    end

end
spin

dic.GUI.sca(11);
imagesc(vec,vec,spin);
axis([0.5 4.5 0.5 4.5]);
caxis([-1 1]);colorbar;
ylabel('x'); xlabel('y'); title('Density Matrix Projections');

%--------------- Save data ------------------

showData='figure;plot(ScanParameter,dark);xlabel(''Pulse Time[\mus]'');ylabel(''dark[%]'');';
dic.save;


%% --------------------------------------------------------------------
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
        
        if StatePreparation
            if g1p~=0
                prog.GenSeq(Pulse('RFDDS2Switch',1,dic.piHalfRF,'phase',g1p));
            end
            if lzp~=0
                prog.GenSeq([Pulse('674DDS1Switch',5,dic.HiddingInfo.Tmm1','phase',0)]);                                
                prog.GenSeq([Pulse('674DDS1Switch',1,dic.HiddingInfo.Tmm1,'phase',pi/2-1/2*(lzp-1)*pi)]);
            end
            if g2p~=0
                prog.GenSeq(Pulse('RFDDS2Switch',1,dic.piHalfRF,'phase',g2p));
            end
        end
        
        % Phase preparation after the state initialization
        if g1~=0
            prog.GenSeq(Pulse('RFDDS2Switch',1,dic.piHalfRF,'phase',g1));
        end
        
%         %takes time to initialize phase, so it is done here.
%         if g2~=0
%             prog.GenSeq(Pulse('RFDDS2Switch',3,-1,'phase',g2));
%         end
        
        if lz~=0     
            % Perform local sigmaz rotation
            prog.GenSeq([Pulse('674DDS1Switch',5,dic.HiddingInfo.Tmm1','phase',0)]);
            prog.GenSeq([Pulse('674DDS1Switch',1,dic.HiddingInfo.Tmm1,'phase',dic.HiddingInfo.PhaseHide-pi/2-1/2*(lz-1)*pi)]);            
        end
        
        if doEcho&((g1~=0)||(g2~=0))&(lz~=0)
            prog.GenSeq(Pulse('RFDDS2Switch',2,dic.TimeRF));% echo Pulse
            prog.GenPause(dic.HiddingInfo.Tmm1);
            prog.GenSeq(Pulse('RFDDS2Switch',2,dic.TimeRF));% echo Pulse
            prog.GenPause(dic.HiddingInfo.Tmm1);
        end

        
        % Second global g2 rotation
        if g2~=0
            prog.GenSeq(Pulse('RFDDS2Switch',1,dic.piHalfRF,'phase',g2));
        end
        
        switch shelvingstyle
            case 0 % Regular global shelving pulse
                prog.GenSeq([Pulse('674DDS1Switch',1,dic.T674),Pulse('674DoublePass',0,dic.T674+1)]);
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
