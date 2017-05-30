function rabi=MicromitionCarrierRabiScan674(ptime)

dic=Dictator.me;
% micromotion frequency given by Keithley
FreqMM=str2num(query(dic.KeithUSB1,'Freq?'))/1e6;

if (exist('ptime'))
    PulseTime=ptime;
else
     PulseTime=1:30:1000;
%     PulseTime=1:0.5:20;
%      PulseTime=1:180:4000;
end

% ------------Set GUI axes ---------------
InitializeAxes(dic.GUI.sca(1),'Photons #','Cases Counted #','Fluorescence Histogram',...
                [0 dic.maxPhotonsNumPerReadout],[],0);

UpperBound=100; %in %
%            cla(dic.GUI.sca(10));
lines =InitializeAxes (dic.GUI.sca(10),...
    'Pulse Time[\mus]','Dark Counts %','Rabi Scan at micromotion SB',...
    [PulseTime(1) PulseTime(end)],[0 UpperBound],2);

grid(dic.GUI.sca(4),'on');
set(lines(1),'Marker','.','MarkerSize',10,'Color','b');
set(lines(2),'Marker','.','MarkerSize',10,'Color','r');

% -------- Main function scan loops ------
dark = zeros(size(PulseTime));
for index1 = 1:length(PulseTime)
    if dic.stop
        return
    end
    r=experimentSequence(PulseTime(index1),dic.updateF674+FreqMM);
%     r=experimentSequence(PulseTime(index1),dic.updateF674);
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
rabiGuess=PulseTime(find(max(dark)==dark,1))*0.5;
ft=fittype('a*(0.5-0.5*cos(pi*x/b))');
fo=fitoptions('Method','NonlinearLeastSquares','StartPoint',[100,rabiGuess]);
curve=fit((PulseTime'),dark',ft,fo);
dic.GUI.sca(10); hold on; plot(curve); legend off; hold off;
rabi=curve.b;
disp(sprintf('PiTime = %4.2f [mus], PiFreq=%.2f (kHz)',curve.b,1/2/curve.b*1000));
% % update T674 if the chi square is small
% if mean((y*100-dark).^2)<50
%     dic.T674=2*pi/Omega/4*1e6+0.1;% the 0.5 is a correction 
%end    
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
    function r=experimentSequence(pulseTime,freq)
        prog=CodeGenerator;
        prog.GenDDSPullParametersFromBase;
        prog.GenSeq(Pulse('674Switch2NovaTech',0,-1));
        prog.GenSeq(Pulse('ExperimentTrigger',0,50));
        % set DDS freq and amp
        prog.GenSeq(Pulse('674DDS1Switch',0,-1,'freq',freq,'amp',100));
        % Doppler coolng
        prog.GenSeq(Pulse('OffRes422',0,1));%turn off cooling
        prog.GenSeq(Pulse('OnResCooling',0,dic.Tcooling) );

        prog.GenSeq(Pulse('OpticalPumping',0,dic.Toptpump));
%         prog.GenSeq([Pulse('674PulseShaper',1,dic.TimeRF-2),...
%                      Pulse('RFDDS2Switch',2,dic.TimeRF)]);
        % wait 
%          prog.GenWait(10000); %half a second
        %sideband Shelving
        if (pulseTime>3)
           prog.GenSeq([Pulse('NoiseEater674',2,pulseTime-2),...
                        Pulse('674DDS1Switch',0,pulseTime)]);
        else
           prog.GenSeq(Pulse('674DDS1Switch',0,pulseTime));
        end
        % detection
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