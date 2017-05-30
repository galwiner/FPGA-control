function r=PulseChannelInfo(varargin)
% This function holds all the information that connect abstract pulse
% to its hardware implementation
% each pulse is a structure in a cell array called info
% each stracture/Pulse MUST have the fields :
%'ChannelName' and 'ChannelType'. In addition any number of
% fields can be added.
% !! all fields should be supported by CodeGenerator !!.
% !! pulse of same type must have the same fields !!!
% Channel type | fields
%---------------------------------
%      'Dig'         'DigitalSwitch','OnIs'
%      'VCO'         'DigitalSwitch','OnIs','SetFreqAddress','Freq2Value','SetAmpAddress'
%      'PMT'         'Operation'
persistent info;
if isempty(info)
    info={
        struct('ChannelName','DigOut0',...
        'ChannelType','Dig','DigitalSwitch',0,'OnIs',1),...
        struct('ChannelName','DigOut1',...
        'ChannelType','Dig','DigitalSwitch',99,'OnIs',1),...
        struct('ChannelName','AOM1',...
        'ChannelType','VCO','DigitalSwitch',1,'OnIs',1,'SetFreqAddress',1,'Freq2Value','int16(freq)','SetAmpAddress',2),...
        struct('ChannelName','PhotonCount1',...
        'ChannelType','PMT','Operation',1),...
        };
    
end

%--------------------------------------------------------
if size(varargin,2)>0
    if isnumeric(varargin{1})
        r=info{varargin{1}}.(varargin{2});
    else
        numofchannel=size(info,2);
        num=1;
        while num<=numofchannel
            if strcmp(info{num}.ChannelName,varargin{1})
                break;
            else
                num=num+1;
            end
        end
        if (num > numofchannel)
            num=0;
            error('Channel name is not in ChannelInfo')
        end
        r=num;
    end
else
    r=info;
end
end