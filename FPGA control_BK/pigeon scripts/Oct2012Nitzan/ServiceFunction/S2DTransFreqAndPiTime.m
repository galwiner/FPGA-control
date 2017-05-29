function [freq,piTime,isOptPumpNeeded]= S2DTransFreqAndPiTime(transNum)
dic = Dictator.me;
% 
% currentLineFreq = dic.quadTrans(dic.currentQuadTrans).ShiftRFFactor*dic.FRF+...
%     dic.quadTransBaseFreq;
% freqOffset = dic.updateF674-currentLineFreq;
% freq = dic.quadTrans(transNum).ShiftRFFactor*dic.FRF+...
%     dic.quadTransBaseFreq+freqOffset;
S1HalfsLevel = struct('sign',{'S_{1/2,-1/2}' 'S_{1/2,1/2}'},...
            'm',{-0.5,0.5});
D5HalfsLevel = struct('sign',{'D_{5/2,-5/2}','D_{5/2,-3/2}',...
            'D_{5/2,-1/2}','D_{5/2,1/2}','D_{5/2,3/2}','D_{5/2,5/2}'},...
            'm',{-5/2 -3/2 -1/2 1/2 3/2 5/2});
global quadTrans;
if isempty(quadTrans)
    quadTrans = struct('S1D5Levels',{[2 3] [1 2] [2 5] [1 4]},...
            'piTime',{3 3 3 3},'ShiftRFFactor',{-0.7967 -0.3974 0.3974 0.8079});
end
currentQuadTrans=3;

piTime = quadTrans(transNum).piTime;
m1 = ...
    S1HalfsLevel(quadTrans(currentQuadTrans).S1D5Levels(1)).m;
mtag1 = ...
    D5HalfsLevel(quadTrans(currentQuadTrans).S1D5Levels(2)).m;
m2 = ...
    S1HalfsLevel(quadTrans(transNum).S1D5Levels(1)).m;
mtag2 = ...
    D5HalfsLevel(quadTrans(transNum).S1D5Levels(2)).m;

deltaF1 = -(-m1+1.68/2.802*mtag1)*dic.FRF;
deltaF2 = -(-m2+1.68/2.802*mtag2)*dic.FRF;
freq = dic.updateF674+(deltaF2-deltaF1);

%is optical pumping needed?
currentSmF = S1HalfsLevel...
    (quadTrans(currentQuadTrans).S1D5Levels(1)).m;
targetSmF = S1HalfsLevel...
    (quadTrans(transNum).S1D5Levels(1)).m;
isOptPumpNeeded = (currentSmF==targetSmF);



end