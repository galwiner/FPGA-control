function MolmerSorensenParityTestPulse

dic=Dictator.me;
repetitions=100;

ChannelSwitch('NovaTechPort2','on');
ChannelSwitch('DIO7','on');

Vmodes=1;

% PulseTime=5:1:31;  
% PulseTime=5:0.2:40;  
 PulseTime=2:0.5:20;  

% PulseTime=9:0.3:19;  

%-------------- Set GUI figures ---------------------
InitializeAxes (dic.GUI.sca(1),'Photons #','Cases Counted #','Fluorescence Histogram',...
                [0 dic.maxPhotonsNumPerReadout],[],0);

lines =InitializeAxes (dic.GUI.sca(10),...
    'Time [mus]','Dark Counts %','Rabi Scan with Modulated Beams',...
    [PulseTime(1) PulseTime(end)],[0 100],2);
darkCountLine(1) = lines(1);
fitLine(1) = lines(2);
set(darkCountLine(1),'Marker','.','MarkerSize',10,'Color','b');

darkCountLine(2) = lines(2);
set(darkCountLine(2),'Marker','.','MarkerSize',10,'Color','r');

%-------------- main scan loop ---------------------
  
%f674Span=-0.07:0.007:0.07;    
% set(dic.GUI.sca(11),'XLim',[PulseTime(1) PulseTime(end)]);

LightShift=0;%*-0.0049;
Freq674SinglePass=77;
SeparationFactor=1.0;
dic.setNovatech4Freq(1,Freq674SinglePass-SeparationFactor*(dic.vibMode(1).freq+LightShift));
dic.setNovatech4Freq(0,Freq674SinglePass+SeparationFactor*(dic.vibMode(1).freq+LightShift));
novatechpower1=90; %blue curve
novatechpower2=90; %red curve

dic.setNovatech4Amp(3,20);
dic.setNovatech4Freq(3,77);

darkBank = zeros(length(Vmodes),2,length(PulseTime));
dark=zeros(size(PulseTime));
if dic.SitOnItFlag
    cont=1;
    while (cont)
        if (dic.stop)
            cont=0;
        end
        dic.setNovatech4Amp(1,200)
        dic.setNovatech4Amp(2,0);

        
        dic.setNovatech4Amp(0,1000);dic.setNovatech4Freq(0,dic.F674);
        dic.setNovatech4Freq(1,Freq674SinglePass-(dic.vibMode(1).freq+LightShift));
        dic.setNovatech4Freq(2,Freq674SinglePass+(dic.vibMode(1).freq+LightShift));
        r=experimentSequence(30,1);
        dic.GUI.sca(1); %get an axis from Dictator GUI to show data
        hist(r,0:1:(1.8*dic.maxPhotonsNumPerReadout));
        if dic.TwoIonFlag
            darkf =100-sum( (r>dic.TwoIonsCountThreshold)*2+...
                ((r>dic.darkCountThreshold)&(r<dic.TwoIonsCountThreshold))*1 ...
                )/2/length(r)*100;
        else
            darkf = sum( r<dic.darkCountThreshold)/length(r)*100;
        end
        xlabel(num2str(round(darkf)),'FontSize',100);
    end
else
    for modeInd=1:length(1)
        grid on;
        for index1 = 1:length(PulseTime)
            for lobeIndex = 1:1
                %select sideband
                dic.setNovatech4Amp(1,novatechpower1);
                dic.setNovatech4Amp(0,novatechpower2);
                                
                if dic.stop
                    return
                end

                dic.setNovatech4Amp(2,1000);dic.setNovatech4Freq(2,dic.F674);
                %             set(darkCountLine(lobeIndex),'XData',[],'YData',[]);
                
                r=experimentSequence(PulseTime(index1),Vmodes(modeInd));
                dic.GUI.sca(1); %get an axis from Dictator GUI to show data
                hist(r,0:1:(1.8*dic.maxPhotonsNumPerReadout));
                if dic.TwoIonFlag
                    dark(index1) =100-sum( (r>dic.TwoIonsCountThreshold)*2+...
                        ((r>dic.darkCountThreshold)&(r<dic.TwoIonsCountThreshold))*1 ...
                        )/2/length(r)*100;
                else
                    dark(index1) = sum( r<dic.darkCountThreshold)/length(r)*100;
                end
                AddLinePoint(darkCountLine(lobeIndex),PulseTime(index1),dark(index1));
                darkBank(modeInd,lobeIndex,index1)=dark(index1);
                pause(0.1);
            end
        end
    end
end
%------------ Save data ------------------
if (dic.AutoSaveFlag)
    destDir=dic.saveDir;
    thisFile=[mfilename('fullpath') '.m' ];
    [filePath fileName]=fileparts(thisFile);
    scriptText=fileread(thisFile);
    showData='figure;RSB(:,:)=darkBank(:,2,:);BSB(:,:)=darkBank(:,1,:);plot(PulseTime,RSB,''r'',PulseTime,BSB,''b'');;xlabel(''Detunning [Mhz]'');ylabel(''dark[%]'');';
    saveFileName=fullfile(destDir ,[fileName datestr(now,'-ddmmmyy-HHMMSS')]);
    dicParameters=dic.getParameters;
    save(saveFileName,'PulseTime','darkBank','Vmodes','showData','dicParameters','scriptText');
    disp(['Save data in : ' saveFileName]);
