function valid=DoubleShelving(varargin)
dic=Dictator.me;
 secondPulseTime=10;
 secondFreq=dic.updateF674+1.2046*dic.FRF;
%[secondFreq secondPulseTime]=S2DTransFreqAndPiTime(1);

damy=1:10;
%-------------- Set GUI figures ---------------------
InitializeAxes (dic.GUI.sca(1),'Photons #','Cases Counted #','Fluorescence Histogram',...
    [0 dic.maxPhotonsNumPerReadout],[],0);
lines =InitializeAxes (dic.GUI.sca(9),'#','Dark Counts %','Shelving prob',...
    [damy(1) damy(end)],[90 100],2);
set(lines(1),'XData',[],'YData',[],'Marker','.','MarkerSize',10);

%-------------- Main function scan loops ---------------------
dark = zeros(size(damy));
if dic.SitOnItFlag
    cont=1;
    while (cont)
        if (dic.stop)
            cont=0;
        end
        r=experimentSequence;
        dic.GUI.sca(1); %get an axis from Dictator GUI to show data
        hist(r,1:2:dic.maxPhotonsNumPerReadout);
        xlabel(num2str(sum( r<dic.darkCountThreshold)/length(r)*100,3),...
            'FontSize',100);
    end
else
    for index1 = 1:length(damy)
        if dic.stop
            return
        end
        r=experimentSequence;
        dic.GUI.sca(1);
        hist(r,1:2:dic.maxPhotonsNumPerReadout);
        dark(index1) = sum( r<dic.darkCountThreshold)/length(r)*100;
        AddLinePoint(lines(1),damy(index1),dark(index1))
    end
    disp(sprintf('mean Dark= %.3f',mean(dark)));
    %------------ Save data ------------------
%     if (dic.AutoSaveFlag&&savedata)
%         destDir=dic.saveDir;
%         thisFile=[mfilename('fullpath') '.m' ];
%         [filePath fileName]=fileparts(thisFile);
%         scriptText=fileread(thisFile);
%         showData='figure;plot(f674List,dark);xlabel(''F_674 [Mhz]'');ylabel(''dark[%]'');';
%         saveFileName=fullfile(destDir ,[fileName datestr(now,'-ddmmmyy-HHMMSS')]);
%         dicParameters=dic.getParameters;
%         save(saveFileName,'f674List','dark','showData','dicParameters','scriptText');
%         disp(['Save data in : ' saveFileName]);
%     end
end
%%------------------------ experiment sequence -----------------
    function r=experimentSequence()
        prog=CodeGenerator;
        prog.GenDDSPullParametersFromBase;
        % set DDS freq and amp
        prog.GenSeq(Pulse('674DDS1Switch',2,-1,'freq',dic.updateF674,'amp',100));
        prog.GenSeq(Pulse('Repump1033',0,dic.T1033));

        prog.GenSeq(Pulse('ExperimentTrigger',0,50));
        % Doppler coolng
        prog.GenSeq(Pulse('OffRes422',0,1));%turn off cooling
        prog.GenSeq(Pulse('OnResCooling',0,dic.Tcooling));
        prog.GenSeq(Pulse('OpticalPumping',1,dic.Toptpump));
%          prog.GenRepeatSeq([Pulse('674DDS1Switch',2,10,'freq',dic.updateF674-0.4*dic.FRF),...
%                             Pulse('Repump1033',17,dic.T1033)],2);
%       prog.GenPause(50);
        % first Shelving pulse
        prog.GenSeq([Pulse('NoiseEater674',4,dic.T674-2),...
                     Pulse('674DDS1Switch',3,dic.T674,'freq',dic.updateF674)]);
        % second Shelving pulse
%         secondPulseTime=50; %for BSB
%         prog.GenSeq([Pulse('NoiseEater674',1,secondPulseTime-2) ...
%                      Pulse('674DDS1Switch',0,secondPulseTime,'freq',secondFreq)]);
%      prog.GenSeq(Pulse('674DDS1Switch',3,secondPulseTime,'freq',secondFreq));
        
        % detection
        prog.GenSeq([Pulse('OnRes422',0,dic.TDetection) Pulse('PhotonCount',0,dic.TDetection)]);
        %resume cooling
        prog.GenSeq(Pulse('Repump1033',0,dic.T1033));

        prog.GenSeq([Pulse('OffRes422',0,0) Pulse('Repump1092',0,0)]);
        prog.GenFinish;    
        dic.com.UploadCode(prog);
        dic.com.UpdateFpga;
        dic.com.WaitForHostIdle; % wait until host finished it last task
        rep=400;
        dic.com.Execute(rep);
        dic.com.WaitForHostIdle;
        r = dic.com.ReadOut(rep);
        r = r(2:end);
    end
end

