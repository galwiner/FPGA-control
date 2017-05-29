function freqcenter=FreqScanRFStab
dic=Dictator.me;
% freqSpan=-0.005:0.0003:0.005;

freqSpan=-0.015:0.0003:0.015;

% freqSpan=-3:0.02:3;
freqList=freqSpan+dic.FRF;
%freqList=linspace(5,6,20);
Freq674SinglePass=77;

%-------------- Set GUI figures ---------------------
InitializeAxes (dic.GUI.sca(1),'Photons #','Cases Counted #','Fluorescence Histogram',...
                [0 dic.maxPhotonsNumPerReadout],[],0);
lines =InitializeAxes (dic.GUI.sca(9),'F_{RF} [MHz]','Dark Counts %','Zeeman line',...
                       [freqList(1) freqList(end)],[0 100],2);
set(lines(1),'XData',[],'YData',[],'Marker','.','MarkerSize',10);
set(lines(2),'Color',[0 0 0],'XData',[],'YData',[]);

%-------------- Main function scan loops ---------------------
dic.setNovatech4Amp(1,0);dic.setNovatech4Amp(2,0);ChannelSwitch('DIO7','on');
dic.setNovatech4Amp(0,1000);      

ChannelSwitch('DIO7','on');
ChannelSwitch('NovaTechPort2','on');

dark = zeros(size(freqList));
if dic.SitOnItFlag
    cont=1;
    while (cont)
        if (dic.stop)
            cont=0;
        end
        r=experimentSequence(dic.FRF);
        dic.GUI.sca(1); %get an axis from Dictator GUI to show data
        hist(r,1:1:dic.maxPhotonsNumPerReadout);
        xlabel(num2str(sum( r<dic.darkCountThreshold)/length(r)*100,2),...
            'FontSize',100);
    end
else
    for index1 = 1:length(freqList)
        if dic.stop
            return
        end
        dic.setNovatech4Freq(0,dic.F674);        
        r=experimentSequence(freqList(index1));
        dic.GUI.sca(1); 
        hist(r,1:2:dic.maxPhotonsNumPerReadout);
        if dic.TwoIonFlag
            dark(index1) =100-sum( (r>dic.TwoIonsCountThreshold)*2+...
                                 ((r>dic.darkCountThreshold)&(r<dic.TwoIonsCountThreshold))*1 ...
                                )/2/length(r)*100;
        else
            dark(index1) = sum( r<dic.darkCountThreshold)/length(r)*100;
        end
        pause(1);
        AddLinePoint(lines(1),freqList(index1),dark(index1))
    end
    %---------- fitting and updating ---------------------

    ft=fittype('d-a*sinc((x-b)*c).^2');
    fo=fitoptions('Method','NonlinearLeastSquares',...
           'Startpoint',[100,dic.FRF,500,90],'Lower',[10 freqSpan(1)+dic.FRF 10 80],'Upper',[100 freqSpan(end)+dic.FRF 2000 100]);
    [curve,goodness]=fit(freqList',dark',ft,fo);
    dic.FRF=curve.b;
    set(lines(2),'Color',[0 0 0],'XData',freqList,'YData',feval(curve,freqList));
%     disp(sprintf('RF resonance freq is set to %2.3f MHz',curve.b));
    freqcenter=dic.FRF;
    
    %------------ Save data ------------------
%     if (dic.AutoSaveFlag)
%         destDir=dic.saveDir;
%         thisFile=[mfilename('fullpath') '.m' ];
%         [filePath fileName]=fileparts(thisFile);
%         scriptText=fileread(thisFile);
%         scriptText(find(int8(scriptText)==10))='';
%         showData='figure;plot(freqList,dark);xlabel(''F_{RF} [Mhz]'');ylabel(''dCrark[%]'');';
%         saveFileName=fullfile(destDir ,[fileName datestr(now,'-ddmmmyy-HHMMSS')]);
%         dicParameters=dic.getParameters;
%         save(saveFileName,'freqList','dark','showData','dicParameters','scriptText');
% %         disp(['Save data in : ' saveFileName]);
%     end 
end
%---------------------------------------------------------------------
function r=experimentSequence(freq)
    prog=CodeGenerator; 
    prog.GenDDSPullParametersFromBase;
    prog.GenSeq(Pulse('ExperimentTrigger',0,50));
    prog.GenSeq(Pulse('674DDS1Switch',2,-1,'freq',Freq674SinglePass,'amp',100) );
    prog.GenSeq(Pulse('RFDDS2Switch',2,-1,'freq',freq,'amp',2));
    prog.GenSeq(Pulse('OffRes422',0,100));
    prog.GenSeq(Pulse('OnResCooling',0,200));
    
%     prog.GenRepeatSeq([Pulse('OpticalPumping',0,7),...
%                        Pulse('674PulseShaper',10,dic.TimeRF-2),...
%                        Pulse('RFDDS2Switch',11,dic.TimeRF)],50);
    
    prog.GenSeq(Pulse('OpticalPumping',0,dic.Toptpump));
    %Do pi pulse RF
    
%     prog.GenSeq([Pulse('674PulseShaper',1,dic.TimeRF-1),...
%                      Pulse('RFDDS2Switch',2,dic.TimeRF)]);
     prog.GenSeq([Pulse('RFDDS2Switch',0,dic.TimeRF*30)]);

    prog.GenSeq([Pulse('674DDS1Switch',0,dic.T674)]);

             %second shelving Pulse 
%     prog.GenSeq(Pulse('674DDS1Switch',5,10,'freq',dic.FRF*1.2046));
    
    prog.GenSeq([Pulse('OnRes422',0,dic.TDetection)...
                 Pulse('PhotonCount',0,dic.TDetection)]);
    %resume cooling
    prog.GenSeq(Pulse('Repump1033',0,dic.T1033));
    prog.GenSeq(Pulse('OffRes422',0,0));

    prog.GenFinish;
    %prog.DisplayCode;


    % FPGA/Host control
    n=dic.com.UploadCode(prog);
    dic.com.UpdateFpga;
    dic.com.WaitForHostIdle;

    rep=1000;
    dic.com.Execute(rep);
    dic.com.WaitForHostIdle;
    r=dic.com.ReadOut(rep);
    r=r(2:end);
end
end

