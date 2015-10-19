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
%     if the varargin structur is such that the first param is numeric., the effect is
%     1st param is the channel number,
%     2nd param is the type of info we want to query e.g "ChannelName",
%     "ChannelType" etc. this is then the return value of the function
    if isnumeric(varargin{1})
        r=info{varargin{1}}.(varargin{2});
    else
%         if the first input param is not numeric, it is assumed we only have one input param 
% which is a channel name. this has to match the name of one of the channles in the info structure 
% the function then retuns the channel number.
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