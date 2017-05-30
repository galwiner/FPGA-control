% example of Vescent ICE communications

s=serial('COM4','BaudRate',115200,'StopBits',1,'Parity','none','timeout',0.1,'Terminator',char(13));
fopen(s)
fprintf(s,'#Status');
fscanf(s)
fclose(s)