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
        NovatechSerial; %Novatech serial controlling 674 Freq
        fastNovatechSerial; %dual channel fast Novatech serial controlling 674 Freq
        com; %tcp2labview object controlling FPGA
        HPgpib% 674 deflector freq source
        KeithleyUSB1; %usb handle to Keithley controlling RF master
        KeithleyUSB2; %usb handle to Keithley controlling RF slave
        KeithleyUSB3; %usb handle to Keithley controlling RF slave
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
        detection422ScanList = 190:2:230; % MHz
        darkCountThreshold = 8; %detected photons
        TwoIonsCountThreshold=45; % Threshold counts between one and two ions
        maxPhotonsNumPerReadout = 40; % the maximally expected number of...
        % photons to arrive duting TDetection.
        LambDickeParameter = 0.05;

        noiseEaterDetValue = 0; % volts
        noiseEater674 = 0.4;
        % default times [micro-sec]
        Toptpump=20;% 422 optical pumping time
        TOffResCooling = 500;
        Tcooling=500;% 422 on res cooling rime
        T1033=50;% 1033 optical pumping time
        T674=2.5;% 674 pi time
        %BSBPiTime = 20; %BLue sideband flipping time for hot ion.
        %BSBCooledPiTime = 100; %BLue sideband flipping time for ground state
        %cooled  ion.
        %T674plus=14.38; %674 2nd level pi time(not in use, starting aug
        %2010)
        TimeRF=7.6;% RF pi time
        TArm=1000;% ramsey/echo single arm time
        TDetection=500;
        %TSidebandCooling = 3e3;
        %default freqs
        F422onRes=226;
        F422onResCool=220;
        F1092=63;
        F674=85;% 674 carrier freq time
        Hp674Freq=982; %674 deflector freq [MHZ]
        port2T674 = 2;
        F674FWHM = 0.1; %Full width half maximum
        DarkMax = 0;
        FRF=8.74;% RF freq time

        vibMode = struct('name',{'COM','Strech','Radial1','Radial2'},...
            'freq',{0.97 1.68 2.988 3.07},...
            'hotPiTime',{30 40 59 50},...
            'coldPiTime',{130 200 100 100},...
            'foundInSingleIon',{1,0,1,1},...
            'coolingTime',{2e3 2e3 2e3 2e3});

        acStarkShift674=0.06139;

        numOfPigeonCodeRepetitions = 100;

        %auxilary vars
        Necho=1;% number of echos in a ramsey type experiment
        lastidx=1;% flag indicating from which loop index to restart
        SitOnEchoFlag=1;% if true, do a single echo experiment at RamseyArm
        SitOnItFlag=0;% if true, forces 422 resonance scan to sit instead at a given 422 freq
        is674LockedFlag=0;%
        timerOnOffFlag=0;
        TwoIonFlag=0;
        resumeFlag=0;% flag indicating if should resume previous run and in that case:
        AutoSaveFlag=0;
        deflectorCompenFlag = 0;% change the update674 to HP-deflector
        
        DblScan674Flag=0;
        coarse674ScanList=[82:0.05:85]; %coarse scan list (used when DBlScan674Flag=1)
        fine674ScanList=-0.7:0.05:0.7; %fine scan list (used when timer reads scan 674)
        Force674ScanIntr=0;% if true, forces a scan of 674 freq
        saveIntr=0; %if true - save data
        stopIntr=0; %if true -signal to stop current run
        experimentDesc='Experiment Description:'; %description text

        % ULE linear estimator data
        ULE=[];
        ULEEStimatorLinewidth = 0.01;
        ULEEstimatorF674Scale = -0.015:0.0007:0.015;
        ULEEstimatorScanNESetPoint = -100;
        ULEEstimatorScanNEPulseDuration = 140;
        deflectorCurrentFreq = 892;
        hpFreq = 987.2;
        switchSetFreq = 85;


        % DDS Guaging data.
        DDSGuageData=[];
        numOfDDS = 2;
        usingDDS=1; %when =0 using Novatech
        usingDDSForRF = 1;
        estimatorDDSNum = 1;
        %filename header to save user data
        saveDest='E:\measrments\DataArchive';

        sitOnItRecord = zeros(1,15); % a list of the recent SitOnit measurements for statistics.
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
            newObj.out('openning COM13 for 674 Novatech control');
            newObj.NovatechSerial=openSerial('COM13','BaudRate',19200);
            %open tcp2labview control of FPGA
            newObj.out('opening com with Tcp2Labview on port 6340');
            newObj.com=Tcp2Labview('localhost',6340);
            %open usb handles to Keithley controllnig RF
            %newObj.out('opening usb communication with the two RF Keithley sig. gen');
            %newObj.KeithleyUSB1=openUSB('USB0::0x05E6::0x3390::1221818::0::INSTR'); %master
            newObj.out('opening GPIB communication HP generator');
            newObj.HPgpib=gpib('ni',0,6);
            try
                fopen(newObj.HPgpib);
            catch
                newObj.out('Could not communicate with HP generator');
            end
            %oscilator (DO10 chooses the master/slave, DO9 opens/closes them both)
            %674channel3 chooses if it is master/slave or the third
            %KEithley
            %           newObj.estimatedF674=newObj.F674;
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
                {'ionAxialFreq','acStarkShift674','RFPhase','F674FWHM',...
                'SecondRFPhase','DDSGuageData','usingDDS','DarkMax',...
                'maxPhotonsNumPerReadout','LambDickeParameter',...
                'noiseEaterDetValue','numOfPigeonCodeRepetitions',...
                'is674LockedFlag','ULEEStimatorLinewidth','ULEEstimatorF674Scale',...
                'ULEEstimatorScanNESetPoint','ULEEstimatorScanNEPulseDuration',...
                'DDSGuageData','numOfDDS','usingDDS','usingDDSForRF','estimatorDDSNum','Hp674Freq'});
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
                if (eval(['length(obj.',curprop.Name,')==1']))&&(~curprop.Constant)&&(~curprop.Transient)&&(~eval(['isstruct(obj.',curprop.Name,');']))
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
        function setNovatech4Freq(obj,channel,f)
            fprintf(obj.NovatechSerial,['F' num2str(channel) ' ' num2str(f)]);
        end
        function setHPFreq(obj,f)
            fprintf(obj.HPgpib,['FR ' num2str(f,10) ' MZ']);
            obj.deflectorCurrentFreq = f;
        end
        function setNovatech4Amp(obj,channel,v)
            fprintf(obj.NovatechSerial,['V' num2str(channel) ' ' num2str(v)]);
        end
        function setNovatech4Phase(obj,channel,p)
            fprintf(obj.NovatechSerial,['P' num2str(channel) ' ' num2str(int16(p*8192/pi))]); %p phase shift
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
            if (~obj.is674LockedFlag)
                handleTimer(obj)
            end
            if ~obj.deflectorCompenFlag
                f=estimateF674(obj);
