function SMGateScans

dic=Dictator.me;
 dic.setNovatech('Parity','clock','external');
 dic.setNovatech('Red','clock','external');
 dic.setNovatech('Blue','clock','external');

repetitions=200;
SBmode = 2;
panelc=11;
%GateDetuning=0.0128; "working"

DoFeedback=1;

ParityTime=dic.T674/2;
DoParityPulse=0;
DoZeemanMapping=0;

scanTypeNum=5;
switch scanTypeNum
    case 1
        scanType='scanGateTime';
        GateTime=(10:10:800);
%         GateTime=(100:3:170);
    case 2
        scanType='scanGateDetuning';
        GateTime=dic.GateInfo.GateTime_mus;
        GateTime=370;
        GateDetuning=(-0.4:0.05:0.4)+11.9+1/0.115; % in kHz
    case 3
        scanType='scanGateOffeset';
        GateOffset=(-1:0.05:1); % in kH
    case 4
        scanType='scanBeamBalance';
        BeamBalance=(-10:0.5:10);
        GateTime=260;
    case 5
        scanType='scanParityPhase';
%       ParityPhase=(0:pi/20:2*pi); % in kHz
        ParityPhase=linspace(0,6.2,40); % in kHz
        DoParityPulse=1;
    case 6 
       scanType='scanRfParityPhase';
       ParityPhase=linspace(0,6.2,80); % in kHz
       DoParityPulse=1;
       DoZeemanMapping=1;
    case 7 
       scanType='scanLightShift';
       DoFeedback=0;
       LightShiftOffset=(-1.5:0.15:1.5)+12;  % in kHz
       
end;
% Using the Echo channel for ground state cooling
dic.setNovatech('Echo','freq',dic.SinglePass674freq+dic.vibMode(SBmode).freq+dic.acStarkShift674,'amp',1000);
dic.setNovatech('Parity','freq',dic.SinglePass674freq+dic.vibMode(1).freq+dic.acStarkShift674,'amp',1000);

%-------------- main scan loop ---------------------
switch scanType 
    case 'scanGateTime'
%         GateTime=(10:05:300); 
        %----- Set GUI figures -----------
        InitializeAxes (dic.GUI.sca(1),'Photons #','Cases Counted #','Fluorescence Histogram',...
            [0 dic.maxPhotonsNumPerReadout],[],0);
        feedbackLine =InitializeAxes (dic.GUI.sca(10),...
            'x','y','feedback',[GateTime(1) GateTime(end)],[0 100],1);
        
        darkCountLine =InitializeAxes (dic.GUI.sca(9),...
            'Gate Time [mus]','Populations %','Entangling Gate',...
            [GateTime(1) GateTime(end)],[0 100],3);
        set(darkCountLine(1),'Marker','.','MarkerSize',10,'Color','b');
        set(darkCountLine(2),'Marker','.','MarkerSize',10,'Color','r');
        set(darkCountLine(3),'Marker','.','MarkerSize',10,'Color','g');
         %----- Main loop -----------
        dark=zeros(length(GateTime),1);
        p0=zeros(length(GateTime),1);
        p1=zeros(length(GateTime),1);
        p2=zeros(length(GateTime),1);
        CrystalCheckPMT;
        
        dic.setNovatech('Red','freq',dic.SinglePass674freq ...
                                    +(dic.vibMode(SBmode).freq-dic.GateInfo.GateDetuningkHz/1000),'amp',dic.GateInfo.RedAmp);
        dic.setNovatech('Blue','freq',dic.SinglePass674freq ...
                                    -(dic.vibMode(SBmode).freq-dic.GateInfo.GateDetuningkHz/1000),'amp',dic.GateInfo.BlueAmp);
        feedback=0;
        for index2 = 1:length(GateTime)
            if dic.stop
                return
            end
            dic.setNovatech('DoublePass','freq',dic.updateF674+feedback,'amp',1000);
            [r,fb]=experimentSequence(GateTime(index2),SBmode);
            dic.GUI.sca(1); %get an axis from Dictator GUI to show data
            hist(r,0:1:(1.8*dic.maxPhotonsNumPerReadout));
            if DoFeedback
                AddLinePoint(feedbackLine,GateTime(index2),fb);
                feedback=feedback-(fb-50)*5e-7;
            end
            p0(index2)=sum(r<dic.IonThresholds(1))/length(r)*100;
            p2(index2)=sum(r>dic.IonThresholds(2))/length(r)*100;
            p1(index2)=100-p0(index2)-p2(index2);
            
            dic.GUI.sca(panelc);
            AddLinePoint(darkCountLine(1),GateTime(index2),p0(index2));
            AddLinePoint(darkCountLine(2),GateTime(index2),p2(index2));
            AddLinePoint(darkCountLine(3),GateTime(index2),p1(index2));
            pause(0.1);
        end
        showData='figure;plot(GateTime,p0,''g'',GateTime,p1,''b'',GateTime,p2,''r'');xlabel(''Gate Time[\mus]'');ylabel(''Populations'');';
