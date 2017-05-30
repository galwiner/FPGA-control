function RFTimeScan

dic=Dictator.me;

doHalfPi=0;

if doHalfPi
    PulseTime=0.8*dic.piHalfRF:0.1:1.2*dic.piHalfRF;
    minvalue=45;maxvalue=55;
else
    PulseTime=0.1:dic.TimeRF/10:dic.TimeRF*3;
    minvalue=0;maxvalue=100;
end
% ------------Set GUI axes -------------
InitializeAxes(dic.GUI.sca(1),'Photons #','Cases Counted #','Fluorescence Histogram',...
                [0 dic.maxPhotonsNumPerReadout],[],0);

lines =InitializeAxes (dic.GUI.sca(6),...
    'Pulse Time[\mus]','Dark Counts %','RF Rabi Scan',...
    [PulseTime(1) PulseTime(end)],[minvalue maxvalue],2);
grid(dic.GUI.sca(6),'on');
set(lines(1),'Marker','.','MarkerSize',10,'Color','b');
set(lines(2),'Marker','.','MarkerSize',10,'Color','r');

set(lines(1),'XData',[],'YData',[]);
set(lines(2),'XData',[],'YData',[]);

% -------- Main function scan loops -------
dark = zeros(size(PulseTime));
for index1 = 1:length(PulseTime)
    if dic.stop
        return
    end
    dic.setNovatech('DoublePass','freq',dic.updateF674,'amp',1000);
    r=experimentSequence(PulseTime(index1));
    dic.GUI.sca(1); %get an axis from Dictator GUI to show data
    hist(r,0:1:(1.8*dic.maxPhotonsNumPerReadout));
    ivec=dic.IonThresholds;
    tmpdark=0;
    for tmp=1:dic.NumOfIons
        tmpdark=tmpdark+sum((r>ivec(tmp))&(r<ivec(tmp+1)))*tmp;
    end
    tmpdark=100-tmpdark/length(r)/(dic.NumOfIons)*100;
    dark(index1)=tmpdark;
    AddLinePoint(lines(1),PulseTime(index1),dark(index1));
    pause(0.1);
end
%---------- fitting and updating ---------------------
if doHalfPi==0
    ft=fittype('50+a*cos(b*(x-c))');
    fo=fitoptions('Method','NonlinearLeastSquares','Startpoint',[50,pi/dic.TimeRF,0.0],'Lower',[40 0.001 -pi],'Upper',[50 10 pi]);
    [curve,goodness]=fit(PulseTime',dark',ft,fo);
    set(lines(2),'Color',[0 0 0],'XData',PulseTime,'YData',feval(curve,PulseTime));
    dic.TimeRF=pi/curve.b+curve.c;
    disp(sprintf('RF pi-Time is found to %2.3f muS',pi/curve.b));
end
%--------------- Save data ------------------
    showData='figure;plot(PulseTime,dark);xlabel(''Pulse Time[\mus]'');ylabel(''dark[%]'');';
    dic.save;


%--------------------------------------------------------------------
   function r=experimentSequence(pTime)
        prog=CodeGenerator; 
        prog.GenDDSPullParametersFromBase;
        prog.GenSeq(Pulse('ExperimentTrigger',0,50));
        prog.GenSeq( Pulse('674DDS1Switch',2,-1,'freq',dic.SinglePass674freq,'amp',100) );
        prog.GenSeq(Pulse('RFDDS2Switch',2,-1,'freq',dic.FRF,'amp',dic.ampRF));
        prog.GenSeq(Pulse('OffRes422',0,1));
        prog.GenSeq(Pulse('OnResCooling',0,dic.Tcooling));
        
        prog.GenSeq([Pulse('674DDS1Switch',0,15),... 
            Pulse('NoiseEater674',2,10),Pulse('674DoublePass',0,15),...
            Pulse('Repump1033',15,dic.T1033),...
            Pulse('OpticalPumping',16+dic.T1033,dic.Toptpump)]);
        
        %Do pi pulse RF
        prog.GenSeq(Pulse('RFDDS2Switch',2,pTime));
                
        prog.GenSeq([Pulse('674DDS1Switch',2,dic.T674) Pulse('674DoublePass',0,dic.T674+2)]);
    
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

        rep=200;
        dic.com.Execute(rep);
        dic.com.WaitForHostIdle;
        r=dic.com.ReadOut(rep);
        r=r(1:end);
    end
end
