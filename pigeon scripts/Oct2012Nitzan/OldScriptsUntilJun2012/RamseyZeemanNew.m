function RamseyZeemanNew

dic=Dictator.me;

armTime=20:100:1000;
% armTime=0:5:50;

piPhase=0:pi/5:2*pi;

doEcho=0;

repetitions=50;
Freq674SinglePass=77;

% armTime=0:50:2000;
% piPhase=0:pi/10:2*pi;

% PulseTime=0.1:30:1000;
dic.setNovatech4Amp(1,0);dic.setNovatech4Amp(0,0);ChannelSwitch('DIO7','on');
dic.setNovatech4Amp(2,1000);      

%  PulseTime=0.1:0.3:4;
% ------------Set GUI axes ---------------
cla(dic.GUI.sca(7));
InitializeAxes(dic.GUI.sca(1),'Photons #','Cases Counted #','Fluorescence Histogram',...
                [0 dic.maxPhotonsNumPerReadout],[],0);
% 
lines =InitializeAxes (dic.GUI.sca(6),...
    'Pi Phase','Dark Counts %','Rabi Scan',...
    [piPhase(1) piPhase(end)],[0 100],2);
grid(dic.GUI.sca(6),'on');
set(lines(1),'Marker','.','MarkerSize',10,'Color','b');
set(lines(2),'Marker','.','MarkerSize',10,'Color','r');

% -------- Main function scan loops ------
dark = zeros(length(armTime),length(piPhase));
for index1 = 1:length(armTime)
    set(lines(1),'XData',[],'YData',[]);
    for index2=1:length(piPhase)
        if dic.stop
            return
        end
        dic.setNovatech4Freq(2,dic.updateF674);
        pause(0.1);
        r=experimentSequence(armTime(index1),piPhase(index2));
        %     r=experimentSequence(PulseTime(index1),dic.updateF674);
        dic.GUI.sca(1); %get an axis from Dictator GUI to show data
        hist(r,0:1:(1.8*dic.maxPhotonsNumPerReadout));
        if dic.TwoIonFlag
            dark(index1,index2) =100-sum( (r>dic.TwoIonsCountThreshold)*2+...
                ((r>dic.darkCountThreshold)&(r<dic.TwoIonsCountThreshold))*1 ...
                )/2/length(r)*100;
        else
            dark(index1,index2) = sum( r<dic.darkCountThreshold)/length(r)*100;
        end
        dic.GUI.sca(7);
        imagesc(piPhase,armTime,dark);
        axis([min(piPhase) max(piPhase) min(armTime) max(armTime)]);
        colorbar;
        ylabel('armTime(mus)'); xlabel('piPhase'); title('Dark');
        AddLinePoint(lines(1),piPhase(index2),dark(index1,index2));
        pause(0.1);
    end
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
    save(saveFileName,'armTime','dark','showData','dicParameters','scriptText');
    disp(['Save data in : ' saveFileName]);
end 

%--------------------------------------------------------------------
    function r=experimentSequence(armTime,piPhase)
        prog=CodeGenerator;
        prog.GenDDSPullParametersFromBase;
        prog.GenSeq(Pulse('674Switch2NovaTech',0,-1));
        prog.GenSeq(Pulse('ExperimentTrigger',0,50));
        prog.GenWaitExtTrigger;
        % set DDS freq and amp
        prog.GenSeq(Pulse('674DDS1Switch',0,-1,'freq',Freq674SinglePass,'amp',100));
        prog.GenSeq(Pulse('RFDDS2Switch',3,-1,'amp',dic.ampRF,'freq',dic.FRF,'phase',0));

        % Doppler coolng
        prog.GenSeq(Pulse('OffRes422',0,500));%turn off cooling
        prog.GenSeq(Pulse('OnResCooling',0,dic.Tcooling) );

        prog.GenSeq([Pulse('NoiseEater674',2,16),...
                     Pulse('674DDS1Switch',0,20)]); %NoiseEater initialization
        prog.GenSeq(Pulse('Repump1033',0,dic.T1033)); %cleaning D state
        
        prog.GenSeq(Pulse('OpticalPumping',10,dic.Toptpump));

%         %674 Ramsey Sequence
%         prog.GenSeq([Pulse('674DDS1Switch',0,dic.T674/2,'phase',0)]); %first pi/2 Pulse
%         prog.GenPause(armTime/2);
%         if doEcho
%             prog.GenSeq([Pulse('674DDS1Switch',0,dic.T674)]);% echo Pulse
%         end
%         prog.GenPause(armTime/2);
%         
%         prog.GenSeq([Pulse('674DDS1Switch',0,dic.T674/2,'phase',piPhase)]); %second pi/2 Pulse
% 
%         prog.GenSeq([Pulse('674PulseShaper',2,dic.piHalfRF-1),...
%                      Pulse('RFDDS2Switch',3,dic.piHalfRF)]);    
         prog.GenSeq([Pulse('RFDDS2Switch',0,dic.piHalfRF)]);    

        prog.GenPause(armTime);
        if doEcho
            prog.GenSeq([Pulse('674PulseShaper',1,dic.TimeRF-1),...
                         Pulse('RFDDS2Switch',2,dic.TimeRF)]);% echo Pulse
        end
        prog.GenPause(armTime);        
        %second pi/2 Pulse
        prog.GenSeq([Pulse('RFDDS2Switch',0,dic.piHalfRF,'phase',piPhase)]);    
%         prog.GenSeq([Pulse('674PulseShaper',1,dic.piHalfRF-1),...
%                      Pulse('RFDDS2Switch',2,dic.piHalfRF,'phase',piPhase)]);    
        
                 
        % detection
        prog.GenSeq([Pulse('NoiseEater674',2,dic.T674-2),...
                     Pulse('674DDS1Switch',0,dic.T674)]);
                 
%         prog.GenSeq(Pulse('674DDS1Switch',5,7,'freq',dic.updateF674+dic.FRF*1.2046));
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