function MollmerSorensenGate2DScan
dic=Dictator.me;

% set file name
destDir=dic.saveDir;
thisFile=[mfilename('fullpath') '.m' ];
[filePath fileName]=fileparts(thisFile);
saveFileName=fullfile(destDir ,[fileName datestr(now,'-ddmmmyy-HHMMSS')]);

FreqMM=str2num(query(dic.KeithUSB1,'Freq?'))/1e6;
PulseTime=dic.T674;

GateTime=[0:15:50];
GateDetuning=1.3+[-0.3:0.1:0.5]; 
dic.AVdcr=0;

% ------------Set GUI axes ---------------
InitializeAxes(dic.GUI.sca(1),'Photons #','Cases Counted #','Fluorescence Histogram',...
                [0 dic.maxPhotonsNumPerReadout],[],0);
% -------- Main function scan loops ------
p0=zeros(length(GateDetuning),length(GateTime));
p1=zeros(length(GateDetuning),length(GateTime));
p2=zeros(length(GateDetuning),length(GateTime));

for idx1=1:length(GateTime)
    for idx2=1:length(GateDetuning)
        if dic.stop
            return;
        end
        
        pause(1);
        %check detection
        r = detectionSeq(dic.F422onRes); r(1) = [];
        detectionEff(idx2,idx1)=mean(r);
        dic.GUI.sca(7);
        imagesc(GateTime,GateDetuning,double(detectionEff));
        axis([min(GateTime) max(GateTime) min(GateDetuning) max(GateDetuning)]);
        colorbar;
        xlabel('GateTime(V)'); ylabel('Vdcl(V)'); title('Detection Eff');
        
        %check Shelving
        if checkShelving
            r=shelvingSeq(f674,dic.T674,100);
            if dic.TwoIonFlag
                shelvingEff(idx2,idx1) =100-sum( (r>dic.TwoIonsCountThreshold)*2+...
                    ((r>dic.darkCountThreshold)&(r<dic.TwoIonsCountThreshold))*1 ...
                    )/2/length(r)*100;
            else
                shelvingEff(idx2,idx1) = sum( r<dic.darkCountThreshold)/length(r)*100;
            end
            
            dic.GUI.sca(6);
            imagesc(GateTime,GateDetuning,double(shelvingEff));
            axis([min(GateTime) max(GateTime) min(GateDetuning) max(GateDetuning)]);
            colorbar;
            xlabel('GateTime(V)'); ylabel('Vdcl(V)'); title('Shelving Eff');
        end
        
        % check micromotion shelving
        if checkMicSideband
            pause(0.1);
            r=shelvingSeq(f674+FreqMM,dic.T674,100);
            pause(0.1);
            if dic.TwoIonFlag
               micromotionEff(idx2,idx1) =100-sum( (r>dic.TwoIonsCountThreshold)*2+...
                   ((r>dic.darkCountThreshold)&(r<dic.TwoIonsCountThreshold))*1 ...
                   )/2/length(r)*100;
            else
                micromotionEff(idx2,idx1) = sum( r<dic.darkCountThreshold)/length(r)*100;
            end
            
            dic.GUI.sca(4);
            imagesc(GateTime,GateDetuning,double(micromotionEff));
            axis([min(GateTime) max(GateTime) min(GateDetuning) max(GateDetuning)]);
            colorbar;
            xlabel('GateTime(V)'); ylabel('Vdcl(V)'); title('micromotion Eff');
        end
        
        % save
        savethis(0);
    end
end

        

