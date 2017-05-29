function [peakValue,x0,w,bias,xInterpulated,fittedCurve,isValidFit] = ...
    FitToBiasedSincSquared(x,y)

beta = zeros(1,4);
[maxValue maxIndex] = max(y);
beta(4) = min(y);
beta(1) = maxValue-beta(4);
beta(2) = x(maxIndex);
[crap minIndex] = min(abs(y-(beta(4)+0.5*beta(1))));
beta(3) = 0.443/abs(x(minIndex)-x(maxIndex));
lastwarn('');
%temp = nlinfit(x,y,@BiasedSincSquared,beta);
ft=fittype('a*sinc((x-b)*c).^2+d');
fo=fitoptions('Method','NonlinearLeastSquares',...
               'Startpoint',beta);
[curve,goodness]=fit(x,y,ft,fo);
temp(1)=curve.a;
temp(2)=curve.b;
temp(3)=curve.c;
temp(4)=curve.d;
% *** crap happends
[a b] = lastwarn;
lastwarn('');
if strcmp(b,'stats:nlinfit:Overparameterized')||...
        strcmp(b,'stats:nlinfit:IterationLimitExceeded')||...
        strcmp(b,'stats:nlinfit:IllConditionedJacobian')||...
        strcmp(b,'stats:nlinfit:UnableToDecreaseSSE')

    disp('Coudn''t reach appropriate fit.');
    isValidFit = 0;
    peakValue = NaN;
    x0 = NaN;
    w = NaN;
    bias = NaN;
    xInterpulated = NaN;
    fittedCurve = NaN;
else
    peakValue = temp(1)+temp(4);
    x0 = temp(2);
    bias = temp(4);
    w = temp(3);

    deltaX = x(2)-x(1);
    xInterpulated = x(1):deltaX/10:x(end);
    fittedCurve = BiasedSincSquared(temp,xInterpulated);
    isValidFit = 1;
end


end



