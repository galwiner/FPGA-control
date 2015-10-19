function PhotonIonEntaglement
dic=Dictator.me;
% pi excitation
dic.com.UpdateWavePlates(325,400);
PulseTime=1:10; % only use as a dummy variable

%-------------- set GUI ---------------
InitializeAxes (dic.GUI.sca(1),'phase [pi]','Cases Counted #','Osc phase Histogram',...
                [],[],0);
InitializeAxes (dic.GUI.sca(5),'phase [pi]','Cases Counted #','prob',...
                [],[],0);
lines =InitializeAxes (dic.GUI.sca(10),'#','prob','',...
                       [PulseTime(1) PulseTime(end)],[],2);
set(lines(1),'XData',[],'YData',[],'Color','b',...
          'LineWidth',0.5,'Marker','.','MarkerSize',10);
set(lines(2),'XData',[],'YData',[],'Color','r',...
          'LineWidth',0.5,'Marker','.','MarkerSize',10);
repline =InitializeAxes (dic.GUI.sca(9),' # ','repeation','',...
                       [PulseTime(1) PulseTime(end)],[],1);
set(repline,'XData',[],'YData',[],'Color','b',...
          'LineWidth',0.5,'Marker','.','MarkerSize',10);
InitializeAxes (dic.GUI.sca(11),'Photn Polarization','Ion State','\rho',...
                       [0 3],[0 3],0);

%-------------- main scan loop -----------
meanDensityM=zeros(2,2);
phaseBins=linspace(0,2,20);
condProb=zeros(length(phaseBins),2);
condProbCounts=zeros(length(phaseBins),2);
for ind1 =1:length(PulseTime)
    if (dic.stop)
        return;
    end

    r=experimentSeqeunce(PulseTime(ind1));
    photon=1+(r(1:4:end)==1);
    ion=1+(r(4:4:end)>dic.darkCountThreshold);
    photonPhase=(r(3:4:end)-4200)/3400*2;% (AI=~4200 ->7900) / 3400*2[pi] 
    [counts,binInd]=histc(photonPhase,phaseBins);
    DensityM=zeros(2,2);
    for ind=1:length(ion)
        DensityM(ion(ind),photon(ind))=DensityM(ion(ind),photon(ind))+1;
        if (binInd(ind)>0)
        condProb(binInd(ind),photon(ind))=condProb(binInd(ind),photon(ind))...
                                          + (ion(ind)-1);
        condProbCounts(binInd(ind),photon(ind))=condProbCounts(binInd(ind),photon(ind))+1;
        end
    end
    DensityM=DensityM/length(r)*4;
    meanDensityM=meanDensityM+DensityM;
    % plot 
    dic.GUI.sca(5);
    plot(phaseBins,condProb(:,1)./condProbCounts(:,1),'-ob',...
         phaseBins,condProb(:,2)./condProbCounts(:,2),'-xr');
    axis([0 2 0 1]);
    AddLinePoint(lines(1),PulseTime(ind1),sum(photon-1));
    AddLinePoint(lines(2),PulseTime(ind1),sum(ion-1));
    AddLinePoint(repline,PulseTime(ind1),mean(r(2:4:end)));
    dic.GUI.sca(1);
    bar(phaseBins,condProbCounts);
    axis([0 2 0 300]);
    dic.GUI.sca(11);
    bar3(DensityM);view([-56.5 50]);
    axis([0.5 2.5 0.5 2.5 0 0.6])
    expResult(ind1,:)=r;
    pause(0.5);

end
meanDensityM=meanDensityM/length(PulseTime);
disp('the average density matrix:'); 
disp(meanDensityM);
dic.GUI.sca(11);
bar3(meanDensityM);view([-56.5 50]);

%------------ Save data ------------------
if (dic.AutoSaveFlag)
    destDir=dic.saveDir;
    thisFile=[mfilename('fullpath') '.m' ];
    [filePath fileName]=fileparts(thisFile);
    scriptText=fileread(thisFile);
    showData=['figure;plot(phaseBins,condProb(:,1)./condProbCounts(:,1),''-ob'',phaseBins,condProb(:,2)./condProbCounts(:,2),''-xr''); axis([0 2 0 1]);'...
              'figure;bar(phaseBins,condProbCounts);'];
    saveFileName=fullfile(destDir ,[fileName datestr(now,'-ddmmmyy-HHMMSS')]);
    dicParameters=dic.getParameters;
    save(saveFileName,'meanDensityM','expResult','phaseBins','condProb','condProbCounts','PulseTime','showData','dicParameters','scriptText');
    disp(['Save data in : ' saveFileName]);
end 

% ------------------------- Experiment sequence ------------------------------------    
    function [r]=experimentSeqeunce(par) 
    prog=CodeGenerator; 
    prog.GenDDSPullParametersFromBase;
    prog.GenSeq(Pulse('OnRes422',0,-1,'amp',1000));      
    prog.GenSeq(Pulse('ExperimentTrigger',0,50));
    prog.GenSeq(Pulse('RFDDS2Switch',0,-1,'freq',dic.FRF));
    prog.GenSeq( Pulse('674DDS1Switch',0,-1,'freq',dic.updateF674,'amp',100) );
    %initialization
    prog.GenSeq(Pulse('OffRes422',0,100));
    prog.GenSeq(Pulse('OnResCooling',0,dic.Tcooling));
    prog.GenSeq(Pulse('OpticalPumping',0,dic.Toptpump));
    % Photon scattering 
    prog.GenRegOp('RegB=',0);
    prog.GenRegOp('RegC=',0);
    % flip qubit pulse : Pulse('RFDDS2',8,dic.TimeRF),...
    prog.GenRepeat
            prog.GenSeq([Pulse('Repump1092',2,9),...
                         Pulse('OpticalPumping',2,6),...
                         Pulse('TACgate',10,4),...
                         Pulse('OnRes422',12,0.225),...
                         Pulse('PMTsAccumulate',13.125,0.125)]);
    prog.GenRegOp('RegC=+1',0);
    prog.GenRepeatEnd('RegB>0');
    % A photon was measured
    prog.GenRegOp('FIFO<-RegB',0);
    prog.GenPause(0.1);
    prog.GenRegOp('FIFO<-RegC',0);
    prog.GenPause(15);
    prog.GenRegOp('FIFO<-AI1',0);
    prog.GenSeq(Pulse('OnRes422',10,-1,'Amp',2000));  
    % pi/2 pulse on the ion state
    prog.GenSeq(Pulse('RFDDS2Switch',1,dic.TimeRF/2));
    % Ion detection 
    prog.GenSeq([Pulse('NoiseEater674',2,dic.T674-2) Pulse('674DDS1Switch',0,dic.T674)]);
    prog.GenSeq(Pulse('674DDS1Switch',5,9,'freq',dic.updateF674+4.09));

    prog.GenSeq([Pulse('Repump1092',0,0)...
                 Pulse('OnRes422',0,dic.TDetection)...
                 Pulse('PhotonCount',0,dic.TDetection)]);
    prog.GenSeq([Pulse('Repump1033',0,dic.T1033) Pulse('OffRes422',0,0)]);
    prog.GenFinish;


        %prog.DisplayCode;

        % FPGA/Host control
        n=dic.com.UploadCode(prog);
        dic.com.UpdateFpga;
        dic.com.WaitForHostIdle;
        rep=100;
        dic.com.Execute(rep);
        dic.com.WaitForHostIdle;
        r=dic.com.ReadOut(-1);        
    end
end


