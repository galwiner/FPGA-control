function out = IsStop
fileFullPath = 'E:\Matlab\pigeon\pigeon programs\Oct2011_Shlomi\DictatorStopFile.txt';
fid = fopen(fileFullPath,'r');
a = fread(fid,1);
out = strcmp(char(a),'1');
fclose(fid);
