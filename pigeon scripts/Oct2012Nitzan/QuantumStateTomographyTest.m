function QuantumStateTomographyTest

dic=Dictator.me;



doEcho=0;

repetitions=400;

DetuningSpinDown=(-2.802*1/2+1.68*3/2)*(dic.FRF/2.802);

novatechAmp1=363;novatechAmp2=1000;
CrystalCheckPMT;
LightShift=14.5;
dic.setNovatech('Echo','freq',dic.SinglePass674freq-dic.MMFreq,'amp',novatechAmp2);
dic.setNovatech('Parity','freq',dic.SinglePass674freq-dic.MMFreq+DetuningSpinDown+LightShift/1000,'amp',novatechAmp2);
dic.setNovatech('Blue','freq',dic.SinglePass674freq,'amp',novatechAmp1);
dic.setNovatech('Red','freq',dic.SinglePass674freq+DetuningSpinDown+LightShift/1000,'amp',novatechAmp2);
   

% ------------Set GUI axes ---------------
cla(dic.GUI.sca(7));
InitializeAxes(dic.GUI.sca(1),'Photons #','Cases Counted #','Fluorescence Histogram',...
                [0 dic.maxPhotonsNumPerReadout],[],0);

% lines =InitializeAxes (dic.GUI.sca(6),...
%     'Pi Phase','Dark Counts %','Rabi Scan',...
%     [piPhase(1) piPhase(end)],[minvalue maxvalue],2);
% grid(dic.GUI.sca(6),'on');
% set(lines(1),'Marker','.','MarkerSize',10,'Color','b');
% set(lines(2),'Marker','.','MarkerSize',10,'Color','r');

% -------- Main function scan loops ------
dark = zeros(4);
spin=zeros(4);
vec=[1:4];
dic.setNovatech('DoublePass','freq',dic.updateF674,'amp',1000);
for index1 = 1:4
    CrystalCheckPMT;
    for index2=1:4
%     set(lines(1),'XData',[],'YData',[]);
        if dic.stop
            return
        end
        pause(0.1);

        % measure the density matrix in the basis "sigma1 x sigma2'
        [r hiddenIon]=experimentSequence(index1,index2);
        
        dic.GUI.sca(1); %get an axis from Dictator GUI to show data
        hist(r,0:1:(1.8*dic.maxPhotonsNumPerReadout));
        ivec=dic.IonThresholds;
        tmpdark=0;
        for tmp=1:dic.NumOfIons
            tmpdark=tmpdark+sum((r>ivec(tmp))&(r<ivec(tmp+1)))*tmp;
        end
        tmpdark=100-tmpdark/length(r)/(dic.NumOfIons)*100;
        dark(index1,index2)=tmpdark;
        % correction for hiddenIon
        if hiddenIon==0
            spin(index1,index2)=(-1*sum((r<dic.IonThresholds(2))&r>dic.IonThresholds(1))+1*sum(r>dic.IonThresholds(2))+1*sum(r<dic.IonThresholds(1)))/length(r);
        else
            spin(index1,index2)=(-1*sum(r<dic.IonThresholds(1))+1*sum(((r>dic.IonThresholds(1))&(r<dic.IonThresholds(2)))))/length(r);
        end
    end
    dic.GUI.sca(7);
    imagesc(vec,vec,dark);
    axis([min(vec) max(vec) min(vec) max(vec)]);
    colorbar;
    ylabel('x'); xlabel('y'); title('Dark Counts');
    
end

dic.GUI.sca(11);
imagesc(vec,vec,spin);
axis([min(vec) max(vec) min(vec) max(vec)]);
colorbar;
ylabel('x'); xlabel('y'); title('Density Matrix Projections');
spin

%--------------- Save data ------------------

showData='figure;plot(ScanParameter,dark);xlabel(''Pulse Time[\mus]'');ylabel(''dark[%]'');';
dic.save;


