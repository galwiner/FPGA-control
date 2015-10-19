function TwoIonsHeating
dic=Dictator.me;

% set file name
destDir=dic.saveDir;
thisFile=[mfilename('fullpath') '.m' ];
[filePath fileName]=fileparts(thisFile);
saveFileName=fullfile(destDir ,[fileName datestr(now,'-ddmmmyy-HHMMSS')]);

% PulseTime=0.1:10:300;
PulseTime=dic.T674;
% waittime=linspace(0,20000,5); %in msec
%waittime=linspace(0,100,3); %in msec
% waittime=[10 2500]; %in msec
%  waittime=[1 100 2500]; %in msec
waittime=5;%4000;

Vrf=3.1;%[2.5:0.2:3.1];

repetitions=1;
chunksize=1;

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

linestot =InitializeAxes (dic.GUI.sca(7),...
    'Vrf [V]','Detection Efficiency %','Vrf Sweep',...
    [Vrf(1)-0.00001 Vrf(end)],[70 100],2);
set(linestot(1),'Marker','.','MarkerSize',10,'Color','b');

% -------- Main function scan loops ------
dark = zeros(length(iterationsize),length(Vrf));
set(linestot(1),'XData',[],'YData',[]);
 for index1=1:length(Vrf)
%     dic.AVdcl=Vdcl0+Vdc(index1);
%     dic.AVdcr=Vdcr0+Vdc(index1);    
     dic.Vkeith=Vrf(index1);    
    
    for index2=1:iterationsize
        fprintf('.');    
        if dic.stop || ~CrystalCheckPMT(dic.Vkeith)
            return;
        end
        % real
        r=experimentSequence(waittime,dic.updateF674);
        disp(r);
    %     r=experimentSequence(PulseTime(index1),dic.updateF674);
%         dic.GUI.sca(1); %get an axis from Dictator GUI to show data
%         hist(r,0:1:(1.8*dic.maxPhotonsNumPerReadout));
        if dic.TwoIonFlag
            dark(index2,index1) =100-sum( (r>dic.TwoIonsCountThreshold)*2+...
                                 ((r>dic.darkCountThreshold)&(r<dic.TwoIonsCountThreshold))*1 ...
                                )/2/length(r)*100;
        else
            dark(index2,index1) = sum( r<dic.darkCountThreshold)/length(r)*100;
        end
%         AddLinePoint(lines(1),waittime,mean(dark(1:index2,index1)));
%         disp(sprintf('waittime=%2.f [s]  Detection Efficiency = %4.2f',waittime(index1),mean(dark(1:index2,index1))));    
        pause(0.1);
%         fprintf('Wait time = %d // Detection Efficiency = %.2f \n',waittime(index1),mean(dark(1:index2,index1)));
    end
    fprintf('\n At %d, we have an efficiency of %d \n',Vrf(index1),mean(dark(1:index2,index1)));    
    AddLinePoint(linestot(1),Vrf(index1),mean(dark(1:index2,index1)));    
    savethis;
end

% set(lines(2),'XData',waittime,'YData',mean(dark));
savethis;
%--------------- Save data ------------------
function savethis
    if (dic.AutoSaveFlag)
        scriptText=fileread(thisFile);
        scriptText(find(int8(scriptText)==10))='';
        showData='figure;plot(Vrf,mean(dark));xlabel(''Vrf (V)'');ylabel(''detection efficiency[%]'');';
        dicParameters=dic.getParameters;
        save(saveFileName,'waittime','Vrf','dark','chunksize','repetitions','index1','index2','showData','dicParameters','scriptText');
        disp(['Save data in : ' saveFileName]);
    end 
end

%--------------------------------------------------------------------
    function r=experimentSequence(waitt,freq)
        prog=CodeGenerator;
        prog.GenDDSPullParametersFromBase;
        prog.GenSeq(Pulse('674Switch2NovaTech',0,-1));
        prog.GenSeq(Pulse('ExperimentTrigger',0,50));
        prog.GenSeq(Pulse('OffRes422',0,500));

        % set DDS freq and amp
        prog.GenSeq(Pulse('674DDS1Switch',0,-1,'freq',freq,'amp',100));
        % Doppler coolng
        prog.GenSeq(Pulse('OffRes422',0,1));%turn off cooling
        prog.GenSeq(Pulse('OnResCooling',0,dic.Tcooling) );
        prog.GenSeq(Pulse('OpticalPumping',0,dic.Toptpump));
        
        if waitt>0
            prog.GenPause(waitt*1000);     
        end
        
        prog.GenSeq(Pulse('OpticalPumping',0,dic.Toptpump));
%          prog.GenPause(10);
%         prog.GenSeq([Pulse('674PulseShaper',1,dic.TimeRF-2),...
%                      Pulse('RFDDS2Switch',2,dic.TimeRF)]);
        % wait 
%          prog.GenWait(10000); %half a second
        %sideband Shelving
        if (PulseTime>3)
           prog.GenSeq([Pulse('NoiseEater674',2,PulseTime-2),...
                        Pulse('674DDS1Switch',0,PulseTime)]);
        else
           prog.GenSeq(Pulse('674DDS1Switch',0,PulseTime));
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
        dic.com.Execute(chunksize);
        dic.com.WaitForHostIdle;
        r = dic.com.ReadOut(chunksize);
        if chunksize>1
            r = r(2:end);
        end
    end
end