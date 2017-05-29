for j=1:10
    OptimizeRFNullSecond('scantype',1);
    pause(180);
    if dic.stop
     return;
    end
end

