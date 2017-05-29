% parity scans
detuneList=linspace(0.0018,0.0023,1);
gateTimeList=linspace(150,180,1);
for j=1:length(detuneList)
    for i=1:length(gateTimeList)
        EntanglingtGateParityScan2(gateTimeList(i),detuneList(j));
        exit;
    end
end