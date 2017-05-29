% TODO: add tests. 
t1=tcpip('10.10.10.102',8462);
fopen(t1)
%clear error queue
for i=1:10
    fprintf(t1,'system:error?');
    fscanf(t1)
end


fprintf(t1,'*IDN?')
fscanf(t1)
fprintf(t1,'*PUD CIRCULAR COILS')
fprintf(t1,'*SAV')
fprintf(t1,'system:interface:ianalog 4,RANGE,HI')
fprintf(t1,'system:interface:ianalog 4,RANGE?')
fscanf(t1)
fprintf(t1,'*SAV')

fprintf(t1,'system:remote:cv:status ethernet')
fprintf(t1,'system:remote:cv:status?')
fscanf(t1)

fprintf(t1,'system:remote:cc:status slot4')
fprintf(t1,'system:remote:cc:status?')
fscanf(t1)

fprintf(t1,'system:limits:voltage 18,ON')
fprintf(t1,'system:limits:current 220,ON')

fprintf(t1,'system:limits:voltage?')
fscanf(t1)
fprintf(t1,'system:limits:current?')
fscanf(t1)

fprintf(t1,'source:voltage 18')
fprintf(t1,'output on')
fclose(t1)


t2=tcpip('10.10.10.103',8462);
fopen(t2)
%clear error queue
for i=1:10
    fprintf(t2,'system:error?');
    fscanf(t2)
end


fprintf(t2,'*IDN?')
fscanf(t2)
fprintf(t2,'*PUD RECTANGULAR COILS')
fprintf(t2,'*SAV')
fprintf(t2,'system:interface:ianalog 4,RANGE,HI')
fprintf(t2,'system:interface:ianalog 4,RANGE?')
fscanf(t2)
fprintf(t2,'*SAV')

fprintf(t2,'system:remote:cv:status ethernet')
fprintf(t2,'system:remote:cv:status?')
fscanf(t2)

fprintf(t2,'system:remote:cc:status slot4')
fprintf(t2,'system:remote:cc:status?')
fscanf(t2)

fprintf(t2,'system:limits:voltage 18,ON')
fprintf(t2,'system:limits:current 220,ON')

fprintf(t2,'system:limits:voltage?')
fscanf(t2)
fprintf(t2,'system:limits:current?')
fscanf(t2)

fprintf(t2,'source:voltage 18')
fprintf(t2,'output on')
fclose(t2)