function PhotonIonCorr_Pi(varargin)
dic=Dictator.me;
WP1=475;
WP2=475;
%--------options-------------
for i=1:2:size(varargin,2)
    switch lower(char(varargin(i)))
        case 'wp1'
            WP1=varargin{i+1};
        case 'wp2'
            WP2=varargin{i+1};
    end; %switch
end;%for loop% pi excitation
dic.com.UpdateWavePlates(WP1,WP2);
Single_Pulse(Pulse('RFDDS2Switch',2,-1,'freq',dic.FRF,'amp',dic.ampRF));
PulseTime=linspace(1,2,10);

%-------------- set GUI ---------------
InitializeAxes (dic.GUI.sca(1),'repeation','Cases Counted #','repeation Histogram',...
                [],[],0);

lines =InitializeAxes (dic.GUI.sca(9),'excitation time [\mus]','H pol','',...
                       [PulseTime(1) PulseTime(end)],[],2);
set(lines(1),'XData',[],'YData',[],'Color','b',...
          'LineWidth',0.5,'Marker','.','MarkerSize',10);
set(lines(2),'XData',[],'YData',[],'Color','r',...
          'LineWidth',0.5,'Marker','.','MarkerSize',10);
repline =InitializeAxes (dic.GUI.sca(10),'excitation time [\mus]','repeation','',...
                       [PulseTime(1) PulseTime(end)],[],1);
set(repline,'XData',[],'YData',[],'Color','b',...
          'LineWidth',0.5,'Marker','.','MarkerSize',10);
InitializeAxes (dic.GUI.sca(11),'Photn Polarization','Ion State','\rho',...
                       [0 3],[0 3],0);

set(dic.GUI.sca(11),'XTickLabel','H|V','YTickLabel','up|down');

%-------------- main scan loop -----------
meanDensityM=zeros(2,2);
for ind1 =1:length(PulseTime)
    if (dic.stop)
        return;
    end

    r=experimentSeqeunce(PulseTime(ind1));
    photon=1+(r(1:3:end)==1);
    ion=1+(r(3:3:end)>dic.darkCountThreshold);
    DensityM=zeros(2,2);
    for ind=1:length(ion)
        DensityM(ion(ind),photon(ind))=DensityM(ion(ind),photon(ind))+1;
    end
    AddLinePoint(lines(1),PulseTime(ind1),sum(photon-1));
    AddLinePoint(lines(2),PulseTime(ind1),sum(ion-1));
    AddLinePoint(repline,PulseTime(ind1),25*mean(r(2:3:end)));
    dic.GUI.sca(1);
    hist(r(2:3:end)*25,linspace(0,30000,20));
    axis([0 30000 0 100]);
    DensityM=DensityM/length(r)*3;
    %disp(DensityM);
    dic.GUI.sca(11);
    bar3(DensityM);view([-56.5 50]);
    axis([0.5 2.5 0.5 2.5 0 0.6])
    expResult(ind1,:)=r;
    pause(0.5);
    meanDensityM=meanDensityM+DensityM;
end
meanDensityM=meanDensityM/length(PulseTime);
disp(sprintf('     |  H  |  V   \n-----|-----|------\n  up |%3.2f | %3.2f \n down|%3.2f | %3.2f',...
             meanDensityM(1,1),meanDensityM(1,2),meanDensityM(2,1),meanDensityM(2,2))); 
disp(sprintf('Prob for up given H =%f', meanDensityM(1,1)/(meanDensityM(1,1)+meanDensityM(2,1)) ));
disp(sprintf('Prob for up given V =%f', meanDensityM(1,2)/(meanDensityM(1,2)+meanDensityM(2,2)) ));
dic.GUI.sca(11);
bar3(meanDensityM);view([-56.5 50]);

%------------ Save data ------------------
if (dic.AutoSaveFlag)
    destDir=dic.saveDir;
    thisFile=[mfilename('fullpath') '.m' ];
    [filePath fileName]=fileparts(thisFile);
    scriptText=fileread(thisFile);
    scriptText(find(int8(scriptText)==10))='';
    showData=[' figure; bar3(meanDensityM);view([-56.5 50]);axis([0 3 0 3 0 1]);title(sprintf(''WP1=%.0f WP2=%.0f'',WP1,WP2))'];
    saveFileName=fullfile(destDir ,[fileName datestr(now,'-ddmmmyy-HHMMSS')]);
    dicParameters=dic.getParameters;
    save(saveFileName,'WP1','WP2','meanDensityM','expResult','PulseTime','showData','dicParameters','scriptText');
    disp(['Save data in : ' saveFileName]);
