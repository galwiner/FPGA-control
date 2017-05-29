function setCurColor(handle)
%gets plot handle, and changes the color of its plot in a round robin
%manner
global CurColor;
if (isempty(CurColor))
    CurColor=0;
end
colors=['b';'r';'g';'m';'c'];

set(handle,'MarkerFaceColor',colors(CurColor+1),'MarkerSize',3,...
    'Color',colors(CurColor+1),'LineStyle','-','Marker','o');
end