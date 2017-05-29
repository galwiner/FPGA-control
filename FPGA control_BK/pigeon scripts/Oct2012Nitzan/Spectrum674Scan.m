function valid=Spectrum674Scan(varargin)
dic=Dictator.me;
savedata=1;

pulseTime=dic.T674*10;
pulseAmp=100;
MMFreq=21.75;

DetuningSpinDown=(-2.802*1/2+1.68*3/2)*(dic.FRF/2.802);

InitSpinDownd=0;
DoPrepareMixture=0; %prepare 50/50 mixture of up and down (no optical pumping)
SweepWithSinglePass=0;

if DoPrepareMixture
    maxvalplot=50;
else
    maxvalplot=100;
end
lineNum=3;
if dic.curBeam==0 %674 beam horizontal at 45 deg to axial
    f674List=-4:0.03:0;
else             %674 beam vertical at 45 deg to axial
    f674List=dic.F674+(-0.1:0.005:0.1); 
    if (lineNum~=3)
        [secondLineFreq,secondLineTime,isOptPumpNeeded]=S2DTransFreqAndPiTime(lineNum);
        f674List=secondLineFreq+(-0.1:0.005:0.1); 
    end
end

%--------options-------------
for i=1:2:size(varargin,2)
    switch lower(char(varargin(i)))
        case 'freq'
            f674List=varargin{i+1};
        case 'duration'
            pulseTime=varargin{i+1};
        case 'amp'
            pulseAmp=varargin{i+1};
        case 'save'
            savedata=varargin{i+1};
        case 'deflectorguaging'
            forDeflectorGuaging = varargin{i+1};
    end; %switch
end;%for loop
valid = 0;

%-------------- Set GUI figures ---------------------
InitializeAxes (dic.GUI.sca(1),'Photons #','Cases Counted #','Fluorescence Histogram',...
    [0 dic.maxPhotonsNumPerReadout],[],0);
lines =InitializeAxes (dic.GUI.sca(9),'F_{674} [MHz]','Dark Counts %','Shelving Line',...
    [f674List(1) f674List(end)],[0 maxvalplot],2);
set(lines(1),'XData',[],'YData',[],'Color',RandRGBNoWhite,'Marker','.','MarkerSize',10);
set(lines(2),'Color',[0 0 0],'XData',[],'YData',[]);

%-------------- Main function scan loops ---------------------
dark = zeros(size(f674List));
countcheck=0;

if dic.SitOnItFlag
    cont=1;
    dic.setNovatech('DoublePass','freq',dic.F674,'amp',1000);
    ChannelSwitch('674DoublePass','on');
    while (cont)
        if (dic.stop)
            cont=0;
        end
%         r=experimentSequence(dic.SinglePass674freq,pulseTime,pulseAmp);
%         dic.GUI.sca(1); %get an axis from Dictator GUI to show data
%         hist(r,1:1:dic.maxPhotonsNumPerReadout);
%         if dic.TwoIonFlag
%             darka =100-sum( (r>dic.TwoIonsCountThreshold)*2+...
%                 ((r>dic.darkCountThreshold)&(r<dic.TwoIonsCountThreshold))*1 ...
%                 )/2/length(r)*100;
%         else
%             darka = sum( r<dic.darkCountThreshold)/length(r)*100;
%         end        
%          xlabel(num2str(darka,2),'FontSize',100);
    end
else
    for index1 = 1:length(f674List)
        if dic.stop
            return
        end
        if countcheck==15
            CrystalCheckPMT;
            countcheck=0;
        else
            countcheck=countcheck+1;
        end
        
        % control the double pass frequency
%         dic.setNovatech('DoublePass','freq',dic.updateF674-MMFreq/2+(1-SweepWithSinglePass)*f674List(index1)/2,'amp',1000);
         dic.setNovatech('DoublePass','freq',dic.updateF674+(1-SweepWithSinglePass)*f674List(index1)/2,'amp',1000);

        pause(0.1);
        r=experimentSequence(dic.SinglePass674freq+SweepWithSinglePass*f674List(index1),pulseTime,pulseAmp);%(FreqSinglePass,pulseTime,pulseAmp);
        dic.GUI.sca(1);
        hist(r,1:1:dic.maxPhotonsNumPerReadout);
        ivec=dic.IonThresholds;
        tmpdark=0;
        for tmp=1:dic.NumOfIons
            tmpdark=tmpdark+sum((r>ivec(tmp))&(r<ivec(tmp+1)))*tmp;
        end
        tmpdark=100-tmpdark/length(r)/(dic.NumOfIons)*100;
        dark(index1)=tmpdark;       
        AddLinePoint(lines(1),f674List(index1),dark(index1))
    end

    %------------ Save data ------------------
        showData='figure;plot(f674List,dark);xlabel(''F_674 [Mhz]'');ylabel(''dark[%]'');';
        dic.save;
end
%%------------------------ experiment sequence -----------------
    function r=experimentSequence(pFreq,pTime,pAmp)
        prog=CodeGenerator;
        prog.GenDDSPullParametersFromBase;

        % set DDS freq and amp
        prog.GenSeq(Pulse('674DDS1Switch',2,-1,'freq',pFreq,'amp',100));
        prog.GenSeq(Pulse('ExperimentTrigger',0,50));
        % Doppler coolng
        prog.GenSeq(Pulse('OffRes422',0,100));%turn off cooling
        prog.GenSeq(Pulse('OnResCooling',10,dic.Tcooling));
        
        %activate noise eater, move it to int hold and repump
        prog.GenSeq([Pulse('674DDS1Switch',0,15),... 
                     Pulse('NoiseEater674',2,10),Pulse('674DoublePass',0,15),...
                     Pulse('Repump1033',15,dic.T1033)]);
                 
        % Optical pumping    
        if ~DoPrepareMixture
         prog.GenSeq(Pulse('OpticalPumping',1,dic.Toptpump));
        end 
        %Do pi pulse RF $prepare to -1/2
        if InitSpinDownd
                prog.GenSeq(Pulse('RFDDS2Switch',0,dic.TimeRF));
        end
        % Shelving pulse
        prog.GenSeq([Pulse('674DDS1Switch',2,pTime,'freq',pFreq,'amp',pAmp),...
                     Pulse('674DoublePass',0,pTime+2)]);     


        % detection
        prog.GenSeq([Pulse('OnRes422',0,dic.TDetection) Pulse('PhotonCount',0,dic.TDetection)]);
        %resume cooling
        prog.GenSeq(Pulse('Repump1033',0,dic.T1033));
        prog.GenSeq(Pulse('674DDS1Switch',2,-1,'amp',100));
        prog.GenSeq(Pulse('OffRes422',0,0));
        prog.GenFinish;    
        dic.com.UploadCode(prog);
        dic.com.UpdateFpga;
        dic.com.WaitForHostIdle; % wait until host finished it last task
        rep=100;
        dic.com.Execute(rep);
        dic.com.WaitForHostIdle;
        r = dic.com.ReadOut(rep);
        r = r(2:end);
    end
end