%--------------------------------------------------------------------
    function [r hidden]=experimentSequence(sigma1,sigma2)
        prog=CodeGenerator;
        prog.GenDDSPullParametersFromBase;
        prog.GenSeq(Pulse('ExperimentTrigger',0,50));
        % prog.GenWaitExtTrigger;
        % set DDS freq and amp
        prog.GenSeq(Pulse('674DDS1Switch',0,-1,'freq',dic.SinglePass674freq-2*DetuningSpinDown,'amp',100,'phase',0));
        prog.GenSeq(Pulse('RFDDS2Switch',3,-1,'amp',dic.ampRF,'freq',dic.FRF,'phase',0));

        % Doppler coolng
        prog.GenSeq(Pulse('OffRes422',0,500));%turn off cooling
        prog.GenSeq(Pulse('OnResCooling',0,dic.Tcooling) );

        prog.GenSeq([Pulse('674Echo',0,15),... % NoiseEater Initialization
                Pulse('NoiseEater674',2,10),Pulse('674DoublePass',0,15),...
                Pulse('Repump1033',15,dic.T1033),...
                Pulse('OpticalPumping',16+dic.T1033,dic.Toptpump)]);
                
        prog.GenSeq(Pulse('OpticalPumping',10,dic.Toptpump));
        ZeemanPiTime=dic.piHalfRF;   

         prog.GenSeq(Pulse('RFDDS2Switch',0,dic.TimeRF));
        
        hidden=0;
        if sigma1==1
            hidden=1;
            if sigma2~=1
                if sigma2<4
                    % MEASUREMENT OF 1 x SIGMAX or 1 x SIGMA Y
                    % global sigmaX or sigmaY
                    prog.GenSeq(Pulse('RFDDS2Switch',0,ZeemanPiTime,'phase',(sigma2-2)*pi/2)); 
                end    
                    % local hiding                    
                    prog.GenSeq([Pulse('674Echo',0,dic.HiddingInfo.Tmm1),Pulse('674Parity',dic.HiddingInfo.Tmm1,dic.HiddingInfo.Tmm2),...
                       Pulse('674DoublePass',0,dic.HiddingInfo.Tmm1+dic.HiddingInfo.Tmm2)]);                 
                    % hiding exchange
                    prog.GenSeq([Pulse('674Gate',0,dic.HiddingInfo.Tcarrier1),Pulse('674DoublePass',0,dic.HiddingInfo.Tcarrier1)]);                    
            else
                hidden=0; %in case of IxI
            end    
        else
            % MEASUREMENT OF SIGMAi x 1
            if sigma2==1
            hidden=1;    
                    % local hiding
                    prog.GenSeq([Pulse('674Echo',0,dic.HiddingInfo.Tmm1),Pulse('674Parity',dic.HiddingInfo.Tmm1,dic.HiddingInfo.Tmm2),...
                       Pulse('674DoublePass',0,dic.HiddingInfo.Tmm1+dic.HiddingInfo.Tmm2)]);                 
                    % MEASUREMENT OF SIGMAx x 1 or SIGMAy x 1
                    if sigma1<4
                        prog.GenSeq(Pulse('RFDDS2Switch',0,ZeemanPiTime,'phase',(sigma1-2)*pi/2));
                    end %OTHERWISE SIGMAz x 1
                    
            else  % MEASUREMENT of SIGMAi x SIGMAj
                if sigma2<4
                    % global sigmaX or sigmaY
                    prog.GenSeq(Pulse('RFDDS2Switch',0,ZeemanPiTime,'phase',(sigma2-2)*pi/2));
                end
                % local hiding
                prog.GenSeq([Pulse('674Echo',0,dic.HiddingInfo.Tmm1),Pulse('674Parity',dic.HiddingInfo.Tmm1,dic.HiddingInfo.Tmm2),...
                    Pulse('674DoublePass',0,dic.HiddingInfo.Tmm1+dic.HiddingInfo.Tmm2)]);
                
                if sigma2<4
                    % local -sigmaX or -sigmaY (AFTER HIDING)
                    prog.GenSeq(Pulse('RFDDS2Switch',0,ZeemanPiTime,'phase',pi+(sigma2-2)*pi/2));
                end                
                if sigma1<4
                    % local sigmaX or sigmaY (AFTER HIDING)
                    prog.GenSeq(Pulse('RFDDS2Switch',0,ZeemanPiTime,'phase',(sigma1-2)*pi/2));
                end
                
                % local recovery
                prog.GenSeq([Pulse('674Echo',0,dic.HiddingInfo.Tmm1),Pulse('674Parity',dic.HiddingInfo.Tmm1,dic.HiddingInfo.Tmm2),...
                    Pulse('674DoublePass',0,dic.HiddingInfo.Tmm1+dic.HiddingInfo.Tmm2)]);
            end
        end    
        % shelving on the s=-1/2 to d=-3/2
        prog.GenSeq([Pulse('674DDS1Switch',0,dic.HiddingInfo.Tshelving),Pulse('674DoublePass',0,dic.HiddingInfo.Tshelving)]); %first pi/2 Pulse
                 
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
