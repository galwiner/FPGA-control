function MeltingRatePMTvsVcap
dic=Dictator.me;

Amp=3.1; minAmp=2.1;
% Vcap=[200 300 400 450 500];

Vcapg=[200 300 400 450 500];

% Vrfgrid=3.1;

waittime=150;% in seconds
repetitions=20;
samplingTime=0.5*1e6; % in microseconds
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


% ------------Set GUI axes ---------------
lines =InitializeAxes (dic.GUI.sca(7),...
    'Time','Photon Count','Melting Quantum Dynamics',...
    [timeAxis(1) timeAxis(end)],[0 dic.maxPhotonsNumPerReadout*1.3],2);
grid(dic.GUI.sca(4),'on');
set(lines(1),'Marker','.','MarkerSize',10,'Color','b');
set(lines(2),'Marker','.','MarkerSize',10,'Color','r');

lines2 =InitializeAxes (dic.GUI.sca(8),...
    'Vcap','EscapeTime','Rock n Roll',...
    [Vcapg(1) Vcapg(end)],[0 1.4*waittime],1);
set(lines2(1),'Marker','.','MarkerSize',10,'Color','b');
set(lines2(1),'XData',[],'YData',[]);

% -------- Main function scan loops ------
 photonCount = zeros(repetitions,loop);
 set(lines(1),'XData',[],'YData',[]);
 CrystalCheckPMT(Amp);
 escapetime=zeros(repetitions,length(Vcapg));
 for index2=length(Vcapg):-1:1
    Detection;
    dic.Vcap=Vcapg(index2);
    pause(5);
%     fprintf(keith,['VOLTage ' num2str(Vrfgrid(index2)) ' V']);
    for index1 = 1:repetitions
        if dic.stop %|| ~CrystalCheckPMT
            disp('Manual Stop');
            return;
        end        
        r=experimentSeq(loop,samplingTime);
        if length(r)<loop-1 
%             disp('Warning: Emergency exit');
              escapetime(index1,index2)=timeAxis(length(r));
%               disp('V');
%               disp(timeAxis(length(r)))
        else
              escapetime(index1,index2)=timeAxis(end);
%               length(r)
%               disp('F');
        end
        disp(sprintf('Vcap=%1.2f [V] (rep:%2.f) // Escape Time = %4.2f',Vcapg(index2),index1,escapetime(index1,index2)));
        
        photonCount(index1,1:length(r))=r;
%         set(lines(1),'XData',timeAxis,'YData',photonCount(index1,:));
        savethis(0);
        [result initstat]=CrystalCheckPMT(Amp); 
        if result==0
            disp('Critical Failure');
            return;
        end
        pause(1);    
    end
    escapemean=mean(escapetime(:,index2));
    AddLinePoint(lines2(1),Vcapg(index2),escapemean);
    disp(sprintf('Vcap=%1.2f [V]  Escape Time = %4.2f',Vcapg(index2),escapemean));
 end
    
savethis(1);
%--------------- Save data ------------------
    function savethis(doprint)
        if (dic.AutoSaveFlag)
            scriptText=fileread(thisFile);
            scriptText(find(int8(scriptText)==10))='';
            showData='figure;plot(Vcapg,mean(escapetime));xlabel(''Vcap [V]'');ylabel(''Escape Time'');';
            dicParameters=dic.getParameters;
            save(saveFileName,'Vcapg','escapetime','waittime','timeAxis','loop','samplingTime','photonCount','index1','showData','dicParameters','scriptText');
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

        prog.GenRegOp('RegC=',0);
        prog.GenRepeat
             prog.GenSeq([Pulse('OnRes422',samplingTime,dic.TDetection),...
                          Pulse('PhotonCount',samplingTime,dic.TDetection)]); % the Photon count is in RegB 
            %Check if photon count is below crystal  
            prog.GenIfDo('RegB>',20)              
                    prog.GenRegOp('RegC=+1',0);
            prog.GenElseDo
                    prog.GenRegOp('RegC=',loop);
            prog.GenElseEnd;
        
        prog.GenRepeatEnd('RegC>',loop);
               
        prog.GenSeq(Pulse('OffRes422',0,0));
        prog.GenFinish;
        
        dic.com.UploadCode(prog);
        dic.com.UpdateFpga;
        dic.com.WaitForHostIdle; % wait until host finished it last task
        dic.com.Execute(1);
        dic.com.WaitForHostIdle;
        r = dic.com.ReadOut(-1);
        %r = r(2:end);        
    end
       
    dic.controlEndcapFlag=1;
    dic.Vcap=50;
    % fprintf(dic.SRSgpib,sprintf('VSET%g',50));
    disp('End cap voltage set to 50 V')
    pause(3);
    keith=openUSB('USB0::0x05E6::0x3390::1310276::0::INSTR');
    fprintf(keith,['VOLTage 1.0 V']);
    disp('Keithley voltage set to 1.0 V')
    
end
    