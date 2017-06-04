%this code describes exp. # from date TODAY



clear all;
close all
instrreset; 

cooling=Laser('COM4',4,4);
cooling.setTemp(13.6);
cooling.setCurr(169.8);
cooling.setTempLock('On');
cooling.setLaserStat('On');
cooling.setIntRef('On');
cooling.setIntFreq(86.077507);
cooling.setPhaseLockMultiplyer(16);
cooling.setLaserServoStat('On');
cooling.getLaserServoStat

repump=Laser('COM4',2,2);
repump.setTemp(8.6);
repump.setCurr(169.11);
repump.setTempLock('On');
repump.setLaserStat('On');
repump.setIntRef('On');
repump.setIntFreq(173.468750);
repump.setPhaseLockMultiplyer(32);
repump.setLaserServoStat('On');
repump.getLaserServoStat


