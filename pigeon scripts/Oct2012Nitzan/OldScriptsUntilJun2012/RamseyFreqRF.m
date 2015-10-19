function RamseyFreqRF
dic=Dictator.me;
%piHalf=7;% for FRF=3.401

freqList=dic.FRF+linspace(-0.001,0.001,10);
%-------------- set GUI ---------------
lines=InitializeAxes (dic.GUI.sca(5),'meas #','prob','',[freqList(1) freqList(end)],[-1 1],2);
set(lines(1),'XData',[],'YData',[],'Color','b',...
          'LineWidth',0.5,'Marker','.','MarkerSize',10);
set(lines(2),'XData',[],'YData',[],'Color','r',...
          'LineWidth',0.5,'Marker','.','MarkerSize',10);
%-------------- main scan loop -----------

upProb=zeros(length(freqList),2);
for ind1 =1:length(freqList)
    if (dic.stop)
        return;
    end
    dic.LasersLockedFlag=dic.com.GetLasersStatus; % check that the lasers are OK
    %--------------- run experiment sequence -------------------
    r1=experimentSeqeunce(freqList(ind1),pi/2);
    r2=experimentSeqeunce(freqList(ind1),3*pi/2);

    %--------------- basic result analysis ---------------------
    upProb(ind1,1)=mean(r1>dic.darkCountThreshold);
    upProb(ind1,2)=mean(r2>dic.darkCountThreshold);

    %------------------------ plotting ------------------------- 
    dic.GUI.sca(9);
    AddLinePoint(lines(1),freqList(ind1),upProb(ind1,1)-upProb(ind1,2));
%    AddLinePoint(lines(2),freqList(ind1),upProb(ind1,2));
    pause(0.5);
end
%------------------ fitting----------------------
ft=fittype({'x','1'},'coefficients',{'a1','a2'});
[curve]=fit(freqList',upProb(:,1)-upProb(:,2),ft);
set(lines(2),'Xdata',freqList,'Ydata',feval(curve,freqList));
% set FRF
disp(-curve.a2/curve.a1);
if abs(dic.FRF-(-curve.a2/curve.a1))<0.01
    dic.FRF=-curve.a2/curve.a1;
else
    disp('invalid fit');
end
Single_Pulse(Pulse('RFDDS2Switch',2,-1,'freq',dic.FRF));
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
    save(saveFileName,'freqList','upProb','showData','dicParameters','scriptText');
    disp(['Save data in : ' saveFileName]);
end 

% ------------------------- Experiment sequence ------------------------------------    
    function [r]=experimentSeqeunce(freq,phase) 
    prog=CodeGenerator; 
    prog.GenDDSPullParametersFromBase;
    prog.GenSeq(Pulse('ExperimentTrigger',0,50));
    prog.GenSeq(Pulse('RFDDS2Switch',2,-1,'freq',freq,'phase',0,'amp',dic.ampRF));
    prog.GenSeq( Pulse('674DDS1Switch',5,-1,'freq',dic.updateF674,'amp',100) );
    prog.GenDDSFSKState(2,0);% set DDS2 phase to phase word1

    %-------- cooling ------------------------
    prog.GenSeq(Pulse('OffRes422',0,500));
    prog.GenSeq(Pulse('OnResCooling',0,dic.Tcooling));
    % -------initializing and Photon scattering ------------
    prog.GenSeq(Pulse('OpticalPumping',0,10));
    prog.GenSeq([Pulse('674PulseShaper',2,dic.piHalfRF-1),...
                 Pulse('RFDDS2Switch',3,dic.piHalfRF)]);    
    prog.GenPause(30);
    %--------- Ion detection -------------------------
    % qubit rotation for measuring in the wanted basis
    prog.GenSeq([Pulse('674PulseShaper',2,dic.piHalfRF-1),...
                 Pulse('RFDDS2Switch',3,dic.piHalfRF,'phase',phase)]);    
    % double shelving pulses
    prog.GenSeq([Pulse('NoiseEater674',2,dic.T674-2) Pulse('674DDS1Switch',0,dic.T674)]);
    prog.GenSeq(Pulse('674DDS1Switch',5,10,'freq',dic.updateF674+dic.FRF*1.2046));    % state flourescence detection
    
    prog.GenSeq([Pulse('Repump1092',0,0)...
                 Pulse('OnRes422',0,dic.TDetection)...
                 Pulse('PhotonCount',0,dic.TDetection)]);
    prog.GenSeq([Pulse('Repump1033',0,dic.T1033) Pulse('OffRes422',0,0)]);
    
    prog.GenFinish;
    %--------------------------------------------------
    %prog.DisplayCode;

    % FPGA/Host control
    n=dic.com.UploadCode(prog);
    dic.com.UpdateFpga;
    dic.com.WaitForHostIdle;
    rep=800;
    dic.com.Execute(rep);
    dic.com.WaitForHostIdle;
    r=dic.com.ReadOut(-1);        
    end
end


