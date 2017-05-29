function [res initialstatus]=CrystalCheckPMT;
dic=Dictator.me;

% number of scattered photons under which the state is considered 
% uncrystallized
CrystallizedStateThreshold=28; 
freqDetect=dic.F422onRes;

totalattempts=10;

% Keithley Voltage
Amp=3.1; minAmp=1.5;

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

while (iscrystal==false)&&(attempt<totalattempts)
    if attempt==0
        keith=openUSB('USB0::0x05E6::0x3390::1310276::0::INSTR');
        fprintf('Trying to recover the crystal...\n');
    end
    attempt=attempt+1;
    fprintf(keith,['VOLTage ' num2str(minAmp) ' V']);
    pause(2);
    fprintf(keith,['VOLTage ' num2str(Amp) ' V']);
    
    [iscrystal photoncount] = experimentSeq(freqDetect);
    AddLinePoint(linesrecov(2),attempt,photoncount);
end

if attempt==totalattempts
    fprintf('Desperate attempt...\n');
    Vcapinit=dic.Vcap;
    dic.Vcap=150;
    pause(1);
    fprintf(keith,['VOLTage ' num2str(minAmp) ' V']);
    pause(4);
    fprintf(keith,['VOLTage ' num2str(Amp) ' V']);
    dic.Vcap=Vcapinit;
    pause(2);
    [iscrystal photoncount] = experimentSeq(freqDetect);
    AddLinePoint(linesrecov(2),attempt,photoncount);
end
    

if iscrystal==false
    fprintf('Warning : crystal not recovered\n');
    res=false;
else
    res=true;
    if attempt>0
        fprintf('Yoohoo : back to work\n');
    end
end

% if bright<CrystallizedStateThreshold
%     res=false;
%     disp('Warning : Possible crystal melting');
% else
%     res=true;
% end
       

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
            r=false;
        else
            r=true;
        end 
         
    end
end
% 
% % ------ make sure we have two ions ------
%     function res=
%         shot=experimentSeq(0);
%         attempts=0;
%         while (NumOfIons(shot,thresh)~=2)&&(attempts<6)
%             attempts=attempts+1;
%             gca = dic.GUI.sca(5);
%             title('Validating');
%             fprintf(keith,['VOLTage ' num2str(minAmp) ' V']);
%             pause(2);
%             fprintf(keith,['VOLTage ' num2str(Amp) ' V']);
%             %             for t=linspace(minAmp,Amp,200)
%             %                fprintf(keith,['VOLTage ' num2str(t) ' V']);
%             %                pause(0.01);
%             %                if (dic.stop)
%             %                  fclose(keith);
%             %                  return;
%             %                end
%             %             end
%             shot=experimentSeq(0);
%             plot(shot);
%         end
%         if NumOfIons(shot,thresh)==2
%             res=true;
%         else
%             res=false;
%         end
%     end