%-----------------------------------------------------------------      
    case 'scanGateDetuning'
%         GateDetuning=(17.5:0.1:19.5); % in kHz
        %----- Set GUI figures -----------
        InitializeAxes (dic.GUI.sca(1),'Photons #','Cases Counted #','Fluorescence Histogram',...
            [0 dic.maxPhotonsNumPerReadout],[],0);
           feedbackLine =InitializeAxes (dic.GUI.sca(10),...
            'x','y','feedback',[GateDetuning(1) GateDetuning(end)],[0 100],1);
        
     
        darkCountLine =InitializeAxes (dic.GUI.sca(9),...
            'Gate Detuning [kHz]','Populations %','Entangling Gate',...
            [GateDetuning(1) GateDetuning(end)],[0 100],3);
        set(darkCountLine(1),'Marker','.','MarkerSize',10,'Color','b');
        set(darkCountLine(2),'Marker','.','MarkerSize',10,'Color','r');
        set(darkCountLine(3),'Marker','.','MarkerSize',10,'Color','g');
         %----- Main loop -----------
        dark=zeros(length(GateDetuning),1);
        p0=zeros(length(GateDetuning),1);
        p1=zeros(length(GateDetuning),1);
        p2=zeros(length(GateDetuning),1);
        CrystalCheckPMT;
        feedback=0;
        for index2 = 1:length(GateDetuning)
            dic.setNovatech('Red','freq',dic.SinglePass674freq...
                +(dic.vibMode(SBmode).freq-GateDetuning(index2)/1000),'amp',dic.GateInfo.RedAmp);
            dic.setNovatech('Blue','freq',dic.SinglePass674freq...
                -(dic.vibMode(SBmode).freq-GateDetuning(index2)/1000),'amp',dic.GateInfo.BlueAmp);

            if dic.stop
                return
            end
            dic.setNovatech('DoublePass','freq',dic.updateF674+feedback,'amp',1000);
            [r,fb]=experimentSequence(GateTime,SBmode);
            dic.GUI.sca(1); %get an axis from Dictator GUI to show data
            hist(r,0:1:(1.8*dic.maxPhotonsNumPerReadout));
            if DoFeedback
                AddLinePoint(feedbackLine,GateDetuning(index2),fb);
                feedback=feedback-(fb-50)*5e-7;
            end
           
            p0(index2)=sum(r<dic.IonThresholds(1) )/length(r)*100;
            p2(index2)=sum(r>dic.IonThresholds(2))/length(r)*100;
            p1(index2)=100-p0(index2)-p2(index2);
            
            dic.GUI.sca(panelc);
            AddLinePoint(darkCountLine(1),GateDetuning(index2),p0(index2));
            AddLinePoint(darkCountLine(2),GateDetuning(index2),p2(index2));
            AddLinePoint(darkCountLine(3),GateDetuning(index2),p1(index2));
            pause(0.1);
        end
        showData='figure;plot(GateDetuning,p0,''g'',GateDetuning,p1,''b'',GateDetuning,p2,''r'');xlabel(''Gate Detuning[kHz]'');ylabel(''Populations'');';
%-----------------------------------------------------------------    
    case 'scanGateOffeset'
