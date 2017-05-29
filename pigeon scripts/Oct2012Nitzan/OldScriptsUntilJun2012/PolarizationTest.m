function PolarizationTest
dic=Dictator.me;

WP1Pos=linspace(-200,400,25);
WP2Pos=linspace(400,450,2);
if (dic.SitOnItFlag)
    cont=1;       
    experimentSeq;        
    while (cont)
        if (dic.stop)
            cont=0;
        end 
        [PMT1,PMT2]=experimentSeq;        
        disp(sprintf('PMT1 %d PMT2 %d ',PMT1,PMT2));
        dic.GUI.sca(1); %get an axis from Dictator GUI to show data
        bar([1,2],[PMT1,PMT2]);
        axis([0 3 0 50]);
        pause(0.1);

   end
else
    %-------------- set GUI ---------------
    lines =InitializeAxes (dic.GUI.sca(9),'Waveplate position','Photons #','Waveplate scan',...
                           [WP1Pos(1) WP1Pos(end)],[],2);
    set(lines(1),'XData',[],'YData',[],'Color','b',...
              'LineWidth',0.5,'Marker','.','MarkerSize',10);
    set(lines(2),'XData',[],'YData',[],'Color','r',...
              'LineWidth',0.5,'Marker','.','MarkerSize',10);
    InitializeAxes (dic.GUI.sca(10),'waveplate 1 position','waveplate 2 position','Waveplate scan',...
                    [WP1Pos(1) WP1Pos(end)],[WP2Pos(1) WP2Pos(end)],0);

    %-------------- main scan loop -----------
    PMT1=zeros(length(WP1Pos),length(WP2Pos));
    PMT2=PMT1;
    for ind2 =1:length(WP2Pos)
        set(lines(1),'XData',[],'YData',[]);        
        set(lines(2),'XData',[],'YData',[]);
        for ind1 =1:length(WP1Pos)
            if (dic.stop)
                return;
            end
            dic.com.UpdateWavePlates(WP1Pos(ind1),WP2Pos(ind2));  
            pause(1);
            avg=4;
            p1=zeros(avg,1);
            p2=p1;
            for j=1:avg
                [p1(j) p2(j)]=experimentSeq;
            end
            PMT1(ind1,ind2)=mean(p1);
            PMT2(ind1,ind2)=mean(p2);
            AddLinePoint(lines(1),WP1Pos(ind1),PMT1(ind1));
            AddLinePoint(lines(2),WP1Pos(ind1),PMT2(ind1));
        end
        dic.GUI.sca(10); 
        imagesc(WP1Pos,WP2Pos,(PMT1-PMT2)');

    end
    %------------ Save data ------------------
    if (dic.AutoSaveFlag)
        destDir=dic.saveDir;
        thisFile=[mfilename('fullpath') '.m' ];
        [filePath fileName]=fileparts(thisFile);
        scriptText=fileread(thisFile);
        showData=['figure;plot(WP1Pos,PMT1,''b'',WP1Pos,PMT2,''r'');'...
                  'xlabel(''waveplate position'');ylabel(''photons'');'...
                  'figure;imagesc(WP1Pos,WP2Pos,(PMT1-PMT2)'');colorbar;'...
                  'xlabel(''waveplate 1 position'');ylabel(''waveplate 2 position''); title(''PMT1-PMT2'')'];
        saveFileName=fullfile(destDir ,[fileName datestr(now,'-ddmmmyy-HHMMSS')]);
        dicParameters=dic.getParameters;
        save(saveFileName,'WP1Pos','WP2Pos','PMT1','PMT2','showData','dicParameters','scriptText');
        disp(['Save data in : ' saveFileName]);
     end 
end

% ------------------------- Experiment sequence ------------------------------------    
    function [p1,p2]=experimentSeq 
        prog=CodeGenerator; 
        prog.GenDDSPullParametersFromBase;
        prog.GenSeq(Pulse('ExperimentTrigger',0,50));
        prog.GenSeq( Pulse('674DDS1Switch',0,-1,'freq',dic.updateF674,'amp',100) );
        prog.GenSeq(Pulse('OffRes422',0,100));
        prog.GenSeq(Pulse('OnResCooling',0,dic.Tcooling));
        prog.GenSeq(Pulse('OpticalPumping',0,dic.Toptpump));    
        prog.GenRegOp('RegB=',0);
        prog.GenRepeatSeq([Pulse('OpticalPumping',0,dic.Toptpump)...
                           Pulse('NoiseEater674',dic.Toptpump,dic.T674),...
                           Pulse('674DDS1Switch',dic.Toptpump,dic.T674)...
                           Pulse('PMTsAccumulate',dic.Toptpump+dic.T674+1.9,1.5)...
                           Pulse('Repump1033',dic.Toptpump+dic.T674+1.8,4)],400);
        prog.GenRegOp('FIFO<-RegB',0); 
        prog.GenSeq(Pulse('OffRes422',200,0));
        prog.GenFinish;
        %prog.DisplayCode;

        % FPGA/Host control
        n=dic.com.UploadCode(prog);
        dic.com.UpdateFpga;
        dic.com.WaitForHostIdle;
        rep=250;
        dic.com.Execute(rep);
        dic.com.WaitForHostIdle;
        r=dic.com.ReadOut(-1);
        r=reshape(typecast(uint16(r),'uint8'),2,[]);
        p1=sum(r(1,:));
        p2=sum(r(2,:));
        
    end
end


