function [tau,maxAmp,fittedCurve,xInterpulated,yInterpulated] = ...
    FitToSaturatingExp (x,y)

beta(1) = mean(y(end-2:end));
[crap midIndex] = min(abs(y-0.5*beta(1)));
beta(2) = -x(midIndex)/log(0.5);

ft=fittype('a*(1-exp(-x/b))');
fo=fitoptions('Method','NonlinearLeastSquares',...
               'Startpoint',beta);
[curve,goodness]=fit(x',y',ft,fo);
maxAmp=curve.a;
tau=curve.b;


fittedCurve = maxAmp*(1-exp(-x/tau));
dx = diff(x(1:2));
xInterpulated = min(x):(dx/10):max(x);
yInterpulated = maxAmp*(1-exp(-xInterpulated/tau));