%         GateOffset=(-1.5:0.1:1.5); % in kHz
        %----- Set GUI figures -----------
        InitializeAxes (dic.GUI.sca(1),'Photons #','Cases Counted #','Fluorescence Histogram',...
            [0 dic.maxPhotonsNumPerReadout],[],0);
        
        darkCountLine =InitializeAxes (dic.GUI.sca(9),...
            'Gate OffesetkHz]','Populations %','Entangling Gate',...
            [GateOffset(1) GateOffset(end)],[0 100],3);
        set(darkCountLine(1),'Marker','.','MarkerSize',10,'Color','b');
        set(darkCountLine(2),'Marker','.','MarkerSize',10,'Color','r');
        set(darkCountLine(3),'Marker','.','MarkerSize',10,'Color','g');
        feedbackLine =InitializeAxes (dic.GUI.sca(10),...
            'x','y','feedback',...
            [GateOffset(1) GateOffset(end)],[0 100],1);
         %----- Main loop -----------
        dark=zeros(length(GateOffset),1);
        p0=zeros(length(GateOffset),1);
        p1=zeros(length(GateOffset),1);
        p2=zeros(length(GateOffset),1);
        CrystalCheckPMT;
        
        for index2 = 1:length(GateOffset)
            dic.setNovatech('Red','freq',dic.SinglePass674freq ...
                +(dic.vibMode(SBmode).freq-dic.GateInfo.GateDetuningkHz/1000),'amp',dic.GateInfo.RedAmp);
            dic.setNovatech('Blue','freq',dic.SinglePass674freq...
                -(dic.vibMode(SBmode).freq-dic.GateInfo.GateDetuningkHz/1000),'amp',dic.GateInfo.BlueAmp);

            if dic.stop
                return
            end
            dic.setNovatech('DoublePass','freq',dic.updateF674-GateOffset(index2)/2000,'amp',1000);
            [r,fb]=experimentSequence(dic.GateInfo.GateTime_mus,SBmode);
            dic.GUI.sca(1); %get an axis from Dictator GUI to show data
            hist(r,0:1:(1.8*dic.maxPhotonsNumPerReadout));
            if DoFeedback
                AddLinePoint(feedbackLine,GateOffset(index2),fb);
            end
            p0(index2)=sum(r<dic.IonThresholds(1))/length(r)*100;
            p2(index2)=sum(r>dic.IonThresholds(2))/length(r)*100;
            p1(index2)=100-p0(index2)-p2(index2);
            
            dic.GUI.sca(panelc);
            AddLinePoint(darkCountLine(1),GateOffset(index2),p0(index2));
            AddLinePoint(darkCountLine(2),GateOffset(index2),p2(index2));
            AddLinePoint(darkCountLine(3),GateOffset(index2),p1(index2));
            pause(0.1);
        end
        showData='figure;plot(GateOffset,p0,''g'',GateOffset,p1,''b'',GateOffset,p2,''r'');xlabel(''Gate Offset[kHz]'');ylabel(''Populations'');';
    case 'scanBeamBalance'
