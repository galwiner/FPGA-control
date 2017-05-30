function MolmerSorensenGateScan

dic=Dictator.me;

%GateTime=1:20:400;  
GateTime=1:8:351;  

ChannelSwitch('NovaTechPort2','on');

%GateDetuning=-0.013;
repetitions=200;
%SBoffset=-0.006;
%GateDetuning=0.0128; "working"

SBoffset=0.00;
% GateDetuning=(22.7+2)/1000; 
GateDetuning=(30)/1000; 

Freq674SinglePass=77;
novatechpower1=90;
novatechpower2=91;

doEcho=0;
% echostart=100/sqrt(2);
echostart=round(110/sqrt(2));
echoduration=3.3;
% echoduration=0.1;

% dic.setNovatech4Amp(3,30);
dic.setNovatech4Amp(3,0);
dic.setNovatech4Freq(3,77);
dic.setNovatech4Phase(3,2.35);

if ~exist('Vmodes')
    Vmodes = [1];
end
%-------------- Set GUI figures ---------------------
InitializeAxes (dic.GUI.sca(1),'Photons #','Cases Counted #','Fluorescence Histogram',...
                [0 dic.maxPhotonsNumPerReadout],[],0);

lines =InitializeAxes (dic.GUI.sca(6),...
    'Gate Time [mus]','Populations %','Entangling Gate',...
    [GateTime(1) GateTime(end)],[0 100],3);
darkCountLine(1) = lines(1);
fitLine(1) = lines(2);
set(darkCountLine(1),'Marker','.','MarkerSize',10,'Color','b');

darkCountLine(2) = lines(2);
set(darkCountLine(2),'Marker','.','MarkerSize',10,'Color','r');

darkCountLine(3) = lines(3);
set(darkCountLine(3),'Marker','.','MarkerSize',10,'Color','g');

%-------------- main scan loop ---------------------


%f674Span=-0.07:0.007:0.07;    
% set(dic.GUI.sca(10),'XLim',[PulseTime(1) PulseTime(end)]);

% darkBank = zeros(length(Vmodes),2,length(PulseTime));
dark=zeros(length(GateTime));
p0=zeros(length(GateTime));
p1=zeros(length(GateTime));
p2=zeros(length(GateTime));

dic.setNovatech4Amp(0,1000);dic.setNovatech4Freq(0,dic.updateF674);

if dic.SitOnItFlag
    cont=1;
    while (cont)
        if (dic.stop)
            cont=0;
        end
        dic.setNovatech4Amp(1,1000)
        dic.setNovatech4Amp(2,0);

        
        dic.setNovatech4Amp(2,1000);dic.setNovatech4Freq(2,dic.F674);
        dic.setNovatech4Freq(1,Freq674SinglePass-(dic.vibMode(1).freq));
        dic.setNovatech4Freq(0,Freq674SinglePass+(dic.vibMode(1).freq));
        r=experimentSequence(10,1);
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
    %     for modeInd=1:length(Vmodes)
    %         grid on;
    dic.setNovatech4Amp(1,novatechpower1); % BSB
    dic.setNovatech4Amp(0,novatechpower2); %RSB
    dic.setNovatech4Freq(1,Freq674SinglePass-(dic.vibMode(Vmodes(1)).freq-GateDetuning));
    dic.setNovatech4Freq(0,Freq674SinglePass+(dic.vibMode(Vmodes(1)).freq-GateDetuning));
    
    
    for index2 = 1:length(GateTime)
        
        CrystalCheckPMT;
        
        if dic.stop
            return
        end
        
        LightShift=0;%*-0.0049;
        %dic.setNovatech4Amp(0,1000);
        dic.setNovatech4Freq(2,dic.updateF674+SBoffset/2);
        %                 dic.setNovatech4Phase(1,0);dic.setNovatech4Phase(2,pi);
        %             set(darkCountLine(lobeIndex),'XData',[],'YData',[]);
        
        r=experimentSequence(GateTime(index2),Vmodes);
        dic.GUI.sca(1); %get an axis from Dictator GUI to show data
        hist(r,0:1:(1.8*dic.maxPhotonsNumPerReadout));
        if dic.TwoIonFlag
            dark(index2) =100-sum( (r>dic.TwoIonsCountThreshold)*2+...
                ((r>dic.darkCountThreshold)&(r<dic.TwoIonsCountThreshold))*1 ...
                )/2/length(r)*100;
            %p0(index1)=dark(index1);
            p0(index2)=sum(r<dic.darkCountThreshold)/length(r)*100;
            p2(index2)=sum(r>dic.TwoIonsCountThreshold)/length(r)*100;
            p1(index2)=100-p0(index2)-p2(index2);
        else
            dark(index2) = sum( r<dic.darkCountThreshold)/length(r)*100;
        end
        
        AddLinePoint(darkCountLine(1),GateTime(index2),p0(index2));
        AddLinePoint(darkCountLine(2),GateTime(index2),p2(index2));
         AddLinePoint(darkCountLine(3),GateTime(index2),p1(index2));
        pause(0.1);
        %         end
    end
