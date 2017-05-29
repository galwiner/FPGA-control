classdef ICE
    %this class represent the ICE laser control system
   
    
    properties
        comport
        s %serial communication variable
        config=struct('Cooling',struct('slot',4,'tempChan',4,'Name', 'Cooling'),'Repump',struct('slot',2,'tempChan',2,'Name', 'Repump'));

    end
    
    methods
        function obj=ICE(comport)
         obj.s=serial(comport,'BaudRate',115200,'StopBits',1,'Parity','none','timeout',0.5,'Terminator','CR');

        end
%%  temp control board function

        function success=comTest(obj)
            fopen(obj.s);
            fprintf(obj.s,'#Status');
            stat=fscanf(obj.s);
            if (strcmp(stat(1:2),'On'))
                success=1;
            else 
                success=0;
            end
            
            fclose(obj.s);
        end
        
        function stat=tempLockServoStat(obj,chan)
%             this function checks if we are servoing temp
        fopen(obj.s);
        fprintf(obj.s,'#Slave 1');
        fprintf(obj.s,['Servo? ' num2str(chan)]);
        stat=fscanf(obj.s);
        fclose(obj.s);
        
        end
        function stat=tempLockStat(obj,laserName)
%             this function checks if our error signal on temp is tight
%             enough to turn on a laser. and also checks servoing. 
        %Check if laserName is in the config
        if strcmp(laserName,fieldnames(obj.config)) == 0
           error('Wrong laserName. See ICE config for valid names');
        end
        chan=obj.config.(laserName).tempChan;
        % Check if temp servo is on
        if obj.tempLockServoStat(chan) == 0
            disp('Temp Servo is not engaged');
            stat = 0;
            return
        end
        
        %Check if Terror is less then 50mK. if Not then temp is not stable
        if abs(obj.tempError(chan)) > 0.05
            disp('Temperture is not stable')
            stat = 0;
            return
        end
        stat = 1;
        end

        function stat=tempSet(obj,chan,setTemp)
        fopen(obj.s);
        fprintf(obj.s,'#Slave 1');
        fprintf(obj.s,['TempSet ' num2str(chan) ' ' num2str(setTemp)]);
        stat=fscanf(obj.s);
        fclose(obj.s);
        end
        
        function stat=tempLockControl(obj,chan,bool)
%          enable/disable the temp lock loop on channel chan. (bool 'On'/'Off')
        fopen(obj.s);
        fprintf(obj.s,'#Slave 1');
        fprintf(obj.s,['Servo ' num2str(chan) ' ' bool]);
        stat=fscanf(obj.s);
        fclose(obj.s);
        end
        
        function stat=tempError(obj,chan)
%          enable/disable the temp lock loop on channel chan. (bool 'On'/'Off')
        fopen(obj.s);
        fprintf(obj.s,'#Slave 1');
        fprintf(obj.s,['TError? ' num2str(chan)]);
        stat=fscanf(obj.s);
        stat = str2num(stat(3:end));
        fclose(obj.s);
        end 
        function temp = getTemp(obj,chan)
%          Returns the temperature of chanel chan
        fopen(obj.s);
        fprintf(obj.s,'#Slave 1');
        fprintf(obj.s,['Temp? ' num2str(chan)]);
        temp=fscanf(obj.s);
        fclose(obj.s);
        end
        
        function stat=setTempMin(obj,chan,setMin)
        fopen(obj.s);
        fprintf(obj.s,'#Slave 1');
        fprintf(obj.s,['TempMin ' num2str(chan) ' ' num2str(setMin)]);
        stat=fscanf(obj.s);
        fclose(obj.s);
        end
        
        function stat=getTempMin(obj,chan)
        fopen(obj.s);
        fprintf(obj.s,'#Slave 1');
        fprintf(obj.s,['TempMin? ' num2str(chan)]);
        stat=fscanf(obj.s);
        fclose(obj.s);
        end
        
        function stat=getTempGain(obj,chan)
        fopen(obj.s);
        fprintf(obj.s,'#Slave 1');
        fprintf(obj.s,['Gain? ' num2str(chan)]);
        stat=fscanf(obj.s);
        fclose(obj.s);
        end
        
        
        function stat=setTempGain(obj,chan,gain)
        fopen(obj.s);
        fprintf(obj.s,'#Slave 1');
        fprintf(obj.s,['Gain? ' num2str(chan) ' ' gain]);
        stat=fscanf(obj.s);
        fclose(obj.s);
        end
        
        function stat=setMaxTECcurr(obj,chan,curr)
        fopen(obj.s);
        fprintf(obj.s,'#Slave 1');
        fprintf(obj.s,['MaxCurr ' num2str(chan) ' ' num2str(curr)]);
        stat=fscanf(obj.s);
        fclose(obj.s);
        end
        
        function stat=getMaxTECcurr(obj,chan)
        fopen(obj.s);
        fprintf(obj.s,'#Slave 1');
        fprintf(obj.s,['MaxCurr? ' num2str(chan)]);
        stat=fscanf(obj.s);
        fclose(obj.s);
        end
        
%% laser control board functions        
     function stat=getLaserStat(obj,slot)
        fopen(obj.s);
        fprintf(obj.s,['#Slave ' num2str(slot)]);
        fprintf(obj.s,'Laser?');
        stat=fscanf(obj.s);
        fclose(obj.s);
     end
           
        function stat=setLaserStat(obj,slot,bool)
        fopen(obj.s);
        fprintf(obj.s,['#Slave ' num2str(slot)]);
        if ~(obj.templockStat(slot)==1)
            disp('Temp unlocked. cannot turn on laser.');
        else 
            fprintf(obj.s,['Laser ' bool]);
        end
        
        stat=fscanf(obj.s);
        fclose(obj.s);
        end
        
    end
    
end
