function TwoIonsSwap(varargin)
dic=Dictator.me;
%set filename information
destDir=dic.saveDir;
thisFile=[mfilename('fullpath') '.m' ];
[filePath fileName]=fileparts(thisFile);
scriptText=fileread(thisFile);
saveFileName=fullfile(destDir ,[fileName datestr(now,'-ddmmmyy-HHMMSS')]);


waittime=linspace(5000,5000,1); %in milli-seconds
repetitions=50;
%SwapThreshold=85;

%-------------- set GUI ---------------
InitializeAxes (dic.GUI.sca(1),'Photons #','Cases Counted #','Fluorescence Histogram',...
    [0 100],[0 1.5],1);

lines =InitializeAxes (dic.GUI.sca(9),...
    'Rep num ','Photons Counts #','S_{1/2}-P_{1/2} Fluorescence',...
    [0 repetitions],[0 dic.maxPhotonsNumPerReadout],1);
set(lines,'XData',[],'YData',[],'Color',randRGBNoWhite,...
    'LineWidth',0.5,'Marker','.','MarkerSize',10);
%-------------- main scan loop -----------
r=zeros(repetitions,length(waittime));
grid on ;
for index=1:length(waittime)
    for count=1:repetitions
        if (dic.stop)
            return;
        end
        r(count,index) = experimentSeq(waittime(index));
        pause(0.01);
        gca = dic.GUI.sca(1);
        AddLinePoint(lines,count,r(count,index))
        savedata;
    end

end
 
    %------------ Save data ------------------
function savedata    
    if (dic.AutoSaveFlag)
        showData='figure; cla;plot(r(1:count,index)';
        dicParameters=dic.getParameters;
        save(saveFileName,'repetitions','waittime','r','index','count','showData','dicParameters','scriptText');
        disp(['Save data in : ' saveFileName]);
    end
end


%% ------------------------- Experiment sequence ------------------------------------    
    function r=experimentSeq(waitt)%create and run a single sequence of detection
        prog=CodeGenerator; 
        prog.GenSeq(Pulse('ExperimentTrigger',0,50));
        prog.GenSeq(Pulse('OffRes422',0,500));
        prog.GenSeq(Pulse('OnResCooling',0,dic.Tcooling));        
       
        prog.GenPause(waitt*1000);

        prog.GenSeq([Pulse('OnRes422',100,dic.TDetection) Pulse('PhotonCount',100,dic.TDetection)]);
        prog.GenSeq(Pulse('OffRes422',0,0));
        prog.GenFinish;
        % FPGA/Host control
        n=dic.com.UploadCode(prog);
        dic.com.UpdateFpga;
        dic.com.WaitForHostIdle;
        rep=1;
        dic.com.Execute(rep);
        dic.com.WaitForHostIdle;
        r=dic.com.ReadOut(rep);
    end
end
