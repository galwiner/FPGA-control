function out = NumOfIons (imageSum,thresh)


maxValue = max(imageSum);
if ~exist('thresh')    
    binLine = double(imageSum>0.7*maxValue);
else
    binLine = double(imageSum>max([thresh 0]));
end
binLine([1 end]) = 0;
f = find(binLine);
for index2 = 1:length(f)
    if (binLine(f(index2)+1)~=binLine(f(index2)))&&(binLine(f(index2)-1)~=binLine(f(index2)))
        binLine(f(index2)) = 0;
    end
end
idx = diff(binLine);
%sanity check on peaks
peakStarts=find(idx==1);
peakEnds=find(idx==-1);
peakCenters=floor((peakStarts+peakEnds)/2);
peakWidths=peakEnds-peakStarts;
if (length(peakStarts)==2)&&(sum(peakWidths>3)==2)&&(abs(diff(peakCenters))>4)
    out=2;
    hold on; plot(maxValue*binLine,'r'); hold off;
else %maybe one ion
    
    binLine = double(imageSum>0.7*maxValue);
    binLine([1 end]) = 0;
    f = find(binLine);
    for index2 = 1:length(f)
        if (binLine(f(index2)+1)~=binLine(f(index2)))&&(binLine(f(index2)-1)~=binLine(f(index2)))
            binLine(f(index2)) = 0;
        end
    end
    idx = diff(binLine);
    %sanity check on peaks
    peakStarts=find(idx==1);
    peakEnds=find(idx==-1);
    peakCenters=floor((peakStarts+peakEnds)/2);
    peakWidths=peakEnds-peakStarts;
    if (length(peakStarts)==1)&&(peakWidths>3)
        out=1;
        hold on; plot(maxValue*binLine,'r'); hold off;
    else
        out=-1;
    end
end
