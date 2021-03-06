function PhotonIonQEC_ProcTom
dic=Dictator.me;
% set wavw plates
 %dic.com.UpdateWavePlates(100,400);
% set RF DDS2 amplitude and frequency
Single_Pulse(Pulse('RFDDS2Switch',2,-1,'freq',dic.FRF,'amp',dic.ampRF));
piHalf=7;
Zp=[-1 0];
Zm=[dic.TimeRF 0];
Xp=[piHalf pi/2];
Xm=[piHalf pi*3/2];
Yp=[piHalf 0];
Ym=[piHalf pi];

initMeas=zeros(24,4);
ind=0;
initMeas(ind+1,:)=[Zp Zp];
initMeas(ind+2,:)=[Zp Zm];
initMeas(ind+3,:)=[Zp Xp];
initMeas(ind+4,:)=[Zp Xm];
initMeas(ind+5,:)=[Zp Yp];
initMeas(ind+6,:)=[Zp Ym];
ind=ind+6;
initMeas(ind+1,:)=[Zm Zp];
initMeas(ind+2,:)=[Zm Zm];
initMeas(ind+3,:)=[Zm Xp];
initMeas(ind+4,:)=[Zm Xm];
initMeas(ind+5,:)=[Zm Yp];
initMeas(ind+6,:)=[Zm Ym];
ind=ind+6;
initMeas(ind+1,:)=[Xp Zp];
initMeas(ind+2,:)=[Xp Zm];
initMeas(ind+3,:)=[Xp Xp];
initMeas(ind+4,:)=[Xp Xm];
initMeas(ind+5,:)=[Xp Yp];
initMeas(ind+6,:)=[Xp Ym];
ind=ind+6;
initMeas(ind+1,:)=[Yp Zp];
initMeas(ind+2,:)=[Yp Zm];
initMeas(ind+3,:)=[Yp Xp];
initMeas(ind+4,:)=[Yp Xm];
initMeas(ind+5,:)=[Yp Yp];
initMeas(ind+6,:)=[Yp Ym];
ind=ind+6;

% initMeas=zeros(6,4);
% ind=0;
% initMeas(ind+1,:)=[Xp Zp];
% initMeas(ind+2,:)=[Xp Zm];
% initMeas(ind+3,:)=[Xp Xp];
% initMeas(ind+4,:)=[Xp Xm];
% initMeas(ind+5,:)=[Xp Yp];
% initMeas(ind+6,:)=[Xp Ym];
% ind=ind+6;
%-------------- set GUI ---------------
InitializeAxes (dic.GUI.sca(1),'repetiton','Cases Counted #','rep Histogram',...
                [],[],0);
InitializeAxes (dic.GUI.sca(9),'meas #','prob','',[0 ind+1],[0 1],0);
repline =InitializeAxes (dic.GUI.sca(10),' phase ','repeation','',...
                        [0 ind],[],1);
set(repline,'XData',[],'YData',[],'Color','b',...
          'LineWidth',0.5,'Marker','.','MarkerSize',10);
InitializeAxes (dic.GUI.sca(11),'Photon Polarization','Ion State','\rho',...
                       [0 3],[0 3],0);

%-------------- main scan loop -----------
meanDensityM=zeros(2,2);
length_initMeas=size(initMeas,1);
DensityM=zeros(length_initMeas,2,2);
condProb=zeros(length_initMeas,2);
expRep=zeros(length_initMeas,1);
for ind1 =1:length_initMeas
    if (dic.stop)
        return;
    end
    dic.LasersLockedFlag=dic.com.GetLasersStatus; % check that the lasers are OK
    %--------------- run experiment sequence -------------------
    r=experimentSeqeunce(initMeas(ind1,1),initMeas(ind1,2),initMeas(ind1,3),initMeas(ind1,4));
    %--------------- basic result analysis ---------------------
    photon=1+(r(1:4:end)==1);
    ion=1+(r(4:4:end)>dic.darkCountThreshold);
    %photonPhase=(r(3:4:end)-4200)/3400*2;% (AI=~4200 ->7900) / 3400*2[pi] 
    expRep(ind1)=mean(r(2:4:end))*100;
    tempDensityM=zeros(2,2);
    for ind2=1:length(ion)
        tempDensityM(ion(ind2),photon(ind2))=tempDensityM(ion(ind2),photon(ind2))+1;
    end
    tempDensityM=tempDensityM/length(r)*4;
    DensityM(ind1,:,:)=tempDensityM;
    condProb(ind1,1)=tempDensityM(1,1)/(tempDensityM(1,1)+tempDensityM(2,1));
    condProb(ind1,2)=tempDensityM(1,2)/(tempDensityM(1,2)+tempDensityM(2,2));
    meanDensityM=meanDensityM+tempDensityM;
    %------------------------ plotting ------------------------- 
    % plot the mean repeatition 
    AddLinePoint(repline,ind1,expRep(ind1));
    dic.GUI.sca(1);
    hist(r(2:4:end)*100,linspace(0,32000,10));
    axis([0 32000 0 100]);
    dic.GUI.sca(9);
    bar(condProb);
    dic.GUI.sca(11);
    bar3(tempDensityM);view([-56.5 50]);
    axis([0.5 2.5 0.5 2.5 0 0.6])
    if (ind1==1)
        expResult=zeros(length_initMeas,length(r));
    end
    expResult(ind1,:)=r;
    pause(0.5);

