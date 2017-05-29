function TwoIonsMeltingPMTScan
dic=Dictator.me;


%Vcap=400;
LaserHeatingFrequency=213;
doheat=1; theat=1600; % in microsec
waittime=[50];% msec
repetitions=50;

%dic.Vkeith=Amp;


%Vrf=[2.4:0.05:3.1];
Vrf=[2.9:0.01:3.1];
% bb1=[200 300 350];
% bb2=[360:20:500];
% Vcapg=[bb1,bb2];
Vcap=400;
dic.Vcap=Vcap;
%Vcapg=[200 450 500];

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
% pause(1);
% dic.Vcap=Vcap;
% pause(1);


% ------------Set GUI axes ---------------
InitializeAxes(dic.GUI.sca(1),'Photons #','Cases Counted #','Fluorescence Histogram',...
                [0 dic.maxPhotonsNumPerReadout],[],0);

lines =InitializeAxes (dic.GUI.sca(7),...
    'Repetitions','Crystallized ?','Decrystalization measurement',...
    [1 repetitions],[0 1.01],2);
grid(dic.GUI.sca(4),'on');
set(lines(1),'Marker','.','MarkerSize',10,'Color','b');

lines2 =InitializeAxes (dic.GUI.sca(6),...
    'Vrf','Crystallization Probability','Crystallization',...
    [Vrf(1) Vrf(end)],[0 1.],1);
set(lines2(1),'Marker','.','MarkerSize',10,'Color','b');
set(lines2(1),'XData',[],'YData',[]);


% -------- Main function scan loops ------
 dark = zeros(length(iterationsize),length(Vrf));
% dark = zeros(length(iterationsize));
success=0;


for index1=1:length(Vrf)
    dic.Vkeith=Vrf(index1);
%     dic.Vcap=Vcapg(index1);
    pause(4);
    success=0;
    set(lines(1),'XData',[],'YData',[]);
%     fprintf('Completing %d out of total %d repetitions\n',index2*chunksize,repetitions);
    for index2 = 1:iterationsize
        if dic.stop %|| ~CrystalCheckPMT
            return;
        end
        photoncount=experimentSeq(waittime,doheat,500);
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
%         disp(sprintf('Success Rate : %.0f/%.0f (total of %.0f)',success,index2,repetitions))        
        dark(index2,index1)=mean(photoncount);
        AddLinePoint(lines(1),index2,initstat);
    end
    disp(sprintf('Success Rate : %.0f/%.0f (total of %.0f)',success,index2,repetitions))            
    successrate(index1)=success/repetitions;
    AddLinePoint(lines2(1),Vrf(index1),successrate(index1));
    disp(sprintf('Vrf=%1.2f [V]  Crystallization rate = %4.2f',Vrf(index1),successrate(index1)));    
    savethis(0);
end

savethis(1);
%--------------- Save data ------------------
    function savethis(doprint)
        if (dic.AutoSaveFlag)
            scriptText=fileread(thisFile);
            scriptText(find(int8(scriptText)==10))='';
            showData='figure;plot(Vrf,successrate);xlabel(''Vrf (V)'');ylabel(''success rate [%]'');';
            dicParameters=dic.getParameters;
            save(saveFileName,'successrate','Vrf','waittime','Vcap','dark','chunksize','repetitions','index1','index2','showData','dicParameters','scriptText');
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