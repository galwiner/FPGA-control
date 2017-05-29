%optimizing according to 422 det
[optVdcl,optVcomp]=DetEffVsCompLinScan(0.00752,1.33);
if dic.stop
    return;
end
dic.HPVcomp=optVcomp;
dic.AVdcl=optVdcl;
dic.calibRfFlag=1;
TwoIonsHeating;
dic.calibRfFlag=0;
if dic.stop
    return;
end

%optimizing according to micromotion shelving eff
[optVdcl,optVcomp]=DetEffVsCompLinScan(0.00752,1.13);
if dic.stop
    return;
end
dic.HPVcomp=optVcomp;
dic.AVdcl=optVdcl;
dic.calibRfFlag=1;
TwoIonsHeating;
dic.calibRfFlag=0;


