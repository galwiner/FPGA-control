function rabi=LaserHeatingCarrierRabiScan674Scan

dic=Dictator.me;

repetitions=100;

% PulseTime=0.1:10:300;
PulseTime=0.1:1:60;
%HeatingTime=1:40:401;
HeatingTime=1:50:201;


% ------------Set GUI axes ---------------
InitializeAxes(dic.GUI.sca(1),'Photons #','Cases Counted #','Fluorescence Histogram',...
                [0 dic.maxPhotonsNumPerReadout],[],0);

lines =InitializeAxes (dic.GUI.sca(4),...
    'Pulse Time[\mus]','Dark Counts %','Rabi Scan',...
    [PulseTime(1) PulseTime(end)],[0 100],2);

linesheat =InitializeAxes (dic.GUI.sca(7),...
    'Heating Time[\mus]','nbar','Laser Heating Rate',...
    [HeatingTime(1) HeatingTime(end)],[0 300],2);

grid(dic.GUI.sca(4),'on');
set(lines(1),'Marker','.','MarkerSize',10,'Color','b');
set(lines(2),'Marker','.','MarkerSize',10,'Color','r');
set(linesheat(1),'Marker','.','MarkerSize',10,'Color','r');

% -------- Main function scan loops ------
nbardata=zeros(size(HeatingTime));
for indexheat=1:length(HeatingTime)
    
    dark = zeros(size(PulseTime));
    for index1 = 1:length(PulseTime)
        if dic.stop
            return
        end
        r=experimentSequence(PulseTime(index1),dic.F674,HeatingTime(indexheat));
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
    
    [Nbar,Omega,y]=fitNbar2CarrierRabi(0.9*(PulseTime)*1e-6,dark/100,3.2,pi/4);
    nbardata(indexheat)=Nbar(1);
    disp(sprintf('heatingtime=%2.f [mus]  average n = %.2f  PiTime = %4.2f [mus]',HeatingTime(indexheat),Nbar,2*pi/Omega/4*1e6+0.5));
%     set(lines(1),'XData',PulseTime,'YData',dark);
    set(lines(2),'XData',PulseTime,'YData',y*100);
%     dic.GUI.sca(7);
    pause(2);
    set(lines(1),'XData',[],'YData',[]);
    set(lines(2),'XData',[],'YData',[]);

    AddLinePoint(linesheat(1),HeatingTime(indexheat),nbardata(indexheat));
    
    % update T674 if the chi square is small
    if mean((y*100-dark).^2)<50
        dic.T674=2*pi/Omega/4*1e6+0.1;% the 0.5 is a correction
        rabi=dic.T674;
             
    end
    

end

%--------------- Save data ------------------
if (dic.AutoSaveFlag)
    destDir=dic.saveDir;
    thisFile=[mfilename('fullpath') '.m' ];
    [filePath fileName]=fileparts(thisFile);
    scriptText=fileread(thisFile);
    scriptText(find(int8(scriptText)==10))='';
    %             showData='figure;plot(PulseTime,dark);xlabel(''Pulse Time[\mus]'');ylabel(''dark[%]'');';
    showData='figure;plot(HeatingTime,nbardata);xlabel(''Heating Time[\mus]'');ylabel(''nbar'');';
    
    saveFileName=fullfile(destDir ,[fileName datestr(now,'-ddmmmyy-HHMMSS')]);
    dicParameters=dic.getParameters;
    %             save(saveFileName,'PulseTime','dark','showData','dicParameters','scriptText');
    save(saveFileName,'HeatingTime','nbardata','showData','dicParameters','scriptText');
    
    disp(['Save data in : ' saveFileName]);
end

%--------------------------------------------------------------------
    function r=experimentSequence(pulseTime,freq,theat)
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
        
        % Heating with probe beam
        LaserHeatingFrequency=213;
        %          prog.GenSeq(Pulse('OnRes422',0,-1,'freq',LaserHeatingFrequency));
        
        %           HeatingTime=250; % in microsec
        prog.GenSeq(Pulse('OnRes422',0,-1,'freq',LaserHeatingFrequency));
        prog.GenPause(2000);
        prog.GenSeq(Pulse('OnRes422',0,theat));
        %             prog.GenPause(10000);
        %          prog.GenSeq(Pulse('OnRes422',0,-1,'freq',dic.F422onRes));
        prog.GenSeq(Pulse('OpticalPumping',0,dic.Toptpump));

         
         %         prog.GenSeq(Pulse('OnRes422',0,-1,'freq',dic.F422onRes));
%         LaserHeatingFrequency=211;
%         HeatingTime=30; % in microsec
%         prog.GenSeq(Pulse('OnResCooling',0,HeatingTime,'freq',LaserHeatingFrequency));
%         prog.GenPause(200);
%         prog.GenSeq(Pulse('OpticalPumping',0,dic.Toptpump));
%         prog.GenSeq(Pulse('OnResCooling',0,-1,'freq',dic.F422onResCool));
        
%         prog.GenSeq([Pulse('674PulseShaper',1,dic.TimeRF-2),...
%                      Pulse('RFDDS2Switch',2,dic.TimeRF)]);
 
%         prog.GenSeq(Pulse('OnRes422',0,HeatingTime,'freq',LaserHeatingFrequency));
        % back to the original frequency
%         prog.GenSeq(Pulse('OnRes422',0,-1,'freq',dic.F422onRes));
%         prog.GenSeq(Pulse('OnResCooling',0,-1,'freq',dic.F422onResCool));

        %% the big wait
%         waitTimeMs=10;
%         prog.GenSeq(Pulse('Shutters',0,0)); %shut down all lasers (takes <=3ms)
%         prog.GenSeq(Pulse('674DDS1Switch',0,-1,'freq',50,'amp',0)); %turn off 674
%         prog.GenPause((waitTimeMs-4)*1000); %convert to microseconds
%         prog.GenSeq(Pulse('Shutters',0,-1));%open all lasers (takes <=4ms)
%         prog.GenPause(4000);
%         prog.GenSeq(Pulse('674DDS1Switch',0,-1,'freq',freq,'amp',100));%set 674 freq to normal
        
        %sideband Shelving
        if (pulseTime>3)
           prog.GenSeq([Pulse('NoiseEater674',2,pulseTime-2),...
                        Pulse('674DDS1Switch',0,pulseTime)]);
        else
           prog.GenSeq(Pulse('674DDS1Switch',0,pulseTime));
        end
        % detection
        prog.GenSeq(Pulse('OnRes422',0,-1,'freq',dic.F422onRes));
        prog.GenPause(2000);
         prog.GenSeq([Pulse('OnRes422',0,dic.TDetection,'freq',dic.F422onRes) Pulse('PhotonCount',0,dic.TDetection)]);
%         prog.GenSeq([Pulse('OnRes422',0,dic.TDetection,'freq',209) Pulse('PhotonCount',0,dic.TDetection)]);

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