function [mainMeanFreq,mainFWHM,mainPeak,fittedCurve] = ...
    FitToGaussian (freq,curve)
% returns fit line fit parameters.

[p mIndex] = max(curve);
m = freq(mIndex);
[crap fIndex]=min(abs(curve-0.5*p));
f = 2*abs(freq(fIndex)-m);
[b crap crap2 crap3 MSE] = nlinfit(freq,curve,@SingleGaussian,[m f p]);

mainMeanFreq = b(1);
mainFWHM = b(2);
mainPeak = b(3);

fittedCurve = SingleGaussian(b,freq);

end