end
meanDensityM=meanDensityM/length_initMeas;
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
    scriptText(find(int8(scriptText)==10))='';
    showData=['figure;bar(condProb);xlabel(''measurement #'');ylabel(''cond. prob. upH and upV'');'...
              'figure;plot(expRep);'];
    saveFileName=fullfile(destDir ,[fileName datestr(now,'-ddmmmyy-HHMMSS')]);
    dicParameters=dic.getParameters;
    save(saveFileName,'meanDensityM','expResult','expRep','initMeas','condProb','showData','dicParameters','scriptText');
    disp(['Save data in : ' saveFileName]);
end 

% ------------------------- Experiment sequence ------------------------------------    
    function res=experimentSeqeunce(initTime,initPhase,measureTime,measurePhase) 
    disp(sprintf('meausing: init state: %3.2f %3.2f measure basis: %3.2f %3.2f',...
                 initTime,initPhase,measureTime,measurePhase));
    prog=CodeGenerator; 
    prog.GenDDSPullParametersFromBase;
    prog.GenSeq(Pulse('OnRes422',0,-1,'amp',dic.weakOnResAmp));      
    prog.GenDDSPhaseWord(2,2,5.2);%set DDS2 phase word 2 to 0
    prog.GenSeq(Pulse('RFDDS2Switch',2,-1,'phase',initPhase+0.0));
    prog.GenSeq( Pulse('674DDS1Switch',5,-1,'freq',dic.updateF674,'amp',100) );
    %-------- cooling ------------------------
    prog.GenSeq(Pulse('OffRes422',0,500));
    prog.GenSeq(Pulse('OnResCooling',0,dic.Tcooling));
    % -------initializing and Photon scattering ------------
    prog.GenRegOp('RegA=',0);
    prog.GenRegOp('RegB=',0);
    prog.GenRegOp('RegC=',0);
    prog.GenRepeat
        prog.GenIfDo('RegC=',100)
            prog.GenRegOp('RegC=',0);
            prog.GenSeq(Pulse('OnResCooling',0,dic.Tcooling));
            prog.GenRegOp('RegA=+1',0);
        prog.GenElseDo
            prog.GenSeq([Pulse('Repump1092',2,10),...
                         Pulse('OpticalPumping',2,7),...
                         Pulse('674PulseShaper',10,initTime-2),...
                         Pulse('RFDDS2Switch',11,initTime)]);
            prog.GenDDSFSKState(2,1);% set DDS2 phase to phase word 2(=0)
            %prog.GenPause(12);% wait echo arm
            prog.GenSeq([Pulse('TACgate',1,3),...
                         Pulse('OnRes422',2,0.225),...
                         Pulse('PMTsAccumulate',3.125,0.100)]);
            prog.GenDDSFSKState(2,0);% set DDS2 phase to phase word 2(=0)
        prog.GenElseEnd;
        prog.GenRegOp('RegC=+1',0);
    prog.GenRepeatEnd('RegB>0');
    % A photon was measured
    prog.GenRegOp('FIFO<-RegB',0);
    prog.GenPause(0.1);
    prog.GenRegOp('FIFO<-RegA',0);
    prog.GenSeq(Pulse('OnRes422',2,-1,'Amp',dic.OnResAmp));  
    %---- quantum error correction logic --------
    prog.GenIfDo('RegB>',1000)  % if statement of the photon polarization 
        %for sigma-photon, pi pulse on the ion state with phase 0
        prog.GenPause(15);
        prog.GenRegOp('RegD=AI1toPhase',0);
        prog.GenRegOp('RegD*2^n',-2);
        prog.GenSeq([Pulse('674PulseShaper',0,dic.TimeRF-2),...
                     Pulse('RFDDS2Switch',1,dic.TimeRF,'phase',-1)]);
    prog.GenElseDo
        % for pi-photon, do only echo  
%         prog.GenSeq([Pulse('674PulseShaper',0,dic.TimeRF-2),...
%                      Pulse('RFDDS2Switch',1,dic.TimeRF)]);
%         prog.GenPause(15);
%         prog.GenSeq([Pulse('674PulseShaper',0,dic.TimeRF-2),...
%                      Pulse('RFDDS2Switch',1,dic.TimeRF)]);
    prog.GenElseEnd;
    prog.GenRegOp('FIFO<-AI1',0);
 
    %--------- Ion detection --------------------
    % qubit rotation for measuring in the wanted basis
    prog.GenSeq([Pulse('674PulseShaper',1,measureTime-2),...
                 Pulse('RFDDS2Switch',2,measureTime,'phase',measurePhase)]);    
    % double shelving pulses

    prog.GenSeq([Pulse('NoiseEater674',2,dic.T674-2) Pulse('674DDS1Switch',0,dic.T674)]);
    prog.GenSeq(Pulse('674DDS1Switch',5,12,'freq',dic.updateF674+4.09));
    prog.GenSeq(Pulse('ExperimentTrigger',0,10));
    % state flourescence detection
    prog.GenSeq([Pulse('Repump1092',0,0)...
                 Pulse('OnRes422',0,dic.TDetection)...
                 Pulse('PhotonCount',0,dic.TDetection)]);
    prog.GenSeq([Pulse('Repump1033',0,dic.T1033) Pulse('OffRes422',0,0)]);
    
    prog.GenFinish;
    %--------------------------------------------------
    %prog.DisplayCode;

    % FPGA/Host control
        rep=400;
        repMod50=round(rep/50);
        res=[];
        % using a for loop due to long integration time
        for j=1:repMod50
            n=dic.com.UploadCode(prog);
            dic.com.UpdateFpga;
            dic.com.WaitForHostIdle;
            dic.com.Execute(50);
            dic.com.WaitForHostIdle;
            res=[res; dic.com.ReadOut(-1)];
            pause(0.5);
            if dic.stop
                error('Program was stopped!');
            end
        end
    end
end


