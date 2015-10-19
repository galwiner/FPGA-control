function PhotonIonCorr2DMap(varargin)
dic=Dictator.me;
WP1=0:50:1000;
WP2=0:50:1800;

% %--------options-------------
% for i=1:2:size(varargin,2)
%     switch lower(char(varargin(i)))
%         case 'wp1'
%             WP1=varargin{i+1};
%         case 'wp2'
%             WP2=varargin{i+1};
%     end; %switch
% end;%for loop% pi excitation
% dic.com.UpdateWavePlates(WP1,WP2);

%-------------- set GUI ---------------
InitializeAxes (dic.GUI.sca(1),'repeation','Cases Counted #','repeation Histogram',...
                [],[],0);

% lines =InitializeAxes (dic.GUI.sca(9),'excitation time [\mus]','H pol','',...
%                        [PulseTime(1) PulseTime(end)],[],2);
% set(lines(1),'XData',[],'YData',[],'Color','b',...
%           'LineWidth',0.5,'Marker','.','MarkerSize',10);
% set(lines(2),'XData',[],'YData',[],'Color','r',...
%           'LineWidth',0.5,'Marker','.','MarkerSize',10);
InitializeAxes (dic.GUI.sca(10),'excitation time [\mus]','repeation','',...
                        [WP1(1) WP1(end)],[WP2(1) WP2(end)],0);
% set(repline,'XData',[],'YData',[],'Color','b',...
%           'LineWidth',0.5,'Marker','.','MarkerSize',10);
InitializeAxes (dic.GUI.sca(11),'Photn Polarization','Ion State','\rho',...
                       [0 3],[0 3],0);

set(dic.GUI.sca(11),'XTickLabel','H|V','YTickLabel','up|down');

%-------------- main scan loop -----------

E=zeros(length(WP1),length(WP2));
for ind1 =1:length(WP1)
    dic.com.UpdateWavePlates(WP1(ind1),WP2(1)-100);
    for ind2 =1:length(WP2)        
        if (dic.stop)
            return;
        end
        dic.com.UpdateWavePlates(WP1(ind1),WP2(ind2));
        pause(1);
        r=experimentSeqeunce();
        photon=1+(r(1:3:end)==1);
        ion=1+(r(3:3:end)>dic.darkCountThreshold);
        
        DensityM=zeros(2,2);
        for ind=1:length(ion)
            DensityM(ion(ind),photon(ind))=DensityM(ion(ind),photon(ind))+1;
        end
        DensityM=DensityM/length(r)*3;
        E(ind1,ind2)=DensityM(1,1)+DensityM(2,2);
        disp(sprintf('rep=%f E= %f',mean(r(2:3:end))*25,E(ind1,ind2)));
        dic.GUI.sca(10);
        imagesc(WP1,WP2,E);
        %disp(DensityM);
        dic.GUI.sca(11);
        bar3(DensityM);view([-56.5 50]);
        axis([0.5 2.5 0.5 2.5 0 0.6])
        expResult(ind1,ind2,:)=r;
        pause(0.5);
        
    end
end
% disp(sprintf('     |  H  |  V   \n-----|-----|------\n  up |%3.2f | %3.2f \n down|%3.2f | %3.2f',...
%              meanDensityM(1,1),meanDensityM(1,2),meanDensityM(2,1),meanDensityM(2,2))); 
% disp(sprintf('Prob for up given H =%f', meanDensityM(1,1)/(meanDensityM(1,1)+meanDensityM(2,1)) ));
% disp(sprintf('Prob for up given V =%f', meanDensityM(1,2)/(meanDensityM(1,2)+meanDensityM(2,2)) ));
% dic.GUI.sca(11);
% bar3(meanDensityM);view([-56.5 50]);

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
    save(saveFileName,'WP1','WP2','E','expResult','showData','dicParameters','scriptText');
    disp(['Save data in : ' saveFileName]);
end 

% ------------------------- Experiment sequence ------------------------------------    
    function [res]=experimentSeqeunce 
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
%             prog.GenSeq([Pulse('674PulseShaper',1,dic.TimeRF-1),...
%                          Pulse('RFDDS2Switch',2,dic.TimeRF)]);
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
        rep=400;
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
            pause(1);
            if dic.stop
                error('Program was stopped!');
            end
        end 
    end
end


