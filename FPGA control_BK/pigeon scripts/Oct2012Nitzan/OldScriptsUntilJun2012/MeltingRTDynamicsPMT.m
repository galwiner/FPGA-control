function TwoIonsMeltingPMT
dic=Dictator.me;

Amp=2.9; minAmp=1.6;
Vcap=400;

waittime=100;% in seconds
repetitions=1;
samplingTime=0.2*1e6; % in microseconds
loop=1+round(waittime*1e6/samplingTime);% numbers of timons in sequence
% note: timon=quantum of time
timeAxis=(1:loop)*samplingTime*1e-6;

% set file name
destDir=dic.saveDir;
thisFile=[mfilename('fullpath') '.m' ];
[filePath fileName]=fileparts(thisFile);
saveFileName=fullfile(destDir ,[fileName datestr(now,'-ddmmmyy-HHMMSS')]);



%% open keithley (change RF trap voltage)
%keith=visa('ni','USB0::0x05E6::0x3390::1310276::INSTR');
keith=openUSB('USB0::0x05E6::0x3390::1310276::0::INSTR');

fprintf(keith,['VOLTage ' num2str(Amp) ' V']);
pause(1);
dic.Vcap=Vcap;
pause(1);


% ------------Set GUI axes ---------------
lines =InitializeAxes (dic.GUI.sca(7),...
    'Time','Photon Count','Melting Quantum Dynamics',...
    [timeAxis(1) timeAxis(end)],[0 dic.maxPhotonsNumPerReadout*1.3],2);
grid(dic.GUI.sca(4),'on');
set(lines(1),'Marker','.','MarkerSize',10,'Color','b');
set(lines(2),'Marker','.','MarkerSize',10,'Color','r');

% -------- Main function scan loops ------
 photonCount = zeros(repetitions,loop);
 set(lines(1),'XData',[],'YData',[]);
 CrystalCheckPMT(Amp);

    for index1 = 1:repetitions
        if dic.stop %|| ~CrystalCheckPMT
            return;
        end        
        photonCount(index1,:)=experimentSeq(loop,samplingTime);
        set(lines(1),'XData',timeAxis,'YData',photonCount(index1,:));
        savethis(0);
        
        [result initstat]=CrystalCheckPMT(Amp); 
        if result==0
            disp('Critical Failure');
            return;
        end

        pause(0.1);    

    end

savethis(1);
%--------------- Save data ------------------
    function savethis(doprint)
        if (dic.AutoSaveFlag)
            scriptText=fileread(thisFile);
            scriptText(find(int8(scriptText)==10))='';
            showData='figure;plot(timeAxis,photonCount);xlabel(''Time [\mus]'');ylabel(''Photon Count'');';
            dicParameters=dic.getParameters;
            save(saveFileName,'waittime','repetitions','timeAxis','loop','samplingTime','photonCount','index1','showData','dicParameters','scriptText');
            if doprint
                disp(['Save data in : ' saveFileName]);
            end
        end
    end

    function r=experimentSeq(loop,samplingTime)%create and run a single sequence of detection
        pause(0.5);
        prog=CodeGenerator;
        prog.GenDDSPullParametersFromBase;
        prog.GenSeq(Pulse('ExperimentTrigger',0,50));  
        % trial
        prog.GenSeq(Pulse('Repump1092',0,0,'freq',dic.F1092));
        prog.GenSeq(Pulse('OffRes422',0,1000));
        prog.GenSeq(Pulse('OnResCooling',0,dic.Tcooling,'freq',dic.F422onResCool));
        %         samplingTime=5000;
        %         loop=1+round(waitt/samplingTime);% numbers of total half seconds in waitt
        %         prog.GenRepeatSeq([Pulse('OffRes422',samplingTime-550,500),...
        %                            Pulse('OnRes422',samplingTime,dic.TDetection),...
        %                            Pulse('PhotonCount',samplingTime,dic.TDetection)],loop);
        prog.GenRepeatSeq([Pulse('OnRes422',samplingTime,dic.TDetection),...
                           Pulse('PhotonCount',samplingTime,dic.TDetection)],loop);
        
        prog.GenSeq(Pulse('OffRes422',500,0));

        prog.GenFinish;
        
        dic.com.UploadCode(prog);
        dic.com.UpdateFpga;
        dic.com.WaitForHostIdle; % wait until host finished it last task
        dic.com.Execute(1);
        dic.com.WaitForHostIdle;
        r = dic.com.ReadOut(loop);
%         r = r(2:end);        
    end
       

end
    