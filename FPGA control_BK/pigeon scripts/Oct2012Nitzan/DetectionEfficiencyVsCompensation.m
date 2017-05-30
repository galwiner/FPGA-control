function DetectionEfficiencyVsCompensation
dic=Dictator.me;

% set file name
showData='figure;imagesc(Vcomp,AVdcl,reshape(mean(dark(1:rep,:,:)),length(AVdcl),length(Vcomp))); axis([min(Vcomp) max(Vcomp) min(AVdcl) max(AVdcl)]); colorbar;xlabel(''Vcomp(V)''); ylabel(''Vdcl(V)''); title(''Shelving efficiency after 2s''); figure; imagesc(Vcomp,AVdcl,reshape(mean(1-initialCrystal(1:rep,:,:)),length(AVdcl),length(Vcomp)));axis([min(Vcomp) max(Vcomp) min(AVdcl) max(AVdcl)]);colorbar; xlabel(''Vcomp(V)''); ylabel(''Vdcl(V)''); title(''Decrystal %''); figure; imagesc(Vcomp,AVdcl,double(detectionEff)); axis([min(Vcomp) max(Vcomp) min(AVdcl) max(AVdcl)]);colorbar; xlabel(''Vcomp(V)''); ylabel(''Vdcl(V)''); title(''Detection Eff''); imagesc(Vcomp,AVdcl,double(shelvingEff)); axis([min(Vcomp) max(Vcomp) min(AVdcl) max(AVdcl)]); colorbar; xlabel(''Vcomp(V)''); ylabel(''Vdcl(V)''); title(''Shelving efficiency'');';

PulseTime=dic.T674;
waittime=5000; %in msec

Vcomp=[-2:0.5:2];
AVdcl=1+[-0.0:0.07:0.3]; 
dic.AVdcr=0;

repetitions=100;
chunksize=1;

% number of sweeps
iterationsize=repetitions/chunksize;

% if dic.curBeam==0 %674 beam horizontal at 45 deg to axial
%     PulseTime=0.1:1:50;
% elseif dic.curBeam==1             %674 beam vertical at 45 deg to axial
%     PulseTime=1:3:150;
% else
%     PulseTime=1:20:600;
% end
% ------------Set GUI axes ---------------
InitializeAxes(dic.GUI.sca(1),'Photons #','Cases Counted #','Fluorescence Histogram',...
                [0 dic.maxPhotonsNumPerReadout],[],0);
% -------- Main function scan loops ------
dark = zeros(iterationsize,length(AVdcl),length(Vcomp));
initialCrystal=zeros(iterationsize,length(AVdcl),length(Vcomp));
finalCrystal=zeros(iterationsize,length(AVdcl),length(Vcomp));
detectionEff=zeros(length(AVdcl),length(Vcomp));
shelvingEff=zeros(length(AVdcl),length(Vcomp));
AVdclOrig=dic.AVdcl;
HPVcompOrig=dic.HPVcomp;
dic.setNovatech('DoublePass','freq',dic.updateF674,'amp',1000);
for idx1=1:length(Vcomp)
        dic.Vcomp=Vcomp(idx1);

    for idx2=1:length(AVdcl)
        if dic.stop
            return;
        end                
        
%         f674=dic.updateF674;
        %set electroedes to tested value
%         dic.HPVcomp=Vcomp(idx1);
        dic.AVdcl=AVdcl(idx2);
        r = detectionSeq(dic.F422onRes); r(1) = [];
        detectionEff(idx2,idx1)=mean(r);
        r=shelvingSeq(dic.SinglePass674freq,dic.T674,100);
        if dic.TwoIonFlag
            shelvingEff(idx2,idx1) =100-sum( (r>dic.TwoIonsCountThreshold)*2+...
                ((r>dic.darkCountThreshold)&(r<dic.TwoIonsCountThreshold))*1 ...
                )/2/length(r)*100;
        else
            shelvingEff(idx2,idx1) = sum( r<dic.darkCountThreshold)/length(r)*100;
        end
        dic.GUI.sca(7);
        imagesc(Vcomp,AVdcl,double(detectionEff));
        axis([min(Vcomp) max(Vcomp) min(AVdcl) max(AVdcl)]);
        colorbar;
        xlabel('Vcomp(V)'); ylabel('Vdcl(V)'); title('Detection Eff');
        dic.GUI.sca(6);
        imagesc(Vcomp,AVdcl,double(shelvingEff));
        axis([min(Vcomp) max(Vcomp) min(AVdcl) max(AVdcl)]);
        colorbar;
        xlabel('Vcomp(V)'); ylabel('Vdcl(V)'); title('Shelving Eff');
        for rep=1:iterationsize
