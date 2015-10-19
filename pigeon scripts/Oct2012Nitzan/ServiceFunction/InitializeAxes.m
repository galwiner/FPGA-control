function out = InitializeAxes (axesHandle,xLabelStr,yLaberStr,titleSTR,...
    xLimRange,yLimRange,numOfRequiredLines)

if strcmp(get(axesHandle,'Nextplot'),'replacechildren')
    delete(get(axesHandle,'Children'));
end
if isempty(xLimRange)
    set(axesHandle,'XLimMode','auto');
else
    set(axesHandle,'XLim',xLimRange);
end
if isempty(yLimRange)
    set(axesHandle,'YLimMode','auto');
else
    set(axesHandle,'YLim',yLimRange);
end
xlabel(axesHandle,xLabelStr);
ylabel(axesHandle,yLaberStr);
title(axesHandle,titleSTR);
for index = 1:numOfRequiredLines
    out(index) = line('XData',[],'YData',[],'Color',RandRGBNoWhite,'Parent',axesHandle);
end

