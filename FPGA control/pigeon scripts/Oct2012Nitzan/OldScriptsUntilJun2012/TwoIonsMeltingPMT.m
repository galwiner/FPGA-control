function TwoIonsMeltingPMT
dic=Dictator.me;

Vcap=100;
LaserHeatingFrequency=213;
doheat=1; theat=8000; % in microsec
waittime=[60000];% msec
% waittime=linspace(0,20000,5); %in msec
% chunksize=2;
repetitions=10;
Amp=dic.Vkeith;

% set file name
destDir=dic.saveDir;
thisFile=[mfilename('fullpath') '.m' ];
[filePath fileName]=fileparts(thisFile);
saveFileName=fullfile(destDir ,[fileName datestr(now,'-ddmmmyy-HHMMSS')]);


chunksize=1;

% number of sweeps
 iterationsize=repetitions/chunksize;

% success=nan(repetitions,length(waittime));
success=nan(repetitions);

%% open keithley (change RF trap voltage)
%keith=visa('ni','USB0::0x05E6::0x3390::1310276::INSTR');
keith=openUSB('USB0::0x05E6::0x3390::1310276::0::INSTR');

% fprintf(keith,['VOLTage ' num2str(Amp) ' V']);
pause(1);
dic.Vcap=Vcap;
pause(1);


% ------------Set GUI axes ---------------
InitializeAxes(dic.GUI.sca(1),'Photons #','Cases Counted #','Fluorescence Histogram',...
                [0 dic.maxPhotonsNumPerReadout],[],0);

lines =InitializeAxes (dic.GUI.sca(7),...
    'Repetitions','Crystallized ?','Decrystalization measurement',...
    [1 repetitions],[0 1.01],2);
grid(dic.GUI.sca(4),'on');
set(lines(1),'Marker','.','MarkerSize',10,'Color','b');

% -------- Main function scan loops ------
 dark = zeros(length(iterationsize),length(waittime));
% dark = zeros(length(iterationsize));
    set(lines(1),'XData',[],'YData',[]);
success=0;

for index2=1:iterationsize
%     fprintf('Completing %d out of total %d repetitions\n',index2*chunksize,repetitions);
    for index1 = 1:length(waittime)
        if dic.stop %|| ~CrystalCheckPMT
            return;
        end
        photoncount=experimentSeq(waittime(index1),doheat,500);
        % if photoncount > 35 then system is considered crystallized
        % otherwise either melted or one ion.
        [result initstat]=CrystalCheckPMT(dic.Vkeith); 
        if result==0
            savethis(1);
            disp('Critical Failure');
            return;
        end
        if initstat==1
            success=success+1;
        end
        disp(sprintf('Success Rate : %.0f/%.0f (total of %.0f)',success,index2,repetitions))        
        dark(index2,index1)=mean(photoncount);
        AddLinePoint(lines(1),index2,initstat);
    end
    savethis(0);
end

savethis(1);
%--------------- Save data ------------------
    function savethis(doprint)
        if (dic.AutoSaveFlag)
            scriptText=fileread(thisFile);
            scriptText(find(int8(scriptText)==10))='';
            showData='figure;plot(1:repetitions,reshape(dark,1,[])>35);xlabel(''repetitons'');ylabel(''crystal?''); title(sprintf(''Vkeith=%.2f,Vcap%.2f'',Amp,Vcap))';
            dicParameters=dic.getParameters;
            save(saveFileName,'Amp','waittime','Vcap','dark','chunksize','repetitions','index1','index2','showData','dicParameters','scriptText');
            if doprint
                disp(['Save data in : ' saveFileName]);
            end
        end
    end

    function r=experimentSeq(waitt,Heat,offResTime)%create and run a single sequence of detection
        prog=CodeGenerator;
        prog.GenDDSPullParametersFromBase;
        prog.GenSeq(Pulse('ExperimentTrigger',0,50));  
        
        %set 422 on resonanance to cool
        prog.GenSeq(Pulse('OnRes422',0,-1,'freq',dic.F422onResCool));
        if waitt>0
            %cool with 522 then close it.
            prog.GenSeq(Pulse('OffRes422',0,100));
            prog.GenSeq(Pulse('OnResCooling',0,dic.Tcooling));
            
            if Heat==1
                % Heating with probe beam
                prog.GenSeq(Pulse('OnRes422',0,-1,'freq',LaserHeatingFrequency));
                prog.GenPause(2000);
                prog.GenSeq(Pulse('OnRes422',0,theat));
                prog.GenSeq(Pulse('OpticalPumping',0,dic.Toptpump));
                
                % brings back 422 to initial frequency for cooling
                prog.GenSeq(Pulse('OnRes422',0,-1,'freq',dic.F422onResCool));
            end
            prog.GenPause(waitt*1000);
        else
            prog.GenPause(1000);
        end
              
        %resume cooling
        prog.GenSeq([Pulse('OnRes422',100,dic.TDetection) Pulse('PhotonCount',100,dic.TDetection)]);       
        prog.GenSeq(Pulse('OffRes422',0,0));
        prog.GenFinish;
        
        dic.com.UploadCode(prog);
        dic.com.UpdateFpga;
        dic.com.WaitForHostIdle; % wait until host finished it last task
        dic.com.Execute(chunksize);
        dic.com.WaitForHostIdle;
        r = dic.com.ReadOut(chunksize);
    end

end
    