%             f674=dic.updateF674;
%             fprintf('.');
            %set electroedes to tested value
%             dic.HPVcomp=Vcomp(idx1);
%             dic.AVdcl=AVdcl(idx2);
            
%             [res initial]=CrystalCheckPMT(dic.Vkeith);
%             finalCrystal(rep,idx2,idx1)=res;
%             initialCrystal(rep,idx2,idx1)=initial;
%             if dic.stop || ~res
%                 dic.save;
%                 dic.HPVcomp=HPVcompOrig;
%                 dic.AVdcl=AVdclOrig;
%                 return;
%             end
%             r=experimentSequence(waittime,f674);
            % return electrodes to origianl value
%             dic.HPVcomp=HPVcompOrig;
%             dic.AVdcl=AVdclOrig;
            
%             if dic.TwoIonFlag
%                 dark(rep,idx2,idx1) =100-sum( (r>dic.TwoIonsCountThreshold)*2+...
%                     ((r>dic.darkCountThreshold)&(r<dic.TwoIonsCountThreshold))*1 ...
%                     )/2/length(r)*100;
%             else
%                 dark(rep,idx2,idx1) = sum( r<dic.darkCountThreshold)/length(r)*100;
%             end
%             pause(0.1);
        end
%         fprintf('\n At (Vcomp,Vdcl)=(%g,%g), shelving efficiency of %d \n',Vcomp(idx1),AVdcl(idx2),mean(dark(1:rep,idx2,idx1)));
        %show intermediate graph
        dic.GUI.sca(11);
        imagesc(Vcomp,AVdcl,reshape(mean(dark(1:rep,:,:)),length(AVdcl),length(Vcomp)));
        axis([min(Vcomp) max(Vcomp) min(AVdcl) max(AVdcl)]);
        colorbar;
        xlabel('Vcomp(V)'); ylabel('Vdcl(V)'); title('Shelving efficiency after 2s');
        dic.GUI.sca(10);
        imagesc(Vcomp,AVdcl,reshape(mean(1-initialCrystal(1:rep,:,:)),length(AVdcl),length(Vcomp)));
        axis([min(Vcomp) max(Vcomp) min(AVdcl) max(AVdcl)]);
        colorbar;
        xlabel('Vcomp(V)'); ylabel('Vdcl(V)'); title('Melting %');
       
    end
end
dic.HPVcomp=HPVcompOrig;
dic.AVdcl=AVdclOrig;
% set(lines(2),'XData',waittime,'YData',mean(dark));
dic.save;

%--------------------------------------------------------------------
    function r=experimentSequence(waitt,freq)
        prog=CodeGenerator;
        prog.GenDDSPullParametersFromBase;
        prog.GenSeq(Pulse('674Switch2NovaTech',0,-1));
        prog.GenSeq(Pulse('ExperimentTrigger',0,50));
        prog.GenSeq(Pulse('OffRes422',0,500));

        % set DDS freq and amp
        prog.GenSeq(Pulse('674DDS1Switch',0,-1,'freq',freq,'amp',100));
        % Doppler coolng
        prog.GenSeq(Pulse('OffRes422',0,1));%turn off cooling
        prog.GenSeq(Pulse('OnResCooling',0,dic.Tcooling) );
        prog.GenSeq(Pulse('OpticalPumping',0,dic.Toptpump));
        
        if waitt>0
            prog.GenPause(waitt*1000);     
        end
        
        prog.GenSeq(Pulse('OpticalPumping',0,dic.Toptpump));
%          prog.GenPause(10);
%         prog.GenSeq([Pulse('674PulseShaper',1,dic.TimeRF-2),...
%                      Pulse('RFDDS2Switch',2,dic.TimeRF)]);
        % wait 
