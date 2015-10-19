function out = SincSquared (beta,x)

amp = beta(1);
x0 = beta(2);
b = beta(3);


out = amp*sinc(b*(x-x0)).^2;
end