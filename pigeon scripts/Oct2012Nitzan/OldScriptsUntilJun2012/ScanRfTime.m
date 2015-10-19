function ScanRfTime

dic=Dictator.me;

PulseTime=3:0.5:30;
% ------------Set GUI axes -------------
InitializeAxes(dic.GUI.sca(1),'Photons #','Cases Counted #','Fluorescence Histogram',...
                [0 dic.maxPhotonsNumPerReadout],[],0);

lines =InitializeAxes (dic.GUI.sca(6),...
    'Pulse Time[\mus]','Dark Counts %','RF Rabi Scan',...
    [PulseTime(1) PulseTime(end)],[0 100],2);
grid(dic.GUI.sca(6),'on');
set(lines(1),'Marker','.','MarkerSize',10,'Color','b');
set(lines(2),'Marker','.','MarkerSize',10,'Color','r');

% -------- Main function scan loops -------
dark = zeros(size(PulseTime));
for index1 = 1:length(PulseTime)
    if dic.stop
        return
    end
    r=experimentSequence(PulseTime(index1));
    dic.GUI.sca(1); %get an axis from Dictator GUI to show data
    hist(r,0:1:(1.8*dic.maxPhotonsNumPerReadout));
    if dic.TwoIonFlag
        dark(index1) =100-sum( (r>dic.TwoIonsCountThreshold)*2+...
                             ((r>dic.darkCountThreshold)&(r<dic.TwoIonsCountThreshold))*1 ...
                            )/2/length(r)*100;
    else
        dark(index1) = sum( r<dic.darkCountThreshold)/length(r)*100;
    end
    AddLinePoint(lines(1),PulseTime(index1),dark(index1));
    pause(0.1);
end
%---------- fitting and updating ---------------------
ft=fittype('50+a*cos(b*(x-c))');
fo=fitoptions('Method','NonlinearLeastSquares','Startpoint',[50,pi/dic.TimeRF,0.0],'Lower',[40 0.001 -pi],'Upper',[50 10 pi]);
[curve,goodness]=fit(PulseTime',dark',ft,fo);
set(lines(2),'Color',[0 0 0],'XData',PulseTime,'YData',feval(curve,PulseTime));
dic.TimeRF=pi/curve.b+curve.c; 
disp(sprintf('RF pi-Time is found to %2.3f muS',pi/curve.b));

%--------------- Save data ------------------
if (dic.AutoSaveFlag)
    destDir=dic.saveDir;
    thisFile=[mfilename('fullpath') '.m' ];
    [filePath fileName]=fileparts(thisFile);
    scriptText=fileread(thisFile);
    scriptText(find(int8(scriptText)==10))='';
    showData='figure;plot(PulseTime,dark);xlabel(''Pulse Time[\mus]'');ylabel(''dark[%]'');';
    saveFileName=fullfile(destDir ,[fileName datestr(now,'-ddmmmyy-HHMMSS')]);
    dicParameters=dic.getParameters;
    save(saveFileName,'PulseTime','dark','showData','dicParameters','scriptText');
    disp(['Save data in : ' saveFileName]);
end 


%--------------------------------------------------------------------
   function r=experimentSequence(pTime)
        prog=CodeGenerator; 
        prog.GenDDSPullParametersFromBase;
        prog.GenSeq(Pulse('ExperimentTrigger',0,50));
        prog.GenSeq( Pulse('674DDS1Switch',2,-1,'freq',dic.updateF674,'amp',100) );
        prog.GenSeq(Pulse('RFDDS2Switch',2,-1,'freq',dic.FRF,'amp',dic.ampRF));
        prog.GenSeq(Pulse('OffRes422',0,1));
        prog.GenSeq(Pulse('OnResCooling',0,dic.Tcooling));
        prog.GenSeq(Pulse('OpticalPumping',0,dic.Toptpump));
        %Do pi pulse RF
        prog.GenSeq([Pulse('674PulseShaper',1,pTime-1),...
                     Pulse('RFDDS2Switch',2,pTime)]);
        prog.GenSeq([Pulse('NoiseEater674',4,dic.T674-2),...
                     Pulse('674DDS1Switch',2,dic.T674)]);
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

        rep=400;
        dic.com.Execute(rep);
        dic.com.WaitForHostIdle;
        r=dic.com.ReadOut(rep);
        r=r(2:end);
    end
end
