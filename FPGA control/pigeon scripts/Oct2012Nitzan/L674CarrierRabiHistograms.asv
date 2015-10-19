function valid=L674CarrierRabiHistograms(varargin)
dic=Dictator.me;
savedata=1;
pulseTime=dic.T674;
pulseAmp=100;
updateFit=1;

PulseTime=[linspace(dic.T674,3/2*dic.T674,5) linspace(3/2*dic.T674,2*dic.T674,5)];

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
lines =InitializeAxes (dic.GUI.sca(4),...
    'Pulse Time[\mus]','Dark Counts %','Rabi Scan',...
    [PulseTime(1) PulseTime(end)],[0 100],2);
grid(dic.GUI.sca(4),'on');
set(lines(1),'Marker','.','MarkerSize',10,'Color','b');
set(lines(2),'Marker','.','MarkerSize',10,'Color','r');

%-------------- Main function scan loops ---------------------
dark = zeros(size(PulseTime));
rep=500;
histinfo=zeros(rep,length(PulseTime));
histbins=zeros(dic.maxPhotonsNumPerReadout,length(PulseTime));
if dic.SitOnItFlag
    cont=1;
    while (cont)
        if (dic.stop)
            cont=0;
        end
        r=experimentSequence(dic.SinglePass674freq,pulseTime,pulseAmp);
        dic.GUI.sca(1); %get an axis from Dictator GUI to show data
        hist(r,1:1:dic.maxPhotonsNumPerReadout);
        xlabel(num2str(sum( r<dic.darkCountThreshold)/length(r)*100,2),...
            'FontSize',100);
    end
else
    for index1 = 1:length(PulseTime)
        if dic.stop
            return;
        end
                
        % control the double pass frequency
        dic.setNovatech('DoublePass','freq',dic.updateF674,'amp',1000);
        pause(0.1);
        r=experimentSequence(dic.SinglePass674freq,PulseTime(index1),pulseAmp);%(FreqSinglePass,pulseTime,pulseAmp);
        dic.GUI.sca(1);
        hist(r,1:1:dic.maxPhotonsNumPerReadout);
        if dic.TwoIonFlag
            dark(index1) =100-sum( (r>dic.TwoIonsCountThreshold)*2+...
                ((r>dic.darkCountThreshold)&(r<dic.TwoIonsCountThreshold))*1 ...
                )/2/length(r)*100;
        else
            dark(index1) = sum( r<dic.darkCountThreshold)/length(r)*100;
        end
        AddLinePoint(lines(1),PulseTime(index1),dark(index1));
        histinfo(:,index1)=r;
        histbins=hist(histinfo,1:1:dic.maxPhotonsNumPerReadout);
%         dic.GUI.sca(6);cla;
%         pcolor(histbins); shading flat; xlabel('Pulse Time(mus)'); ylabel('Photon #'); title('Rabi Histograms'); set(gca,'Ydir','normal');
    end
    %---------- fitting and updating ---------------------
    
    %------------ Save data ------------------
    if (dic.AutoSaveFlag&&savedata)
        showData='figure;plot(PulseTime,dark);xlabel(''F_674 [Mhz]'');ylabel(''dark[%]''); figure; imshow(histbins); shading flat; xlabel(''Pulse Time(mus)''); ylabel(''Photon #''); title(''Rabi Histograms''); set(gca,''Ydir'',''normal'');';
        dic.save;
    end
end
%%------------------------ experiment sequence -----------------
    function r=experimentSequence(pFreq,pTime,pAmp)
        prog=CodeGenerator;
        prog.GenDDSPullParametersFromBase;

        % set DDS freq and amp
        prog.GenSeq(Pulse('ExperimentTrigger',0,50));
        % Doppler coolng
        prog.GenSeq(Pulse('OffRes422',0,1));%turn off cooling
        prog.GenSeq(Pulse('OnResCooling',10,dic.Tcooling));
        % update the noiseEater value
        if pAmp<50
            prog.GenSeq(Pulse('674DDS1Switch',2,-1,'freq',pFreq,'amp',100));            
            prog.GenSeq([Pulse('674DDS1Switch',0,15),...
                         Pulse('NoiseEater674',2,10),Pulse('674DoublePass',0,15),...        
                         Pulse('Repump1033',15,dic.T1033),...
                         Pulse('OpticalPumping',16+dic.T1033,dic.Toptpump)]);
            prog.GenSeq(Pulse('674DDS1Switch',2,-1,'amp',pAmp));
            prog.GenSeq([Pulse('674DDS1Switch',2,pTime),...
                         Pulse('NoiseEater674',3,pTime-1),...
                         Pulse('674DoublePass',2,pTime)]);
        else         
            prog.GenSeq(Pulse('674DDS1Switch',2,-1,'freq',pFreq,'amp',pAmp)); 
            prog.GenSeq(Pulse('OpticalPumping',1,dic.Toptpump)); 
            prog.GenSeq([Pulse('674DDS1Switch',2,pTime),...
                         Pulse('NoiseEater674',3,pTime-1),...
                         Pulse('674DoublePass',2,pTime)]);
        end
        % detection
        prog.GenSeq([Pulse('OnRes422',0,dic.TDetection) Pulse('PhotonCount',0,dic.TDetection)]);
        % resume cooling
        prog.GenSeq(Pulse('Repump1033',0,dic.T1033));

        prog.GenSeq([Pulse('OffRes422',0,0) Pulse('Repump1092',0,0)]);
        prog.GenFinish;    
        dic.com.UploadCode(prog);
        dic.com.UpdateFpga;
        dic.com.WaitForHostIdle; % wait until host finished it last task
 
        dic.com.Execute(rep);
        dic.com.WaitForHostIdle;
        r = dic.com.ReadOut(rep);        
    end
end

