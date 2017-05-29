function PhotonIonNullProcTom
dic=Dictator.me;
% pi excitation

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

% initMeas=zeros(2,4);
% ind=0;
% initMeas(ind+1,:)=[Zp Zp];
% initMeas(ind+2,:)=[Zp Zm];
% initMeas(ind+3,:)=[Zm Zm];
% ind=ind+3;
%-------------- set GUI ---------------
InitializeAxes (dic.GUI.sca(1),'repetiton','Cases Counted #','rep Histogram',...
                [],[],0);
InitializeAxes (dic.GUI.sca(9),'meas #','prob','',[-2 ind+1],[0 1],0);
repline =InitializeAxes (dic.GUI.sca(10),' phase ','repeation','',...
                        [0 ind],[],1);
set(repline,'XData',[],'YData',[],'Color','b',...
          'LineWidth',0.5,'Marker','.','MarkerSize',10);
InitializeAxes (dic.GUI.sca(11),'Photon Polarization','Ion State','\rho',...
                       [0 3],[0 3],0);

%-------------- main scan loop -----------
length_initMeas=size(initMeas,1);

upProb=zeros(length_initMeas,1);
for ind1 =1:length_initMeas
    if (dic.stop)
        return;
    end
    dic.LasersLockedFlag=dic.com.GetLasersStatus; % check that the lasers are OK
    %--------------- run experiment sequence -------------------
    r=experimentSeqeunce(initMeas(ind1,1),initMeas(ind1,2),initMeas(ind1,3),initMeas(ind1,4));
    %--------------- basic result analysis ---------------------
      upProb(ind1)=mean(r>dic.darkCountThreshold);

    %------------------------ plotting ------------------------- 
    dic.GUI.sca(1);
    hist(r,0:30);
    axis([0 30 0 50]);
    dic.GUI.sca(9);
    bar(upProb);

    if (ind1==1)
        expResult=zeros(length_initMeas,length(r));
    end
    expResult(ind1,:)=r;
    pause(0.5);

end


%------------ Save data ------------------
if (dic.AutoSaveFlag)
    destDir=dic.saveDir;
    thisFile=[mfilename('fullpath') '.m' ];
    [filePath fileName]=fileparts(thisFile);
    scriptText=fileread(thisFile);
    scriptText(find(int8(scriptText)==10))='';
    showData=['figure;bar(upProb);xlabel(''measurement #'');ylabel(''upProb'');'];
    saveFileName=fullfile(destDir ,[fileName datestr(now,'-ddmmmyy-HHMMSS')]);
    dicParameters=dic.getParameters;
    save(saveFileName,'expResult','upProb','showData','dicParameters','scriptText');
    disp(['Save data in : ' saveFileName]);
end 

% ------------------------- Experiment sequence ------------------------------------    
    function res=experimentSeqeunce(initTime,initPhase,measureTime,measurePhase) 
    disp(sprintf('meausing: init state: %3.2f %3.2f measure basis: %3.2f %3.2f',...
                 initTime,initPhase,measureTime,measurePhase));
    prog=CodeGenerator; 
    prog.GenDDSPullParametersFromBase;
    
    %--------------- scattering exp ----------------------------------
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
    prog.GenSeq(Pulse('OnRes422',2,-1,'Amp',dic.OnResAmp));  
    prog.GenSeq(Pulse('Repump1092',0,0));
    %--------- new null Process exp ---------------------------- 
    prog.GenSeq(Pulse('ExperimentTrigger',0,50));
    prog.GenSeq(Pulse('RFDDS2Switch',2,-1,'phase',initPhase));
    prog.GenSeq( Pulse('674DDS1Switch',5,-1,'freq',dic.updateF674,'amp',100) );
    %
    %-------- cooling ------------------------
%     prog.GenSeq(Pulse('OffRes422',0,500));
%     prog.GenSeq(Pulse('OnResCooling',0,dic.Tcooling));
    % -------initializing and Photon scattering ------------
    prog.GenSeq(Pulse('OpticalPumping',0,10));
    prog.GenSeq([Pulse('674PulseShaper',3,initTime-2),...
                 Pulse('RFDDS2Switch',4,initTime)]);    
    prog.GenPause(10);
    %--------- Ion detection -------------------------
    % qubit rotation for measuring in the wanted basis
    prog.GenSeq([Pulse('674PulseShaper',1,measureTime-2),...
                 Pulse('RFDDS2Switch',2,measureTime,'phase',measurePhase)]);    
    % double shelving pulses
    prog.GenSeq([Pulse('NoiseEater674',2,dic.T674-2) Pulse('674DDS1Switch',0,dic.T674)]);
    prog.GenSeq(Pulse('674DDS1Switch',5,12,'freq',dic.updateF674+4.09));
    % state flourescence detection
    prog.GenSeq([Pulse('OnRes422',0,dic.TDetection)...
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


