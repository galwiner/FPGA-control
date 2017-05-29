% send SMS
function sendSMS
disp('Sending SMS lasers alert.');
system('E:\Matlab\pigeon\pigeon programs\ScansSep10_Nitzan\ServiceFunction\SendSMS.bat');
disp('Pausing ... Press any key to continue.');
dic=Dictator.me;
dic.timerOnOffFlag=0;
pause;
end