% set(lines(2),'XData',waittime,'YData',mean(dark));
savethis;
%--------------- Save data ------------------
function savethis(verbose)
    if ~exist('verbose')
        verbose=1;
    end
    if (dic.AutoSaveFlag)
        scriptText=fileread(thisFile);
        scriptText(find(int8(scriptText)==10))='';
        showData=['figure; imagesc(GateTime,GateDetuning,double(detectionEff)); axis([min(GateTime) max(GateTime) min(GateDetuning) max(GateDetuning)]);colorbar; xlabel(''GateTime(V)''); ylabel(''Vdcl(V)''); title(''Detection Eff'');' ...
            'figure; imagesc(GateTime,GateDetuning,double(shelvingEff)); axis([min(GateTime) max(GateTime) min(GateDetuning) max(GateDetuning)]); colorbar; xlabel(''GateTime(V)''); ylabel(''Vdcl(V)''); title(''Shelving efficiency'');' ...
            'figure; imagesc(GateTime,GateDetuning,double(micromotionEff)); axis([min(GateTime) max(GateTime) min(GateDetuning) max(GateDetuning)]); colorbar; xlabel(''GateTime(V)''); ylabel(''Vdcl(V)''); title(''Micromotion efficiency'');'];
        dicParameters=dic.getParameters;
        save(saveFileName,'checkShelving','GateTime','GateDetuning','shelvingEff','detectionEff','micromotionEff','idx1','idx2','showData','dicParameters','scriptText');
        if verbose
            disp(['Save data in : ' saveFileName]);
        end
    end 
end

% --------------------------------------------------------------------
    function r=experimentSequence(pulseTime,freq)

        prog=CodeGenerator;
        prog.GenDDSPullParametersFromBase;
        prog.GenSeq(Pulse('ExperimentTrigger',0,50));
        prog.GenSeq(Pulse('674DDS1Switch',0,-1,'amp',100));
        % Doppler coolng
        prog.GenSeq(Pulse('OffRes422',0,1));%turn off cooling
        prog.GenSeq(Pulse('OnResCooling',0,dic.Tcooling));
                     
         % continuous GSC
        SeqGSC=[]; N=4; Tstart=2;
        Mode2Cool=1;
        if (~isempty(Mode2Cool))
            for mode=Mode2Cool
                SeqGSC=[SeqGSC,Pulse('NoiseEater674',Tstart,dic.vibMode(mode).coolingTime/N),...
                               Pulse('674DDS1Switch',Tstart,dic.vibMode(mode).coolingTime/N,...
                                     'freq',dic.updateF674+dic.vibMode(mode).freq+dic.acStarkShift674)];
                Tstart=2+Tstart+dic.vibMode(mode).coolingTime/N;
            end
            prog.GenSeq([Pulse('Repump1033',0,0), Pulse('OpticalPumping',0,0)]);
            prog.GenRepeatSeq(SeqGSC,N);
            prog.GenSeq([Pulse('Repump1033',dic.T1033,-1), Pulse('OpticalPumping',dic.T1033,-1)]);
            % pulsed GSC
            for mode=fliplr(Mode2Cool)
            prog.GenRepeatSeq([Pulse('NoiseEater674',2,dic.vibMode(mode).coldPiTime),...
                               Pulse('674DDS1Switch',2,dic.vibMode(mode).coldPiTime,'freq',dic.updateF674+dic.vibMode(mode).freq),...
                               Pulse('Repump1033',dic.vibMode(mode).coldPiTime,dic.T1033),...
                               Pulse('OpticalPumping',dic.vibMode(mode).coldPiTime+dic.T1033,dic.Toptpump)],2);                          
            end
        end                                
 
        %sideband Shelving
        prog.GenSeq([Pulse('NoiseEater674',2,pulseTime),...
                     Pulse('674DDS1Switch',2,pulseTime,'freq',freq)]);
        % detection
        prog.GenSeq([Pulse('OnRes422',0,dic.TDetection) Pulse('PhotonCount',0,dic.TDetection)]);
        %resume cooling
        prog.GenSeq(Pulse('Repump1033',0,dic.T1033));
        prog.GenSeq(Pulse('OffRes422',0,0));
        prog.GenFinish;

        dic.com.UploadCode(prog);
        dic.com.UpdateFpga;
        dic.com.WaitForHostIdle; % wait until host finished it last task
        dic.com.Execute(rep);
        dic.com.WaitForHostIdle;
        r = dic.com.ReadOut(rep);
        r = r(2:end);
    end
end