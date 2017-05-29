function TwoIonsMeltingPMT
dic=Dictator.me;

Amp=3.1; minAmp=1.6;
Vcap=400;
LaserHeatingFrequency=213;
waittime=[1];
% waittime=linspace(0,20000,5); %in msec
% chunksize=2;
% repetitions=20;
heattimegrid=[10:5:4000];

% set file name
destDir=dic.saveDir;
thisFile=[mfilename('fullpath') '.m' ];
[filePath fileName]=fileparts(thisFile);
saveFileName=fullfile(destDir ,[fileName datestr(now,'-ddmmmyy-HHMMSS')]);


chunksize=1;

% number of sweeps
%  iterationsize=repetitions/chunksize;

% success=nan(repetitions,length(waittime));
% success=nan(repetitions);

%% open keithley (change RF trap voltage)
%keith=visa('ni','USB0::0x05E6::0x3390::1310276::INSTR');
keith=openUSB('USB0::0x05E6::0x3390::1310276::0::INSTR');

fprintf(keith,['VOLTage ' num2str(Amp) ' V']);
pause(1);
dic.Vcap=Vcap;
pause(1);


% ------------Set GUI axes ---------------
InitializeAxes(dic.GUI.sca(1),'Photons #','Cases Counted #','Fluorescence Histogram',...
                [0 dic.maxPhotonsNumPerReadout],[],0);

lines =InitializeAxes (dic.GUI.sca(7),...
    'Laser Heating Time','Photon Count','Melting Quantum Dynamics',...
    [heattimegrid(1) heattimegrid(end)],[0 dic.maxPhotonsNumPerReadout*2],2);
grid(dic.GUI.sca(4),'on');
set(lines(1),'Marker','.','MarkerSize',10,'Color','b');
set(lines(2),'Marker','.','MarkerSize',10,'Color','r');

% -------- Main function scan loops ------
 dark = zeros(length(heattimegrid),length(waittime));
% dark = zeros(length(iterationsize));
 set(lines(1),'XData',[],'YData',[]);

for index2=1:length(heattimegrid)
%     fprintf('Completing %d out of total %d repetitions\n',index2*chunksize,repetitions);
    for index1 = 1:length(waittime)
        if dic.stop %|| ~CrystalCheckPMT
            return;
        end
        photoncount=experimentSeq(waittime(index1),heattimegrid(index2),500);
        [result initstat]=CrystalCheckPMT(Amp); 
        
        %     r=experimentSequence(PulseTime(index1),dic.updateF674);
%         dic.GUI.sca(1); %get an axis from Dictator GUI to show data
%         hist(r,0:1:(1.8*dic.maxPhotonsNumPerReadout));
        if result==0
            disp('Critical Failure');
            return;
        end
        dark(index2,index1)=photoncount;
%         AddLinePoint(lines(1),waittime(index1),mean(dark(1:index2,index1)));
        AddLinePoint(lines(1),heattimegrid(index2),photoncount);

        %         disp(sprintf('waittime=%2.f [s]  Detection Efficiency = %4.2f',waittime(index1),mean(dark(1:index2,index1))));
%         pause(0.1);
%         fprintf('Wait time = %d // Success Probability = %.2f \n',waittime(index1),mean(dark(1:index2,index1)));
    end
    savethis(0);
end

set(lines(2),'XData',waittime,'YData',mean(dark));
savethis(1);
%--------------- Save data ------------------
    function savethis(doprint)
        if (dic.AutoSaveFlag)
            scriptText=fileread(thisFile);
            scriptText(find(int8(scriptText)==10))='';
            showData='figure;plot(heattimegrid,dark(:,1));xlabel(''Heating Time [\mus]'');ylabel(''Photon Count'');';
            dicParameters=dic.getParameters;
            save(saveFileName,'heattimegrid','dark','index2','showData','dicParameters','scriptText');
            if doprint
                disp(['Save data in : ' saveFileName]);
            end
        end
    end

    function r=experimentSeq(waitt,HeatTime,offResTime)%create and run a single sequence of detection
        pause(0.5);
        prog=CodeGenerator;
        prog.GenDDSPullParametersFromBase;
        prog.GenSeq(Pulse('ExperimentTrigger',0,50));  
        % trial
        prog.GenSeq(Pulse('Repump1092',0,0,'freq',dic.F1092));
        
        prog.GenSeq(Pulse('OffRes422',0,offResTime));
        
        %set-up detection(also=optical repump), 1092 and on-res cooling freq.
        prog.GenSeq(Pulse('OnRes422',0,-1,'freq',dic.F422onResCool));
        if waitt>0
            prog.GenSeq(Pulse('OffRes422',0,100));
            prog.GenSeq(Pulse('OnResCooling',0,dic.Tcooling));
            
            % Heating with probe beam
            prog.GenSeq(Pulse('OnRes422',0,-1,'freq',LaserHeatingFrequency));
            prog.GenPause(2000);
            prog.GenSeq(Pulse('OnRes422',0,HeatTime));
            prog.GenSeq(Pulse('OpticalPumping',0,dic.Toptpump));
            
            % brings back 422 to initial frequency for cooling
            prog.GenSeq(Pulse('OnRes422',0,-1,'freq',dic.F422onResCool));
            prog.GenSeq(Pulse('Repump1092',0,-1));
            prog.GenSeq(Pulse('Repump1033',0,-1));

            %        prog.GenSeq(Pulse('Shutters',0,0));
            prog.GenPause(waitt*1000);
            %        prog.GenSeq(Pulse('Shutters',0,-1));
            %        prog.GenPause(5000); %convert to microseconds
            prog.GenSeq(Pulse('Repump1033',0,0));
            prog.GenSeq(Pulse('Repump1092',0,0));

        else
            prog.GenPause(1000);
        end
        
        %resume cooling
        prog.GenSeq(Pulse('Repump1033',0,dic.T1033));
        prog.GenSeq([Pulse('OnRes422',100,dic.TDetection) Pulse('PhotonCount',100,dic.TDetection)]);
        prog.GenSeq(Pulse('OffRes422',500,0));
        
        prog.GenFinish;
        
        dic.com.UploadCode(prog);
        dic.com.UpdateFpga;
        dic.com.WaitForHostIdle; % wait until host finished it last task
        dic.com.Execute(1);
        dic.com.WaitForHostIdle;
        r = dic.com.ReadOut(1);
%         r = r(2:end);        
    end
       

end
    