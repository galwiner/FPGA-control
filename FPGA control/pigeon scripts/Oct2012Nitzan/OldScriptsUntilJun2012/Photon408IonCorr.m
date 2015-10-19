function Photon408IonCorr
dic=Dictator.me;

PulseTime=linspace(1,3,2);

%-------------- set GUI ---------------
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

%-------------- main scan loop -----------
for ind1 =1:length(PulseTime)
    r=experimentSeqeunce(PulseTime(ind1));
    photon=1+(r(1:3:end)==1);
    ion=1+(r(3:3:end)>dic.darkCountThreshold);
    DensityM=zeros(2,2);
    for ind=1:length(ion)
        DensityM(ion(ind),photon(ind))=DensityM(ion(ind),photon(ind))+1;
    end
    AddLinePoint(lines(1),PulseTime(ind1),sum(photon-1));
    AddLinePoint(lines(2),PulseTime(ind1),sum(ion-1));
    AddLinePoint(repline,PulseTime(ind1),mean(r(2:3:end)));

    disp(DensityM);
    disp(mean(r(2:3:end)));
    expResult(ind1,:)=r;
    pause(0.1);
end

%------------ Save data ------------------
if (dic.AutoSaveFlag)
    destDir=dic.saveDir;
    thisFile=[mfilename('fullpath') '.m' ];
    [filePath fileName]=fileparts(thisFile);
    scriptText=fileread(thisFile);
    showData=['disp(''no disp for this file'')'];
    saveFileName=fullfile(destDir ,[fileName datestr(now,'-ddmmmyy-HHMMSS')]);
    dicParameters=dic.getParameters;
    save(saveFileName,'expResult','PulseTime','showData','dicParameters','scriptText');
    disp(['Save data in : ' saveFileName]);
end 

% ------------------------- Experiment sequence ------------------------------------    
    function [r]=experimentSeqeunce(pTime) 
    prog=CodeGenerator; 
    prog.GenDDSPullParametersFromBase;
    
    prog.GenSeq(Pulse('ExperimentTrigger',0,50));
    prog.GenSeq(Pulse('RFDDS2',0,-1,'freq',dic.FRF));
    prog.GenSeq( Pulse('674DDS1Switch',0,-1,'freq',dic.updateF674,'amp',100) );
    %initialization
    prog.GenSeq(Pulse('OffRes422',0,100));
    prog.GenSeq(Pulse('OnResCooling',0,dic.Tcooling));
    %prog.GenSeq(Pulse('OpticalPumping',0,dic.Toptpump));
    % Photon scattering 
    prog.GenRegOp('RegB=',0);
    prog.GenRegOp('RegC=',0);
    prog.GenRepeat
         prog.GenSeq([Pulse('Repump1033',5,10),...
                      Pulse('OpticalPumping',5,5),...
                      Pulse('NoiseEater674',16,dic.T674),...
                      Pulse('674DDS1Switch',16,dic.T674),...
                      Pulse('Repump1033',18+dic.T674,pTime),...
                      Pulse('PMTsAccumulate',18.5+dic.T674,pTime)]);

    prog.GenRegOp('RegC=+1',0);
    prog.GenRepeatEnd('RegB>0');
    % A photon was measured
    prog.GenRegOp('FIFO<-RegB',0);
    prog.GenPause(0.1);
    prog.GenRegOp('FIFO<-RegC',0);
    % Ion detection 
  
    prog.GenSeq(Pulse('674DDS1Switch',0,dic.T674));
    prog.GenSeq([Pulse('OnRes422',0,dic.TDetection)...
                 Pulse('PhotonCount',0,dic.TDetection)]);
    prog.GenSeq(Pulse('OffRes422',0,0));
    prog.GenFinish;


        %prog.DisplayCode;

        % FPGA/Host control
        n=dic.com.UploadCode(prog);
        dic.com.UpdateFpga;
        dic.com.WaitForHostIdle;
        rep=300;
        dic.com.Execute(rep);
        dic.com.WaitForHostIdle;
        r=dic.com.ReadOut(-1);        
    end
end


