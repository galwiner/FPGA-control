function DetectionEfficiencyVsCompensationFluorescenceCheck
dic=Dictator.me;

% set file name
destDir=dic.saveDir;
thisFile=[mfilename('fullpath') '.m' ];
[filePath fileName]=fileparts(thisFile);
saveFileName=fullfile(destDir ,[fileName datestr(now,'-ddmmmyy-HHMMSS')]);

% PulseTime=0.1:10:300;

% waittime=linspace(0,20000,5); %in msec
%waittime=linspace(0,100,3); %in msec
% waittime=[10 2500]; %in msec
%  waittime=[1 100 2500]; %in msec
waittime=20;

% Vdcl=[-0.25:0.03:0.26];
% Vdcl0=1.5;
% dic.AVdcr=0;    

Vcomp=[0:5:50];
dic.AVdcl=1.45;    
dic.AVdcr=0;  

repetitions=50;
chunksize=10;

% number of sweeps
iterationsize=repetitions/chunksize;


% if dic.curBeam==0 %674 beam horizontal at 45 deg to axial
%     PulseTime=0.1:1:50;
% elseif dic.curBeam==1             %674 beam vertical at 45 deg to axial
%     PulseTime=1:3:150;
% else
%     PulseTime=1:20:600;
% end
% ------------Set GUI axes ---------------
InitializeAxes(dic.GUI.sca(1),'Photons #','Cases Counted #','Fluorescence Histogram',...
                [0 dic.maxPhotonsNumPerReadout],[],0);

% lines =InitializeAxes (dic.GUI.sca(7),...
%     'Waittime Time[ms]','Dark Counts %','Heating Measurement',...
%     [waittime(1)-0.0001 waittime(end)],[0 100],2);
% grid(dic.GUI.sca(4),'on');
% set(lines(1),'Marker','.','MarkerSize',10,'Color','b');
% set(lines(2),'Marker','.','MarkerSize',10,'Color','r');

linestot =InitializeAxes (dic.GUI.sca(6),...
    'Vcomp [V]','Photon Count %','Vcomp Sweep',...
    [Vcomp(1) Vcomp(end)],[35 70],2);
set(linestot(1),'Marker','.','MarkerSize',10,'Color','b');

% -------- Main function scan loops ------
dark = zeros(length(iterationsize),length(Vcomp));
set(linestot(1),'XData',[],'YData',[]);
 for index1=1:length(Vcomp)
%      dic.AVdcr=Vdcr0+Vdcr(index1);
%      dic.Vkeith=Vrf(index1);    
    dic.HPVcomp=Vcomp(index1);
    
    for index2=1:iterationsize
        fprintf('.');    
        if dic.stop || ~CrystalCheckPMT(dic.Vkeith)
            return;
        end
        % real
        r=experimentSequence(waittime);
        
        dark(index2,index1) = mean(r);

        pause(0.1);
    end
    fprintf('\n At %d, we have %d photons \n',Vcomp(index1),mean(dark(1:index2,index1)));    
    AddLinePoint(linestot(1),Vcomp(index1),mean(dark(1:index2,index1)));    
    savethis;
end

% set(lines(2),'XData',waittime,'YData',mean(dark));
savethis;
%--------------- Save data ------------------
function savethis
    if (dic.AutoSaveFlag)
        scriptText=fileread(thisFile);
        scriptText(find(int8(scriptText)==10))='';
        showData='figure;plot(Vcomp,mean(dark));xlabel(''Vcomp (V)'');ylabel(''Photon count'');';
        dicParameters=dic.getParameters;
        save(saveFileName,'waittime','Vcomp','dark','chunksize','repetitions','index1','index2','showData','dicParameters','scriptText');
        disp(['Save data in : ' saveFileName]);
    end 
end

%--------------------------------------------------------------------
    function r=experimentSequence(waitt)
        prog=CodeGenerator;
        prog.GenDDSPullParametersFromBase;
        prog.GenSeq(Pulse('ExperimentTrigger',0,50));
        prog.GenSeq(Pulse('OffRes422',0,500));

        % Doppler coolng
        prog.GenSeq(Pulse('OffRes422',0,1));%turn off cooling
        prog.GenSeq(Pulse('OnResCooling',0,dic.Tcooling) );
        prog.GenSeq(Pulse('OpticalPumping',0,dic.Toptpump));
        
        if waitt>0
            prog.GenPause(waitt*1000);     
        end
        
        prog.GenSeq(Pulse('OpticalPumping',0,dic.Toptpump));

        % detection
        prog.GenSeq([Pulse('OnRes422',0,dic.TDetection) Pulse('PhotonCount',0,dic.TDetection)]);
        %resume cooling
        prog.GenSeq(Pulse('OffRes422',0,0));
        prog.GenFinish;

        dic.com.UploadCode(prog);
        dic.com.UpdateFpga;
        dic.com.WaitForHostIdle; % wait until host finished it last task
        dic.com.Execute(chunksize);
        dic.com.WaitForHostIdle;
        r = dic.com.ReadOut(chunksize);
        if chunksize>1
            r = r(2:end);
        end
    end
end