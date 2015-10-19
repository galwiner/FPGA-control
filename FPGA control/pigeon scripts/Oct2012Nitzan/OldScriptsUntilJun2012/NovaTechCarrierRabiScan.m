function NovaTechCarrierRabiScan

dic=Dictator.me;
pwrNovaTech=800;

PulseTime=1:1:30;
% ------------Set GUI axes -------------
InitializeAxes(dic.GUI.sca(1),'Photons #','Cases Counted #','Fluorescence Histogram',...
                [0 dic.maxPhotonsNumPerReadout],[],0);

lines = InitializeAxes (dic.GUI.sca(4),...
    'Pulse Time[\mus]','Dark Counts %','Rabi Scan',...
    [PulseTime(1) PulseTime(end)],[0 100],2);
grid(dic.GUI.sca(4),'on');
set(lines(1),'Marker','.','MarkerSize',10,'Color','b');
set(lines(2),'Marker','.','MarkerSize',10,'Color','r');

% -------- Main function scan loops -------
dark = zeros(size(PulseTime));
dic.setNovatech4Amp(0,pwrNovaTech);
dic.setNovatech4Amp(1,0);
dic.setNovatech4Freq(0,dic.updateF674);
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

[Nbar,Omega,y]=fitNbar2CarrierRabi((PulseTime)*1e-6,dark/100,dic.vibMode(1).freq,pi/4);
disp(sprintf('average n = %.2f  PiTime = %4.2f [mus]',Nbar,2*pi/Omega/4*1e6));
set(lines(2),'XData',PulseTime,'YData',y*100);
    
%--------------- Save data ------------------
if (dic.AutoSaveFlag)
    destDir=dic.saveDir;
    thisFile=[mfilename('fullpath') '.m' ];
    [filePath fileName]=fileparts(thisFile);
    scriptText=fileread(thisFile);
    showData='figure;plot(PulseTime,dark);xlabel(''Pulse Time[\mus]'');ylabel(''dark[%]'');';
    saveFileName=fullfile(destDir ,[fileName datestr(now,'-ddmmmyy-HHMMSS')]);
    dicParameters=dic.getParameters;
    save(saveFileName,'PulseTime','dark','showData','dicParameters','scriptText');
    disp(['Save data in : ' saveFileName]);
end 


%--------------------------------------------------------------------
    function r=experimentSequence(pulseTime)
        prog=CodeGenerator;
        prog.GenDDSPullParametersFromBase;
        prog.GenSeq(Pulse('ExperimentTrigger',0,50));
        % Doppler coolng
        prog.GenSeq(Pulse('OffRes422',0,1));%turn off cooling
        prog.GenSeq(Pulse('OnResCooling',0,dic.Tcooling) );
        prog.GenSeq(Pulse('OpticalPumping',0,dic.Toptpump));
        %sideband Shelving
        prog.GenSeq([Pulse('674PulseShaper',0,pulseTime),...
                     Pulse('674Switch2NovaTech',0,pulseTime+5)]);
        
        prog.GenSeq([Pulse('OnRes422',0,dic.TDetection) Pulse('PhotonCount',0,dic.TDetection)]);
        %resume cooling
        prog.GenSeq(Pulse('Repump1033',0,dic.T1033));
        prog.GenSeq(Pulse('OffRes422',0,0));
        prog.GenFinish;

        dic.com.UploadCode(prog);
        dic.com.UpdateFpga;
        dic.com.WaitForHostIdle; % wait until host finished it last task
        dic.com.Execute(200);
        dic.com.WaitForHostIdle;
        r = dic.com.ReadOut(200);
        r = r(2:end);
    end

end