function AddLinePoint (lineHandle,x,y)

xData = get(lineHandle,'XData');
yData = get(lineHandle,'YData');
xData(end+1) = x;
yData(end+1) = y;
set(lineHandle,'XData',xData,'YData',yData);