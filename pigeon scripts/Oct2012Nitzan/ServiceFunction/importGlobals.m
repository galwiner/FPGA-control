function importGlobals

assignin('base','IamInBase',1);

if evalin('base','~exist(''Toptpump'')')
    Toptpump=50;% default value
else
    Toptpump=evalin('base','Toptpump');
end
assignin('caller','Toptpump',Toptpump);    


if evalin('base','~exist(''stopRun'')')
    stopRun=0;% default value
else
    stopRun=evalin('base','stopRun');
end
assignin('caller','stopRun',stopRun);    

if evalin('base','~exist(''Tcooling'')')
    Tcooling=500;% default value
else
    Tcooling=evalin('base','Tcooling');
end
assignin('caller','Tcooling',Tcooling);    

if evalin('base','~exist(''T1033'')')
    T1033=50;% default value
else
    T1033=evalin('base','T1033');
end
assignin('caller','T1033',T1033);    

if evalin('base','~exist(''resume'')')
    resume=0;% default value
else
    resume=evalin('base','resume');
end
assignin('caller','resume',resume);

if evalin('base','~exist(''lastidx'')')
    lastidx=1;% default value
else
    lastidx=evalin('base','lastidx');
end
assignin('caller','lastidx',lastidx);



if evalin('base','~exist(''Necho'')')
    Necho=1;% default value
else
    Necho=evalin('base','Necho');
end
assignin('caller','Necho',Necho);    
    
if evalin('base','~exist(''RamseyTime'')')
    RamseyTime=1000;% default value
else
    RamseyTime=evalin('base','RamseyTime');
end
assignin('caller','RamseyTime',RamseyTime);

if evalin('base','~exist(''SitOnEcho'')')
    SitOnEcho=1;% default value
else
    SitOnEcho=evalin('base','SitOnEcho');
end
assignin('caller','SitOnEcho',SitOnEcho);


if evalin('base','~exist(''Force674Scan'')')
    Force674Scan=0;% default value
else
    Force674Scan=evalin('base','Force674Scan');
end
assignin('caller','Force674Scan',Force674Scan);

if evalin('base','~exist(''SitOnIt'')')
    SitOnIt=0;% default value
else
    SitOnIt=evalin('base','SitOnIt');
end
assignin('caller','SitOnIt',SitOnIt);

if evalin('base','~exist(''T674'')')
    T674=10;% default value for 674 pi time
else
    T674=evalin('base','T674');
end
assignin('caller','T674',T674);

if evalin('base','~exist(''T674plus'')')
    T674plus=14.38;% default value for 674 pi time
else
    T674plus=evalin('base','T674plus');
end
assignin('caller','T674plus',T674);

if evalin('base','~exist(''F674'')')
    F674=80.7;% default value for 674 pi time
else
    F674=evalin('base','F674');
end
assignin('caller','F674',F674);

if evalin('base','~exist(''is674Locked'')')
    is674Locked=0;% default value for 674 pi time
else
    is674Locked=evalin('base','is674Locked');
end
assignin('caller','is674Locked',is674Locked);


if evalin('base','~exist(''TimeRF'')')
    TimeRF=7.6;% default value for RF pi time
else
    TimeRF=evalin('base','TimeRF');
end
assignin('caller','TimeRF',TimeRF);

if evalin('base','~exist(''FRF'')')
    FRF=8.74;% default value for RF res
else
    FRF=evalin('base','FRF');
end
assignin('caller','FRF',FRF);

if evalin('base','~exist(''DarkMax'')')
    DarkMax=0;% default value for RF res
else
    DarkMax=evalin('base','DarkMax');
end
assignin('caller','DarkMax',DarkMax);

if evalin('base','~exist(''ionAxialFreq'')')
    ionAxialFreq=0.98;% default value for axial oscillation frequency
else
    ionAxialFreq=evalin('base','ionAxialFreq');
end
assignin('caller','ionAxialFreq',ionAxialFreq);




if evalin('base','~exist(''estimatedF674'')')
    estimatedF674=F674;
else
    estimatedF674=evalin('base','estimatedF674');
end
assignin('caller','estimatedF674',estimatedF674);

if evalin('base','~exist(''acStarkShift674'')')
    acStarkShift674=0.06139;
else
    acStarkShift674=evalin('base','acStarkShift674');
end
assignin('caller','acStarkShift674',acStarkShift674);


if evalin('base','~exist(''RFPhase'')')
    RFPhase=0;% default value for RF phase which is zero
else
    RFPhase=evalin('base','RFPhase');
end
assignin('caller','RFPhase',RFPhase);

if evalin('base','~exist(''CurTime'')')
    assignin('base','CurTime',0);
    CurTime=0;
    tic;
end
CurTime=toc;
assignin('caller','CurTime',CurTime);
assignin('base','CurTime',CurTime);
end