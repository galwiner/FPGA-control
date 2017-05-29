function [piTime,T2,maxAmp,fittedCurve,xInterpulated,yInterpulated] = FitToSinkingRabiFlops (x,y)

[maxValue maxIndex] = max(y);
interpXSpan = x(round(1.5*maxIndex))-x(1);
deltaInterpX = interpXSpan/30;
interpX = x(1):deltaInterpX:x(round(1.5*maxIndex));
interpY = csaps(x(1:round(1.5*maxIndex)),...
    y(1:round(1.5*maxIndex)),0.95,interpX);
[crap maxInterpIndex] = max(interpY);


beta(1) = x(maxIndex)*2;
if length(x)>(2*maxIndex+1)
    minValue = min(y(2*maxIndex+[-1:1]));
    beta(3) = 2*(maxValue*exp(2)+minValue)/(1+exp(2));
    beta(2) = -beta(1)/2/log(2*maxValue/beta(3)-1);
    
else
    beta(2) = -beta(1)/2/log(maxValue/50-1);
    beta(3) = 100;
end
beta(4) = 0;

%  temp = nlinfit(x,y,@SinkingRabiFlops,beta);
ft=fittype('c/2*(1+exp(-x/b).*cos(2*pi*x/a+pi+d))');
fo=fitoptions('Method','NonlinearLeastSquares',...
               'Startpoint',beta);
[curve,goodness]=fit(x',y',ft,fo);
temp(1)=curve.a;
temp(2)=curve.b;
temp(3)=curve.c;
temp(4) = curve.d;

% piTime = temp(1)/2;
piTime = interpX(maxInterpIndex);
T2 = temp(2);
maxAmp = temp(3);
fittedCurve = SinkingRabiFlops(temp,x);
dx = diff(x(1:2));
xInterpulated = min(x):(dx/10):max(x);
yInterpulated = SinkingRabiFlops(temp,xInterpulated);
