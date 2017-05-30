classdef ULELinearEstimator <handle

    properties (Constant = true)
        numOfScansPerReference = 1;
        peakThreshold = 60; % minial dark counts threshold [%].
        logFilePathAndName = ...
            'E:\Matlab\pigeon\pigeon programs\DictatorLogs\LinearEstimatorLog.txt';
    end

    properties
        updateTimeIntreval = 5 % minutes
        recentFrequency; % MHz
        recentUpdateTime; % days (matlab time basis)
        recentSlope; % MHz/day
        dic=[];
    end

    methods
        function obj = ULELinearEstimator(dic)
            obj.dic=dic; %dic is a dictator object
            % Initialize the ULELinearEstimator class
            obj.recentFrequency = obj.dic.F674;
            obj.recentUpdateTime = [];
            obj.recentSlope = [];


            % if no slope was defined, try to get one from a log file.
            if isempty (obj.recentSlope)
                fid = fopen(obj.logFilePathAndName);
                if fid ~=-1
                    fclose(fid);
                    logData = ReadLinEstimatorLogFile(obj.logFilePathAndName);
                    lastUpdateTime = logData(end,1);
                    if (now-lastUpdateTime)*1440<2*obj.updateTimeIntreval
                        obj.recentUpdateTime = lastUpdateTime;
                        obj.recentFrequency = logData(end,2);
                        obj.recentSlope = logData(end,3);
                        disp('ULE estimation data was loaded from a file.');
%                         obj.startupScansNum = 0;
                    else
                        % delete the log file
                        delete(obj.logFilePathAndName);
                    end
                end

            end
        end

        function reset(obj)
            % Initialize the ULELinearEstimator class
            obj.recentFrequency = obj.dic.F674;
            obj.recentUpdateTime = [];
            obj.recentSlope = [];
        end

        function ReturnEstimatedFrequency(obj,force)
            % check for the time
            currentTime = now;
            if isempty(obj.recentSlope)
                minutesFromLastUpdate = obj.updateTimeIntreval+1;
            else
                minutesFromLastUpdate =...
                    (currentTime-obj.recentUpdateTime)*1440;
            end
            if (nargin==2)
                Force674Scan=force;
            else
                Force674Scan=0;
            end
            if (minutesFromLastUpdate>obj.updateTimeIntreval)||...
                    (Force674Scan)
                
                disp('Measuring F674 for reference');

                % Gathering the next reference freuqency measurement
                measF674 = zeros(obj.numOfScansPerReference,1);
                scanTimeList = zeros(obj.numOfScansPerReference,1);
                maxDarkCounts = measF674;
                isValidFit = measF674;

                if isempty(obj.recentSlope)
                    Fcenter = obj.recentFrequency;
                else
                    Fcenter = obj.recentFrequency + ...
                        obj.recentSlope*(now-obj.recentUpdateTime);
                end

                for scanIndex = 1:obj.numOfScansPerReference
                    F674List=((Fcenter-0.1):0.01:(Fcenter+0.1));
                    saveT674=obj.dic.T674;
                    newV=400;%Power2DDS(10); %calculate amplitude relevant for 10% power
                    obj.dic.setV674(0,newV); %decrease rabi for better resultion
                    obj.dic.T674=saveT674*2; %extend pi time accordingly
                    %scan 674, update F674 if scan was good
                    isValidFit(scanIndex)=Search_674_Res(F674List,obj.dic);
                    obj.dic.setV674(0,1023);%restore large rabi
                    obj.dic.T674=saveT674; %restore pi time                  
                    obj.dic.GUI.updateVars;
                    scanTimeList(scanIndex) = now;
                    maxDarkCounts(scanIndex)=obj.dic.DarkMax;
                    measF674(scanIndex) = obj.dic.F674;
                end
                %aquire time stamp
                newRefTime = mean(scanTimeList);
                % If, at least, the majority of the samples are strong
                % enought to work with (no out of lock laser).
                if all(isValidFit)
                    obj.dic.is674LockedFlag=1;
                    newRefFreq = mean(measF674);

                    %update the object fields
                    if isempty(obj.recentSlope)
                        % if running for the first time:
                        obj.recentFrequency = newRefFreq;
                        obj.recentUpdateTime = newRefTime;
                        obj.recentSlope = 0;
                    else
                        % if allready has perliminary data
                        obj.recentSlope = (newRefFreq-obj.recentFrequency)/...
                            (newRefTime-obj.recentUpdateTime);
                        obj.recentFrequency = newRefFreq;
                        obj.recentUpdateTime = newRefTime;
                    end

                    %update the log file
                    fid = fopen(obj.logFilePathAndName);
                    if fid ~=-1
                        fclose(fid);
                        logData = ReadLinEstimatorLogFile(obj.logFilePathAndName);
                        logData = [datevec(logData(:,1)) logData(:,[2 3 4])];
                    else
                        % Initialize a file.
                        logData = [];
                    end
                    logData(end+1,1:9) = [datevec(newRefTime) ...
                        newRefFreq obj.recentSlope mean(maxDarkCounts)];
                    save(obj.logFilePathAndName,'logData','-ascii','-double');

                else % In case of a poor fit
                    obj.dic.is674LockedFlag=0;
                    disp ('Low dark counts level, point skipped.');
                end
                
            end

            % return estimated frequency.
            currentTime = now;
            estFreq = obj.recentFrequency + ...
                obj.recentSlope*(currentTime-obj.recentUpdateTime);
            obj.dic.estimatedF674=estFreq;
            obj.dic.GUI.updateVars;
        end
    end

end