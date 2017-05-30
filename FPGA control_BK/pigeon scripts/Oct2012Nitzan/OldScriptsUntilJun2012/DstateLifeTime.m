function DstateLifeTime

dic=Dictator.me;

WaitTime=50:100:10000;

InitializeAxes(dic.GUI.sca(1),'Photons #','Cases Counted #','Fluorescence Histogram',...
                [0 dic.maxPhotonsNumPerReadout],[],0);

lines =InitializeAxes (dic.GUI.sca(4),...
    'Pulse Time[\mus]','Dark Counts %','Rabi Scan',...
    [WaitTime(1) WaitTime(end)],[0 100],1);
grid(dic.GUI.sca(9),'on');
set(lines(1),'Marker','.','MarkerSize',10,'Color','k');


dark = zeros(size(WaitTime));

for index1 = 1:length(WaitTime)
    if dic.stop
        return
    end
    r=experimentSequence(WaitTime(index1));
    dic.GUI.sca(1); %get an axis from Dictator GUI to show data
    hist(r,0:1:(1.8*dic.maxPhotonsNumPerReadout));
    if dic.TwoIonFlag
        dark(index1) =100-sum( (r>dic.TwoIonsCountThreshold)*2+...
                             ((r>dic.darkCountThreshold)&(r<dic.TwoIonsCountThreshold))*1 ...
                            )/2/length(r)*100;
    else
        dark(index1) = sum( r<dic.darkCountThreshold)/length(r)*100;
    end
    AddLinePoint(lines(1),WaitTime(index1),dark(index1));
    pause(0.1);
end


% --------------------------------------------------------------------
    function r=experimentSequence(waitTime)
        prog=CodeGenerator;
        prog.GenDDSPullParametersFromBase;
        prog.GenSeq(Pulse('ExperimentTrigger',0,50));
        prog.GenSeq(Pulse('674DDS1Switch',0,-1,'freq',dic.updateF674,'amp',100));
        % Doppler coolng
        prog.GenSeq(Pulse('OffRes422',0,1));%turn off cooling
        prog.GenSeq(Pulse('OnResCooling',0,dic.Tcooling) );
        prog.GenSeq(Pulse('OpticalPumping',0,dic.Toptpump));
        %sideband Shelving
        
        prog.GenSeq([Pulse('NoiseEater674',0,dic.T674),...
                     Pulse('674DDS1Switch',0,dic.T674)]);
        % detection
        prog.GenSeq([Pulse('OnRes422',waitTime,dic.TDetection) Pulse('PhotonCount',waitTime,dic.TDetection)]);
        %resume cooling
        prog.GenSeq(Pulse('Repump1033',0,dic.T1033));
        prog.GenSeq(Pulse('OffRes422',0,0));
        prog.GenFinish;

        dic.com.UploadCode(prog);
        dic.com.UpdateFpga;
        dic.com.WaitForHostIdle; % wait until host finished it last task
        rep=100;
        dic.com.Execute(rep);
        dic.com.WaitForHostIdle;
        r = dic.com.ReadOut(rep);
        r = r(2:end);
    end

end