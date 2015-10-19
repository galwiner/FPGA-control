classdef Dictator < handle
    %    This is a singleton class dealing with
    %    1. GUI
    %    2. 674 freq. drifts
    %    3. basic scans of system
    %
    %   The singleton design pattern was written by Bobby Nedelkovski
    %   The MathWorks Australia Pty Ltd
    %   Copyright 2009, The MathWorks, Inc.

    properties(Transient=true) %properties that should no be saved
        % instruments
        NovatechSerial={}; %array of Novatech serial controlling 674 Freq
        com; %tcp2labview object controlling FPGA
        HPgpib% 674 deflector freq source
        KeithUSB1; %usb handle to Keithley controlling RF master
        KeithUSB2; %usb handle to Keithley controlling RF slave
        KeithUSB3; %usb handle to Keithley controlling RF slave
        SRSgpib;
        HPVgpib; %50 Volt HP power supply
        AGILENTgpib; %agilent power supply
        %GUI
        GUI=[];
        lh=[]; %listnere for variable change
        %semaphore for GUI
        TCPlock=[];
        %scheduler object
        scheduler=[];
        %          %filename header to save user data
        %         filenameDesc='E:\measrments\Bfield\';
    end

    properties(SetObservable=true) %if one of these properties is
        %changed, an event will occure, and it will be directed
        % in the constructor to an event Handler (function
        % handlePropertyEvents(obj,src,evnt) ) which will change
        % something in the physical world corresponding to the
        % variable change

        % Threshold for telling dark count
        maxPhotonsNumPerReadout = 40; % the maximally expected number of...
                                      % photons to arrive duting TDetection.

        noiseEater674 = 2000;
        weakOnResAmp=900;
        OnResAmp=1600;
        ampRF=100;
        % default times [micro-sec]
        Toptpump=10;% 422 optical pumping time
        TOffResCooling = 500;
        Tcooling=500;% 422 on res cooling rime
        T1033=100;% 1033 optical pumping time
        T674=2.3;% 674 pi time
        TimeRF=11;% RF pi time
        piHalfRF=5.5;
        TArm=1000;% ramsey/echo single arm time
        TDetection=1200;
        vibMode = struct('name',{'COM','Strech','Radial1','Radial2'},...
            'freq',{0.97 1.68 2.988 3.07},...
            'hotPiTime',{20 20 59 50},...
            'coldPiTime',{80 100 100 100},...
            'foundInSingleIon',{1,0,1,1},...
            'coolingTime',{1e3 1e3 2e3 2e3});
        %default freqs
        F422onRes=210;
        F422onResCool=204;
        F1092=307;
        F674=100;% 674 carrier freq time
        F674DoublePassCarrier=61;
        F674FWHM = 0.1; %Full width half maximum
        FRF=12.38;% RF freq time
        acStarkShift674=0.06139;
        
        % micromotion compensation voltages
        Vcomp=3; %FPGA controlled
        AVdcl=1.5; %Agilent controlled (GPIB)
        AVdcr=2.4; %Agilent controlled (GPIB)
        HPVcomp=1.12; %HP controlled (GPIB)
        Vcap=50; %endcap north set voltage, SRS controlled
        Vkeith=1.5; %endcap north set voltage
        curBeam=0; %three possible 674 approches 0=horiz, 45 deg to axial; 1=horiz 90 to axial (i.e radial); 2=vertical
        NumOfIons=1;
        
        %auxilary vars
        %Flags variable
        SitOnEchoFlag=1;% if true, do a single echo experiment at RamseyArm
        SitOnItFlag=0;% if true, forces 422 resonance scan to sit instead at a given 422 freq
        controlEndcapFlag=0; %if true, allow Dictator to change endcap 'Vcap'
        controlKeithFlag=0;
        calibRfFlag=0; %if true calibrate the RF transition each time F674 is calibrated
        is674LockedFlag=0;%
        timerOnOffFlag=0;
        resumeFlag=0;% flag indicating if should resume previous run and in that case:
        LasersLockedFlag=0;
        SMSlaserAlertFlag=0;
        %push botton variable
        Force674ScanIntr=0;% if true, forces a scan of 674 freq
        saveIntr=0; %if true - save data
        stopIntr=0; %if true -signal to stop current run
        %experimentDesc='Experiment Description:'; %description text

        % ULE linear estimator data
        ULE=[];
        
        % S-D transition data
        S1HalfsLevel = struct('sign',{'S_{1/2,-1/2}' 'S_{1/2,1/2}'},...
            'm',{-0.5,0.5});
        D5HalfsLevel = struct('sign',{'D_{5/2,-5/2}','D_{5/2,-3/2}',...
            'D_{5/2,-1/2}','D_{5/2,1/2}','D_{5/2,3/2}','D_{5/2,5/2}'},...
            'm',{-5/2 -3/2 -1/2 1/2 3/2 5/2});
        quadTrans = struct('S1D5Levels',{[2 3] [1 2] [2 5] [1 4]},...
            'piTime',{3 3 3 3},'ShiftRFFactor',{-0.7967 -0.3974 0.3974 0.8079});
        currentQuadTrans = 3;
        
        % DDS Guaging data.
        DDSGuageData=[];
        numOfDDS = 2;
        estimatorDDSNum = 1;
        %filename header to save user data
        saveDest='E:\measrments\DataArchive';

        %sitOnItRecord = zeros(1,15); % a list of the recent SitOnit measurements for statistics.
    end

    properties %properties to save but not to do any action 
        NovatechAlias=struct(...
                'alias',{'Red','Blue','DoublePassSecond','Parity','Echo','DoublePass','DoublePassCarrier'},...
                'dev',{1,1,1,2,2,2,2},...
                'channel',{0,2,3,0,1,2,3});
       SinglePass674freq=87; %MHz;
       GateInfo=struct('GateTime_mus',125,'motionFreq_MHz',1,'GateDetuningkHz',18,'RedDetune_kHz',0,'BlueDetune_kHz',0,'RedAmp',250,'BlueAmp',250,'SBoffset',0);
       AddrInfo=struct('T674Echo',10,'T674Parity',10,'T674Blue',10,'T674Red',10,'TDDS1Switch',10,'T674Gate',10,...
           'P674Echo',0,'P674Parity',0,'P674Blue',0,'P674Red',0,'PDDS1Switch',0,'P674Gate',0);
       HiddingInfo=struct('Tmm1',30,'Tmm2',130,'Tcarrier1',3.4,'Tcarrier2',4.5,'PhaseHide',0,'Tshelving',5);

       IonThresholds=[12 100 200 1000 0 0 0 0]; %up to 8 ions threshold
    end
    properties(Hidden=true) %the following prop will not show on a propery list
        %clipbaord - a struct holding data from outside
        clipboard=[];
        %auxilary vars
        stopRun=0;% a flag indicating if the current loop should stop
        stp=0; %if true should stop current run
    end

    properties(Constant=true)
        logDir='E:\Matlab\pigeon\pigeon programs\DictatorLogs\';
        defaultFname='DictatorLog';
    end

    methods(Access=private)
        % Guard the constructor against external invocation.  We only want
        % to allow a single instance of this class.
        function newObj = Dictator()
            %             dbstack
            newObj.out('reseting all instruments');
            instrreset;%reset all serials and TCPs
            %open Novatech controlling 674 freq
            newObj.out('openning COM18 for 674 Novatech 409A control');
            newObj.NovatechSerial{1}=openSerial('COM18','BaudRate',19200);
            newObj.out('openning COM11 for 674 Novatech 409B control');
            newObj.NovatechSerial{2}=openSerial('COM11','BaudRate',19200);
            
            %open tcp2labview control of FPGA
            newObj.out('opening com with Tcp2Labview on port 6340');
            newObj.com=Tcp2Labview('localhost',6340);
            
            try
                newObj.SRSgpib=gpib('ni',0,9);
                fopen(newObj.SRSgpib);
                newObj.out('opening GPIB of SRS high voltage');
            catch
                newObj.out('Could not communicate with SRS high voltage');
            end
            try
                newObj.HPVgpib=gpib('ni',0,4);
                fopen(newObj.HPVgpib);
                newObj.out('opening GPIB of HP 50V supply');
            catch
                newObj.out('Could not communicate with HP 50V supply');
            end
            try
                newObj.AGILENTgpib=gpib('ni',0,8);
                fopen(newObj.AGILENTgpib);
                newObj.out('opening GPIB of AGILENT supply');
            catch
                newObj.out('Could not communicate with AGILENT supply');
            end
            %newObj.KeithUSB1=openUSB('USB0::0x05E6::0x3390::1310276::0::INSTR');
            newObj.KeithUSB1=openUSB('USB0::0x05E6::0x3390::1195167::0::INSTR');

