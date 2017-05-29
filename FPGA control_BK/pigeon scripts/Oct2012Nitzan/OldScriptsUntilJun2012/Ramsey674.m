function Ramsey674(varargin)
dic=Dictator.me;
% no B feedback 
doEcho=0; % default is Ramsey
armTime=linspace(10,1000,10);
%armTime = [874 2000:49.75:3000];
phaseList=linspace(0,2*pi,20);
%--------options------------- 
for i=1:2:size(varargin,2)
   switch lower(char(varargin(i)))
       case 'armtime'
           armTime=varargin{i+1};
       case 'phase'
           phaseList=varargin{i+1};
       case 'type'
           doEcho=varargin{i+1};           
   end; %switch
end;%for loop
%-------------- Set GUI figures ---------------------
InitializeAxes (dic.GUI.sca(1),'Photons #','Cases Counted #','Fluorescence Histogram',...
                [0 dic.maxPhotonsNumPerReadout],[],0);
visLines =InitializeAxes (dic.GUI.sca(9),'T_{arm}[\mus]','Dark Counts %','Ramsey Visibility',...
                       [armTime(1) armTime(end)],[0 100],2);
set(visLines(1),'XData',[],'YData',[],'Marker','.','MarkerSize',10);
set(visLines(2),'Color',[0 0 0],'XData',[],'YData',[]);

phaseLines =InitializeAxes (dic.GUI.sca(10),'Second \pi/2 phase [rad]','Dark Counts %','Phase scan',...
                       [phaseList(1) phaseList(end)],[0 100],2);
set(phaseLines(1),'XData',[],'YData',[],'Marker','.','MarkerSize',10);
set(phaseLines(2),'Color',[0 0 0],'XData',[],'YData',[]);

%-------------- Main function scan loops ---------------------
dark = zeros(length(armTime),length(phaseList));
visibility=zeros(length(armTime),1);
for timeInd=1:length(armTime)
    set(phaseLines(1),'XData',[],'YData',[]);

    for phaseInd = 1:length(phaseList)
        if dic.stop
            return
        end
        r=experimentSequence(armTime(timeInd),phaseList(phaseInd));
        dic.GUI.sca(1); 
        hist(r,1:2:dic.maxPhotonsNumPerReadout);
        if dic.TwoIonFlag
            dark(timeInd,phaseInd) =100-sum( (r>dic.TwoIonsCountThreshold)*2+...
                                 ((r>dic.darkCountThreshold)&(r<dic.TwoIonsCountThreshold))*1 ...
                                )/2/length(r)*100;
        else
            dark(timeInd,phaseInd) = sum( r<dic.darkCountThreshold)/length(r)*100;
        end        
        AddLinePoint(phaseLines(1),phaseList(phaseInd),dark(timeInd,phaseInd));
    end
    %---------- fitting and updating ---------------------
    ft=fittype('50+a*cos(x-b)');
    PhiCenter=phaseList(find(dark(timeInd,:)==max(dark(timeInd,:),[],2),1));
    disp(PhiCenter);
    fo=fitoptions('Method','NonlinearLeastSquares',...
       'Startpoint',[50,PhiCenter],'Lower',[0 0],'Upper',[100 2*pi]);
    [curve,goodness]=fit(phaseList',dark(timeInd,:)',ft,fo);
    set(phaseLines(2),'Color',[0 0 0],'XData',phaseList,'YData',feval(curve,phaseList));
    visibility(timeInd)=curve.a*2;
    AddLinePoint(visLines(1),armTime(timeInd),visibility(timeInd))
    pause(0.5);
end

%------------ Save data ------------------
if (dic.AutoSaveFlag)
    destDir=dic.saveDir;
    thisFile=[mfilename('fullpath') '.m' ];
    [filePath fileName]=fileparts(thisFile);
    scriptText=fileread(thisFile);
    showData=['figure;plot(armTime,visibility);',...
              'xlabel(''\tau_{arm}[Mhz]'');ylabel(''dark[%]'');',...
              'figure;pcolor(phaseList,armTime,dark);shading flat;',...
              'ylabel(''\tau_{arm}[Mhz]'');xlabel(''Phase'')'];
    saveFileName=fullfile(destDir ,[fileName datestr(now,'-ddmmmyy-HHMMSS')]);
    dicParameters=dic.getParameters;
    save(saveFileName,'phaseList','armTime','visibility','dark','doEcho','showData','dicParameters','scriptText');
    disp(['Save data in : ' saveFileName]);
end 

%%------------------------ experiment sequence -----------------
    function r=experimentSequence(armTime,piPhase)
        prog=CodeGenerator;
        prog.GenDDSPullParametersFromBase;
        %prog.GenWaitExtTrigger;
        prog.GenSeq(Pulse('ExperimentTrigger',0,50));

        % set DDS freq and amp
        prog.GenSeq( Pulse('674DDS1Switch',0,-1,'freq',dic.updateF674,'amp',100) );
        prog.GenSeq(Pulse('ExperimentTrigger',0,50));
        % Doppler coolng
        prog.GenSeq(Pulse('OffRes422',0,1));%turn off cooling
        prog.GenSeq(Pulse('OnResCooling',0,dic.Tcooling));
        prog.GenSeq(Pulse('OpticalPumping',0,dic.Toptpump));    
        %Ramsey Sequence

        prog.GenSeq([Pulse('NoiseEater674',2,dic.T674/2),...
                     Pulse('674DDS1Switch',2,dic.T674/2,'phase',0)]); %second pi/2 Pulse
        if doEcho
            prog.GenSeq([Pulse('NoiseEater674',armTime,dic.T674),...
                         Pulse('674DDS1Switch',armTime,dic.T674)]);% echo Pulse
        end
        prog.GenSeq([Pulse('NoiseEater674',armTime,dic.T674/2),...
                     Pulse('674DDS1Switch',armTime,dic.T674/2,'phase',piPhase)]); %second pi/2 Pulse

        % detection
%         prog.GenSeq(Pulse('674DDS1Switch',1,dic.T674));
        prog.GenSeq([Pulse('OnRes422',0,dic.TDetection) Pulse('PhotonCount',0,dic.TDetection)]);
        %resume cooling
        prog.GenSeq(Pulse('Repump1033',0,dic.T1033));
        prog.GenSeq(Pulse('OffRes422',0,0));
        prog.GenFinish;
%         prog.DisplayCode;
        dic.com.UploadCode(prog);
        dic.com.UpdateFpga;
        dic.com.WaitForHostIdle; % wait until host finished it last task
        rep=200;
        dic.com.Execute(rep);
        dic.com.WaitForHostIdle;
        r = dic.com.ReadOut(rep);
        r = r(2:end);
    end 
end

