function DLifeTime

dic=Dictator.me;

% WaitTime=1:20:161;
WaitTime=[10 20 30 40 80 100 150 200];

InitializeAxes(dic.GUI.sca(1),'Photons #','Cases Counted #','Fluorescence Histogram',...
                [0 dic.maxPhotonsNumPerReadout],[],0);

lines =InitializeAxes (dic.GUI.sca(4),...
    'Pulse Time[ms]','Dark Counts %','D Lifetime',...
    [WaitTime(1) WaitTime(end)],[0 100],1);
grid(dic.GUI.sca(9),'on');
 
set(lines(1),'Marker','.','MarkerSize',10,'Color','k');
    
dark = zeros(size(WaitTime));

for index1 = 1:length(WaitTime)
    if dic.stop
        return
    end
    CrystalCheckPMT;  
    dic.setNovatech('DoublePass','freq',dic.updateF674,'amp',1000);
    r=experimentSequence(WaitTime(index1)*1000);
    dic.GUI.sca(1); %get an axis from Dictator GUI to show data
    hist(r,0:1:(1.8*dic.maxPhotonsNumPerReadout));
    ivec=dic.IonThresholds;
    tmpdark=0;
    for tmp=1:dic.NumOfIons
        tmpdark=tmpdark+sum((r>ivec(tmp))&(r<ivec(tmp+1)))*tmp;
    end
    tmpdark=100-tmpdark/length(r)/(dic.NumOfIons)*100;
    dark(index1)=tmpdark;
    AddLinePoint(lines(1),WaitTime(index1),dark(index1));
    pause(0.1);
end
% fit
ft=fittype('a*exp(-x/b)');
fo=fitoptions('Method','NonlinearLeastSquares','StartPoint',[100,380]);
fr=fit(WaitTime',dark',ft,fo);
c=diff(confint(fr))/2;
dic.GUI.sca(4); hold on; plot(fr); hold off; legend off;
fprintf('D life time=%.2f(+-%.2f) ms\n',fr.b,c(2));
showData='figure;plot(WaitTime,dark);xlabel(''Wait Time[ms]'');ylabel(''dark[%]'');';
dic.save;

%%------------------------ experiment sequence -----------------
    function r=experimentSequence(waittime)
        prog=CodeGenerator;
        prog.GenDDSPullParametersFromBase;

        % set DDS freq and amp
        prog.GenSeq(Pulse('ExperimentTrigger',0,50));
        % Doppler coolng
        prog.GenSeq(Pulse('OffRes422',0,1));%turn off cooling
        prog.GenSeq(Pulse('OnResCooling',10,dic.Tcooling));
        % update the noiseEater value
       
        prog.GenSeq(Pulse('674DDS1Switch',2,-1,'freq',dic.SinglePass674freq,'amp',100)); 
        % update the noiseEater value
        prog.GenSeq([Pulse('674DDS1Switch',0,15,'amp',100),...
                     Pulse('NoiseEater674',2,10),Pulse('674DoublePass',0,15),...        
                     Pulse('Repump1033',15,15+dic.T1033)]);
                                  
        % Optical pumping                 
        prog.GenSeq(Pulse('OpticalPumping',1,dic.Toptpump));
        % Shelving pulse
        prog.GenSeq([Pulse('674DDS1Switch',2,dic.T674),Pulse('674DoublePass',0,dic.T674+3)]);

        
        prog.GenPause(waittime);
        
        % detection
        prog.GenSeq([Pulse('OnRes422',0,dic.TDetection) Pulse('PhotonCount',0,dic.TDetection)]);
        % resume cooling
        prog.GenSeq(Pulse('Repump1033',0,dic.T1033));

        prog.GenSeq([Pulse('OffRes422',0,0) Pulse('Repump1092',0,0)]);
        prog.GenFinish;    
        dic.com.UploadCode(prog);
        dic.com.UpdateFpga;
        dic.com.WaitForHostIdle; % wait until host finished it last task
        rep=50;
        dic.com.Execute(rep);
        dic.com.WaitForHostIdle;
        r = dic.com.ReadOut(rep);
        r = r(2:end);
    end

end