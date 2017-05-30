function fig=openFigure(name)
    FigList=get(0,'Children'); %get alist of all of root's figures
    for loop=1:length(FigList)
        if strfind(get(FigList(loop),'Name'),name) %figure already exists
            fig=figure(FigList(loop)); %direct the handle to it
            return;
        end
    end
    %open new figure
    fig=figure('Name',name);
%     set(fig,'NextPlot','replacechildren');
end