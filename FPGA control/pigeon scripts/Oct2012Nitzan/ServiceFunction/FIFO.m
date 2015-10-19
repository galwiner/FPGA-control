classdef FIFO < handle
    
    properties(Access=private)
        sz=1; %fifo size
        data=[]; %fifo data
    end
    
    methods
        function newObj=FIFO(iSz)
            if (nargin>0)&&(iSz>1)
                newObj.sz=iSz;
            end
        end
        function []=push(obj,el)
            if (length(obj.data)<obj.sz)
                obj.data(end+1)=el;
            else
                obj.data=obj.data(2:end);
                obj.data(end+1)=el;
            end
        end
        function d=getData(obj)
            d=obj.data;
        end
        function reset(obj)
            obj.data=[];
        end
    end
end