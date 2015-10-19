function ResetStopFile
fileFullPath = 'E:\Matlab\pigeon\pigeon programs\Oct2011_Shlomi\DictatorStopFile.txt';
fid = fopen(fileFullPath,'w');
fwrite(fid,'0');
fclose(fid);