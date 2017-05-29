function newf=extrapolateF674(t,f,inow)
%given a vector of times when F674 was measured and
% a vector of frequencies taken at those times
%returns the extrapolated value of F674
% f in MHz
% t in days (format of the matlab 'now' command)
if (nargin<3)
    inow=now;
end
if isempty(t)
    %no data!
    newf=-1;
    return; %error
end
if (length(t)==1)
    %only single data point - no slope available
    newf=f(1);
else
    m=double(diff(f)/diff(t));
    newf=f(2)+m*(inow-t(2));
end
end