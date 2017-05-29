classdef DDS
    %this class represent a DDS device
    
    properties
        comport
        singleMode=1
        parallel=0
        OSK=0
        DRG=0
        REF1=0
        TCXO1=0
    end
    
    methods
        function obj=DDS(comport,varargin)
%             TODO: add options parser.
            obj.comport=comport;
            DDSinit(obj.comport,obj.parallel,obj.DRG,obj.singleMode,obj.OSK,obj.REF1,obj.TCXO1);
           
           
        end
        
        function profileSet(obj,profileNum,freq,phase,amplitude)
            DDSprofile(obj.comport,profileNum,freq,phase,amplitude);
        end
        
    end
    
end


