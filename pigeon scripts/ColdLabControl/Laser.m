classdef Laser 
    %this class represent a laser module in the ICE box.
   
    
    properties
        comport
        s %serial communication variable
        slot %where the current driver card is installed
        coolingChan %which channel in the quad temp control board (1-4)

    end
    
    methods
        function obj=Laser(comport,slot,coolingChan)
         obj.s=serial(comport,'BaudRate',115200,'StopBits',1,'Parity','none','timeout',0.5,'Terminator','CR');
         obj.slot=num2str(slot);
         obj.coolingChan=num2str(coolingChan);

        end
        
        function boolReturn = boolChck(obj,bool)
            % This function checks if bool is 'on' or 'off' and also
            % capitalize it, i.e 'on' becomes 'On'
            if strcmp(bool, 'on') || strcmp(bool,'On')
                boolReturn = 'On';
            elseif strcmp(bool, 'off') || strcmp(bool,'Off')
                boolReturn = 'Off';
            else
                    error('wrong value at tempLockControl. bool must be On/Off');
            end
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
        
        function stat=tempLockServoStat(obj)
%             this function checks if we are servoing temp
        fopen(obj.s);
        fprintf(obj.s,'#Slave 1'); %switch control to the quad temp board (on slot 1)
        fprintf(obj.s,['Servo? ' obj.coolingChan]);
        stat=fscanf(obj.s);
        fclose(obj.s);
        
        end
        
        function stat=tempLockStat(obj)
%             this function checks if our error signal on temp is tight
%             enough to turn on a laser. and also checks servoing. 
        % Check if temp servo is on
        if obj.tempLockServoStat == 0
            disp('Temp Servo is not engaged');
            stat = 0;
            return
        end
        
        %Check if Terror is less then 50mK. if Not then temp is not stable
        if abs(obj.tempError) > 0.05
            disp('Temperture is not stable')
            stat = 0;
            return
        end
        stat = 1;
        end

        function stat=tempSet(obj,setTemp)
        fopen(obj.s);
        fprintf(obj.s,'#Slave 1');
        fprintf(obj.s,['TempSet ' obj.coolingChan ' ' num2str(setTemp)]);
        stat=fscanf(obj.s);
        fclose(obj.s);
        end
        
        function stat=tempLockControl(obj,bool)
%          enable/disable the temp lock loop on channel chan. (bool 'On'/'Off')
        bool = obj.boolChck(bool); %Check that bool is 'on' or 'off'
            
        fopen(obj.s);
        fprintf(obj.s,'#Slave 1');
        fprintf(obj.s,['Servo ' obj.coolingChan ' ' bool]);
        stat=fscanf(obj.s);
        fclose(obj.s);
        end
        
        function stat=tempError(obj)
%          enable/disable the temp lock loop on channel chan. (bool 'On'/'Off')
        fopen(obj.s);
        fprintf(obj.s,'#Slave 1');
        fprintf(obj.s,['TError? ' obj.coolingChan]);
        stat=fscanf(obj.s);
        stat = str2num(stat(3:end));
        fclose(obj.s);
        end
        
        function temp = getTemp(obj)
%          Returns the temperature of chanel chan
        fopen(obj.s);
        fprintf(obj.s,'#Slave 1');
        fprintf(obj.s,['Temp? ' obj.coolingChan]);
        temp=fscanf(obj.s);
        fclose(obj.s);
        end
        
        function stat=setTempMin(obj,setMin)
        fopen(obj.s);
        fprintf(obj.s,'#Slave 1');
        fprintf(obj.s,['TempMin ' obj.coolingChan ' ' num2str(setMin)]);
        stat=fscanf(obj.s);
        fclose(obj.s);
        end
        
        function stat=getTempMin(obj)
        fopen(obj.s);
        fprintf(obj.s,'#Slave 1');
        fprintf(obj.s,['TempMin? ' obj.coolingChan]);
        stat=fscanf(obj.s);
        fclose(obj.s);
        end
        
        function stat=getTempGain(obj)
        fopen(obj.s);
        fprintf(obj.s,'#Slave 1');
        fprintf(obj.s,['Gain? ' obj.coolingChan]);
        stat=fscanf(obj.s);
        fclose(obj.s);
        end
        
        function stat=setTempGain(obj,gain)
        fopen(obj.s);
        fprintf(obj.s,'#Slave 1');
        fprintf(obj.s,['Gain ' obj.coolingChan ' ' num2str(gain)]);
        stat=fscanf(obj.s);
        fclose(obj.s);
        end
        
        function stat=setMaxTECcurr(obj,curr)
        fopen(obj.s);
        fprintf(obj.s,'#Slave 1');
        fprintf(obj.s,['MaxCurr ' obj.coolingChan ' ' num2str(curr)]);
        stat=fscanf(obj.s);
        fclose(obj.s);
        end
        
        function stat=getMaxTECcurr(obj)
        fopen(obj.s);
        fprintf(obj.s,'#Slave 1');
        fprintf(obj.s,['MaxCurr? ' obj.coolingChan]);
        stat=fscanf(obj.s);
        fclose(obj.s);
        end
        
