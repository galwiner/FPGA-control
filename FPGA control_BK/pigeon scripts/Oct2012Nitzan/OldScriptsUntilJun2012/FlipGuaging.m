function FlipGuaging
dic = Dictator.me;

if dic.deflectorCompensaion
    if ~isempty(dic.ULE.freqHistory)
        error('Switch frequency history is not empty');
    end
    ULEFreqHistory = dic.switchSetFreq - 2*dic.ULE.deflectorFreqHistory;
    dic.ULE.freqHistory = ULEFreqHistory + 2*dic.deflectorCurrentFreq;
    dic.ULE.deflectorFreqHistory = [];
    dic.deflectorCompensaion = 0;
    disp('Compensating 674 by the switch');
else
    if ~isempty(dic.ULE.deflectorFreqHistory)
        error('Deflector frequency history is not empty');
    end
    ULEFreqHistory = dic.ULE.freqHistory - 2*dic.deflectorCurrentFreq;
    dic.ULE.deflectorFreqHistory = (dic.switchSetFreq-ULEFreqHistory)/2;
    dic.ULE.freqHistory = [];
    dic.deflectorCompensaion = 1;
    dic.updateF674;
    disp('Compensating 674 by the deflector');
end