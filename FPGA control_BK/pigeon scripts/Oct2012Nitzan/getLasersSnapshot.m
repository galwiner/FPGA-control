function out=getLasersSnapshot(fieldName)

%establish connection with TCP server
computerip='132.77.41.57';
port=5555;
% if (~isempty(instrfind('type','tcpip')))
%     TcpID=instrfind('type','tcpip');
%     TcpID=TcpID(find(strcmp(TcpID.Name,'TCPIP-132.77.41.57'),1));
%     if strcmp(TcpID.status,'closed')||~isvalid(TcpID)
        TcpID=tcpip(computerip,port);
        set(TcpID,'InputBufferSize',10*1024);
        set(TcpID,'OutputBufferSize',10*1024);
        set(TcpID,'Timeout',6); %6 seconds for receive
        fopen(TcpID);
%     end
%  else
%     TcpID=tcpip(computerip,port);
%     set(TcpID,'InputBufferSize',10*1024);
%     set(TcpID,'OutputBufferSize',10*1024);
%     set(TcpID,'Timeout',6); %6 seconds for receive
%     fopen(TcpID);
% end

% ask server for data
fwrite(TcpID,int8(1),'int8'); %1=ask for data

% read the answer
stringLength=fread(TcpID,1,'uint8');
laserString=fread(TcpID,stringLength,'char');
outstr=cast(laserString','char');
if exist('fieldName')
    eval(outstr);
    T674
    eval(['out=' fieldName]);
else
    out=outstr;
end
fclose(TcpID);
end