end 

% ------------------------- Experiment sequence ------------------------------------    
    function [r]=experimentSeqeunce(par) 
    prog=CodeGenerator; 
    prog.GenDDSPullParametersFromBase;
    %prog.GenDDSFSKState(2,0);% set DDS2 phase to phase word 2(=0)
    prog.GenSeq(Pulse('OnRes422',0,-1,'Amp',dic.weakOnResAmp));      
    prog.GenSeq(Pulse('RFDDS2Switch',0,-1,'freq',dic.FRF));
    prog.GenSeq( Pulse('674DDS1Switch',0,-1,'freq',dic.updateF674,'amp',100) );
    %initialization
    prog.GenSeq(Pulse('OffRes422',0,500));
    prog.GenSeq(Pulse('OnResCooling',0,dic.Tcooling));
    % Photon scattering 
    prog.GenRegOp('RegA=',0);
    prog.GenRegOp('RegB=',0);
    prog.GenRegOp('RegC=',0);
    prog.GenRepeat
        prog.GenIfDo('RegC=',25)
            prog.GenRegOp('RegC=',0);
            prog.GenSeq([Pulse('Repump1092',0,50),...
                         Pulse('Repump1033',0,10),...
                         Pulse('OnResCooling',0,50)]);
            prog.GenRegOp('RegA=+1',0);
        prog.GenElseDo        
            prog.GenPauseMemoryBlock;
            prog.GenSeq([Pulse('Repump1092',1,8),...
                         Pulse('OpticalPumping',2,5)]);
            prog.GenSeq([Pulse('674PulseShaper',1,dic.TimeRF-1),...
                         Pulse('RFDDS2Switch',2,dic.TimeRF)]);
            prog.GenSeq([Pulse('OnRes422',2,0.175),...
                         Pulse('PMTsAccumulate',3.00,0.125)]);
        prog.GenElseEnd;
        prog.GenRegOp('RegC=+1',0);
    prog.GenRepeatEnd('RegB>0');
    % A photon was measured
    prog.GenRegOp('FIFO<-RegB',0);
    prog.GenPause(0.1);
    prog.GenRegOp('FIFO<-RegA',0);
    % Ion detection 
    prog.GenSeq(Pulse('OnRes422',0,-1,'Amp',dic.OnResAmp));     
    prog.GenSeq(Pulse('Repump1092',0,0))

%     prog.GenSeq([Pulse('674PulseShaper',1,dic.TimeRF-2),...
%                  Pulse('RFDDS2Switch',2,dic.TimeRF)]);
    % check only detection fidelity
%       prog.GenSeq(Pulse('OnResCooling',0,dic.Tcooling));
%       prog.GenSeq(Pulse('OpticalPumping',0,5));
%       prog.GenSeq([Pulse('674PulseShaper',10,dic.TimeRF-2),...
%                     Pulse('RFDDS2Switch',11,-1)]);
    %firdt shelving Pulse 
    prog.GenSeq([Pulse('NoiseEater674',2,dic.T674-2) ...
                 Pulse('674DDS1Switch',0,dic.T674)]);
    %second shelving Pulse 
    prog.GenSeq(Pulse('674DDS1Switch',5,7,'freq',dic.updateF674+dic.FRF*1.2046));
    prog.GenSeq(Pulse('ExperimentTrigger',0,10));
    prog.GenSeq([Pulse('OnRes422',0,dic.TDetection)...
                 Pulse('PhotonCount',0,dic.TDetection)]);
    prog.GenSeq([Pulse('Repump1033',0,dic.T1033) Pulse('OffRes422',0,0)]);
    prog.GenFinish;


        %prog.DisplayCode;

        % FPGA/Host control
        n=dic.com.UploadCode(prog,round(5*40*rand(1,25))+1);
        dic.com.UpdateFpga;
        dic.com.WaitForHostIdle;
        rep=100;
        dic.com.Execute(rep);
        dic.com.WaitForHostIdle;
        r=dic.com.ReadOut(-1);        
    end
end