%                 if ~obj.usingDDS
%                     setF674(obj,0,f);
%                     setF674(obj,1,f);
%                     setF674(obj,2,f);
%                 end
            else
                f = obj.switchSetFreq;
                if length(obj.ULE.deflectorFreqHistory)<2
                    disp('Not enought points for deflector estimations');
                else
                    a = diff(obj.ULE.deflectorFreqHistory(end-1:end))/...
                        diff(obj.ULE.timeHistory(end-1:end));
                    b = obj.ULE.deflectorFreqHistory(end)-a*obj.ULE.timeHistory(end);
                    obj.setHPFreq(round((a*now+b)*1e6)*1e-6);
                    obj.deflectorCurrentFreq = obj.deflectorCurrentFreq;
%                     targetDeflectorFreq = round((a*now+b)*1e6)*1e-6;
%                     DDS2Freq = obj.hpFreq-targetDeflectorFreq;
%                     SetDDSSingelToneFrequency (2,DDS2Freq);
%                     obj.deflectorCurrentFreq = obj.hpFreq-DDS2Freq;
                end
            end

        end
        function setFRF(obj,f)
            if ~obj.usingDDSForRF
                %fprintf(obj.KeithleyUSB1,['FREQ ' num2str(f) 'MHz']);
                %fprintf(obj.KeithleyUSB2,['FREQ ' num2str(f) 'MHz']);
                fprintf(obj.KeithleyUSB3,['FREQ ' num2str(f) 'MHz']);
            end
        end
        function setRFPhase(obj,ph)
            %fprintf(obj.KeithleyUSB2,['BURSt:PHASe ' num2str(ph)]);
        end
        function setSecondRFPhase(obj,ph)
            %fprintf(obj.KeithleyUSB3,['BURSt:PHASe ' num2str(ph)]);
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
                case 'FRF'
                    if (val>=0)&&(val<=50)
                        obj.setFRF(val);
                        obj.out(sprintf('FRF set to %.6f',val));
                    else
                        obj.out('Freq out of range!');
                    end
                case 'saveIntr' %save button was pressed
                    obj.saveme; %save dictator
                    obj.save; %save graphs +obj.clipboard data
                case 'stopIntr'
                    obj.stp=1;
                case 'Force674ScanIntr'
                    %                     obj.ULE.ReturnEstimatedFrequency(1);
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
            F674List=obj.F674+obj.ULEEstimatorF674Scale;
            valid=EstimatorFreqScan674;
            if (valid)
                obj.is674LockedFlag=1;
                DrawULETrace
            else
                %obj.is674LockedFlag=0; % keep trying
                obj.is674LockedFlag=1; % ignore and continue
            end
