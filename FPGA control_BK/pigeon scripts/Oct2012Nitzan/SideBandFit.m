function SideBandFit(Vmodes)

dic=Dictator.me;

if ~exist('Vmodes')
    Vmodes = 2;
end
%-------------- Set GUI figures ---------------------
InitializeAxes (dic.GUI.sca(1),'Photons #','Cases Counted #','Fluorescence Histogram',...
                [0 dic.maxPhotonsNumPerReadout],[],0);

lines =InitializeAxes (dic.GUI.sca(7),...
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
f674Span=-0.15:0.008:0.15;        
darkBank = zeros(length(Vmodes),2,length(f674Span));
dark=zeros(size(f674Span));
CrystalCheckPMT;
for modeInd=1:length(Vmodes)
    titlePrefix = dic.vibMode(Vmodes(modeInd)).name;
    x0=[0 0];
    isValidFit=[0 0];
    for lobeIndex = 1:2
        f674List = f674Span+dic.SinglePass674freq+(lobeIndex-1.5)*2*dic.vibMode(Vmodes(modeInd)).freq;
        set(dic.GUI.sca(8-lobeIndex),'XLim',[min(f674List) max(f674List)]);
        grid on;
        title(titlePrefix);
        set(darkCountLine(lobeIndex),'XData',[],'YData',[]);
        for index1 = 1:length(f674List)
            dic.setNovatech('DoublePass','freq',dic.updateF674,'amp',1000);                    
            if dic.stop
                return
            end
            r=experimentSequence(f674List(index1),Vmodes(modeInd));
            ivec=dic.IonThresholds;
            tmpdark=0;
            for tmp=1:dic.NumOfIons
                tmpdark=tmpdark+sum((r>ivec(tmp))&(r<ivec(tmp+1)))*tmp;
            end
            tmpdark=100-tmpdark/length(r)/(dic.NumOfIons)*100;
            dark(index1)=tmpdark;
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
        dic.vibMode(Vmodes(modeInd)).freq =-round(modeFreq*1e5)*1e-5;
        disp(char(strcat('Ion',{' '},titlePrefix,{' '},'mode frequency:',num2str(modeFreq),' MHz')));
    end
end
%------------ Save data ------------------

showData='figure;RSB(:,:)=darkBank(:,2,:);BSB(:,:)=darkBank(:,1,:);plot(f674Span,RSB,''r'',f674Span,BSB,''b'');;xlabel(''Detunning [Mhz]'');ylabel(''dark[%]'');';
dic.save;

%--------------------------------------------------------------------
    function r=experimentSequence(pulseFreq,mode)
        prog=CodeGenerator;
        prog.GenDDSPullParametersFromBase;
        prog.GenSeq(Pulse('ExperimentTrigger',0,50));
        prog.GenSeq(Pulse('674DDS1Switch',0,-1,'freq',pulseFreq,'amp',100));
        % Doppler coolng
        prog.GenSeq(Pulse('OffRes422',0,1));%turn off cooling
        prog.GenSeq(Pulse('OnResCooling',0,dic.Tcooling));
        % update the noiseEater value
        prog.GenSeq([Pulse('674DDS1Switch',0,15,'amp',100),...
                     Pulse('NoiseEater674',2,10),Pulse('674DoublePass',0,15),...        
                     Pulse('Repump1033',15,15+dic.T1033)]);
        
        prog.GenSeq(Pulse('OpticalPumping',0,dic.Toptpump));
        % sideband Shelving
        prog.GenSeq( [Pulse('674DoublePass',1,dic.vibMode(mode).hotPiTime+2),...
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
        dic.com.Execute(200);
        dic.com.WaitForHostIdle;
        r = dic.com.ReadOut(200);
        r = r(2:end);
    end 

end