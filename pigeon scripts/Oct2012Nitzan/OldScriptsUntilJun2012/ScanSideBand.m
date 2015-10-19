function ScanSideBand(Vmodes)

dic=Dictator.me;

if ~exist('Vmodes')
    Vmodes = 1;
end
%-------------- Set GUI figures ---------------------
InitializeAxes (dic.GUI.sca(1),'Photons #','Cases Counted #','Fluorescence Histogram',...
                [0 dic.maxPhotonsNumPerReadout],[],0);

lines =InitializeAxes (dic.GUI.sca(5),...
    'F [MHz]','Dark Counts %','Blue Sideband',...
    [],[0 100],2);
darkCountLine(1) = lines(1);
fitLine(1) = lines(2);
set(darkCountLine(1),'Marker','.','MarkerSize',10);
set(fitLine(1),'Color',[0 0 0]);

lines =InitializeAxes (dic.GUI.sca(6),...
    'F [MHz]','Dark Counts %','Red Sideband',...
    [],[0 100],2);
darkCountLine(2) = lines(1);
fitLine(2) = lines(2);
set(darkCountLine(2),'Color',get(darkCountLine(1),'Color'));
set(darkCountLine(2),'Marker','.','MarkerSize',10);
set(fitLine(2),'Color',[0 0 0]);
%-------------- main scan loop ---------------------
f674Span=-0.04:0.002:0.04;        
darkBank = zeros(length(Vmodes),2,length(f674Span));
dark=zeros(size(f674Span));
for modeInd=1:length(Vmodes)
    titlePrefix = dic.vibMode(Vmodes(modeInd)).name;
    x0=[0 0];
    isValidFit=[0 0];
    for lobeIndex = 1:2
        f674List = f674Span+dic.updateF674+(lobeIndex-1.5)*2*dic.vibMode(Vmodes(modeInd)).freq;
        set(dic.GUI.sca(4+lobeIndex),'XLim',[min(f674List) max(f674List)]);
        grid on;
        title(titlePrefix);
        set(darkCountLine(lobeIndex),'XData',[],'YData',[]);
        for index1 = 1:length(f674List)
            if dic.stop
                return
            end
            r=experimentSequence(f674List(index1),Vmodes(modeInd));
            if dic.TwoIonFlag
                dark(index1) =100-sum( (r>dic.TwoIonsCountThreshold)*2+...
                                     ((r>dic.darkCountThreshold)&(r<dic.TwoIonsCountThreshold))*1 ...
                                    )/2/length(r)*100;
            else
                dark(index1) = sum( r<dic.darkCountThreshold)/length(r)*100;
            end
            AddLinePoint(darkCountLine(lobeIndex),f674List(index1),dark(index1));
            darkBank(modeInd,lobeIndex,index1)=dark(index1);
            pause(0.1);
        end
        [peakValue,x0(lobeIndex),w,bias,xInterpulated,fittedCurve,isValidFit(lobeIndex)] = ...
            FitToBiasedSincSquared(f674List',dark');
        if ~isValidFit(lobeIndex)
            error('Invalid fit, scan aborted');
        else
            set(fitLine(lobeIndex),'XData',xInterpulated,'YData',fittedCurve);
        end
    end
    if (isValidFit(1)&&isValidFit(2))
        modeFreq = abs(diff(x0))/2;
        dic.vibMode(Vmodes(modeInd)).freq = modeFreq;
        disp(char(strcat('Ion',{' '},titlePrefix,{' '},'mode frequency:',num2str(modeFreq),' MHz')));
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
    function r=experimentSequence(pulseFreq,mode)
        prog=CodeGenerator;
        prog.GenDDSPullParametersFromBase;
        prog.GenSeq(Pulse('ExperimentTrigger',0,50));
        prog.GenSeq(Pulse('674DDS1Switch',0,-1,'freq',pulseFreq,'amp',100));
        % Doppler coolng
        prog.GenSeq(Pulse('OffRes422',0,1));%turn off cooling
        prog.GenSeq(Pulse('OnResCooling',0,dic.Tcooling));
        prog.GenSeq(Pulse('OpticalPumping',0,dic.Toptpump));
        % sideband Shelving
        prog.GenSeq([Pulse('NoiseEater674',2,dic.vibMode(mode).hotPiTime),...
                     Pulse('674DDS1Switch',2,dic.vibMode(mode).hotPiTime)]);
        % detection
        prog.GenSeq([Pulse('OnRes422',0,dic.TDetection) Pulse('PhotonCount',0,dic.TDetection)]);
        %resume cooling
        prog.GenSeq(Pulse('Repump1033',0,dic.T1033));
        prog.GenSeq(Pulse('OffRes422',0,0));
        prog.GenFinish;
        
        dic.com.UploadCode(prog);
        dic.com.UpdateFpga;
        dic.com.WaitForHostIdle; % wait until host finished it last task
        dic.com.Execute(400);
        dic.com.WaitForHostIdle;
        r = dic.com.ReadOut(100);
        r = r(2:end);
    end 

end