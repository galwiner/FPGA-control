function LaserOnOff(Chanel_Name,Duration,OnOff,varargin)
%UNTITLED Summary of this function goes here
%   Chanel_Name is the name of the laser you want to turn on or off. For
%   example 'Cooling'. Duretion is the time of the on ot off.
%   If Duretion is 0 then the time is infinate.
%   OnOff is indication for the tipe, 1 is
%   on and 0 is off
%   Duration is in microseconds!
%First, make sure that the laser name is a knone chanel (laser sweetch
%% This section is deticated to verifing that Chanel_Name is a valid chanel.
%make sure we have acsses to PulseChannelInfo directory and change the
%directory back.
currentfolder=cd('D:\Box Sync\Lab\ExpCold\FPGA control\pigeon compiler(V3_4)');
info = PulseChannelInfo;
cd(currentfolder)


chanexist = zeros(1,length(info)); %A bollian arry that cheks if Chanel_Name is aa valid chanel name.
channame = strings(1,length(info)); %A string array containing all the chanel names.
for n = 1:length(info)
   channame(1,n) = info{1,n}.ChannelName; %Add current cell to array
   chanexist(1,n) = strcmp(Chanel_Name,channame(1,n)); %Compare current chanel name to Chanel_Name
end
% Check if there is no chale name
if chanexist==zeros(1,length(info))
    filepath = 'D:\Box Sync\Lab\ExpCold\FPGA control\pigeon compiler(V3_4)\PulseChannelInfo.m';
    fprintf('%s is not a valid chanel.\nSee ''%s'' for valid chanels',Chanel_Name,filepath);
    return
end
%% This section is the actual turning on or off of the laser
% fprintf('%s is a valid chanel',Chanel_Name'); %For testing
%Check duretion. Because that Pulse needs 0 for only on and -1 for only off
if Duration == 0
   if OnOff == 0
      Duration = -1;
   end
end
prog=CodeGenerator; % This is the basic way to talk to LabView(Pigeon) and thus ther FPGA
pulseSeq={Pulse(Chanel_Name,0,Duration)}; %GenSeq mut get a cellarray! so we make a cellarray of 1 cell
prog.GenSeq(pulseSeq); % build a sequence
prog.GenFinish; %LeeDrori don't know what use this line
prog.DisplayCode;

% %FPGA/Host control
% com=Tcp2Labview('localhost',6340);
% pause(1);
% com.UploadCode(prog);
% com.UpdateFpga;
% com.WaitForHostIdle;
% com.Execute(1);  
% com.Delete;


end

