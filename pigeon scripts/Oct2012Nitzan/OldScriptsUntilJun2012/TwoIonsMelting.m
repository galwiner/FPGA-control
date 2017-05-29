function Detection(varargin)
dic=Dictator.me;

%freqList=192:1:210;
waittime=10;linspace(0,15000000,2); %in milli-seconds
freq=210;

for i=1:2:size(varargin,2)
    switch lower(char(varargin(i)))
        case 'freq'
            freqList=varargin{i+1};
    end; %switch
    
end;%for loop

if (dic.SitOnItFlag)
    cont=1;
    while (cont)
        if (dic.stop)
            cont=0;
        end
        r = experimentSeq(dic.F422onRes);
        r(1) = [];
        pause(0.01);
        dic.GUI.sca(1); %get an axis from Dictator GUI to show data
        hist(r,1:2:dic.maxPhotonsNumPerReadout);
        xlabel(num2str(round(mean(r))),'FontSize',250);
    end
else
    %-------------- set GUI ---------------
    InitializeAxes (dic.GUI.sca(1),'Photons #','Cases Counted #','Fluorescence Histogram',...
                [0 dic.maxPhotonsNumPerReadout],[],0);

    lines =InitializeAxes (dic.GUI.sca(9),...
    'Waittime [Days]','Photons Counts #','S_{1/2}-P_{1/2} Fluorescence',...
    [waittime(1) waittime(end)],[0 dic.maxPhotonsNumPerReadout],1);
    set(lines,'XData',[],'YData',[],'Color',randRGBNoWhite,...
              'LineWidth',0.5,'Marker','.','MarkerSize',10);
    %-------------- main scan loop -----------
    bright=zeros(size(waittime));
    grid on ;
    for index =1:length(waittime)
        if (dic.stop)
            return;
        end
        r = experimentSeq(waittime(index));
        r(1) = [];
        bright(index)=mean(r);
        pause(0.01);
        gca = dic.GUI.sca(1);
        hist(r,1:2:dic.maxPhotonsNumPerReadout);
        xlabel(num2str(round(mean(r))),'FontSize',40)
        AddLinePoint(lines,waittime(index),bright(index))
    end
    dic.refresh('F422onRes'); %restore information prior to the scan.
    %------------ Save data ------------------
    if (dic.AutoSaveFlag)
        destDir=dic.saveDir;
        thisFile=[mfilename('fullpath') '.m' ];
        [filePath fileName]=fileparts(thisFile);
        scriptText=fileread(thisFile);
        scriptText(find(int8(scriptText)==10))='';
        showData='figure;plot(waittime,bright);xlabel(''Waittime[s]'');ylabel(''photons'');';
        saveFileName=fullfile(destDir ,[fileName datestr(now,'-ddmmmyy-HHMMSS')]);
        dicParameters=dic.getParameters;
        save(saveFileName,'waittime','bright','showData','dicParameters','scriptText');
        disp(['Save data in : ' saveFileName]);
    end 
end
%% ------------------------- Experiment sequence ------------------------------------    
    function [r,rep]=experimentSeq(waittime)%create and run a single sequence of detection
        prog=CodeGenerator; 
        prog.GenSeq(Pulse('ExperimentTrigger',0,50));
        %set-up detection(also=optical repump), 1092 and on-res cooling freq. 
%         if (freq>0)
%             prog.GenSeq(Pulse('OnRes422',0,-1,'freq',freq));
%         end
%         prog.GenSeq(Pulse('Repump1092',0,0,'freq',dic.F1092));
        prog.GenSeq(Pulse('OffRes422',0,500));
        prog.GenSeq(Pulse('OnResCooling',0,dic.Tcooling));
        prog.GenPause(waittime);
        prog.GenSeq([Pulse('OnRes422',100,dic.TDetection) Pulse('PhotonCount',100,dic.TDetection)]);
        prog.GenSeq(Pulse('OffRes422',500,0));
        prog.GenFinish;
        %prog.DisplayCode;

        % FPGA/Host control
        n=dic.com.UploadCode(prog);
        dic.com.UpdateFpga;
        dic.com.WaitForHostIdle;

        rep=30;
        dic.com.Execute(rep);
        dic.com.WaitForHostIdle;
        r=dic.com.ReadOut(rep);
    end
end

