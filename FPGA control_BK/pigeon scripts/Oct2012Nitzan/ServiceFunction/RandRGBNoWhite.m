function out = RandRGBNoWhite
% no black either

% out = round((round(3*rand(1,3))+1)*200/4);

bank  = [32 53 204;
    146 81 65;
    120 115 54;
    89 113 63;
    65 146 107;
    63 148 148;
    71 87 165;
    132 71 165;
    164 72 120;
    38 198 95];
out = bank(round(rand(1)*(size(bank,1)-1))+1,:)/255;
    
