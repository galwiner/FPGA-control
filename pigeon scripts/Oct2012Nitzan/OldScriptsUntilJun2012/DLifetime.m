function DLifeTime
   ax=openAxes(gcf,'Generic');
   xlabel('D_{5/2} Liftime meas, \tau(\mu s)');
   ylabel('dark count %');
   com=Tcp2Labview('localhost',6340);
   pause(1);
   importGlobals; 
   colorCycle;
    WaitTimes=(0:30000:300000);
    darkup=zeros(size(WaitTimes));
    brightup=zeros(size(WaitTimes));
    darkdown=zeros(size(WaitTimes));
    brightdown=zeros(size(WaitTimes));
     for loop=1:length(WaitTimes)
         Search_674_Res;
        if (evalin('base','exist(''stopRun'')'))
            if (evalin('base','stopRun'))
                assignin('base','stopRun',0);
                return;
            end
        end
        if (evalin('base','exist(''clr'')'))
            if (evalin('base','clr'))
                assignin('base','clr',0);
                if exist('a') 
                    clear a;
                end
                cla;
            end
        end
       
        %check up lifetime
        prog=CodeGenerator; %sprog.GenWaitExtTrigger;
        prog.GenSeq(Pulse('OffRes422',0,1));
        prog.GenSeq(Pulse('OnResCooling',0,Tcooling));
        prog.GenSeq(Pulse('OpticalPumping',0,Toptpump));
        % Do Shelving
        prog.GenSeq(Pulse('DO12',0,-1)); %start 674 integrator on noise eater
        prog.GenSeq(Pulse('674Channel1',0,T674));
        prog.GenSeq(Pulse('DO12',0,0)); %stop 674 integrator on noise eater
        % wait
        prog.GenWait(WaitTimes(loop)*10);
        %detection
        prog.GenSeq([Pulse('OnRes422',0,500) Pulse('PhotonCount',0,500)]);
        %resume cooling
        prog.GenSeq(Pulse('Repump1033',0,T1033));            
        prog.GenSeq(Pulse('OffRes422',0,0));

        prog.GenFinish;
        % FPGA/Host control
        n=com.UploadCode(prog);
        com.UpdateFpga;
        com.WaitForHostIdle;
        rep=200;
        com.Execute(rep);
        com.WaitForHostIdle;
        r=com.ReadOut(rep);
        darkup(loop)=sum(r<8)/rep*100;
        brightup=[brightup mean(r)];
        
        pause(0.01);
        hold on;
        if (exist('a')) 
            clear a;
        end
        a=plot(WaitTimes(1:loop),darkup(1:loop),'-o'); 
        setCurColor(a);

        axis([0 max(WaitTimes) 0 100]);        
        hold off;
        pause(0.01);
    end
      
    com.Delete;
end