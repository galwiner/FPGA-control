function takeFive(t)
    if ~exist('t')
        t=5;
    end
    % wait t seconds with matlab
    for dummy=1:t
        pause(1);
        fprintf('%d,',t-dummy);
    end
end