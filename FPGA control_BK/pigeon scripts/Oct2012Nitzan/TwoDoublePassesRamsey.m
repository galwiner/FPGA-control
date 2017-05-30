function TwoDoublePassesRamsey(varargin)
dic=Dictator.me;

phaseVec=linspace(0,2*pi-0.1,17);
novatechAmp=1000;

MMPiTime=84.05;

DoublePassFreq=dic.updateF674; %default

% control the double pass frequency
dic.setNovatech('DoublePass','freq',DoublePassFreq,'amp',1000);
dic.setNovatech('Parity','freq',dic.SinglePass674freq,'amp',1000);

CrystalCheckPMT;

%-------------- Set GUI figures ---------------------
InitializeAxes (dic.GUI.sca(1),'Photons #','Cases Counted #','Fluorescence Histogram',...
    [0 dic.maxPhotonsNumPerReadout],[],0);
lines =InitializeAxes (dic.GUI.sca(7),...
    'Phase[rad]','Dark Counts %','Two Double Passes Ramsey',...
    [phaseVec(1) phaseVec(end)],[0 100],1);
set(lines(1),'Marker','.','MarkerSize',10,'Color','b');

%-------------- Main function scan loops ---------------------
dark = zeros(size(phaseVec));
    for index1 = 1:length(phaseVec)
        if dic.stop
            return;
        end
        
        dic.setNovatech('DoublePass','freq',DoublePassFreq,'amp',1000);
        dic.setNovatech('DoublePassSecond','freq',DoublePassFreq+dic.MMFreq/2,'amp',1000,'phase',phaseVec(index1));        
        pause(0.1);
        r=experimentSequence(dic.F674,MMPiTime);
        dic.GUI.sca(1);
        hist(r,1:1:dic.maxPhotonsNumPerReadout);
        ivec=dic.IonThresholds;
        tmpdark=0;
        for tmp=1:dic.NumOfIons
            tmpdark=tmpdark+sum((r>ivec(tmp))&(r<ivec(tmp+1)))*tmp;
        end
        tmpdark=100-tmpdark/length(r)/(dic.NumOfIons)*100;
        dark(index1)=tmpdark;                    
        AddLinePoint(lines(1),phaseVec(index1),dark(index1));
    end
    %---------- fitting and updating ---------------------
%     pguess=phaseVec(find(dark==max(dark),1));
%     ft=fittype('a*cos(x-b)+c');
%     fo=fitoptions('Method','NonlinearLeastSquares',...
%             'Startpoint',[50 pguess 50],...
%             'MaxFunEvals',20000,'MaxIter',20000);
%     [curve,goodness]=fit(phaseVec',dark',ft,fo);
%     dic.GUI.sca(7); hold on; plot(curve); hold off; legend off;
%     eval(sprintf('dic.AddrInfo.P%s=%.2f',OscName{2},curve.b));
%     fprintf('phase of %s w.r. to %s is %.2f rad\n',OscName{1}(4:end),OscName{2}(4:end),curve.b);
%     fprintf('Contrast is %.2f \n',curve.a*2);

    %------------ Save data ------------------
        showData='figure;plot(phaseVec,dark);xlabel(''Phase [rad]'');ylabel(''dark[%]''); title(sprintf(''Two Osc Ramsey:%s,%s'',OscName{1},OscName{2}))';
        dic.save;

%%------------------------ experiment sequence -----------------
    function r=experimentSequence(pTime1,pTime2)
        prog=CodeGenerator;
        prog.GenDDSPullParametersFromBase;
        
        % set DDS freq and amp
        % Doppler coolng
        prog.GenSeq(Pulse('OffRes422',0,500));%turn off cooling
        prog.GenSeq(Pulse('OnResCooling',10,dic.Tcooling));

        %calibrate noise eater + optical pumping
%          if ~softwareUpdateNE
%             prog.GenSeq([Pulse('674Echo',0,15),...
%                 Pulse('NoiseEater674',2,10),Pulse('674DoublePass',0,15),...
%                 Pulse('Repump1033',15,dic.T1033),...
%                 Pulse('OpticalPumping',16+dic.T1033,dic.Toptpump)]);
%         else
            prog.GenSeq([Pulse('Repump1033',0,dic.T1033),...
            Pulse('OpticalPumping',dic.T1033,dic.Toptpump)]);
%         end
        prog.GenSeq(Pulse('ExperimentTrigger',0,50));
        
        prog.GenSeq([Pulse('674Parity',0,pTime1/2),Pulse('674DoublePass',0,pTime1/2)]);

        prog.GenSeq(Pulse('674Parity',0,pTime1/2));

%         % spin lock
%         spinTime=10000;
%         prog.GenSeq([Pulse('674Echo',2,spinTime),...
%                      Pulse('674DoublePass',2,spinTime)]);
%         
        %drive the second pi/2 pulse
        
        % detection
        prog.GenSeq([Pulse('OnRes422',10,dic.TDetection) Pulse('PhotonCount',10,dic.TDetection)]);
        % resume cooling
        prog.GenSeq(Pulse('Repump1033',0,dic.T1033));

        prog.GenSeq([Pulse('OffRes422',0,0) Pulse('Repump1092',0,0)]);
        prog.GenFinish;    
        dic.com.UploadCode(prog);
        dic.com.UpdateFpga;
        dic.com.WaitForHostIdle; % wait until host finished it last task
        rep=200;
        dic.com.Execute(rep);
        dic.com.WaitForHostIdle;
        r = dic.com.ReadOut(rep);
    end
end

