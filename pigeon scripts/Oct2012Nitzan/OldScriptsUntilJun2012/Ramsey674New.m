function Ramsey674New

dic=Dictator.me;

armTime=0:100:1000;
% armTime=[10 500 1000 1500 2000];%20:50:1000;

% armTime=0:5:50;

piPhase=0:pi/6:2*pi;

doEcho=1;

repetitions=50;
Freq674SinglePass=77;

% armTime=0:50:2000;
% piPhase=0:pi/10:2*pi;

% PulseTime=0.1:30:1000;
dic.setNovatech4Amp(1,0);dic.setNovatech4Amp(0,0);ChannelSwitch('DIO7','on');
dic.setNovatech4Amp(2,1000);      

%  PulseTime=0.1:0.3:4;
% ------------Set GUI axes ---------------
InitializeAxes(dic.GUI.sca(1),'Photons #','Cases Counted #','Fluorescence Histogram',...
                [0 dic.maxPhotonsNumPerReadout],[],0);
% 
lines =InitializeAxes (dic.GUI.sca(6),...
    'Pi Phase','Dark Counts %','Rabi Scan',...
    [piPhase(1) piPhase(end)],[0 100],2);
grid(dic.GUI.sca(6),'on');
set(lines(1),'Marker','.','MarkerSize',10,'Color','b');
set(lines(2),'Marker','.','MarkerSize',10,'Color','r');

lines2 =InitializeAxes (dic.GUI.sca(10),...
    'Time','Contrast','Ramsey',...
    [armTime(1) armTime(end)],[0 100],1);
grid(dic.GUI.sca(6),'on');
set(lines2(1),'Marker','.','MarkerSize',10,'Color','b');

% -------- Main function scan loops ------
dark = zeros(length(armTime),length(piPhase));
contrast=zeros(length(armTime));
for index1 = 1:length(armTime)
    set(lines(1),'XData',[],'YData',[]);
        %disp(dic.estimateF674);
    
    for index2=1:length(piPhase)
        if dic.stop
            return
        end
        %dic.setNovatech4Freq(0,dic.estimateF674);
        dic.setNovatech4Freq(2,dic.updateF674);
        %use the fast estimator correction
        Freq674SinglePass=77;%+Fast674Estimator;
        r=experimentSequence(armTime(index1),piPhase(index2));
        dic.GUI.sca(1); %get an axis from Dictator GUI to show data
        hist(r,0:1:(1.8*dic.maxPhotonsNumPerReadout));
        if dic.TwoIonFlag
            dark(index1,index2) =100-sum( (r>dic.TwoIonsCountThreshold)*2+...
                ((r>dic.darkCountThreshold)&(r<dic.TwoIonsCountThreshold))*1 ...
                )/2/length(r)*100;
        else
            dark(index1,index2) = sum( r<dic.darkCountThreshold)/length(r)*100;
        end
        dic.GUI.sca(11);
        axis([min(piPhase) max(piPhase) min(armTime) max(armTime)]);
        imagesc(piPhase,armTime,dark);
        colorbar;
        ylabel('armTime(mus)'); xlabel('piPhase'); title('Dark');
        AddLinePoint(lines(1),piPhase(index2),dark(index1,index2));
        
        pause(0.1);
    end
        contrast(index1)=max(dark(index1,:))-min(dark(index1,:));
        AddLinePoint(lines2(1),armTime(index1),contrast(index1));
    
end

% %dic.vibMode(1).freq=0.99;
% [Nbar,Omega,y]=fitNbar2CarrierRabi((PulseTime)*1e-6,dark/100,dic.vibMode(1).freq,pi/4);
% disp(sprintf('average n = %.2f  PiTime = %4.2f [mus]',Nbar,2*pi/Omega/4*1e6+0.5));
% set(lines(2),'XData',armTime,'YData',y*100);
% % update T674 if the chi square is small
% if mean((y*100-dark).^2)<50
%     dic.T674=2*pi/Omega/4*1e6+0.1;% the 0.5 is a correction 
% rabi=dic.T674;

%--------------- Save data ------------------
if (dic.AutoSaveFlag)
    destDir=dic.saveDir;
    thisFile=[mfilename('fullpath') '.m' ];
    [filePath fileName]=fileparts(thisFile);
    scriptText=fileread(thisFile);
    scriptText(find(int8(scriptText)==10))='';
    showData='figure;plot(armTime,dark);xlabel(''Pulse Time[\mus]'');ylabel(''dark[%]'');';
    saveFileName=fullfile(destDir ,[fileName datestr(now,'-ddmmmyy-HHMMSS')]);
    dicParameters=dic.getParameters;
    save(saveFileName,'armTime','dark','contrast','showData','dicParameters','scriptText');
    disp(['Save data in : ' saveFileName]);
end 

%--------------------------------------------------------------------
    function r=experimentSequence(armTime,piPhase)
        prog=CodeGenerator;
        prog.GenDDSPullParametersFromBase;
%         prog.GenSeq(Pulse('674Switch2NovaTech',0,-1));
         prog.GenWaitExtTrigger;        
        prog.GenSeq(Pulse('ExperimentTrigger',0,50));
        % set DDS freq and amp
        prog.GenSeq(Pulse('674DDS1Switch',0,-1,'freq',Freq674SinglePass,'amp',100));
        % Doppler coolng

        prog.GenSeq(Pulse('OffRes422',0,500));%turn off cooling
        prog.GenSeq(Pulse('OnResCooling',0,dic.Tcooling) );

%         prog.GenSeq([Pulse('NoiseEater674',2,20),...
%                      Pulse('674DDS1Switch',0,20)]); %NoiseEater initialization
        prog.GenSeq([Pulse('NoiseEater674',2,16),...
                     Pulse('674DDS1Switch',0,20)]); %NoiseEater initialization
        prog.GenSeq(Pulse('Repump1033',0,dic.T1033)); %cleaning D state
        
        prog.GenSeq(Pulse('OpticalPumping',10,dic.Toptpump));

        %Ramsey Sequence
%         prog.GenSeq([Pulse('NoiseEater674',2,dic.T674/2),...
%                      Pulse('674DDS1Switch',0,dic.T674/2,'phase',0)]); %first pi/2 Pulse
        prog.GenSeq([Pulse('674DDS1Switch',0,dic.T674/2,'phase',0)]); %first pi/2 Pulse

        prog.GenPause(armTime);
        if doEcho
%             prog.GenSeq([Pulse('NoiseEater674',2,dic.T674),...
%                          Pulse('674DDS1Switch',0,dic.T674)]);% echo Pulse
            prog.GenSeq([Pulse('674DDS1Switch',0,dic.T674,'phase',0*pi/2)]);% echo Pulse
        end
        prog.GenPause(armTime);
        
%         prog.GenSeq([Pulse('NoiseEater674',2,dic.T674/2),...
%                      Pulse('674DDS1Switch',0,dic.T674/2,'phase',piPhase)]); %second pi/2 Pulse
        prog.GenSeq([Pulse('674DDS1Switch',0,dic.T674/2,'phase',piPhase)]); %second pi/2 Pulse

%         %sideband Shelving
%         if (pulseTime>2)
%            prog.GenSeq([Pulse('NoiseEater674',2,pulseTime-2),...
%                         Pulse('674DDS1Switch',0,pulseTime)]);
%         else
%            prog.GenSeq(Pulse('674DDS1Switch',0,pulseTime));
%         end
        
        % detection
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