%             disp(sprintf('Estimated =%f, measured=%f, deltaF=%f',f,obj.F674,obj.F674-f));
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
                    %                    disp(['saving' curprop.Name]);
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
            %            obj.saveme;
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
        function out = PopNoiseEaterDetectorReading(obj)
            %             % Reads the detector value from a text file which creates the
            %             % FPGA host.
            %             if nargin == 1
            %                 nAverage = 1;
            %             end
            %             measure = zeros(1,nAverage);
            %             for index = 1:nAverage
            %                 pause(0.1);
            %                 fid = fopen('NoiseEaterDetmonitor.txt','r');
            %                 measure(index) = str2num(char(fread(fid)'));
            %                 fclose(fid);
            %             end
            %             obj.noiseEaterDetValue = mean(measure);
            %             out = obj.noiseEaterDetValue;

            out = obj.com.ReadNoiseEaterDetector/2^15*10;
            obj.noiseEaterDetValue = out;
        end
        function ResetDDSGuageData(obj)
            for index = 1:obj.numOfDDS
                obj.DDSGuageData(index).volt2LineWidth = [];
            end
        end
        function AddLineToDDSGuageData(obj,DDSNum,line)
            if (line(1)<=0)||(line(1)>100)||(length(line)~=3)
                error('Wrong line');
            end
            % adding the line
            if isempty(obj.DDSGuageData)
                obj.ResetDDSGuageData;
                obj.DDSGuageData(DDSNum).volt2LineWidth = line;
            else
                obj.DDSGuageData(DDSNum).volt2LineWidth(end+1,1:3) = line;
            end
            % removing any parallel data.
            f = find(obj.DDSGuageData(DDSNum).volt2LineWidth(:,1) ...
                == line(1));
            if length(f)>1
                obj.DDSGuageData(DDSNum).volt2LineWidth(f(1:end-1),:) = [];
            end
            %sorting the list
            [carp order] = sort(obj.DDSGuageData(DDSNum).volt2LineWidth(:,1));
            obj.DDSGuageData(DDSNum).volt2LineWidth = ...
                obj.DDSGuageData(DDSNum).volt2LineWidth(order,:);
        end
        function [pwr duration] = ReturnDDSPowerAndDurationByLinewidth ...
                (obj,linewidth,DDSNum)
            if ~exist('DDSNum')
                DDSNum = 1;
            end
            currentTable = obj.DDSGuageData(DDSNum).volt2LineWidth;
            if (linewidth<min(currentTable(:,2)))||(linewidth>max(currentTable(:,2)))
                error ('Linewidth out of guaging table limits');
            else
                pwr = csaps (currentTable(:,2),currentTable(:,1),1,linewidth);
                duration = csaps (currentTable(:,2),currentTable(:,3),1,linewidth);
            end
        end
        function [pwr linewidth] = ReturnDDSPowerAndLinewidthByPiTime ...
                (obj,piTime,DDSNum)
            if ~exist('DDSNum')
                DDSNum = 1;
            end
            currentTable = obj.DDSGuageData(DDSNum).volt2LineWidth;
            if (piTime<min(currentTable(:,3)))||(piTime>max(currentTable(:,3)))
                error ('Pi time out of guaging table limits');
            else
                pwr = csaps (currentTable(:,3),currentTable(:,1),0.99,piTime);
                linewidth = csaps (currentTable(:,3),currentTable(:,2),1,piTime);
            end
        end
        function ExtractAxesToFigure(obj,axesNum)
            hgsave(obj.GUI.sca(axesNum),'temp_figure.fig');
            figure;
            hgload('temp_figure.fig');
            set(get(gcf,'Children'),'units','normalized');
            set(get(gcf,'Children'),'position',[0.13 0.11 0.775 0.815]);
        end
        function dr=saveDir(obj)
            dr=[obj.saveDest '\archive' date];
            if ~exist(dr)
                mkdir(dr)
            end
        end
    end
end

