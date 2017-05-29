function ScanMicroUsingRabi
    % both cap=50V and horizontal beam (dic.curBeam=1)
    %measuring carrier efficiency
    % set save file name
    dic=Dictator.me;
    destDir=dic.saveDir;
    thisFile=[mfilename('fullpath') '.m' ];
    [filePath fileName]=fileparts(thisFile);
    saveFileName=fullfile(destDir ,[fileName datestr(now,'-ddmmmyy-HHMMSS')]);
    scriptText=fileread(thisFile);
    scriptText(find(int8(scriptText)==10))='';
    showData='figure;imagesc(Vdcl,Vcomp,1./rabi/2);xlabel(''Vdcl(V)'');ylabel(''Vcomp(V)''); colorbar; title(''micromotion using rabi(kHz)'')';
    dicParameters=dic.getParameters;

    %set scan range
    Vdcl=[-2.3:0.1:-2.2];
    Vcomp=[-8:0.5:-2];
    rabi=nan(length(Vcomp),length(Vdcl));
    if dic.curBeam==0
        alpha=1;
    else
        alpha=dic.T674/8;
    end
    oldrabi=dic.T674; %100*alpha;
    tic;
    %scan
    oldTimer=dic.timerOnOffFlag; %save timer value
    dic.timerOnOffFlag=0; %then turn it off
    for ind1=1:length(Vcomp)
        for ind2=1:length(Vdcl)
            if (toc>=180)
                tic;
                f=dic.updateF674;
            end
            dic.com.UpdateTrapElectrode(0,0,0,Vdcl(ind2),Vcomp(ind1)); pause(1);
%             n=3;
%             if (oldrabi>600*alpha)
%                 oldrabi=800*alpha;
%                 %dic.handleTimer;
%                 n=0.5;
%             elseif (oldrabi<50*alpha)
%                 oldrabi=50*alpha;
%             end
n=3;
            rabi(ind1,ind2)=MicromotionCarrierRabiScan674(linspace(1,oldrabi*n,20)); %find Rabi freq
            oldrabi=rabi(ind1,ind2);
            dic.GUI.sca(11);
            pcolor(Vdcl,Vcomp,rabi);
            imagesc(Vdcl,Vcomp,1./rabi/2*1000);shading flat;
            xlabel('Vdcl(V)');ylabel('Vcomp(V)'); title('2d micrmotion scan using rabi(kHz)');
            colorbar;
            pause(0.2);
            savethis;
        end
    end
    dic.timerOnOffFlag=oldTimer; %restore timer value
    savethis;
    %--------------- Save data ------------------
    function savethis
        if (dic.AutoSaveFlag)   
            save(saveFileName,'Vdcl','Vcomp','rabi','showData','dicParameters','scriptText');
            disp(['Save data in : ' saveFileName]);
        end 
    end
end