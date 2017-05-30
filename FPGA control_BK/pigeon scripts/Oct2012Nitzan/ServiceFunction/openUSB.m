function s=openUSB(addr)
    all=instrfindall;
    s=[];
    for loop=1:length(all)
        if (strcmp(all(loop).type,'visa-usb'))&&...%~isempty(regexpi(all(loop).Name,['.*' addr '.*']))&&...
                strcmp(all(loop).RsrcName,addr)&&...
                strcmp(all(loop).Status,'open')
            s=all(loop);
        end
    end
    if (isempty(s))
%         if (length(varargin)>0)
%             varstr='';
%             for t=1:(length(varargin)-1)
%                 varstr=[varstr 'varargin{' num2str(t) '},'];
%             end
%             varstr=[varstr 'varargin{' num2str(length(varargin)) '}']; 
%             s=eval(['serial(com,' 
% varstr ');']);
%         else
            s=visa('ni',addr);
%         end
        fopen(s);
    end
end