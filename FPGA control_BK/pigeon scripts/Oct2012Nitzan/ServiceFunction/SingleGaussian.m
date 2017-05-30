function out = SingleGaussian (beta,x)

m = beta(1);
FWHM = beta(2);
a = beta(3);

s = -FWHM^2/4/log(0.5);

out = a*exp(-(x-m).^2/s);