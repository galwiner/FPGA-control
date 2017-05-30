function getSpectrumAnalyzer(varargin)
dic=Dictator.me;
fStart=0.01;
fEnd=4;
%-----------options-----------------
for i=1:2:size(varargin,2)
   switch lower(char(varargin(i)))
       case 'start'
           fStart=varargin{i+1};
       case 'end'
           fEnd=varargin{i+1};
   end; %switch
end;%for loop

%---------- read data -------------------
gp=gpib('ni',0,18);
set(gp,'InputBufferSize',401*20); %make sure we can read all 1001 data
% % points of Analyzer at once
fopen(gp);

fprintf(gp,['FA ' num2str(fStart) 'MZ']);
fprintf(gp,['FB ' num2str(fEnd) 'MZ']);
freq=linspace(fStart,fEnd,401);
%get trace from Analyzer
sdata=query(gp,'TRA?'); %ask for all data points of TRACE A (String)
a=textscan(sdata,'%.10f','delimiter',','); %change delimited text into object
data=a{1}'; %extract data array from of text
fclose(gp);

% ------------- plot ------------------
spect=InitializeAxes (dic.GUI.sca(9),...
                       'freq [MHz]','Voltage[V]','Spectrum analyzer output',...
                       [fStart fEnd],[],1);
set(spect,'Color',[0 0 0],'XData',freq,'YData',data);
% ------------- save ------------------
if (dic.AutoSaveFlag)
    destDir=dic.saveDir;
    thisFile=[mfilename('fullpath') '.m' ];
    [filePath fileName]=fileparts(thisFile);
    scriptText=fileread(thisFile);
    scriptText(find(int8(scriptText)==10))='';
    showData='figure;plot(freq,data);xlabel(''freq[Mhz]'');ylabel(''voltage'');';
    saveFileName=fullfile(destDir ,[fileName datestr(now,'-ddmmmyy-HHMMSS')]);
    dicParameters=dic.getParameters;
    save(saveFileName,'freq','data','showData','dicParameters','scriptText');
    disp(['Save data in : ' saveFileName]);
end 
end