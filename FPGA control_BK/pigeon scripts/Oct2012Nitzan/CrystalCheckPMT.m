function [res initialstatus]=CrystalCheckPMT

dic=Dictator.me;

if dic.NumOfIons==1
    res=1;
    initialstatus=1;
    return;
end

% number of scattered photons under which the state is considered 
% uncrystallized
CrystallizedStateThreshold=dic.NumOfIons*dic.TDetection/1000*30;
difEndcapVL=dic.AVdcl;
difEndcapVR=dic.AVdcr;

totalattempts=5;

linesrecov=InitializeAxes (dic.GUI.sca(5),'Attempts #','Photons Counted #','Crystal Recovery',...
    [0 totalattempts],[0,CrystallizedStateThreshold*2.3],2);
set(linesrecov(1),'XData',[0:totalattempts],'YData',ones(1,totalattempts+1)*CrystallizedStateThreshold,'Color','r');
set(linesrecov(2),'XData',[],'YData',[],'Marker','.','MarkerSize',10,'Color','b');

%-------------- main scan loop -----------
[iscrystal photoncount] = experimentSeq;
initialstatus=iscrystal;
attempt=0;
AddLinePoint(linesrecov(2),attempt,photoncount);
while (iscrystal==false)&&(attempt<totalattempts)
    if dic.stop
        dic.AVdcl=difEndcapVL;
        dic.AVdcr=difEndcapVR;
        return;
    end
    if attempt==0
        fprintf('Trying to recover the crystal...\n');
    end
    attempt=attempt+1;
    fprintf('Atmpt %d:',attempt);
    % lowring the endacp voltage and set endcapdiff to zero
    dic.AVdcl=0;
	dic.AVdcr=0;  
    ChannelSwitch('EndcapSwitch','on');
    pause(5);
    ChannelSwitch('EndcapSwitch','off');
    pause(2); 
    [iscrystal photoncount] = experimentSeq;    
    AddLinePoint(linesrecov(2),attempt,photoncount);
end
res=iscrystal;
if attempt>0
    fprintf('Yoohoo : back to work\n');
end;

dic.AVdcl=difEndcapVL;
dic.AVdcr=difEndcapVR;


%% ------------------------- Experiment sequence ------------------------------------    
    function [r,photoncount]=experimentSeq
        prog=CodeGenerator; 
        prog.GenSeq(Pulse('ExperimentTrigger',0,50));
        prog.GenSeq(Pulse('OffRes422',0,1000));
        prog.GenSeq(Pulse('OnResCooling',0,dic.Tcooling));
        prog.GenSeq([Pulse('OnRes422',100,dic.TDetection) Pulse('PhotonCount',100,dic.TDetection)]);
        prog.GenSeq(Pulse('OffRes422',1,0));
        prog.GenFinish;

        % FPGA/Host control
        n=dic.com.UploadCode(prog);
        dic.com.UpdateFpga;
        dic.com.WaitForHostIdle;

        rep=100;
        dic.com.Execute(rep);
        dic.com.WaitForHostIdle;
        totalexp=dic.com.ReadOut(rep);
        photoncount=mean(totalexp);
        
        if photoncount<CrystallizedStateThreshold 
            r=0;
        else
            r=1;
        end 
         
    end
end
