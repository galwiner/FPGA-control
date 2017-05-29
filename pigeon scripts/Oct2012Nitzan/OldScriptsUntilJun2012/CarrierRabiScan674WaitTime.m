function CarrierRabiScan674WaitTime

dic=Dictator.me;

PulseTime=0.1:3:120;

silent=1;
waittimebefore=5; %miliseconds
ExpRepetition=50;

%set filename information
destDir=dic.saveDir;
thisFile=[mfilename('fullpath') '.m' ];
[filePath fileName]=fileparts(thisFile);
scriptText=fileread(thisFile);
saveFileName=fullfile(destDir ,[fileName datestr(now,'-ddmmmyy-HHMMSS')]);


% ------------Set GUI axes ---------------
if ~silent
    InitializeAxes(dic.GUI.sca(1),'Photons #','Cases Counted #','Fluorescence Histogram',...
        [0 dic.maxPhotonsNumPerReadout],[],0);
    
    lines =InitializeAxes (dic.GUI.sca(4),...
        'Pulse Time[\mus]','Dark Counts %','Rabi Scan',...
        [PulseTime(1) PulseTime(end)],[0 100],2);
    grid(dic.GUI.sca(4),'on');
    set(lines(1),'Marker','.','MarkerSize',10,'Color','b');
    set(lines(2),'Marker','.','MarkerSize',10,'Color','r');
end

% -------- Main function scan loops ------

savetimerOnOffFlag=dic.timerOnOffFlag;
dic.timerOnOffFlag=0;
startTime=now;
ResetStopFile;

dark = zeros(size(PulseTime));
for index1 = 1:length(PulseTime)
    if IsStop
        disp('Run stopped by User!');
        disp('----------------------------------------------');
        return;
    end
    fprintf('%.1f %%\n',index1/length(PulseTime)*100);
    if dic.stop
        return
    end
    r=experimentSequence(PulseTime(index1),dic.F674,waittimebefore);
%     r=experimentSequence(PulseTime(index1),dic.updateF674);
    hist(r,0:1:(1.8*dic.maxPhotonsNumPerReadout));
    if dic.TwoIonFlag
        dark(index1) =100-sum( (r>dic.TwoIonsCountThreshold)*2+...
                             ((r>dic.darkCountThreshold)&(r<dic.TwoIonsCountThreshold))*1 ...
                            )/2/length(r)*100;
    else
        dark(index1) = sum( r<dic.darkCountThreshold)/length(r)*100;
    end
    %AddLinePoint(lines(1),PulseTime(index1),dark(index1));
    pause(0.1);
    savedata;

end
dic.timerOnOffFlag=savetimerOnOffFlag;

[Nbar,Omega,y]=fitNbar2CarrierRabi((PulseTime)*1e-6,dark/100,dic.vibMode(1).freq,pi/4);
disp(sprintf('average n = %.2f  PiTime = %4.2f [mus]',Nbar,2*pi/Omega/4*1e6+0.5));
%set(lines(2),'XData',PulseTime,'YData',y*100);

% update T674 if the chi square is small
if mean((y*100-dark).^2)<50
    dic.T674=2*pi/Omega/4*1e6+0.1;% the 0.5 is a correction 
end

%--------------- Save data ------------------
function savedata 
    if (dic.AutoSaveFlag)
 %       destDir=dic.saveDir;
 %       thisFile=[mfilename('fullpath') '.m' ];
 %       [filePath fileName]=fileparts(thisFile);
 %       scriptText=fileread(thisFile);
 %       scriptText(find(int8(scriptText)==10))='';
        showData='figure;plot(PulseTime,dark);xlabel(''Pulse Time[\mus]'');ylabel(''dark[%]'');';
 %       saveFileName=fullfile(destDir ,[fileName datestr(now,'-ddmmmyy-HHMMSS')]);
        dicParameters=dic.getParameters;
        save(saveFileName,'waittimebefore','PulseTime','dark','showData','dicParameters','scriptText');
 %       disp(['Save data in : ' saveFileName]);
    end
end

%--------------------------------------------------------------------
    function r=experimentSequence(pulseTime,freq,waittimebefore)
        prog=CodeGenerator;
        prog.GenDDSPullParametersFromBase;
        prog.GenSeq(Pulse('674Switch2NovaTech',0,-1));
        prog.GenSeq(Pulse('ExperimentTrigger',0,50));
        % set DDS freq and amp
  %      prog.GenSeq(Pulse('674DDS1Switch',0,-1,'freq',freq,'amp',100));
        prog.GenSeq(Pulse('674DDS1Switch',0,-1,'freq',dic.updateF674,'amp',100));
        
        % Doppler coolng
        prog.GenSeq(Pulse('OffRes422',0,1));%turn off cooling
        prog.GenSeq(Pulse('OnResCooling',0,dic.Tcooling) );

        %Sideband cooling
        coolingTime=3000;
        sidebandLightShift=1.044; 
        prog.GenSeq(Pulse('674DDS1Switch',0,-1,'freq',dic.updateF674+sidebandLightShift,'amp',100));
        prog.GenSeq([Pulse('NoiseEater674',3,coolingTime) ...
            Pulse('674DDS1Switch',2,coolingTime,'amp',100) ...
            Pulse('OpticalPumping',0,coolingTime) ...
            Pulse('Repump1033',1,coolingTime+dic.T1033)]);  

        % optical pumping
        prog.GenSeq(Pulse('OpticalPumping',0,dic.Toptpump));
%         prog.GenSeq([Pulse('674PulseShaper',1,dic.TimeRF-2),...
%                      Pulse('RFDDS2Switch',2,dic.TimeRF)]);
        % wait 
        prog.GenSeq(Pulse('Shutters',0,0)); %shut down all lasers (takes <=3ms)
        prog.GenSeq(Pulse('RFDDS2Switch',2,-1,'freq',3.1415*dic.FRF,'amp',0)); %turn off RF
        prog.GenPause((waittimebefore-4)*1000); %convert to microseconds
        prog.GenSeq(Pulse('Shutters',0,-1));%open all lasers (takes <=4ms)
        prog.GenPause(4000);
        prog.GenSeq(Pulse('RFDDS2Switch',2,-1,'freq',dic.FRF,'amp',dic.ampRF)); %turn RF back on
        
     %   prog.GenWait(*1000); %half a second
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
        dic.com.Execute(ExpRepetition);
        dic.com.WaitForHostIdle;
        r = dic.com.ReadOut(ExpRepetition);
        r = r(2:end);
    end

end