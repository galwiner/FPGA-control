function s=openSerial(com,varargin)
    all=instrfindall;
    s=[];
    for loop=1:length(all)
        if (strcmp(all(loop).type,'serial'))&&...
                ~isempty(regexpi(all(loop).Name,['.*' com '.*']))&&...
                strcmp(all(loop).Status,'open')
            s=all(loop);
        end
    end
    if (isempty(s))
        if (length(varargin)>0)
            varstr='';
            for t=1:(length(varargin)-1)
                varstr=[varstr 'varargin{' num2str(t) '},'];
            end
            varstr=[varstr 'varargin{' num2str(length(varargin)) '}']; 
            s=eval(['serial(com,' varstr ');']);
        else
            s=serial(com);
        end
        fopen(s);
    end
end