end
%--------------------------------------------------------------------
%--------------------------------------------------------------------
    function r=experimentSequence(pulsetime,mode)
        prog=CodeGenerator;
        prog.GenDDSPullParametersFromBase;
%         prog.GenWaitExtTrigger;

        prog.GenSeq(Pulse('ExperimentTrigger',0,50));
        
        prog.GenSeq(Pulse('674DDS1Switch',0,-1,'amp',100));
        % Doppler coolng
        prog.GenSeq(Pulse('OffRes422',0,1));%turn off cooling
        prog.GenSeq(Pulse('OnResCooling',0,dic.Tcooling));
        
        prog.GenSeq(Pulse('OpticalPumping',0,dic.Toptpump));
        
        %%%%%%%%%%%%% SIDEBAND COOLING %%%%%%%%%%%%%%%%
%         SeqGSC=[]; N=4; Tstart=2;
%         Mode2Cool=mode;
%          % continuous GSC
%         if (~isempty(Mode2Cool))
%             for mode=Mode2Cool
%                 % turn on carrier mode
%                 prog.GenSeq(Pulse('DIO7',0,0));
%                 SeqGSC=[SeqGSC,Pulse('NoiseEater674',Tstart,dic.vibMode(mode).coolingTime/N),...
%                                Pulse('674DDS1Switch',Tstart,dic.vibMode(mode).coolingTime/N,...
%                                      'freq',Freq674SinglePass+dic.vibMode(mode).freq+dic.acStarkShift674)];
%                 Tstart=2+Tstart+dic.vibMode(mode).coolingTime/N;
%             end
%             prog.GenSeq([Pulse('Repump1033',0,0), Pulse('OpticalPumping',0,0)]);
%             prog.GenRepeatSeq(SeqGSC,N);
%             prog.GenSeq([Pulse('Repump1033',dic.T1033,-1), Pulse('OpticalPumping',dic.T1033,-1)]);
%             % pulsed GSC
%             for mode=fliplr(Mode2Cool)
%             prog.GenRepeatSeq([Pulse('NoiseEater674',2,dic.vibMode(mode).coldPiTime),...
%                                Pulse('674DDS1Switch',2,dic.vibMode(mode).coldPiTime,'freq',Freq674SinglePass+dic.vibMode(mode).freq),...
%                                Pulse('Repump1033',dic.vibMode(mode).coldPiTime,dic.T1033),...
%                                Pulse('OpticalPumping',dic.vibMode(mode).coldPiTime+dic.T1033,dic.Toptpump)],2);                          
%             end
%         end         
        %%%%%%%%%% END OF GROUND STATE COOLING %%%%%%%%%%
        prog.GenSeq(Pulse('OpticalPumping',0,dic.Toptpump));

%         prog.GenSeq([Pulse('NoiseEater674',2,16),...
%                      Pulse('674DDS1Switch',0,20)]); %NoiseEater initialization
%         prog.GenSeq(Pulse('Repump1033',0,dic.T1033)); %cleaning D state        
%         prog.GenSeq(Pulse('OpticalPumping',10,dic.Toptpump));

        
        % Gate Pulse 
         prog.GenSeq(Pulse('Repump1092',0,-1)); 
        prog.GenSeq([Pulse('DIO7',0,0),Pulse('NovaTechPort2',0,1)]);
        prog.GenSeq([Pulse('NoiseEater674',5,pulsetime),...
                     Pulse('674DDS1Switch',3,pulsetime)]);
        prog.GenSeq([Pulse('DIO7',0,1),Pulse('NovaTechPort2',0,0)]);

         prog.GenSeq(Pulse('Repump1092',0,0));        
%         prog.GenSeq([Pulse('NoiseEater674',5,pulsetime),...
%                      Pulse('674DDS1Switch',3,pulsetime)]);
%         prog.GenSeq(Pulse('Repump1092',0,0));        

%          prog.GenSeq([Pulse('674PulseShaper',1,pulsetime-4),Pulse('674DDS1Switch',4,pulsetime)]);

%          prog.GenSeq([Pulse('674PulseShaper',1,pulsetime-2),Pulse('674DDS1Switch',1,pulsetime)]);

       
        % detection
        prog.GenSeq([Pulse('OnRes422',0,dic.TDetection) Pulse('PhotonCount',0,dic.TDetection)]);
        %resume cooling
        prog.GenSeq(Pulse('Repump1033',0,dic.T1033));
        prog.GenSeq(Pulse('OffRes422',0,0));
        prog.GenFinish;
        
        dic.com.UploadCode(prog);
        dic.com.UpdateFpga;
        dic.com.WaitForHostIdle; % wait until host finished it last task
        dic.com.Execute(repetitions);
        dic.com.WaitForHostIdle;
        r = dic.com.ReadOut(repetitions);
        r = r(2:end);
    end 



end