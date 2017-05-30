function QPTsingleQubit
dic=Dictator.me; 
% for Zeeman single qubit
rep=1000; % repetitions per input,output pair

% input states: up down X Y
inState.names={'up','down','X','Y'};
inState.time=[0 dic.TimeRF dic.TimeRF/2 dic.TimeRF/2];
inState.phase=[0 0 pi/2 pi];

% measured states: Z X Y
measState.names={'Z','X','Y'};
measState.time=[0 dic.TimeRF/2 dic.TimeRF/2];
measState.phase=[0 3*pi/2 0];

%result Table
ramseyWaitTime=linspace(0,600,21);
resultTbl=zeros(4,3,length(ramseyWaitTime));

for ramseyIdx=1:length(ramseyWaitTime)
    ramseyTime=ramseyWaitTime(ramseyIdx);fprintf('Meas. Ramsey Time %.2f\n',ramseyTime);
    RFResScan;
    for InitState=1:4
        for MeasuredState=1:3
            dic.updateF674;
            r=experimentSequence(InitState,MeasuredState);
            dic.GUI.sca(1);
            hist(r,1:1:dic.maxPhotonsNumPerReadout);
            ivec=dic.IonThresholds;
            tmpdark=sum(r>ivec(1));
            tmpdark=100-tmpdark/length(r)*100;
            resultTbl(InitState,MeasuredState,ramseyIdx)=tmpdark;
        end
    end
end
% show Data
showData=['for ramseyIdx=1:length(ramseyWaitTime);ramseyTime=ramseyWaitTime(ramseyIdx);'...
    'fprintf(''%5s %3s %3s %3s Ramsey=%.2f\n'','' '',measState.names{1},measState.names{2},measState.names{3},ramseyTime);' ...
'for InitState=1:4;' ...
    'fprintf(''%5s '',inState.names{InitState});'...
    'for MeasuredState=1:3;'...
        'fprintf(''%3.0f '',resultTbl(InitState,MeasuredState,ramseyIdx));'...
    'end;'...
    'fprintf(''\n'');' ...
'end; end;'];

% save result
dic.save;
eval(showData);

    function r=experimentSequence(InitState,MeasuredState)
        prog=CodeGenerator;
        prog.GenDDSPullParametersFromBase;
        % set DDS freq and amp
        prog.GenSeq(Pulse('ExperimentTrigger',0,50));
        % Doppler coolng
        prog.GenSeq(Pulse('OffRes422',0,1));%turn off cooling
        prog.GenSeq(Pulse('OnResCooling',10,dic.Tcooling));
        
        pulsePhase=inState.phase(InitState);
        prog.GenSeq(Pulse('RFDDS2Switch',2,-1,'freq',dic.FRF,'amp',dic.ampRF,'phase',pulsePhase));
        prog.GenSeq(Pulse('674DDS1Switch',2,-1,'freq',dic.SinglePass674freq,'amp',100,'phase',0));
        
        %activate noise eater, move it to int hold and repump
        prog.GenSeq([Pulse('674DDS1Switch',2,20),...
            Pulse('NoiseEater674',3,15),Pulse('674DoublePass',0,23),...
            Pulse('Repump1033',23,dic.T1033),...
            Pulse('OpticalPumping',23+dic.T1033,dic.Toptpump)]);
        
        prog.GenSeq(Pulse('OpticalPumping',0,dic.Toptpump));
        
        % Input State Preparation
        pulseTime=inState.time(InitState);
        pulsePhase=inState.phase(InitState);
        if pulseTime>0 
            prog.GenSeq(Pulse('RFDDS2Switch',0,pulseTime));
        end
        
        % Process=Ramsey=wait
        pulsePhase=measState.phase(MeasuredState);
        prog.GenSeq(Pulse('RFDDS2Switch',2,-1,'freq',dic.FRF,'amp',dic.ampRF,'phase',pulsePhase));
        prog.GenPause(ramseyTime);
        
        
        % Analysis Pulses
        pulseTime=measState.time(MeasuredState);
        pulsePhase=measState.phase(MeasuredState);
        if pulseTime>0 
            prog.GenSeq(Pulse('RFDDS2Switch',2,pulseTime));
        end
        
        % Shelving pulse
        prog.GenSeq([Pulse('674DDS1Switch',2,dic.T674),Pulse('674DoublePass',0,dic.T674+2)]);
        % Detection
        prog.GenSeq([Pulse('OnRes422',0,dic.TDetection)...
            Pulse('PhotonCount',0,dic.TDetection)]);
    
        %resume cooling
        prog.GenSeq(Pulse('Repump1033',0,dic.T1033));
        prog.GenSeq(Pulse('OffRes422',0,0));
        prog.GenFinish;
        
        % FPGA/Host control
        n=dic.com.UploadCode(prog);
        dic.com.UpdateFpga;
        dic.com.WaitForHostIdle;
        
        dic.com.Execute(rep);
        dic.com.WaitForHostIdle;
        r=dic.com.ReadOut(rep);
    end



end