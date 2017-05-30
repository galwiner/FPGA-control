function PhotonIonQEC_RT
dic=Dictator.me;
% pi excitation
piHalf=7; %RF pi/2 time. not= dic.TimeRF/2 becuase of the pulse-shaper 
dic.com.UpdateWavePlates(470,485);

%measure and set FRF
%RamseyFreqRF;
Single_Pulse(Pulse('RFDDS2Switch',2,-1,'freq',dic.FRF,'amp',dic.ampRF));
 PulsePhase=linspace(0,2*pi,20); % only use as a dummy variable
%PulsePhase=linspace(pi/2-0.1,pi/2+0.1,10); % only use as a dummy variable

%-------------- set GUI ---------------
InitializeAxes (dic.GUI.sca(1),'phase [pi]','Cases Counted #','rep Histogram',...
                [],[],0);
lines =InitializeAxes (dic.GUI.sca(10),'phase','prob','',...
                       [PulsePhase(1) PulsePhase(end)],[0 1],2);
set(lines(1),'XData',[],'YData',[],'Color','b',...
          'LineWidth',0.5,'Marker','.','MarkerSize',10);
set(lines(2),'XData',[],'YData',[],'Color','r',...
          'LineWidth',0.5,'Marker','.','MarkerSize',10);
repline =InitializeAxes (dic.GUI.sca(9),' phase ','repeation','',...
                       [PulsePhase(1) PulsePhase(end)],[],1);
set(repline,'XData',[],'YData',[],'Color','b',...
          'LineWidth',0.5,'Marker','.','MarkerSize',10);
InitializeAxes (dic.GUI.sca(11),'Photn Polarization','Ion State','\rho',...
                       [0 3],[0 3],0);

%-------------- main scan loop -----------
meanDensityM=zeros(2,2);
condProb=zeros(2,length(PulsePhase));
expRep=zeros(length(PulsePhase),1);
for ind1 =1:length(PulsePhase)
    if (dic.stop)
        return;
    end
    dic.LasersLockedFlag=dic.com.GetLasersStatus; % check that the lasers are OK
    r=experimentSeqeunce(PulsePhase(ind1));
    photon=1+(r(1:4:end)==1);
    ion=1+(r(4:4:end)>dic.darkCountThreshold);
    %photonPhase=(r(3:4:end)-4200)/3400*2;% (AI=~4200 ->7900) / 3400*2[pi] 
    expRep(ind1)=mean(r(2:4:end))*50;
    DensityM=zeros(2,2);
    for ind=1:length(ion)
        DensityM(ion(ind),photon(ind))=DensityM(ion(ind),photon(ind))+1;
    end
    DensityM=DensityM/length(r)*4;
    condProb(1,ind1)=DensityM(1,1)/(DensityM(1,1)+DensityM(2,1));
    condProb(2,ind1)=DensityM(1,2)/(DensityM(1,2)+DensityM(2,2));
    meanDensityM=meanDensityM+DensityM;
    % plot 
    AddLinePoint(lines(1),PulsePhase(ind1),condProb(1,ind1));
    AddLinePoint(lines(2),PulsePhase(ind1),condProb(2,ind1));
    AddLinePoint(repline,PulsePhase(ind1),expRep(ind1));
    dic.GUI.sca(1);
    hist(r(2:4:end),linspace(0,32000,10));
    axis([0 32000 0 100]);
    dic.GUI.sca(11);
    bar3(DensityM);view([-56.5 50]);
    axis([0.5 2.5 0.5 2.5 0 0.6])
    if (ind1==1)
        expResult=zeros(length(PulsePhase),length(r));
    end
    expResult(ind1,:)=r;
    pause(0.5);

end
meanDensityM=meanDensityM/length(PulsePhase);
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
    showData=['figure;plot(PulsePhase,condProb(1,:),''-ob'',PulsePhase,condProb(2,:),''-xr''); axis([0 6.3 0 1]);'...
              'xlabel(''photon phase'');ylabel(''cond. prob. upH and upV'');'...
              'figure;plot(PulsePhase,expRep);'];
    saveFileName=fullfile(destDir ,[fileName datestr(now,'-ddmmmyy-HHMMSS')]);
    dicParameters=dic.getParameters;
    save(saveFileName,'meanDensityM','expResult','PulsePhase','expRep','condProb','showData','dicParameters','scriptText');
    disp(['Save data in : ' saveFileName]);
end 

% ------------------------- Experiment sequence ------------------------------------    
    function res=experimentSeqeunce(par) 
    prog=CodeGenerator; 
    prog.GenDDSPullParametersFromBase;
    prog.GenSeq(Pulse('OnRes422',0,-1,'amp',dic.weakOnResAmp));      
    prog.GenDDSPhaseWord(2,2,5.2);%set DDS2 phase word 2 to 0
    prog.GenSeq(Pulse('RFDDS2Switch',2,-1,'phase',0));
    prog.GenSeq( Pulse('674DDS1Switch',2,-1,'freq',dic.updateF674,'amp',100) );
    %-------- cooling ------------------------
    prog.GenSeq(Pulse('OffRes422',0,500));
    prog.GenSeq(Pulse('OnResCooling',0,dic.Tcooling));
    % -------initializing and Photon scattering ------------
    prog.GenRegOp('RegA=',0);
    prog.GenRegOp('RegB=',0);
    prog.GenRegOp('RegC=',0);
    prog.GenRepeat
        prog.GenIfDo('RegC=',50)
            prog.GenRegOp('RegC=',0);
            prog.GenSeq([Pulse('Repump1092',0,50),Pulse('OnResCooling',0,50)]);
            prog.GenRegOp('RegA=+1',0);
        prog.GenElseDo
            prog.GenSeq([Pulse('Repump1092',2,8),...
                         Pulse('OpticalPumping',2,5),...
                         Pulse('674PulseShaper',10,piHalf-2),...
                         Pulse('RFDDS2Switch',11,piHalf)]);
            prog.GenDDSFSKState(2,1);% set DDS2 phase to phase word 2(=0)
%            prog.GenPause(12);% wait echo arm
            prog.GenSeq([Pulse('TACgate',1,3),...
                         Pulse('OnRes422',2,0.150),...
                         Pulse('PMTsAccumulate',3.0,0.125)]);
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
    prog.GenIfDo('RegB>',1)  % if statement of the photon polarization 
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
    % second Ramsey pulse
    prog.GenSeq([Pulse('674PulseShaper',0,piHalf-2),...
                 Pulse('RFDDS2Switch',1,piHalf,'phase',par)]);    

    %--------- Ion detection -------------------- 
    prog.GenSeq([Pulse('NoiseEater674',2,dic.T674-2) Pulse('674DDS1Switch',0,dic.T674)]);
    prog.GenSeq(Pulse('674DDS1Switch',5,15,'freq',dic.updateF674+4.09));
    prog.GenSeq(Pulse('ExperimentTrigger',0,10));
    prog.GenSeq([Pulse('Repump1092',0,0)...
                 Pulse('OnRes422',0,dic.TDetection)...
                 Pulse('PhotonCount',0,dic.TDetection)]);
    prog.GenSeq([Pulse('Repump1033',0,dic.T1033) Pulse('OffRes422',0,0)]);
    prog.GenFinish;


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


