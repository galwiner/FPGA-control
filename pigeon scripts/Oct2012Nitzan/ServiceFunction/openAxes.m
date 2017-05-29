function ax=openAxes(fig,name)
    figChildren=get(fig,'Children');
    for loop=1:length(figChildren)
        if strfind(get(figChildren(loop),'Type'),'axes')
            if strfind(get(figChildren(loop),'Tag'),name)
                ax=figChildren(loop);
                axes(ax);
                return;
            end
        end
    end
    ax=axes;
    set(ax,'Tag',name);
    set(ax,'NextPlot','replacechildren');
    title(name);
end