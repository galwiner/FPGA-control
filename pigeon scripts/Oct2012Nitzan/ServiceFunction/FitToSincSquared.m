function [peakValue,x0,w,xInterpulated,fittedCurve,isValidFit] = ...
    FitToSincSquared(x,y)

beta = zeros(1,3);
[maxValue maxIndex] = max(y);

beta(1) = maxValue;
beta(2) = x(maxIndex);
[crap minIndex] = min(abs(y-(0.5*beta(1))));
beta(3) = 0.443/abs(x(minIndex)-x(maxIndex));
lastwarn('');
%temp = nlinfit(x,y,@BiasedSincSquared,beta);
ft=fittype('a*sinc((x-b)*c).^2');
fo=fitoptions('Method','NonlinearLeastSquares',...
               'Startpoint',beta);
[curve,goodness]=fit(x,y,ft,fo);
temp(1)=curve.a;
temp(2)=curve.b;
temp(3)=curve.c;

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
    xInterpulated = NaN;
    fittedCurve = NaN;
else
    peakValue = temp(1);
    x0 = temp(2);
    
    w = temp(3);

    deltaX = x(2)-x(1);
    xInterpulated = x(1):deltaX/10:x(end);
    fittedCurve = SincSquared(temp,xInterpulated);
    isValidFit = 1;
end


end