%          prog.GenWait(10000); %half a second
        %sideband Shelving
        if (PulseTime>3)
           prog.GenSeq([Pulse('NoiseEater674',2,PulseTime-2),...
                        Pulse('674DDS1Switch',1,PulseTime),...
                        Pulse('674DoublePass',0,PulseTime+2)]);
        else
           prog.GenSeq(Pulse('674DDS1Switch',0,PulseTime));
        end
        % detection
        prog.GenSeq([Pulse('OnRes422',0,dic.TDetection) Pulse('PhotonCount',0,dic.TDetection)]);
        %resume cooling
        prog.GenSeq(Pulse('Repump1033',0,dic.T1033));
        prog.GenSeq(Pulse('OffRes422',0,0));
        prog.GenFinish;

        dic.com.UploadCode(prog);
        dic.com.UpdateFpga;
        dic.com.WaitForHostIdle; % wait until host finished it last task
        dic.com.Execute(chunksize);
        dic.com.WaitForHostIdle;
        r = dic.com.ReadOut(-1);
        if (length(r))~=chunksize
            fprintf('chunksize=%g differs from retrieved date %g\n',chunksize,length(r));
        end
        %if chunksize>1
         %   r = r(2:end);
        %end
    end

    function r=detectionSeq(freq)%create and run a single sequence of detection
        prog=CodeGenerator; 
        prog.GenSeq(Pulse('ExperimentTrigger',0,50));
        %set-up detection(also=optical repump), 1092 and on-res cooling freq. 
        if (freq>0)
            prog.GenSeq(Pulse('OnRes422',0,-1,'freq',freq));
        end
       % prog.GenSeq(Pulse('Repump1092',0,0,'freq',dic.F1092));
        prog.GenSeq(Pulse('OffRes422',0,100));
        prog.GenSeq(Pulse('OnResCooling',0,dic.Tcooling));
        prog.GenSeq([Pulse('OnRes422',100,dic.TDetection) Pulse('PhotonCount',100,dic.TDetection)]);
        prog.GenSeq(Pulse('OffRes422',500,0));
        prog.GenFinish;
        %prog.DisplayCode;

        % FPGA/Host control
        n=dic.com.UploadCode(prog);
        dic.com.UpdateFpga;
        dic.com.WaitForHostIdle;

        dic.com.Execute(100);
        dic.com.WaitForHostIdle;
        r=dic.com.ReadOut(100);
    end

    function r=shelvingSeq(pFreq,pTime,pAmp)
        prog=CodeGenerator;
        prog.GenDDSPullParametersFromBase;

        % set DDS freq and amp
        prog.GenSeq(Pulse('674DDS1Switch',2,-1,'freq',pFreq,'amp',pAmp));
        prog.GenSeq(Pulse('ExperimentTrigger',0,50));
        % Doppler coolng
        prog.GenSeq(Pulse('OffRes422',0,1));%turn off cooling
        prog.GenSeq(Pulse('OnResCooling',10,dic.Tcooling));
        %activate noise eater, move it to int hold and repump
        prog.GenSeq([Pulse('674DDS1Switch',0,15),... %Echo is our choice for NE calib
            Pulse('NoiseEater674',2,10),Pulse('674DoublePass',0,15),...
            Pulse('Repump1033',15,dic.T1033),...
            Pulse('OpticalPumping',16+dic.T1033,dic.Toptpump)]);
        
        % OffResonance/Shelving pulse
        prog.GenSeq(Pulse('OpticalPumping',1,dic.Toptpump));
%         prog.GenSeq([Pulse('674PulseShaper',1,dic.TimeRF-2),...
%                          Pulse('RFDDS2Switch',2,dic.TimeRF)]);

        if (pAmp>50)
            prog.GenSeq([Pulse('674DDS1Switch',2,pTime),...
                 Pulse('674DoublePass',0,pTime+2)]);
        else
            prog.GenSeq([Pulse('674DDS1Switch',2,pTime),...
                PulseTime]);
        end
         % detection
        prog.GenSeq([Pulse('OnRes422',0,dic.TDetection) Pulse('PhotonCount',0,dic.TDetection)]);
        %resume cooling
        prog.GenSeq(Pulse('Repump1033',0,dic.T1033));

        prog.GenSeq([Pulse('OffRes422',0,0) Pulse('Repump1092',0,0)]);
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