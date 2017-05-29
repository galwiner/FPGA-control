function PhotonIonCorr_SigmaPM
dic=Dictator.me;
% sigma excitation
PulseTime=linspace(1,2,400);

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

%-------------- main scan loop -----------
meanDensityM=zeros(2,2);
for ind1 =1:length(PulseTime)
    if (dic.stop)
        return;
    end

    r=experimentSeqeunce(PulseTime(ind1));
    AddLinePoint(lines(1),PulseTime(ind1),mean(r(6:3:end)));
    AddLinePoint(repline,PulseTime(ind1),mean(r(2:3:end)));
    dic.GUI.sca(1);

    mtime=round(mean(r(6:3:end)));
%     if (std(r(3:3:end))>100)
%         disp(r(3:3:end))
%     end
    hist(r(6:3:end),linspace(mtime-100,mtime+100,20));
    axis([mtime-100 mtime+100 0 30]);
    disp(1/(mean(r(2:3:end))*PulseTime(ind1)*1e-6));

end

%------------ Save data ------------------
if (dic.AutoSaveFlag)
    destDir=dic.saveDir;
    thisFile=[mfilename('fullpath') '.m' ];
    [filePath fileName]=fileparts(thisFile);
    scriptText=fileread(thisFile);
    showData=[' figure; bar3(meanDensityM);view([-56.5 50]);axis([0 3 0 3 0 1]);'];
    saveFileName=fullfile(destDir ,[fileName datestr(now,'-ddmmmyy-HHMMSS')]);
    dicParameters=dic.getParameters;
    save(saveFileName,'meanDensityM','expResult','PulseTime','showData','dicParameters','scriptText');
    disp(['Save data in : ' saveFileName]);
end 

% ------------------------- Experiment sequence ------------------------------------    
    function [r]=experimentSeqeunce(par) 
    prog=CodeGenerator; 
    prog.GenDDSPullParametersFromBase;
    prog.GenSeq(Pulse('ExperimentTrigger',0,50));
    % initialization
    
    % Photon scattering 
    prog.GenRegOp('RegB=',0);
    prog.GenRegOp('RegC=',0);

    prog.GenRepeat;
        prog.GenSeq(Pulse('PMTsAccumulate',10,10));
        prog.GenRegOp('RegC=+1',0);
    prog.GenRepeatEnd('RegB>0');
    % A photon was measured
    prog.GenRegOp('FIFO<-RegB',0);
    prog.GenPause(0.1);
    prog.GenRegOp('FIFO<-RegC',0);
    prog.GenPause(5);
    prog.GenRegOp('FIFO<-AI1',0);

    % Ion detection 
    prog.GenSeq(Pulse('OnRes422',0,-1,'Amp',2000));      
    prog.GenSeq([Pulse('NoiseEater674',2,dic.T674-2) Pulse('674DDS1Switch',0,dic.T674)]);
    prog.GenSeq([Pulse('Repump1033',0,dic.T1033) Pulse('OffRes422',0,0)]);
    prog.GenFinish;


        %prog.DisplayCode;

        % FPGA/Host control
        n=dic.com.UploadCode(prog);
        dic.com.UpdateFpga;
        dic.com.WaitForHostIdle;
        rep=20;
        dic.com.Execute(rep);
        dic.com.WaitForHostIdle;
        r=dic.com.ReadOut(-1);        
    end
end


