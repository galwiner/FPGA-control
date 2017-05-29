function [res initialstatus]=CrystalCheckPMT(avdclin,hpvcompin);
% res=1;
% initialstatus=1;
% return;
% end

dic=Dictator.me;
if (~dic.TwoIonFlag)
    res=1;
    initialstatus=1;
    return;
end

initAmp=dic.Vkeith;
ChannelSwitch('674DDS1Switch','off');

if ~exist('avdclin')
    avdclin=1;
end
if ~exist('hpvcompin')
    hpvcompin=0;
end

factor=1; %dB = the power increase factor of the trap
ampfactor=sqrt(10^(factor/10));
% number of scattered photons under which the state is considered 
% uncrystallized
if dic.TDetection < 800
    CrystallizedStateThreshold=35; 
else
    CrystallizedStateThreshold=60; 
end

freqDetect=dic.F422onRes;

totalattempts=6;

% Keithley Voltage
% Amp=3.1; 
if dic.Vcap==50
    minAmp=1.4;
else
    minAmp=1.9/ampfactor;
end

if dic.Vkeith<1.6
    minAmp=1.0;
end
    
linesrecov=InitializeAxes (dic.GUI.sca(5),'Attempts #','Photons Counted #','Crystal Recovery',...
    [0 totalattempts],[0,CrystallizedStateThreshold*2.3],2);
set(linesrecov(1),'XData',[0:totalattempts],'YData',ones(1,totalattempts+1)*CrystallizedStateThreshold,'Color','r');
set(linesrecov(2),'XData',[],'YData',[],'Marker','.','MarkerSize',10,'Color','b');


%-------------- main scan loop -----------
%bright=zeros(size(freqList));
[iscrystal photoncount] = experimentSeq(freqDetect);
initialstatus=iscrystal;
attempt=0;
AddLinePoint(linesrecov(2),attempt,photoncount);
saveAVdcl=dic.AVdcl;
saveHPVcomp=dic.HPVcomp;
dic.AVdcl=avdclin;
dic.HPVcomp=hpvcompin;
while (iscrystal==false)&&(attempt<totalattempts)
    if dic.stop
        dic.AVdcl=saveAVdcl;
        dic.HPVcomp=saveHPVcomp;
        return;
    end
    if attempt==0
        fprintf('Trying to recover the crystal...\n');
    end
   attempt=attempt+1;
   dic.Vkeith=minAmp;
   fprintf('Atmpt %d:',attempt);
    for dummy=1:5
        pause(1);
        fprintf('%d,',5-dummy);
    end
    dic.Vkeith=initAmp;
    pause(0.3); 
    [iscrystal photoncount] = experimentSeq(freqDetect);    
    AddLinePoint(linesrecov(2),attempt,photoncount);
end

if attempt>=totalattempts
    fprintf('********* Desperate attempt: ');
    Vcapinit=dic.Vcap;
    fprintf('relax trap: ');dic.Vcap=50; takeFive(3); dic.Vkeith=1;
    fprintf('3 sec cooling: '); takeFive(3); fprintf('\n');
    fprintf('re-tighten trap: ');dic.Vkeith=initAmp;takeFive(1); dic.Vcap=Vcapinit; takeFive(5);
    [iscrystal photoncount] = experimentSeq(freqDetect);
    AddLinePoint(linesrecov(2),attempt,photoncount);
end
    

if iscrystal==false
    fprintf('Warning : crystal not recovered\n');
    res=2;
    dic.controlEndcapFlag=1;
    dic.Vcap=50;
    pause(3);
    dic.Vkeith=1;
    fprintf('Moving to keyboard mode.\n Press ''dbquit'' to resume script or ''dbquit(all)'' to stop all executions\n');
    keyboard;
else
    res=true;
    if attempt>0
        fprintf('Yoohoo : back to work\n');
    end
end

dic.AVdcl=saveAVdcl;
dic.HPVcomp=saveHPVcomp;
       

%% ------------------------- Experiment sequence ------------------------------------    
    function [r,photoncount]=experimentSeq(freq)%create and run a single sequence of detection
        prog=CodeGenerator; 
        prog.GenSeq(Pulse('ExperimentTrigger',0,50));
        %set-up detection(also=optical repump), 1092 and on-res cooling freq. 
        if (freq>0)
            prog.GenSeq(Pulse('OnRes422',0,-1,'freq',freq));
        end
       % prog.GenSeq(Pulse('Repump1092',0,0,'freq',dic.F1092));
        prog.GenSeq(Pulse('OffRes422',0,100));
        prog.GenSeq(Pulse('OnResCooling',0,dic.Tcooling));
        prog.GenSeq([Pulse('OnRes422',100,dic.TDetection) Pulse('PhotonCount',100,dic.TDetection)]);
        prog.GenSeq(Pulse('OffRes422',500,0));
        prog.GenFinish;
        %prog.DisplayCode;

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
