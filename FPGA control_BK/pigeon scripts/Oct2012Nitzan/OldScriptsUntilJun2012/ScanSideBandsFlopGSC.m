function ScanSideBandsFlopGSC(Vmodes)

dic=Dictator.me;

if ~exist('Vmodes')
    Vmodes = 1;
end

novatechpower=200;

if dic.TwoIonFlag==1
    dic.vibMode(1).coldPiTime=sqrt(2)*20*dic.T674;
else
     dic.vibMode(1).coldPiTime=17*dic.T674;
end
    
%-------------- Set GUI figurdes ---------------------
InitializeAxes (dic.GUI.sca(1),'Photons #','Cases Counted #','Fluorescence Histogram',...
                [0 dic.maxPhotonsNumPerReadout],[],0);

lines =InitializeAxes (dic.GUI.sca(6),...
    'F [MHz]','Dark Counts %','Blue Sideband',...
    [],[0 100],2);
darkCountLine(1) = lines(1);
fitLine(1) = lines(2);
set(darkCountLine(1),'Marker','.','MarkerSize',10,'Color','b');

darkCountLine(2) = lines(2);
set(darkCountLine(2),'Marker','.','MarkerSize',10,'Color','r');

%-------------- main scan loop ---------------------
f674Span=-0.02:0.002:0.02;    
%f674Span=-0.07:0.007:0.07;    
set(dic.GUI.sca(5),'XLim',[f674Span(1) f674Span(end)]);

darkBank = zeros(length(Vmodes),2,length(f674Span));
dark=zeros(size(f674Span));
for modeInd=1:length(Vmodes)
    %titlePrefix = dic.vibMode(Vmodes(modeInd)).name;
        
        set(dic.GUI.sca(6),'XLim',[f674Span(1) f674Span(end)]);
            
%         set(dic.GUI.sca(4+lobeIndex),'XLim',[f674Span(1) f674Span(end)]);
        grid on;
        %title(titlePrefix);
        for index1 = 1:length(f674Span)
            for lobeIndex = 1:2                
                %select sideband
                if lobeIndex==1
                    dic.setNovatech4Amp(1,novatechpower)
                    dic.setNovatech4Amp(2,0);
                else
                    dic.setNovatech4Amp(1,0)
                    dic.setNovatech4Amp(2,novatechpower)
                end         
            if dic.stop
                return
            end
            Freq674SinglePass=77;          
             LightShift=-0;
            dic.setNovatech4Amp(0,1000);dic.setNovatech4Freq(0,dic.updateF674); 
            dic.setNovatech4Freq(1,Freq674SinglePass-(dic.vibMode(Vmodes(modeInd)).freq+f674Span(index1)+LightShift));
            dic.setNovatech4Freq(2,Freq674SinglePass+(dic.vibMode(Vmodes(modeInd)).freq+f674Span(index1)+LightShift));
%             set(darkCountLine(lobeIndex),'XData',[],'YData',[]);

            r=experimentSequence(Vmodes(modeInd));
            dic.GUI.sca(1); %get an axis from Dictator GUI to show data
            hist(r,0:1:(1.8*dic.maxPhotonsNumPerReadout));
            if dic.TwoIonFlag
                dark(index1) =100-sum( (r>dic.TwoIonsCountThreshold)*2+...
                                     ((r>dic.darkCountThreshold)&(r<dic.TwoIonsCountThreshold))*1 ...
                                    )/2/length(r)*100;
            else
                dark(index1) = sum( r<dic.darkCountThreshold)/length(r)*100;
            end
            AddLinePoint(darkCountLine(lobeIndex),f674Span(index1),dark(index1));
            darkBank(modeInd,lobeIndex,index1)=dark(index1);
            pause(0.1);
        end
    end
end
%------------ Save data ------------------
if (dic.AutoSaveFlag)
    destDir=dic.saveDir;
    thisFile=[mfilename('fullpath') '.m' ];
    [filePath fileName]=fileparts(thisFile);
    scriptText=fileread(thisFile);
    showData='figure;RSB(:,:)=darkBank(:,2,:);BSB(:,:)=darkBank(:,1,:);plot(f674Span,RSB,''r'',f674Span,BSB,''b'');;xlabel(''Detunning [Mhz]'');ylabel(''dark[%]'');';
    saveFileName=fullfile(destDir ,[fileName datestr(now,'-ddmmmyy-HHMMSS')]);
    dicParameters=dic.getParameters;
    save(saveFileName,'f674Span','darkBank','Vmodes','showData','dicParameters','scriptText');
    disp(['Save data in : ' saveFileName]);
end
%--------------------------------------------------------------------
    function r=experimentSequence(mode)
        prog=CodeGenerator;
        prog.GenDDSPullParametersFromBase;
        prog.GenSeq(Pulse('ExperimentTrigger',0,50));
        prog.GenSeq(Pulse('674DDS1Switch',0,-1,'amp',100));
        % Doppler coolng
        prog.GenSeq(Pulse('OffRes422',0,1));%turn off cooling
        prog.GenSeq(Pulse('OnResCooling',0,dic.Tcooling));
         % continuous GSC
        SeqGSC=[]; N=4; Tstart=2;
        Mode2Cool=mode;
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
        prog.GenSeq(Pulse('DIO7',0,1));
        % sideband Shelving
        prog.GenSeq([Pulse('NoiseEater674',2,dic.vibMode(mode).coldPiTime),...
                     Pulse('674DDS1Switch',2,dic.vibMode(mode).coldPiTime)]);
        % detection
        prog.GenSeq([Pulse('OnRes422',0,dic.TDetection) Pulse('PhotonCount',0,dic.TDetection)]);
        %resume cooling
        prog.GenSeq(Pulse('Repump1033',0,dic.T1033));
        prog.GenSeq(Pulse('OffRes422',0,0));
        prog.GenFinish;
        
        dic.com.UploadCode(prog);
        dic.com.UpdateFpga;
        dic.com.WaitForHostIdle; % wait until host finished it last task
        dic.com.Execute(100);
        dic.com.WaitForHostIdle;
        r = dic.com.ReadOut(100);
        r = r(2:end);
    end 

end