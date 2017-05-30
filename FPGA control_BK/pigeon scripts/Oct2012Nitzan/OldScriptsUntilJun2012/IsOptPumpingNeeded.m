function out = IsOptPumpingNeeded(lineNum)
dic=Dictator.me;
currentSmF = dic.S1HalfsLevel...
    (dic.quadTrans(dic.currentQuadTrans).S1D5Levels(1)).m;
targetSmF = dic.S1HalfsLevel...
    (dic.quadTrans(lineNum).S1D5Levels(1)).m;
out = (currentSmF==targetSmF);