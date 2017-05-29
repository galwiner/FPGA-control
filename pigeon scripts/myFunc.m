function myFunc(varargin)
persistent a;
if isempty(a)
    a=0
end
a=a+1
if (length(varargin)==0)
    disp('no input arguments');
else 
    disp(length(varargin));
end

