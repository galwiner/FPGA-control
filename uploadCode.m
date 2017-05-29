function errorCode=uploadCode(prog,varargin)
%This function creates the connection object and uploads the code. 
%prog is a codeGenerator instance, containing the sequence to be uploaded.
%errorCode=1 is success and errorCode=-1 indicates an error
%TODO: add varargin handeling for IP, port and execution parameters

try
com=Tcp2Labview('localhost',6340);
pause(1);
com.UploadCode(prog);
com.UpdateFpga;
com.WaitForHostIdle;
com.Execute(1);
com.Delete;
errorCode=1;
catch 
    warning('error in code upload!')
    errorCode=-1;
    com.Delete;
end
   
end