%% laser control board functions        
        function stat=getLaserStat(obj)
        fopen(obj.s);
        fprintf(obj.s,['#Slave ' obj.slot]);
        fprintf(obj.s,'Laser?');
        stat=fscanf(obj.s);
        fclose(obj.s);
        end
           
        function stat=setLaserStat(obj,bool)
       %This function turnes on\off the laser. Before it does this it checks
       %if the temp of the laser is stabliezd.
        if obj.tempLockStat == 0
            error('Temp unlocked. cannot turn on laser.');
        end
        
        bool = obj.boolChck(bool); %Check that bool is 'on' or 'off'
        
        fopen(obj.s);
        fprintf(obj.s,['#Slave ' obj.slot]);
        fprintf(obj.s,['Laser ' bool]);
       
        stat=fscanf(obj.s);
        fclose(obj.s);
        end
        
        function stat=getCurrSet(obj)
        fopen(obj.s);
        fprintf(obj.s,['#Slave ' obj.slot]);
        fprintf(obj.s,'CurrSet?');
        stat=fscanf(obj.s);
        fclose(obj.s);
        end 
        
        function stat=setCurrSet(obj,Current)
        fopen(obj.s);
        fprintf(obj.s,['#Slave ' obj.slot]);
        fprintf(obj.s,['CurrSet ' num2str(Current)]);
        stat=fscanf(obj.s);
        fclose(obj.s);
        end
        
        function stat=getCurrLim(obj)
        fopen(obj.s);
        fprintf(obj.s,['#Slave ' obj.slot]);
        fprintf(obj.s,'CurrLim?');
        stat=fscanf(obj.s);
        fclose(obj.s);
        end        

        function stat=setCurrLim(obj,CurrentLim)
        fopen(obj.s);
        fprintf(obj.s,['#Slave ' obj.slot]);
        fprintf(obj.s,['CurrLim ' num2str(CurrentLim)]);
        stat=fscanf(obj.s);
        fclose(obj.s);
        end 
        
 %% offset lock functions
 
 function N=getPhaseLockMultiplyer(obj)
        fopen(obj.s);
        fprintf(obj.s,['#Slave ' obj.slot]);
        fprintf(obj.s,'N?');
        N=fscanf(obj.s);
        fclose(obj.s);
 end
 
 function N=setPhaseLockMultiplyer(obj,mult)
     if (mult~=8 && mult~=16 && mult~=32 && mult~=64) 
         error('Wrong multiplyer value!');
     end
     
        fopen(obj.s);
        fprintf(obj.s,['#Slave ' obj.slot]);
        fprintf(obj.s,['N ' num2str(mult)]);
        N=fscanf(obj.s);
        fclose(obj.s);
 end
 
 function invertStat=getInvertBool(obj)
        fopen(obj.s);
        fprintf(obj.s,['#Slave ' obj.slot]);
        fprintf(obj.s,'Invert?');
        invertStat = fscanf(obj.s);
        fclose(obj.s);
 end
 
 function invertStat=setInvertBool(obj, bool)
     
        bool = obj.boolChck(bool); %Check that bool is 'on' or 'off'
        
        fopen(obj.s);
        fprintf(obj.s,['#Slave ' obj.slot]);
        fprintf(obj.s,['Invert ' bool]);
        invertStat = fscanf(obj.s);
        fclose(obj.s);
 end
 
 function intRefStat=getIntRefBool(obj)
        fopen(obj.s);
        fprintf(obj.s,['#Slave ' obj.slot]);
        fprintf(obj.s,'IntRef?');
        intRefStat = fscanf(obj.s);
        fclose(obj.s);
 end
 
 function intRefStat=setIntRefBool(obj, bool)
        bool = obj.boolChck(bool); %Check that bool is 'on' or 'off'
        fopen(obj.s);
        fprintf(obj.s,['#Slave ' obj.slot]);
        fprintf(obj.s,['IntRef ' bool]);
        intRefStat = fscanf(obj.s);
        fclose(obj.s);
 end
 
  function intFreq=getIntFreq(obj)
        %This function returns the inturnal vco frequency in MHz. Remember
        %that the actual signal in the PLL is multiplied by the multiplier.
        
        fopen(obj.s);
        fprintf(obj.s,['#Slave ' obj.slot]);
        fprintf(obj.s,'IntFreq?');
        intFreq = fscanf(obj.s);
        fclose(obj.s);
 end
 
 function intRefStat=setIntFreq(obj, freq)
        %This function sets the inturnal vco frequency in MHz. Remember
        %that the actual signal in the PLL is multiplied by the multiplier.
        fopen(obj.s);
        fprintf(obj.s,['#Slave ' obj.slot]);
        fprintf(obj.s,['IntFreq ' num2str(freq)]);
        intRefStat = fscanf(obj.s);
        fclose(obj.s);
 end
        
    end
    
end
