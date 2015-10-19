function DetectionVsComp
dic=Dictator.me;

% set file name
destDir=dic.saveDir;
thisFile=[mfilename('fullpath') '.m' ];
[filePath fileName]=fileparts(thisFile);
saveFileName=fullfile(destDir ,[fileName datestr(now,'-ddmmmyy-HHMMSS')]);

FreqMM=str2num(query(dic.KeithUSB1,'Freq?'))/1e6;
PulseTime=dic.T674;

check422Detection=1; %if==1 will scan 422 detection
checkShelving=0; %if =1 will also scan 674 shelving
checkMicSideband=0; % if==1 will scan 674 mic sideband

Vcomp=[0:10:50];
AVdcl=1.3+[-0.3:0.05:0.5]; 
dic.AVdcr=0;

% ------------Set GUI axes ---------------
InitializeAxes(dic.GUI.sca(1),'Photons #','Cases Counted #','Fluorescence Histogram',...
                [0 dic.maxPhotonsNumPerReadout],[],0);
% -------- Main function scan loops ------
detectionEff=zeros(length(AVdcl),length(Vcomp));
shelvingEff=zeros(length(AVdcl),length(Vcomp));
micromotionEff=zeros(length(AVdcl),length(Vcomp));
AVdclOrig=dic.AVdcl;
HPVcompOrig=dic.HPVcomp;
for idx1=1:length(Vcomp)
    for idx2=1:length(AVdcl)
        if dic.stop
            return;
        end
%         if dic.TwoIonFlag
%             if ~CrystalCheckPMT
%                 return;
%             end
%         end
        if checkShelving||checkMicSideband
            dic.AVdcl=1.2; dic.HPVcomp=0;pause(0.1);
            f674=dic.updateF674;pause(0.1);
        end
        %set electroedes to tested value
        dic.HPVcomp=Vcomp(idx1);
        dic.AVdcl=AVdcl(idx2);
        pause(1);
        %check detection
        r = detectionSeq(dic.F422onRes); r(1) = [];
        detectionEff(idx2,idx1)=mean(r);
        dic.GUI.sca(7);
        imagesc(Vcomp,AVdcl,double(detectionEff));
        axis([min(Vcomp) max(Vcomp) min(AVdcl) max(AVdcl)]);
        colorbar;
        xlabel('Vcomp(V)'); ylabel('Vdcl(V)'); title('Detection Eff');
        
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
            imagesc(Vcomp,AVdcl,double(shelvingEff));
            axis([min(Vcomp) max(Vcomp) min(AVdcl) max(AVdcl)]);
            colorbar;
            xlabel('Vcomp(V)'); ylabel('Vdcl(V)'); title('Shelving Eff');
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
            imagesc(Vcomp,AVdcl,double(micromotionEff));
            axis([min(Vcomp) max(Vcomp) min(AVdcl) max(AVdcl)]);
            colorbar;
            xlabel('Vcomp(V)'); ylabel('Vdcl(V)'); title('micromotion Eff');
        end
        
        % save
        savethis(0);
    end
end

m=max(max(detectionEff)); 
[a,b]=find(m==detectionEff);
fprintf('\n At (Vcomp,Vdcl)=(%g,%g), detection eff. of %.0f photons ',Vcomp(b),AVdcl(a),m);
if checkShelving
    m=max(max(shelvingEff)); 
    [a,b]=find(m==shelvingEff);
    fprintf('At (Vcomp,Vdcl)=(%g,%g), shelving eff. of %.0f %%\n ',Vcomp(b),AVdcl(a),m);
end

        

dic.HPVcomp=HPVcompOrig;
dic.AVdcl=AVdclOrig;
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
        showData=['figure; imagesc(Vcomp,AVdcl,double(detectionEff)); axis([min(Vcomp) max(Vcomp) min(AVdcl) max(AVdcl)]);colorbar; xlabel(''Vcomp(V)''); ylabel(''Vdcl(V)''); title(''Detection Eff'');' ...
            'figure; imagesc(Vcomp,AVdcl,double(shelvingEff)); axis([min(Vcomp) max(Vcomp) min(AVdcl) max(AVdcl)]); colorbar; xlabel(''Vcomp(V)''); ylabel(''Vdcl(V)''); title(''Shelving efficiency'');' ...
            'figure; imagesc(Vcomp,AVdcl,double(micromotionEff)); axis([min(Vcomp) max(Vcomp) min(AVdcl) max(AVdcl)]); colorbar; xlabel(''Vcomp(V)''); ylabel(''Vdcl(V)''); title(''Micromotion efficiency'');'];
        dicParameters=dic.getParameters;
        save(saveFileName,'checkShelving','Vcomp','AVdcl','shelvingEff','detectionEff','micromotionEff','idx1','idx2','showData','dicParameters','scriptText');
        if verbose
            disp(['Save data in : ' saveFileName]);
        end
    end 
end

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
                        Pulse('674DDS1Switch',0,PulseTime)]);
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
        prog.GenSeq(Pulse('674Switch2NovaTech',0,-1));
        prog.GenSeq(Pulse('674DDS1Switch',2,-1,'freq',pFreq,'amp',pAmp));
        prog.GenSeq(Pulse('ExperimentTrigger',0,50));
        % Doppler coolng
        prog.GenSeq(Pulse('OffRes422',0,1));%turn off cooling
        prog.GenSeq(Pulse('OnResCooling',10,dic.Tcooling));
        % OffResonance/Shelving pulse
        prog.GenSeq(Pulse('OpticalPumping',1,dic.Toptpump));
%         prog.GenSeq([Pulse('674PulseShaper',1,dic.TimeRF-2),...
%                          Pulse('RFDDS2Switch',2,dic.TimeRF)]);
        if (pAmp>50)
            prog.GenSeq([Pulse('NoiseEater674',3,pTime),...
                Pulse('674DDS1Switch',2,pTime)]);
        else
            prog.GenSeq([Pulse('674DDS1Switch',2,pTime)]);
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