%         GateOffset=(-1.5:0.1:1.5); % in kHz
        %----- Set GUI figures -----------
        InitializeAxes (dic.GUI.sca(1),'Photons #','Cases Counted #','Fluorescence Histogram',...
            [0 dic.maxPhotonsNumPerReadout],[],0);       
        feedbackLine =InitializeAxes (dic.GUI.sca(10),...
            'x','y','feedback',[BeamBalance(1) BeamBalance(end)],[0 100],1);
       darkCountLine =InitializeAxes (dic.GUI.sca(9),...
            'Gate Beam Balance]','Populations %','Entangling Gate',...
            [BeamBalance(1) BeamBalance(end)],[0 100],3);
        set(darkCountLine(1),'Marker','.','MarkerSize',10,'Color','b');
        set(darkCountLine(2),'Marker','.','MarkerSize',10,'Color','r');
        set(darkCountLine(3),'Marker','.','MarkerSize',10,'Color','g');
         %----- Main loop -----------
        dark=zeros(length(BeamBalance),1);
        p0=zeros(length(BeamBalance),1);
        p1=zeros(length(BeamBalance),1);
        p2=zeros(length(BeamBalance),1);
        CrystalCheckPMT;
        feedback=0;
        for index2 = 1:length(BeamBalance)
            dic.setNovatech('Red','freq',dic.SinglePass674freq ...
                +(dic.vibMode(SBmode).freq-dic.GateInfo.GateDetuningkHz/1000),'amp',dic.GateInfo.RedAmp+BeamBalance(index2)/2);
            dic.setNovatech('Blue','freq',dic.SinglePass674freq...
                -(dic.vibMode(SBmode).freq-dic.GateInfo.GateDetuningkHz/1000),'amp',dic.GateInfo.BlueAmp-BeamBalance(index2)/2);

            if dic.stop
                return
            end
            dic.setNovatech('DoublePass','freq',dic.updateF674+feedback,'amp',1000);
            [r,fb]=experimentSequence(GateTime,SBmode);
            dic.GUI.sca(1); %get an axis from Dictator GUI to show data
            hist(r,0:1:(1.8*dic.maxPhotonsNumPerReadout));
            if DoFeedback
                AddLinePoint(feedbackLine,BeamBalance(index2),fb);
                feedback=feedback-(fb-50)*5e-7;
            end
            p0(index2)=sum(r<dic.IonThresholds(1))/length(r)*100;
            p2(index2)=sum(r>dic.IonThresholds(2))/length(r)*100;
            p1(index2)=100-p0(index2)-p2(index2);
            
            dic.GUI.sca(panelc);
            AddLinePoint(darkCountLine(1),BeamBalance(index2),p0(index2));
            AddLinePoint(darkCountLine(2),BeamBalance(index2),p2(index2));
            AddLinePoint(darkCountLine(3),BeamBalance(index2),p1(index2));
            pause(0.1);
        end
        showData='figure;plot(BeamBalance,p0,''g'',BeamBalance,p1,''b'',BeamBalance,p2,''r'');xlabel(''Gate BeamBalance'');ylabel(''Populations'');';
        dic.setNovatech('Red','amp',dic.GateInfo.RedAmp);
        dic.setNovatech('Blue','amp',dic.GateInfo.BlueAmp);