%             newObj.out('opening GPIB communication HP generator');
%             newObj.HPgpib=gpib('ni',0,6);
%             try
%                 fopen(newObj.HPgpib);
%             catch
%                 newObj.out('Could not communicate with HP generator');
%             end
            %create ULE linear estimator
            %information
            newObj.ULE.freq=FIFO(2); %F674 freq history
            newObj.ULE.timeStamp=FIFO(2);%times when F674 taken
            newObj.ULE.updateTimeIntreval = 3; % minutes
            newObj.ULE.freqHistory=[];
            newObj.ULE.timeHistory=[];
            newObj.ULE.estimatedFreqHistory=[];
            newObj.ULE.deflectorFreqHistory=[];
            newObj.scheduler=timer('ExecutionMode','fixedDelay',...,
                'Period',newObj.ULE.updateTimeIntreval*60,...
                'BusyMode','drop',... %if timer callback hasn't finished and another timer event tries to start - drop it
                'StartDelay',newObj.ULE.updateTimeIntreval*60,...
                'TimerFcn',@(src,evnt)handleTimer(newObj,src,evnt));
            newObj.timerOnOffFlag=0;
            newObj.out('openning GUI');
            newObj.GUI=PulseGUI(newObj,...
                {'acStarkShift674','F674FWHM','DDSGuageData',...
                'maxPhotonsNumPerReadout', 'noiseEaterDetValue',...
                'is674LockedFlag','ULEEStimatorLinewidth','weakOnResAmp',...
                'ULEEstimatorScanNESetPoint','numOfDDS','estimatorDDSNum',...
                'Hp674Freq','stopRun','stp','SitOnEchoFlag','saveIntr','resumeFlag',...
                'SMSlaserAlertFlag','LasersLockedFlag','Vcap','curBeam',...
                'IonThresholds','piHalfRF','SinglePass674freq','saveDest','currentQuadTrans','F674DoublePassCarrier'});
            % set the listener to monitor changes of the following variables
            [varNames2BeMonitored,v]=newObj.publishVars;
            newObj.lh = addlistener(newObj,...
                varNames2BeMonitored,...
                'PostSet',@(src,evnt)handlePropertyEvents(newObj,src,evnt));
            newObj.lh.Recursive=true;
            newObj.TCPlock=Semaphore.me('TCP2Labview'); %init TCP2Labview Semaphore
            newObj.out('---------------------Finished Initialization---------------------');
        end
        function []=out(obj,str)
            %print a message to stdout;
            % currently set to matlab prompt
            disp(str);
        end
    end

    methods(Static)
        % This method is the only way to access a Dictator object from
        % outside. When called it either creates a new object and returns a
        % reference to it, or if an object already exists, returns a
        % reference to the existing object.
        function obj = me(fname)
            persistent uniqueInstance
            if isempty(uniqueInstance)
                obj = Dictator();
                uniqueInstance = obj;
            else
                obj = uniqueInstance;
            end
            if (nargin>0)
                obj.loadme(fname);
            end
        end
        function er=load(fn)
            er=1;
            if (nargin==2)&&(~strcmpi(fn,'last'))
                fname=fullfile(Dictator.logDir,fn);
            else %load the last object saved
                lst=dir([Dictator.logDir '*.mat']);
                if isempty(lst)
                    Dictator.iout(['No mat file in ' Dictator.logDir]);
                    return;
                end
                datetmp=0;
                dateidx=0;
                for l=1:length(lst)
                    if (datenum(lst(l).date)>datetmp)
                        dateidx=l;
                        datetmp=datenum(lst(l).date);
                    end
                end
                if (dateidx)
                    fname=lst(dateidx).name;
                else
                    Dictator.iout('Did not find latest file');
                    return;
                end
                fname=fullfile(Dictator.logDir,fname);
            end
            if (~exist(fname))
                Dictator.iout(sprintf('%s does not exist',fname));
                return;
            end
            evalin('base',['load(''' fname ''')']);
            Dictator.iout(sprintf('loaded object data from %s',fname));
        end
        function []=iout(str)
            %print a message to stdout;
            % currently set to matlab prompt
            disp(str);
        end
    end

    methods % Public Access
        function importGlobals(obj)
            tmp=metaclass(obj);
            props=tmp.Properties;
            for l=1:length(props)
                curprop=props{l};
                assignin('caller',curprop.Name,eval(['obj.',curprop.Name]));
            end
        end
        function [names vars]=publishVars(obj)
            %returns a list of var names and var values
            % that should be altered by the GUI from outside
            names=[];
            vars=[];
            tmp=metaclass(obj);
            props=tmp.Properties;
            idx=1;
            for l=1:length(props)
                curprop=props{l};
                if (eval(['length(obj.',curprop.Name,')>=1']))&&(~curprop.Constant)&&(~curprop.Transient)&&(~eval(['isstruct(obj.',curprop.Name,');']))
                    names{idx}=curprop.Name;
                    vars{idx}=eval(['obj.',curprop.Name]);
                    idx=idx+1;
                end
            end
        end
        function fl=isProperty(obj,name)
            %returns 1 if name is a valid property
            fl=0;
            tmp=metaclass(obj);
            props=tmp.Properties;
            for l=1:length(props)
                curprop=props{l};
                if (strcmp(curprop.Name,name))
                    fl=1;
                    return;
                end
            end
        end
        function [dev,channel]=NovatechAlias2nums(obj,alias)
            l=length(obj.NovatechAlias);
            dev=-1;
            channel=-1;
            for t=1:l
                if strcmp(obj.NovatechAlias(t).alias,alias)
                    dev=obj.NovatechAlias(t).dev;
                    channel=obj.NovatechAlias(t).channel;
                end
            end
        end
        function setNovatech(obj,idev,varargin)
            if isstr(idev)
                [dev,channel]=obj.NovatechAlias2nums(idev);
                if dev==-1
                    fprintf('Alias %s not valid\n.',idev);
                    return;
                end
                st=1;
            else
                dev=idev;
                channel=varargin{1};
                st=2;
            end
            if mod(length(varargin)-st+1,2)
                disp('variable argument list should be of the form ''varName'',varVal,...');
                return;
            end
            varsz=(length(varargin)-st+1)/2;
            for loop=st:varsz
                varName=varargin{loop*2-1};
                varVal=varargin{loop*2};
                if strcmp(varName,'freq')
                    ExtClock=28.633115306;
                    NovatechClock=28.633115306666667;
                    fr=varVal;%*NovatechClock/ExtClock;            
                    fprintf(obj.NovatechSerial{dev},['F' num2str(channel) ' ' num2str(fr,10)]);
                elseif strcmp(varName,'amp')
                    fprintf(obj.NovatechSerial{dev},['V' num2str(channel) ' ' num2str(varVal)]);
                elseif strcmp(varName,'phase')
                    fprintf(obj.NovatechSerial{dev},['P' num2str(channel) ' ' num2str(int16(varVal*8192/pi))]); %p phase shift
                elseif strcmp(varName,'clock')
                    % 0 is internal clock
                    if strcmp(varVal,'internal')
                        fprintf(obj.NovatechSerial{dev},['C I']); 
                    elseif strcmp(varVal,'external')
                        fprintf(obj.NovatechSerial{dev},['C E']); 
                    else
                        obj.out('Error. Should use: dic.setNovatech(dev,channel,''clock'',''internal''\''external''');
                    end
                end
            end           
        end
        function setHPFreq(obj,f)
            fprintf(obj.HPgpib,['FR ' num2str(fr,10) ' MZ']);
            obj.deflectorCurrentFreq = f;
        end
        function resetULE(obj)
            obj.ULE.estimatedFreqHistory=[];
            obj.ULE.freqHistory=[];
            obj.ULE.timeHistory=[];
            obj.ULE.deflectorFreqHistory = [];
            obj.ULE.timeStamp=FIFO(2);
            obj.ULE.freq=FIFO(2);
            delete(timerfindall);
            obj.ULE.updateTimeIntreval=3;
            obj.scheduler=timer('ExecutionMode','fixedDelay',...,
                'Period',obj.ULE.updateTimeIntreval*60,...
                'BusyMode','drop',... %if timer callback hasn't finished and another timer event tries to start - drop it
                'StartDelay',obj.ULE.updateTimeIntreval*60,...
                'TimerFcn',@(src,evnt)handleTimer(obj,src,evnt));
            obj.timerOnOffFlag=0;
        end
        function f=estimateF674(obj,inow)
            if (nargin>1)
                f=extrapolateF674(obj.ULE.timeStamp.getData,obj.ULE.freq.getData,inow);
            else
                f=extrapolateF674(obj.ULE.timeStamp.getData,obj.ULE.freq.getData);
            end
        end     
        function f = updateF674(obj)
            if ~isempty(obj.ULE.timeHistory)
                minutesSinceLastMeas = 24*60*(now-obj.ULE.timeHistory(end));
            else
                minutesSinceLastMeas = Inf;
            end
            if (minutesSinceLastMeas>obj.ULE.updateTimeIntreval)
                if (~obj.is674LockedFlag)
                    if (obj.TCPlock.locked)
                        obj.out('Tcp2Labview locked, timer exiting');
                        obj.is674LockedFlag=0;
                        return;
                    end
                end
                obj.out('Scanning F674 by update request...');
                EstimatorFreqScan674;
                obj.is674LockedFlag=1;
                DrawULETrace;
            end
            f=estimateF674(obj);
            
        end
        function handlePropertyEvents(obj,src,evnt)
            %event handler for change of properties
            eval(['val=obj.' src.Name ';']);
            switch src.Name % switch on the property name
                case 'F422onRes'
                    if (val>160)&&(val<260)
                        obj.out(sprintf('setting OnRes422=%f',val));
                        Single_Pulse(Pulse('OnRes422',0,-1,'freq',val))
                    else
                        obj.out('Freq out of range!');
                    end
                case 'F422onResCool'
                    if (val>160)&&(val<260)
                        obj.out(sprintf('setting OnResCooling=%f',val));
                        Single_Pulse(Pulse('OnResCooling',0,-1,'freq',val))
                    else
                        obj.out('Freq out of range!');
                    end
                case 'F1092'
                    if (val>180)&&(val<400)
                        obj.out(sprintf('setting Repump1092=%f',val));
                        Single_Pulse(Pulse('Repump1092',0,0,'freq',val))
                    else
                        obj.out('Freq out of range!');
                    end
                case 'F674'
                    if (val>=0)&&(val<172)
                        obj.out(sprintf('F674 set to %.6f',val));
                    else
                        obj.out('Freq out of range!');
                    end
                case 'saveIntr' %save button was pressed
                    obj.saveme; %save dictator
                    obj.save; %save graphs +obj.clipboard data
                case 'stopIntr'
                    obj.stp=1;
                case 'Force674ScanIntr'
                    %  obj.ULE.ReturnEstimatedFrequency(1);
                    handleTimer(obj);
                case 'timerOnOffFlag'
                    if (val)
                        start(obj.scheduler);
                        obj.out('Starting 674 scan timer');
                    else
                        stop(obj.scheduler);
                        obj.out('Stopping 674 scan timer');
                    end
                case 'noiseEater674'
                    obj.com.SetAO7(val);
                case 'LasersLockedFlag'
                    if (obj.LasersLockedFlag==false)
                        if (obj.SMSlaserAlertFlag==true)
                            sendSMS;
                            obj.SMSlaserAlertFlag=false;
                        end
                    end
                case 'OnResAmp'
                    Single_Pulse(Pulse('OnRes422',0,-1,'amp',val));
                    obj.out(sprintf('setting OnResAmp=%f',val));
               case 'Vcomp'
                    obj.com.UpdateTrapElectrode(0,0,0,0,val); pause(1);
                    obj.out(sprintf('Updated compensation electrode to %.2f V',val));
                case 'Vcap'
                    if obj.controlEndcapFlag
                        fprintf(obj.SRSgpib,sprintf('VSET%g',val));
                        obj.out(sprintf('Updated endcap north to %.2f V',val));
                    end
                case 'Vkeith'
                    if obj.controlKeithFlag
                        fprintf(obj.KeithUSB1,sprintf('VOLTage %g V',val));
                        pause(1);
                        obj.out(sprintf('Updated Keithley to %.2f V',val));

                           %New:controls Novatech through Keith, channel 3 of
                           %nova
%                            fprintf(obj.NovatechSerial,['V' num2str(3) ' ' num2str(round(333.33*(val-0.1)))]);
%                            obj.out(sprintf('Updated NovaTech3 to %.2f V',round(333.33*(val-0.1))));
                    end
                case 'AVdcl'
                    fprintf(obj.AGILENTgpib,'INST:SEL OUT2');
                    fprintf(obj.AGILENTgpib,sprintf('APPL %g',val));
                case 'AVdcr'
                    fprintf(obj.AGILENTgpib,'INST:SEL OUT1');
                    fprintf(obj.AGILENTgpib,sprintf('APPL %g',val));
                case 'HPVcomp'
                    fprintf(obj.HPVgpib,sprintf('VSET %g',val));
                case 'NumOfIons'
                    obj.maxPhotonsNumPerReadout=obj.NumOfIons*obj.TDetection/12;
            end
            obj.GUI.updateVars;
        end
        function handleTimer(obj,src,evnt)
            %scan 674 freq (Search_674_Res will update obj.F674
            %automatically, if neccessary)
            if (obj.TCPlock.locked)
                obj.out('Tcp2Labview locked, timer exiting');
                obj.is674LockedFlag=0;
                return;
            end
            
            f=estimateF674(obj);
            obj.out('Scanning F674...');
            valid=EstimatorFreqScan674;
            if (valid)
                obj.is674LockedFlag=1;
                DrawULETrace
            else
                %obj.is674LockedFlag=0; % keep trying
                obj.is674LockedFlag=1; % ignore and continue
            end
            %saving a snapshot
%             obj.saveme(obj.defaultFname);
        end
        function updateAllVars(obj)
            %go through all numerical vars of dictator, activate updateVar on them
            [names vars]=obj.publishVars;
            for l=1:length(names)
                if (isnumeric(vars{l})&&isempty(strfind(names{l},'Intr')))
                    obj.set(names{l},vars{l});
                end
            end
        end
        function refresh(obj,name)
            if obj.isProperty(name)
                setName2Val(obj,name,eval(['obj.' name]));
            end
        end
        function setName2Val(obj,name,val)
            if eval(['ischar(obj.' name ');'])
                %field type is a string
                eval(['obj.' name '=''' val ''';']);
                if isempty(strfind(name,'Intr'))
                    obj.out(sprintf('updated Dictator.%s to %s',name,val));
                end
            else
                eval(['obj.' name '=' num2str(val) ';']);
                if isempty(strfind(name,'Intr'))
                    obj.out(sprintf('updated Dictator.%s to %s',name,num2str(val,8)));
                end
            end
        end
        function set(obj,name,val)
            %set the field obj.name to val
            if obj.isProperty(name)
                if (ischar(val))
                    if eval(['strcmp(obj.' name ',val)'])&&isempty(strfind(name,'Intr'))
                        %in case of chars: if val isnt really new, quit
                    end
                elseif (eval(['obj.' name '==val'])&&isempty(strfind(name,'Intr')))
                    %in case of nums: if val isn't really a new value then quit
                    return;
                end
                setName2Val(obj,name,val);
            end
        end
        function fnameout=addTime2Str(obj,fname)
            fnameout=[fname '-' datestr(clock,'HH-MM')];
        end
        function fnameout=addDate2Str(obj,fname)
            fnameout=[fname '-' datestr(clock,'dd-mmm-yyyy-HH-MM')];
        end
        function save(obj)
            destDir=obj.saveDir;    
            [ST,I]=dbstack('-completenames');
            thisFile=ST(2).file;
            [filePath fileName]=fileparts(thisFile);
            scriptText=fileread(thisFile);
            saveFileName=fullfile(destDir ,[fileName datestr(now,'-ddmmmyy-HHMMSS')]);
            dicParameters=obj.getParameters;
            evalin('caller',sprintf('save(''%s'');',saveFileName));
            save(saveFileName,'dicParameters','scriptText','-append');
            disp(['Save data in : ' saveFileName]);
        end
        function saveme(obj,fn)
            %save all fields as individual variables in fn
            % if fn not specified, saves in defaultFname
            if (nargin==2)
                fname=fn;
            else
                fname=obj.addDate2Str(obj.defaultFname);
                fname=fullfile(obj.logDir,fname);
            end

            % loop over all properties which should be saved
            % and save them as individual variables
            % by copying them to a struct and then saving the
            % struct fields individually (matlab didnt allow
            % this for a class
            tmp=metaclass(obj);
            props=tmp.Properties;
            savestruct=[];
            for l=1:length(props)
                curprop=props{l};
                if (~curprop.Constant)&&(~curprop.Transient)
                    disp(['saving' curprop.Name]);
                    eval(['savestruct.' curprop.Name '=obj.' curprop.Name,';']);
                end
            end
            if (isempty(savestruct))
                obj.out('No properties to save');
                return;
            end
            savestruct=orderfields(savestruct);
            save(fname,'-struct','savestruct');
            obj.out(sprintf('saved object data in %s',fname));
        end
        function parStruc=getParameters(obj)
            %return all fields as  variables srtucture

            % loop over all properties which should be saved
            % and save them as individual variables
            % by copying them to a struct and then saving the
            % struct fields individually (matlab didnt allow
            % this for a class
            tmp=metaclass(obj);
            props=tmp.Properties;
            savestruct=[];
            for l=1:length(props)
                curprop=props{l};
                if (~curprop.Constant)&&(~curprop.Transient)
                    %                    disp(['saving' curprop.Name]);
                    eval(['savestruct.' curprop.Name '=obj.' curprop.Name,';']);
                end
            end
            if (isempty(savestruct))
                obj.out('No properties to save');
                return;
            end
            parStruc=orderfields(savestruct);
        end
        function er=loadme(obj,fn)
            er=1;
            if (nargin==2)&&(~strcmpi(fn,'last'))
                fname=fullfile(obj.logDir,fn);
            else %load the last object saved
                lst=dir([obj.logDir '*.mat']);
                if isempty(lst)
                    obj.out(['No mat file in ' obj.logDir]);
                    return;
                end
                datetmp=0;
                dateidx=0;
                for l=1:length(lst)
                    if (datenum(lst(l).date)>datetmp)
                        dateidx=l;
                        datetmp=datenum(lst(l).date);
                    end
                end
                if (dateidx)
                    fname=lst(dateidx).name;
                else
                    obj.out('Did not find latest file');
                    return;
                end
                fname=fullfile(obj.logDir,fname);
            end
            if (~exist(fname))
                obj.out(sprintf('%s does not exist',fname));
                return;
            end
            tmp=load(fname);
            % loop through all variables in tmp and assign them to
            % obj
            fields=fieldnames(tmp);
            for l=1:length(fields)
                curfield=fields{l};
                if (isProperty(obj,curfield))
                    %if (isempty(strfind(curfield,'Intr')))&&(~eval(['isstruct(obj.' curfield ');']))
                    if isempty(strfind(curfield,'Intr'))
                        %dont load push button variables
                        %if Dictator indeed has a field with the name
                        %in the string curfield
                        eval(['obj.' curfield '=tmp.' curfield,';']);
                    end
                end
            end
            obj.out(sprintf('loaded object data from %s',fname));
            obj.out('-----------------------------------------------------------------');
            %returning curtain values to defaul
            obj.is674LockedFlag=0;
            obj.timerOnOffFlag=0;
            er=0;
            obj.ULE.recentFrequency=obj.F674;
            obj.GUI.reset;
           
        end
        function s=stop(obj)
            %returns true if stp=1 (which happens when stopIntr is pushed),
            %and nulls the stp flag
            if (obj.stp)
                s=1;
                obj.stp=0;
            else
                s=0;
            end
        end
        function delete(obj)
            obj.out('-------------------------------');
            obj.out('performing cleanup...')
            obj.saveme;
            delete(obj.GUI);
            %             close obj.fig;
            obj.out('resetting serial/usb');
            instrreset;
            obj.out('cleaning timer objects');
            delete(timerfindall);
        end
        function add2clipboard(obj,name,val)
            if any(isnumeric(val))||any(islogical(val))
                valstr=mat2str(val);
            else
                valstr=val;
            end
            eval(['obj.clipboard.' name '=' valstr ';']);
        end
        function resetClipboard(obj)
            clipboard=[];
        end
        function ExtractAxesToFigure(obj,axesNum)
            hgsave(obj.GUI.sca(axesNum),'temp_figure.fig');
            figure;
            hgload('temp_figure.fig');
            set(get(gcf,'Children'),'units','normalized');
            set(get(gcf,'Children'),'position',[0.13 0.11 0.775 0.815]);
            copy2pdf;
        end
        function dr=saveDir(obj)
            dr=[obj.saveDest '\archive' date];
            if ~exist(dr)
                mkdir(dr)
            end
        end
        function fr=MMFreq(obj)
            fr=str2num(query(obj.KeithUSB1,'FREQuency?'))/1e6;
        end
    end
end

