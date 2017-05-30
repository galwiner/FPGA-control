function RFResScan
dic=Dictator.me;
coarse=0;
if coarse
    freqSpan=(-0.15:0.007:0.15); %Coarse scan
    RFTime=dic.TimeRF;
    RFamp=100;
else
    freqSpan=(-0.0025:0.00015:0.0025)*10;
    RFTime=dic.TimeRF*7;
    RFamp=10;
end

freqList=freqSpan+dic.FRF;
%-------------- Set GUI figures ---------------------
InitializeAxes (dic.GUI.sca(1),'Photons #','Cases Counted #','Fluorescence Histogram',...
                [0 dic.maxPhotonsNumPerReadout],[],0);
lines =InitializeAxes (dic.GUI.sca(9),'F_{RF} [MHz]','Dark Counts %','Zeeman line',...
                       [freqList(1) freqList(end)],[0 100],2);
set(lines(1),'XData',[],'YData',[],'Marker','.','MarkerSize',10);
set(lines(2),'Color',[0 0 0],'XData',[],'YData',[]);

%-------------- Main function scan loops ---------------------
CrystalCheckPMT;
dark = zeros(size(freqList));
if dic.SitOnItFlag
    cont=1;
    while (cont)
        if (dic.stop)
            cont=0;
        end
        r=experimentSequence(dic.FRF);
        dic.GUI.sca(1); %get an axis from Dictator GUI to show data
        hist(r,1:1:dic.maxPhotonsNumPerReadout);
        xlabel(num2str(sum( r<dic.darkCountThreshold)/length(r)*100,2),...
            'FontSize',100);
    end
else
    for index1 = 1:length(freqList)
        if dic.stop
            return
        end
        dic.setNovatech('DoublePass','freq',dic.updateF674,'amp',1000);
        r=experimentSequence(freqList(index1),RFamp,RFTime);
        dic.GUI.sca(1); 
        hist(r,1:2:dic.maxPhotonsNumPerReadout);
        ivec=dic.IonThresholds;
        tmpdark=0;
        for tmp=1:dic.NumOfIons
            tmpdark=tmpdark+sum((r>ivec(tmp))&(r<ivec(tmp+1)))*tmp;
        end
        tmpdark=100-tmpdark/length(r)/(dic.NumOfIons)*100;
        dark(index1)=tmpdark;
        AddLinePoint(lines(1),freqList(index1),dark(index1))
    end
    %---------- fitting and updating ---------------------

    ft=fittype('100-a*sinc((x-b)*c).^2');
    fo=fitoptions('Method','NonlinearLeastSquares',...
           'Startpoint',[100,dic.FRF,100],'Lower',[10 1 0],'Upper',[100 15 2000]);
    [curve,goodness]=fit(freqList',dark',ft,fo);
    dic.FRF=curve.b;
    set(lines(2),'Color',[0 0 0],'XData',freqList,'YData',feval(curve,freqList));
    disp(sprintf('RF resonance freq is set to %2.3f MHz',curve.b));

    %------------ Save data ------------------

    showData='figure;plot(freqList,dark);xlabel(''F_{RF} [Mhz]'');ylabel(''dark[%]'');';
    dic.save;

end
%---------------------------------------------------------------------
function r=experimentSequence(freq,RFamp,RFTime)
    prog=CodeGenerator; 
    prog.GenDDSPullParametersFromBase;
    prog.GenSeq(Pulse('ExperimentTrigger',0,50));
    prog.GenSeq(Pulse('674DDS1Switch',2,-1,'freq',dic.SinglePass674freq,'amp',100));
    prog.GenSeq(Pulse('RFDDS2Switch',2,-1,'freq',freq,'amp',RFamp));
    prog.GenSeq(Pulse('OffRes422',0,1));
    prog.GenSeq(Pulse('OnResCooling',0,dic.Tcooling));
    %activate noise eater, move it to int hold and repump
    prog.GenSeq([Pulse('674DDS1Switch',2,15),... 
                Pulse('NoiseEater674',3,13),Pulse('674DoublePass',0,18),...
                Pulse('Repump1033',15,dic.T1033),...
                Pulse('OpticalPumping',16+dic.T1033,dic.Toptpump)]);
    %Do pi pulse RF
    prog.GenSeq(Pulse('RFDDS2Switch',0,RFTime));
    % Shelving pulse
    prog.GenSeq([Pulse('674DDS1Switch',2,dic.T674),Pulse('674DoublePass',0,dic.T674+2)]);
    % Detection
    prog.GenSeq([Pulse('OnRes422',0,dic.TDetection)...
                 Pulse('PhotonCount',0,dic.TDetection)]);
    %resume cooling
    prog.GenSeq(Pulse('Repump1033',0,dic.T1033));
    prog.GenSeq(Pulse('OffRes422',0,0));
    
    prog.GenFinish;
    %prog.DisplayCode;


    % FPGA/Host control
    n=dic.com.UploadCode(prog);
    dic.com.UpdateFpga;
    dic.com.WaitForHostIdle;

    rep=100;
    dic.com.Execute(rep);
    dic.com.WaitForHostIdle;
    r=dic.com.ReadOut(rep);
    r=r(2:end);
end
end