%-----------------------------------------------------------------    
    case 'scanParityPhase'
        %----- Set GUI figures -----------
        InitializeAxes (dic.GUI.sca(1),'Photons #','Cases Counted #','Fluorescence Histogram',...
            [0 dic.maxPhotonsNumPerReadout],[],0);
        feedbackLine =InitializeAxes (dic.GUI.sca(10),...
            'x','y','feedback',[ParityPhase(1) ParityPhase(end)],[0 100],1);
          
        darkCountLine =InitializeAxes (dic.GUI.sca(11),...
            'Parity Phase [rad]','Populations %','Entangling Gate',...
            [ParityPhase(1) ParityPhase(end)],[-1 1],2);
        set(darkCountLine(1),'Marker','.','MarkerSize',10,'Color','k');
        set(darkCountLine(2),'Color','r');
         %----- Main loop -----------
        dark=zeros(length(ParityPhase),1);
        p0=zeros(length(ParityPhase),1);
        p1=zeros(length(ParityPhase),1);
        p2=zeros(length(ParityPhase),1);
        parity=zeros(length(ParityPhase),1);
        CrystalCheckPMT;
        dic.setNovatech('Red','freq',dic.SinglePass674freq ...
            +(dic.vibMode(SBmode).freq-dic.GateInfo.GateDetuningkHz/1000),'amp',dic.GateInfo.RedAmp);
        dic.setNovatech('Blue','freq',dic.SinglePass674freq ...
            -(dic.vibMode(SBmode).freq-dic.GateInfo.GateDetuningkHz/1000),'amp',dic.GateInfo.BlueAmp);
        feedback=0;
        for index2 = 1:length(ParityPhase)
            dic.setNovatech('Red','phase',mod(ParityPhase(index2),2*pi));
            if dic.stop
                return
            end
            dic.setNovatech('DoublePass','freq',dic.updateF674+feedback,'amp',1000);
            [r,fb]=experimentSequence(dic.GateInfo.GateTime_mus,SBmode);
            dic.GUI.sca(1); %get an axis from Dictator GUI to show data
            hist(r,0:1:(1.8*dic.maxPhotonsNumPerReadout));
            if DoFeedback
                AddLinePoint(feedbackLine,ParityPhase(index2),fb);
                feedback=feedback-(fb-50)*5e-7;
            end
            p0(index2)=sum(r<dic.IonThresholds(1))/length(r)*100;
            p2(index2)=sum(r>dic.IonThresholds(2))/length(r)*100;
            p1(index2)=100-p0(index2)-p2(index2);
            
            parity(index2)=(p0(index2)+p2(index2)-p1(index2))/100;
            
            dic.GUI.sca(9);
            AddLinePoint(darkCountLine(1),ParityPhase(index2),parity(index2));
            pause(0.1);
        end
        s = fitoptions('Method','NonlinearLeastSquares','Startpoint',[1.1 0 0]);         
        f = fittype('a*sin(x-b)+c','options',s);
        [curve,gof2] = fit(ParityPhase',parity,f);
        ParityContrast=abs(curve.a);
        %     disp(sprintf('Parity Contrast = %.3f  Phase Shift = %1.2f  Offset = %.2f',c2.a,c2.b,c2.c));
        disp(sprintf('Parity Contrast = %.3f  Phase Shift = %1.2f',ParityContrast,curve.b));
        disp(sprintf('Parity Contrast min max= %.3f  ',0.5*(max(parity)-min(parity))));
        set(darkCountLine(2),'XData',ParityPhase,'YData',curve(ParityPhase));
        
        showData='figure;plot(ParityPhase,parity);xlabel(''ParityPhase[rad]'');ylabel(''Populations'');';
    case 'scanRfParityPhase'
        %----- Set GUI figures -----------
        InitializeAxes (dic.GUI.sca(1),'Photons #','Cases Counted #','Fluorescence Histogram',...
            [0 dic.maxPhotonsNumPerReadout],[],0);
        feedbackLine =InitializeAxes (dic.GUI.sca(10),...
            'x','y','feedback',[ParityPhase(1) ParityPhase(end)],[0 100],1);
          
        darkCountLine =InitializeAxes (dic.GUI.sca(11),...
            'Parity Phase [rad]','Populations %','Entangling Gate',...
            [ParityPhase(1) ParityPhase(end)],[-1 1],2);
        set(darkCountLine(1),'Marker','.','MarkerSize',10,'Color','k');
        set(darkCountLine(2),'Color','r');
         %----- Main loop -----------
        dark=zeros(length(ParityPhase),1);
        p0=zeros(length(ParityPhase),1);
        p1=zeros(length(ParityPhase),1);
        p2=zeros(length(ParityPhase),1);
        parity=zeros(length(ParityPhase),1);
        CrystalCheckPMT;
        dic.setNovatech('Red','freq',dic.SinglePass674freq ...
            +(dic.vibMode(SBmode).freq-dic.GateInfo.GateDetuningkHz/1000),'amp',dic.GateInfo.RedAmp);
        dic.setNovatech('Blue','freq',dic.SinglePass674freq ...
            -(dic.vibMode(SBmode).freq-dic.GateInfo.GateDetuningkHz/1000),'amp',dic.GateInfo.BlueAmp);
        feedback=0;
        for index2 = 1:length(ParityPhase)
%             dic.setNovatech('Red','phase',mod(ParityPhase(index2),2*pi));
            if dic.stop
                return
            end
            dic.setNovatech('DoublePass','freq',dic.updateF674+feedback,'amp',1000);
            [r,fb]=experimentSequence([dic.GateInfo.GateTime_mus ParityPhase(index2)],SBmode);
            dic.GUI.sca(1); %get an axis from Dictator GUI to show data
            hist(r,0:1:(1.8*dic.maxPhotonsNumPerReadout));
            if DoFeedback
                AddLinePoint(feedbackLine,ParityPhase(index2),fb);
                feedback=feedback-(fb-50)*5e-7;
            end
            p0(index2)=sum(r<dic.IonThresholds(1))/length(r)*100;
            p2(index2)=sum(r>dic.IonThresholds(2))/length(r)*100;
            p1(index2)=100-p0(index2)-p2(index2);
            
            parity(index2)=(p0(index2)+p2(index2)-p1(index2))/100;
            
            dic.GUI.sca(9);
            AddLinePoint(darkCountLine(1),ParityPhase(index2),parity(index2));
            pause(0.1);
        end
        s = fitoptions('Method','NonlinearLeastSquares','Startpoint',[1.1 0 0]);         
        f = fittype('a*sin(2*x-b)+c','options',s);
        [curve,gof2] = fit(ParityPhase',parity,f);
        ParityContrast=abs(curve.a);
        %     disp(sprintf('Parity Contrast = %.3f  Phase Shift = %1.2f  Offset = %.2f',c2.a,c2.b,c2.c));
        disp(sprintf('Parity Contrast = %.3f  Phase Shift = %1.2f',ParityContrast,curve.b));
        disp(sprintf('Parity Contrast min max= %.3f  ',0.5*(max(parity)-min(parity))));
        set(darkCountLine(2),'XData',ParityPhase,'YData',curve(ParityPhase));
        
        showData='figure;plot(ParityPhase,parity);xlabel(''ParityPhase[rad]'');ylabel(''Populations'');';

    case 'scanLightShift'         
        %----- Set GUI figures -----------
        InitializeAxes (dic.GUI.sca(1),'Photons #','Cases Counted #','Fluorescence Histogram',...
            [0 dic.maxPhotonsNumPerReadout],[],0);
        
        darkCountLine =InitializeAxes (dic.GUI.sca(9),...
            'Gate OffesetkHz]','Populations %','Entangling Gate',...
            [LightShiftOffset(1) LightShiftOffset(end)],[0 100],1);
        set(darkCountLine,'Marker','.','MarkerSize',10,'Color','b');
       
         %----- Main loop -----------
        dark=zeros(length(LightShiftOffset),1);

        CrystalCheckPMT;
        dic.setNovatech('Red','freq',dic.SinglePass674freq ...
            +dic.vibMode(SBmode).freq,'amp',dic.GateInfo.RedAmp);
        dic.setNovatech('Blue','freq',dic.SinglePass674freq...
            -dic.vibMode(SBmode).freq,'amp',dic.GateInfo.BlueAmp);

        for index2 = 1:length(LightShiftOffset)

            if dic.stop
                return
            end
            dic.setNovatech('DoublePass','freq',dic.updateF674-LightShiftOffset(index2)/2000,'amp',120);
            [r,fb]=experimentSequence(dic.vibMode(SBmode).coldPiTime*15,SBmode);
            dic.GUI.sca(1); %get an axis from Dictator GUI to show data
            hist(r,0:1:(1.8*dic.maxPhotonsNumPerReadout));
            
            tmpdark=0;
            for tmp=1:dic.NumOfIons
                tmpdark=tmpdark+sum((r>dic.IonThresholds(tmp))&(r<dic.IonThresholds(tmp+1)))*tmp;
            end
            dark(index2)=100-tmpdark/length(r)/(dic.NumOfIons)*100;
            
            dic.GUI.sca(panelc);
            AddLinePoint(darkCountLine,LightShiftOffset(index2),dark(index2));
            pause(0.1);
        end
        dic.setNovatech('DoublePass','freq',dic.updateF674,'amp',1000);
        showData='figure;plot(LightShiftOffset,dark);xlabel(''LightShift Offset[kHz]'');ylabel(''Dark %'');';
end
dic.save;
%--------------------------------------------------------------------
    function [r,tmpdark]=experimentSequence(parameters,mode)
        pulsetime=parameters(1);
        if length(parameters)>1
    	   RfPhase=parameters(2);    
        end
        prog=CodeGenerator;
        prog.GenDDSPullParametersFromBase;
%       prog.GenWaitExtTrigger;
        
        prog.GenSeq(Pulse('ExperimentTrigger',0,50));

        prog.GenSeq(Pulse('674DDS1Switch',0,-1,'amp',100));
        prog.GenSeq(Pulse('RFDDS2Switch',2,-1,'freq',dic.FRF,'amp',dic.ampRF));
        
        % Doppler coolng
        prog.GenSeq(Pulse('OffRes422',0,1));%turn off cooling
        prog.GenSeq(Pulse('OnResCooling',0,dic.Tcooling));
        
       %activate noise eater, move it to int hold and repump
        prog.GenSeq([Pulse('674DDS1Switch',1,15),... 
                     Pulse('NoiseEater674',2,10),Pulse('674DoublePass',0,16),...
                     Pulse('Repump1033',16,dic.T1033)]);
%       prog.GenSeq(Pulse('Shutters',0,0)); %shut down all lasers (takes <=3ms)
        
        %%%%%%%%%%%%% SIDEBAND COOLING %%%%%%%%%%%%%%%%
        prog.GenSeq([Pulse('Repump1033',0,0), Pulse('OpticalPumping',0,0)]);
        % cooling the Stretch
        prog.GenSeq([Pulse('674DoublePass',0,dic.vibMode(mode).coolingTime+4),... 
                     Pulse('674Echo',2,dic.vibMode(mode).coolingTime)]);
        % cooling the COM
%         prog.GenSeq([Pulse('674DoublePass',0,dic.vibMode(1).coolingTime+4),... 
%                      Pulse('674Parity',2,dic.vibMode(1).coolingTime)]);
         prog.GenSeq([Pulse('Repump1033',dic.T1033,-1), Pulse('OpticalPumping',dic.T1033,-1)]);
                
        %%%%%%%%%% END OF GROUND STATE COOLING %%%%%%%%%%
        prog.GenSeq(Pulse('674DDS1Switch',0,-1,'freq',dic.SinglePass674freq));        
        prog.GenSeq(Pulse('OpticalPumping',0,dic.Toptpump));   
                
        % Gate Pulse
        prog.GenSeq(Pulse('674PulseShaper',0,-1));
        prog.GenPause(10);
        prog.GenSeq([Pulse('674Gate',1,pulsetime),...
                     Pulse('674DoublePass',0,pulsetime+2),...
                     Pulse('674PulseShaper',2,pulsetime-10)]);  
        prog.GenSeq(Pulse('674PulseShaper',0,0));
        prog.GenPause(10);
        
        if DoZeemanMapping
            prog.GenSeq(Pulse('RFDDS2Switch',2,dic.TimeRF,'phase',0));
            prog.GenSeq([Pulse('674DoublePass',0,dic.T674+3),...
                         Pulse('674DDS1Switch',2,dic.T674,'phase',0)]);
            if DoParityPulse
                 prog.GenSeq(Pulse('RFDDS2Switch',2,dic.TimeRF/2,'phase',RfPhase));              
            end
            prog.GenSeq([Pulse('674DoublePass',0,dic.T674+3),...
                         Pulse('674DDS1Switch',2,dic.T674)]);
        elseif DoParityPulse
               prog.GenSeq([Pulse('674DoublePass',0,ParityTime+2),...
                            Pulse('674DDS1Switch',1,ParityTime,'phase',0)]);
        end
        
        % detection
        prog.GenSeq([Pulse('OnRes422',0,dic.TDetection) Pulse('PhotonCount',0,dic.TDetection)]);
        % resume cooling
        prog.GenSeq(Pulse('Repump1033',0,dic.T1033));
        
        % ------another sequence for fast 674 freq  feedback------ 
        if DoFeedback
            prog.GenSeq(Pulse('OnResCooling',0,dic.Tcooling));
            prog.GenSeq(Pulse('OpticalPumping',0,dic.Toptpump));
            prog.GenSeq([Pulse('674DoublePass',0,dic.T674/2+2),...
                         Pulse('674DDS1Switch',1,dic.T674/2,'phase',0)]);
            prog.GenPause(800);
            prog.GenSeq([Pulse('674DoublePass',0,dic.T674/2+2),...
                         Pulse('674DDS1Switch',1,dic.T674/2,'phase',pi/2)]);         
            prog.GenSeq([Pulse('OnRes422',0,dic.TDetection),...
                         Pulse('PhotonCount',0,dic.TDetection)]);
        end
        prog.GenSeq(Pulse('Repump1033',0,dic.T1033));     
        prog.GenSeq(Pulse('OffRes422',0,0));    
        prog.GenFinish;
        
        dic.com.UploadCode(prog);
        dic.com.UpdateFpga;
        dic.com.WaitForHostIdle; % wait until host finished it last task
        dic.com.Execute(repetitions);
        dic.com.WaitForHostIdle;
        r = dic.com.ReadOut(repetitions*(1+DoFeedback));
        if DoFeedback
            y=r(2:2:end);
            r = r(3:2:end);
            tmpdark=0;
            for tmp=1:dic.NumOfIons
                tmpdark=tmpdark+sum((y>dic.IonThresholds(tmp))&(y<dic.IonThresholds(tmp+1)))*tmp;
            end
            tmpdark=100-tmpdark/length(y)/(dic.NumOfIons)*100;
        else
            r = r(2:end);
            tmpdark=0;
        end
    end

end