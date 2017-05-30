function valid=L674FreqScan(varargin)
dic=Dictator.me;
savedata=1;
pulseTime=dic.T674;

pulseAmp=100;

lineNum=3;
f674List=dic.F674+(-0.5:0.03:0.5);

CrystalCheckPMT;
valid=1;

% if dic.curBeadic.m==0 %674 beam horizontal at 45 deg to axial
%        f674List=dic.F674+(-0.6:0.030:0.6);
% %       f674List=dic.F674+(-0.1:0.005:0.1);
%       %     f674List=154.0462+(-0.2:0.010:0.2);
% else             %674 beam vertical at 45 deg to axial
%     f674List=dic.F674+(-0.1:0.005:0.1); 
%     if (lineNum~=3)
%         [secondLineFreq,secondLineTime,isOptPumpNeeded]=S2DTransFreqAndPiTime(lineNum);
%         f674List=secondLineFreq+(-0.1:0.005:0.1); 
%     end
% end

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
lines =InitializeAxes (dic.GUI.sca(3),'F_{674} [MHz]','Dark Counts %','Shelving Line',...
    [f674List(1) f674List(end)],[0 100],2);
set(lines(1),'XData',[],'YData',[],'Marker','.','MarkerSize',10);
set(lines(2),'Color',[0 0 0],'XData',[],'YData',[]);

%-------------- Main function scan loops ---------------------
dark = zeros(size(f674List));
if dic.SitOnItFlag
    cont=1;
    dic.setNovatech('DoublePass','freq',dic.F674,'amp',1000);
    while (cont)
        if (dic.stop)
            cont=0;
        end
        r=experimentSequence(dic.SinglePass674freq,pulseTime,pulseAmp);
        dic.GUI.sca(1); %get an axis from Dictator GUI to show data
        hist(r,1:1:dic.maxPhotonsNumPerReadout);
        ivec=dic.IonThresholds;
        tmpdark=0;
        for tmp=1:dic.NumOfIons
            tmpdark=tmpdark+sum((r>ivec(tmp))&(r<ivec(tmp+1)))*tmp;
        end
        tmpdark=100-tmpdark/length(r)/(dic.NumOfIons)*100;
        darka=tmpdark;
        xlabel(num2str(darka,2),'FontSize',100);
        
%         xlabel(num2str(sum( r<dic.darkCountThreshold)/length(r)*100,2),...
%             'FontSize',100);
    end
else
    for index1 = 1:length(f674List)
        if dic.stop
            return
        end
                
        % control the double pass frequency
        dic.setNovatech('DoublePass','freq',f674List(index1),'amp',1000);
        pause(0.1);
        r=experimentSequence(dic.SinglePass674freq,pulseTime,pulseAmp);%(FreqSinglePass,pulseTime,pulseAmp);
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
    
%     %---------- fitting and updating ---------------------
    [peakValue,x0,w,xInterpulated,fittedCurve,isValidFit] = ...
        FitToSincSquared(f674List',dark');
    if (~isValidFit)||(peakValue<=60)||((max(dark)-min(dark))<=60)
        disp('Invalid fit');
        return;
    elseif (lineNum==3)
        dic.F674 = x0;
        dic.F674FWHM = 2*0.44295/w;

        set(lines(2),'XData',xInterpulated,'YData',fittedCurve);
        gca = dic.GUI.sca(3);
        text(f674List(2),0.9*peakValue,{strcat(num2str(round(peakValue)),'%')...
            ,sprintf('%2.3f MHz',x0),sprintf('%d KHz FWHM',round(2*1e3*0.44295/w))})
        grid on

        valid=1;
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
        prog.GenSeq(Pulse('674DDS1Switch',2,-1,'freq',pFreq));
        prog.GenSeq(Pulse('ExperimentTrigger',0,50));
        % Doppler coolng
        prog.GenSeq(Pulse('OffRes422',0,200));%turn off cooling
        prog.GenSeq(Pulse('OnResCooling',10,dic.Tcooling));
        % update the noiseEater value
        prog.GenSeq([Pulse('674DDS1Switch',2,15,'amp',100),...
                     Pulse('NoiseEater674',3,13),Pulse('674DoublePass',0,16),...        
                     Pulse('Repump1033',15,15+dic.T1033)]);
                                  
        % Optical pumping                 
        prog.GenSeq(Pulse('OpticalPumping',1,dic.Toptpump));

        % Shelving pulse
%         prog.GenSeq([Pulse('674DDS1Switch',2,pTime,'amp',pAmp),Pulse('674DoublePass',2,pTime)]);     
         prog.GenSeq([Pulse('674DDS1Switch',2,pTime),Pulse('674DoublePass',1,pTime+2)]);     

        % detection
        prog.GenSeq([Pulse('OnRes422',0,dic.TDetection) Pulse('PhotonCount',0,dic.TDetection)]);
        %resume cooling
        prog.GenSeq(Pulse('Repump1033',0,dic.T1033));

        prog.GenSeq([Pulse('OffRes422',0,0) Pulse('Repump1092',0,0)]);
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

