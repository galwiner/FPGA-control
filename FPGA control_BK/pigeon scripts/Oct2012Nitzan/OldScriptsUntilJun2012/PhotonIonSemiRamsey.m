function PhotonIonSemiRamsey(angle)
dic=Dictator.me;
% pi excitation 
dic.com.UpdateWavePlates(475+250,475);
SecondpulseTime=7;
freqshift=1.2046*dic.FRF;
%measure and set FRF
%RamseyFreqRF;
%Single_Pulse(Pulse('RFDDS2Switch',2,-1,'freq',dic.FRF,'amp',dic.ampRF));

PhaseBins=linspace(0,2*pi,20); % only use as a dummy variable
%PulsePhase=linspace(pi/2-0.1,pi/2+0.1,10); % only use as a dummy variable

%-------------- set GUI ---------------
InitializeAxes (dic.GUI.sca(1),'phase [pi]','Cases Counted #','rep Histogram',...
                [],[],0);
InitializeAxes (dic.GUI.sca(10),'phase','prob','init to up',...
                       [PhaseBins(1) PhaseBins(end)],[0 1],0);
InitializeAxes (dic.GUI.sca(11),'phase','prob','init to down',...
                       [PhaseBins(1) PhaseBins(end)],[0 1],0);
repline =InitializeAxes (dic.GUI.sca(9),' phase ','repeation','',...
                       [PhaseBins(1) PhaseBins(end)],[],1);
set(repline,'XData',[],'YData',[],'Color','b',...
          'LineWidth',0.5,'Marker','.','MarkerSize',10);

%-------------- main scan loop -----------

expRep=zeros(length(PhaseBins),1);
condProb1=zeros(length(PhaseBins),2);
condProbCounts1=zeros(length(PhaseBins),2);
condProb2=zeros(length(PhaseBins),2);
condProbCounts2=zeros(length(PhaseBins),2);
for ind1 =1:length(PhaseBins)
    if (dic.stop)
        return;
    end
    dic.LasersLockedFlag=dic.com.GetLasersStatus; % check that the lasers are OK
    % Init to state 1 = up
    r=experimentSeqeunce(0);
    photon=reshape(1+(r(1:4:end)==1),1,[]);
    ion=reshape(1+(r(4:4:end)<8),1,[]); %=2 if dark=up
    expRep(ind1)=mean(r(2:4:end))*25;
    photonPhase=reshape((r(3:4:end)-4200)/3250*2*pi,1,[]);
    [counts,binInd]=histc(photonPhase,PhaseBins);
    for ind=1:length(ion)
        if (binInd(ind)>0)
            condProb1(binInd(ind),photon(ind))=condProb1(binInd(ind),photon(ind))+(ion(ind)-1);
            condProbCounts1(binInd(ind),photon(ind))=condProbCounts1(binInd(ind),photon(ind))+1;
        end
    end
    
    if (ind1==1)
        expResult1=zeros(length(PhaseBins),length(r));
        expResult2=zeros(length(PhaseBins),length(r));
    end 
    expResult1(ind1,:)=r;

    % Init to state 2 = down
    r=experimentSeqeunce(dic.TimeRF);
    photon=reshape(1+(r(1:4:end)==1),1,[]);
    ion=reshape(1+(r(4:4:end)<8),1,[]); %=2 if dark=up
    photonPhase=reshape((r(3:4:end)-4200)/3250*2*pi,1,[]);
    [counts,binInd]=histc(photonPhase,PhaseBins);
    for ind=1:length(ion)
        if (binInd(ind)>0)
            condProb2(binInd(ind),photon(ind))=condProb2(binInd(ind),photon(ind))+(ion(ind)-1);
            condProbCounts2(binInd(ind),photon(ind))=condProbCounts2(binInd(ind),photon(ind))+1;
        end
    end
    expResult2(ind1,:)=r;
    
    % ploting 
    AddLinePoint(repline,PhaseBins(ind1),expRep(ind1));
    dic.GUI.sca(10);
    plot(PhaseBins(1:end-1),condProb1(1:end-1,1)./condProbCounts1(1:end-1,1),'-ob',...
         PhaseBins(1:end-1),condProb1(1:end-1,2)./condProbCounts1(1:end-1,2),'-or');
    dic.GUI.sca(11);
    plot(PhaseBins(1:end-1),condProb2(1:end-1,1)./condProbCounts2(1:end-1,1),'-ob',...
         PhaseBins(1:end-1),condProb2(1:end-1,2)./condProbCounts2(1:end-1,2),'-or');
   
    pause(0.5);

end