end
%------------ Save data ------------------
if (dic.AutoSaveFlag)
    destDir=dic.saveDir;
    thisFile=[mfilename('fullpath') '.m' ];
    [filePath fileName]=fileparts(thisFile);
    scriptText=fileread(thisFile);
    showData='figure;plot(GateTime,p0,''g'',GateTime,p1,''b'',GateTime,p2,''r'');xlabel(''Gate Time[\mus]'');ylabel(''Populations'');';
    saveFileName=fullfile(destDir ,[fileName datestr(now,'-ddmmmyy-HHMMSS')]);
    dicParameters=dic.getParameters;
    save(saveFileName,'GateDetuning','GateTime','p0','p1','p2','SBoffset','Vmodes','showData','dicParameters','scriptText');
    disp(['Save data in : ' saveFileName]);
end
%--------------------------------------------------------------------
    function r=experimentSequence(pulsetime,mode)
        prog=CodeGenerator;
        prog.GenDDSPullParametersFromBase;
%         prog.GenWaitExtTrigger;
        
        prog.GenSeq(Pulse('ExperimentTrigger',0,50));
%         prog.GenWaitExtTrigger;
        
        prog.GenSeq(Pulse('674DDS1Switch',0,-1,'amp',100));
        % Doppler coolng
        prog.GenSeq(Pulse('OffRes422',0,1));%turn off cooling
        prog.GenSeq(Pulse('OnResCooling',0,dic.Tcooling));
        
        prog.GenSeq(Pulse('OpticalPumping',0,dic.Toptpump));
        
        %%%%%%%%%%%%% SIDEBAND COOLING %%%%%%%%%%%%%%%%
        SeqGSC=[]; N=4; Tstart=2;
        Mode2Cool=mode;
         % continuous GSC
        if (~isempty(Mode2Cool))
            for mode=Mode2Cool
                % turn on carrier mode
                prog.GenSeq(Pulse('DIO7',0,0));
                SeqGSC=[SeqGSC,Pulse('NoiseEater674',Tstart,dic.vibMode(mode).coolingTime/N),...
                               Pulse('674DDS1Switch',Tstart,dic.vibMode(mode).coolingTime/N,...
                                     'freq',Freq674SinglePass+dic.vibMode(mode).freq+dic.acStarkShift674)];
                Tstart=2+Tstart+dic.vibMode(mode).coolingTime/N;
            end
            prog.GenSeq([Pulse('Repump1033',0,0), Pulse('OpticalPumping',0,0)]);
            prog.GenRepeatSeq(SeqGSC,N);
            prog.GenSeq([Pulse('Repump1033',dic.T1033,-1), Pulse('OpticalPumping',dic.T1033,-1)]);
            % pulsed GSC
            for mode=fliplr(Mode2Cool)
            prog.GenRepeatSeq([Pulse('NoiseEater674',2,dic.vibMode(mode).coldPiTime),...
                               Pulse('674DDS1Switch',2,dic.vibMode(mode).coldPiTime,'freq',Freq674SinglePass+dic.vibMode(mode).freq),...
                               Pulse('Repump1033',dic.vibMode(mode).coldPiTime,dic.T1033),...
                               Pulse('OpticalPumping',dic.vibMode(mode).coldPiTime+dic.T1033,dic.Toptpump)],2);                          
            end
        end
        %%%%%%%%%% END OF GROUND STATE COOLING %%%%%%%%%%
        prog.GenSeq(Pulse('OpticalPumping',0,dic.Toptpump));
        
        %         prog.GenSeq([Pulse('NoiseEater674',2,16),...
        %                      Pulse('674DDS1Switch',0,20)]); %NoiseEater initialization
        %         prog.GenSeq(Pulse('Repump1033',0,dic.T1033)); %cleaning D state
        %         prog.GenSeq(Pulse('OpticalPumping',10,dic.Toptpump));
        
        
        % Gate Pulse
        prog.GenSeq(Pulse('DIO7',0,1));
        prog.GenSeq(Pulse('Repump1092',0,1));
        if (doEcho && (pulsetime>echostart+echoduration+1))
            % Gate Pulse With Echo
            prog.GenSeq([Pulse('674PulseShaper',1,pulsetime+echoduration-5),Pulse('NoiseEater674',5,pulsetime+echoduration),...
                Pulse('674DDS1Switch',3,pulsetime+echoduration,'freq',60),...
                Pulse('DIO7',echostart,echoduration),...
                Pulse('NovaTechPort2',echostart-1,1),...
                Pulse('NovaTechPort2',echostart+echoduration,0)]);
        else
            prog.GenSeq([Pulse('674PulseShaper',1,pulsetime-5),Pulse('NoiseEater674',5,pulsetime),...
                Pulse('674DDS1Switch',3,pulsetime,'freq',60)]);
        end
        prog.GenSeq(Pulse('Repump1092',0,0));
        
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