%------------ Save data ------------------
if (dic.AutoSaveFlag)
    destDir=dic.saveDir;
    thisFile=[mfilename('fullpath') '.m' ];
    [filePath fileName]=fileparts(thisFile);
    scriptText=fileread(thisFile);
    scriptText(find(int8(scriptText)==10))='';
    showData=['figure;plot(PhaseBins(1:end-1),condProb1(1:end-1,1)./condProbCounts1(1:end-1,1)'...
              ',PhaseBins(1:end-1),condProb1(1:end-1,2)./condProbCounts1(1:end-1,2));'...
              'xlabel(''photon phase'');ylabel(''cond. prob. upH and upV'');'...
              'figure;plot(PhaseBins(1:end-1),condProb2(1:end-1,1)./condProbCounts2(1:end-1,1)'...
              ',PhaseBins(1:end-1),condProb2(1:end-1,2)./condProbCounts2(1:end-1,2));'...
              'xlabel(''photon phase'');ylabel(''cond. prob. upH and upV'');'...
              'figure;plot(PhaseBins,expRep);'];
    saveFileName=fullfile(destDir ,[fileName datestr(now,'-ddmmmyy-HHMMSS')]);
    dicParameters=dic.getParameters;
    save(saveFileName,'angle','expResult1','expResult2','PhaseBins','expRep',...
        'condProb1','condProb2','condProbCounts1','condProbCounts2','showData'...
        ,'dicParameters','scriptText');
    disp(['Save data in : ' saveFileName]);
end 

% ------------------------- Experiment sequence ------------------------------------    
    function res=experimentSeqeunce(par) 
    prog=CodeGenerator; 
    prog.GenDDSPullParametersFromBase;
    prog.GenSeq(Pulse('OnRes422',0,-1,'amp',dic.weakOnResAmp));      
    prog.GenDDSPhaseWord(2,2,0);%set DDS2 phase word 2 to 0
    prog.GenSeq(Pulse('RFDDS2Switch',2,-1,'freq',dic.FRF,'phase',0));
    prog.GenSeq( Pulse('674DDS1Switch',2,-1,'freq',dic.updateF674,'amp',100) );
    %-------- cooling ------------------------
    prog.GenSeq(Pulse('OffRes422',0,500));
    prog.GenSeq(Pulse('OnResCooling',0,dic.Tcooling));
    % -------initializing and Photon scattering ------------
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
            if par>0
                prog.GenSeq([Pulse('Repump1092',2,8),...
                             Pulse('OpticalPumping',2,5),...
                             Pulse('674PulseShaper',10,par-1),...
                             Pulse('RFDDS2Switch',11,par)]);
            else
                prog.GenSeq([Pulse('Repump1092',2,8),...
                             Pulse('OpticalPumping',2,5)]);
                prog.GenPause(12);         
            end
            %prog.GenDDSFSKState(2,1);% set DDS2 phase to phase word 2(=0)
            prog.GenSeq([Pulse('TACgate',1,3),...
                         Pulse('OnRes422',2,0.175),...
                         Pulse('PMTsAccumulate',3.0,0.125)]);
           % prog.GenDDSFSKState(2,0);% set DDS2 phase to phase word 2(=0)
        prog.GenElseEnd;
        prog.GenRegOp('RegC=+1',0);

    prog.GenRepeatEnd('RegB>0');
    % A photon was measured
    prog.GenRegOp('FIFO<-RegB',0);
    prog.GenPause(0.1);
    prog.GenRegOp('FIFO<-RegA',0);
    prog.GenSeq(Pulse('OnRes422',2,-1,'Amp',dic.OnResAmp));  
    prog.GenSeq(Pulse('Repump1092',0,0));
    prog.GenPause(15); 
    prog.GenRegOp('FIFO<-AI1',0);

    % second Ramsey pulse
    prog.GenSeq([Pulse('674PulseShaper',0,dic.piHalfRF-1),...
                 Pulse('RFDDS2Switch',1,dic.piHalfRF,'phase',0)]);    

    %--------- Ion detection -------------------- 
    % fisrt shelving pulse
    prog.GenSeq([Pulse('NoiseEater674',2,dic.T674-2) Pulse('674DDS1Switch',0,dic.T674)]);
    % second shelving pulse
    prog.GenSeq(Pulse('674DDS1Switch',5,SecondpulseTime,'freq',dic.updateF674+freqshift));
    % scope triger
    prog.GenSeq(Pulse('ExperimentTrigger',0,10));
    % flourescence
    prog.GenSeq([ Pulse('OnRes422',0,dic.TDetection)...
                 Pulse('PhotonCount',0,dic.TDetection)]);
    % D puming in offres cooling
    prog.GenSeq([Pulse('Repump1033',0,dic.T1033) Pulse('OffRes422',0,0)]);
    prog.GenFinish;


        %prog.DisplayCode;

        % FPGA/Host control 
        rep=200;
        repMod50=round(rep/50);
        res=[];
        % using a for loop due to long integration time
        for j=1:repMod50
            n=dic.com.UploadCode(prog,20*(1:25));
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


