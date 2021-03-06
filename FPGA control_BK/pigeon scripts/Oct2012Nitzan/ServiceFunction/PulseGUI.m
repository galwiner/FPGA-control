classdef PulseGUI  < handle
    
    properties(Constant=true)
        BtnWidth=0.035;
        BtnWidthTotal=0.04;
        BtnHeight=0.02;
        BtnHeightTotal=0.022;
        
        %define dimensions container of dictator variables 
        varListWidth=0.8; %dictator variable list UI container width
        varListHeight=0.2;
        varWidth=1/5;
        varHeight=1/6;
        varRowNum=6; %total number of rows in UI container
        name2valRat=0.5; %text describing variable will 
            % get the length of a obj.varWidth*name2valRat;

        
        %define dimensions of description box
        descWidth=0.2;
        %define dimenstions of user defined box
        userWidth=0.15;
        %general dimensions for graphs and graph buttons
        FirstBtnRow=0.725;
        graphWidth=0.18;
        graphHeight=0.18;
        graphMargin=0.08;
        graphTotalWidth=0.25; %=graphWidth+graphMargin
        graphTotalHeight=0.26;
        leftMargin=0.05;
        lowerMargin=0.005;
    end

    properties
        dic=[];
        fig=[]; 
        %axes and annotations
        totalAxNum=0;
        AxList=[];
        AnnList=[];
        %buttons 
        varPanel=[]; %UI element containing all dictator variables
        varList=[]; %list of dictator variables, 
        BtnList=[]; %graph clear and add buttons
        descPanel=[]; %description text panel
        userPanel=[]; %extra user panel
        hiddenList=[]; %list of buttons to hide
%         saveBtn=[];
%         stopBtn=[];
%         descText=[];
    end
     
    methods
     
        function rowY=graphRow(obj,num)
            % num=1,2,3
            rowY=1-(num-1)*obj.graphTotalHeight-obj.graphHeight-obj.graphMargin/2;
        end  
        function colX=graphCol(obj,num)
            %num=1,2,3,4
            colX=obj.leftMargin+(num-1)*obj.graphTotalWidth;
        end
        function ax=openAxes(obj,name,ipos,add)
            pos=ipos;
            if (length(pos)<4)
                pos(3)=1;
                pos(4)=1;
            end;
            figChildren=get(obj.fig,'Children');
            for loop=1:length(figChildren)
                if strfind(get(figChildren(loop),'Type'),'axes')
                    if strfind(get(figChildren(loop),'Tag'),name)
                        ax=figChildren(loop);
                        axes(ax);
                        return;
                    end
                end
            end
            ax=axes;
            set(ax,'Tag',name);
            addflag=0;
            if (nargin==4)
                set(ax,'NextPlot',add)
                if (strcmp(add,'add'))
                    addflag=1;
                end
            else
                set(ax,'NextPlot','replacechildren');
            end
            title(name);
            set(ax,'Position',[obj.graphCol(pos(1)) obj.graphRow(pos(2)) (obj.graphWidth+(pos(3)-1)*obj.graphTotalWidth) (obj.graphWidth+(pos(4)-1)*obj.graphTotalHeight)]);
            obj.totalAxNum=obj.totalAxNum+1;
            obj.AxList{obj.totalAxNum}=ax;
            h_t = annotation('textbox','Position',[(obj.graphCol(pos(1))-obj.BtnWidthTotal) (obj.graphRow(pos(2))-obj.BtnHeightTotal) obj.BtnWidthTotal/2 obj.BtnHeightTotal],'FontSize',10,...%'FontWeight','bold',...
                'String',num2str(obj.totalAxNum),'BackgroundColor',[.7 .9 .7],...
                 'VerticalAlignment','Cap',...
                 'HorizontalAlignment','left');
            obj.AnnList{obj.totalAxNum}=h_t;
            %create clear button
            h_b=uicontrol('Style', 'pushbutton','UserData',obj.totalAxNum, ...
                'String', 'CLR','Units','Normalized',...
                'Position', [(obj.graphCol(pos(1))-obj.BtnWidthTotal) (obj.graphRow(pos(2))-2*obj.BtnHeightTotal) obj.BtnWidthTotal/2 obj.BtnHeight], 'Callback', @(h,e)cla(obj,h,e));
            obj.BtnList{obj.totalAxNum}=h_b;
            %create add/replace button
            h_b=uicontrol('Style','checkbox','UserData',obj.totalAxNum, ...
                'String','add','Units','Normalized','Value',addflag,...
                'Position', [(obj.graphCol(pos(1))-obj.BtnWidthTotal/2) (obj.graphRow(pos(2))-2*obj.BtnHeightTotal) obj.BtnWidthTotal obj.BtnHeight], 'Callback', @(h,e)addOrReplaceCallback(obj,h,e));
        end
        function ax=sca(obj,num)
            % set current axes
            ax=double(obj.AxList{num});
            axes(ax);
        end
        function addOrReplaceCallback(obj,h,e)
            %get relevant axes&value
            ax=double(obj.AxList{int16(get(h,'UserData'))});
            fl=get(h,'Value');
            %set axes propety accordingly
            if (fl)
                set(ax,'NextPlot','add')
            else
                set(ax,'NextPlot','replacechildren');
            end
        end
        function cla(obj,h,e)
            % clear axes
            a=double(obj.AxList{int16(get(h,'UserData'))});
            %preserve XLim,YLim
            xl=get(a,'XLim');
            yl=get(a,'YLim');
            %clear
            cla(a);
            %restore xlim,ylim
            set(a,'XLim',xl);
            set(a,'YLim',yl);            
        end
        function newObj=PulseGUI(dic,hl)
            newObj.dic=dic;
            newObj.fig=openFigure('Pulse GUI');
            set(newObj.fig,'Position',[1286 5 1272 975]);
            if (exist('hl'))
                newObj.hiddenList=hl;
            else
                newObj.hiddenList={'ionAxialFreq','acStarkShift674','RFPhase','SecondRFPhase','DDSGuageData'};
            end
            newObj.drawGUI;
        end
        function rowY=varRow(obj,num)
            % num=1,2,3...
            rowY=1-(num)*obj.varHeight;
        end
        function colX=varCol(obj,num)
            %num=1,2,3,...
            colX=(num-1)*obj.varWidth;
        end
        function updateVarCallback(obj,h,e)
            %call dictator and tell him to update the value 
            %according to pulse variable box UI button
            varName=get(h,'UserData');
            if (strcmp(get(h,'Style'),'checkbox'))
                %variable type is a flag
                varVal=get(h,'Value');
            elseif (strcmp(get(h,'Style'),'pushbutton'))
                %variable type is a pushbutton
                varVal=1;
            else
                tmpvarVal=get(h,'String');
                [m n]=size(tmpvarVal); 
                if (m>1)
                    str=[];
                    %if varVal contains more than one line, concatenate them
                    for t=1:m
                        str=[str tmpvarVal(t,:) ];
                    end
                    varVal=str;
                else
                    if isempty(strfind(varName,'Desc'))
                        %not a string variable
                        varVal=str2num(tmpvarVal);
                    else
                        varVal=tmpvarVal;
                    end
                end
            end
            obj.dic.set(varName,varVal);
        end
        function updateVars(obj)
            %update values of var buttons according to values of dictator
            [names,vars]=obj.dic.publishVars; %get vars from dictator
            obj.varList.names=names;
            obj.varList.vars=vars;
            for l=0:length(names)-1
                if (~isempty(strmatch(names{l+1},obj.hiddenList))) %if this button should be hidden
                    continue; %go to the next iteration of loop.
                end
                if (~isempty(strfind(obj.varList.names{l+1},'Flag')))
                    %variable type is a flag
                    set(obj.varList.btn(l+1),'Value',vars{l+1});
                elseif (~isempty(strfind(obj.varList.names{l+1},'Intr')))
                    %variable type is a button
                elseif (~isempty(strfind(obj.varList.names{l+1},'Desc')))
                    %variable type is the main description
                    a=vars{l+1};
                    v=regexprep(a,'\\n',''','''); 
                    eval(['tmpvar=char(''' v ''');']); 
                    set(obj.varList.btn(l+1),'String',tmpvar);
                else
                    %variable type is entered text
                    set(obj.varList.btn(l+1),'String',num2str(vars{l+1}));
                end
            end
        end
        function drawGUI(obj)
            %create all panels
            obj.varPanel=uipanel('Parent',obj.fig,'Title','Dictator Variables','Position',[0,0,obj.varListWidth,obj.varListHeight]);
            obj.descPanel=uipanel('Parent',obj.fig,'Title','Description','Position',[obj.varListWidth,0,obj.descWidth,obj.varListHeight]);
            %obj.userPanel=uipanel('Parent',obj.fig,'Title','User Defined','Position',[obj.varListWidth+obj.descWidth,0,obj.userWidth,obj.varListHeight]);
            
            %create all axes
            obj.openAxes('hist',[1,1]); ylabel('Counts');
            obj.openAxes('detection',[2,1],'add'); xlabel('F_{422} (\mu s)'); ylabel('photon count');
            obj.openAxes('674 Resonance',[3,1]); xlabel('F_{674} (MHz)'); ylabel('dark counts %');
            obj.openAxes('674 pi time',[4,1]); xlabel('T_{674} (\mu s)'); ylabel('dark counts %');
            obj.openAxes('RF Resonance',[3,2]); xlabel('F_{RF} (MHz)'); ylabel('dark counts %');
            obj.openAxes('RF pi time',[4,2]); xlabel('T_{RF} (\mus)'); ylabel('dark counts %');
            obj.openAxes('Find DA Phase',[4,3]);xlabel('Second pi/2 pulse Phase[deg]'); ylabel('dark counts %');
            obj.openAxes('Generic',[3,3]); xlabel('TBD'); ylabel('TBD');
            obj.openAxes('Ramsey Scan',[1 2 2 1]);xlabel('T_{Ramsey} (\mu s)'); ylabel('dark counts %'); 
            obj.openAxes('Echo Scan',[1,3]);xlabel('\phi (deg)'); ylabel('dark counts %'); axis([0 360 0 100]);
            obj.openAxes('2D Scan',[2,3]);xlabel('\phi (deg)'); ylabel('\tau_{delay} (\mus)'); axis([0 360 0 100]);
            
            %create control&variable panel
            [names,vars]=obj.dic.publishVars; %get vars from dictator
            obj.varList.names=names;
            obj.varList.vars=vars;
            ll=0;
            howManyDescSoFar=0;
            for l=0:length(names)-1
                if (~isempty(strmatch(names{l+1},obj.hiddenList))) %if this button should be hidden
                    continue; %go to the next iteration of loop.
                end
                r=mod(ll,obj.varRowNum)+1;
                c=floor(ll/obj.varRowNum)+1;
                if (~isempty(strfind(obj.varList.names{l+1},'Flag')))
                    %variable type is a flag
                    obj.varList.btnTxt(l+1)=uicontrol('Style', 'text', 'Parent',obj.varPanel,...
                     'String', obj.varList.names{l+1},'Units','Normalized',...
                     'HorizontalAlignment','left',...%'VerticalAlignment','center',...
                     'Position', [obj.varCol(c) obj.varRow(r) obj.varWidth*obj.name2valRat obj.varHeight]);
                    obj.varList.btn(l+1)=uicontrol('Style', 'checkbox', 'UserData',obj.varList.names{l+1},...
                        'Parent',obj.varPanel,'HorizontalAlignment','right',...
                    'Value', obj.varList.vars{l+1},'Units','Normalized',...
                     'Position',[(obj.varCol(c)+obj.varWidth*(obj.name2valRat+1)*0.45) obj.varRow(r) obj.varWidth*(1-obj.name2valRat) obj.varHeight], ...
                     'Callback', @(h,e)updateVarCallback(obj,h,e));
                elseif (~isempty(strfind(obj.varList.names{l+1},'Intr')))
                    %variable type is push button
                    obj.varList.btn(l+1)=uicontrol('Style', 'pushbutton', 'UserData',obj.varList.names{l+1},...
                        'Parent',obj.varPanel,'HorizontalAlignment','right',...
                    'String', obj.varList.names{l+1},'Units','Normalized',...
                    'FontSize',10,...
                     'Position',[(obj.varCol(c)+obj.varWidth*0.05) obj.varRow(r) obj.varWidth*0.9 obj.varHeight], ...
                     'Callback', @(h,e)updateVarCallback(obj,h,e));
                elseif (~isempty(strfind(obj.varList.names{l+1},'Desc'))&&(howManyDescSoFar<2))
                    % deal with description variables, the first two are
                    % assigned a special place (directory to save and
                    % experiment description) 
                        ll=ll-1;   
                        a=obj.varList.vars{l+1};
                        v=regexprep(a,'\\n',''','''); 
                        eval(['tmpvar=char(''' v ''');']); 
                        tmph=(1-howManyDescSoFar)*0.8+howManyDescSoFar*0.2;
                        tmpm=(1-howManyDescSoFar)*15+howManyDescSoFar*1;
                        obj.varList.btn(l+1)=uicontrol('Style', 'edit', 'UserData',obj.varList.names{l+1},...
                         'String', tmpvar,'Units','Normalized',...
                         'Parent',obj.descPanel,'HorizontalAlignment','left',...
                         'Position',[0 howManyDescSoFar*0.8 1 tmph],'Max',tmpm,...
                         'Callback', @(h,e)updateVarCallback(obj,h,e));
                        howManyDescSoFar=howManyDescSoFar+1;
                else %variable type is edit data
                        obj.varList.btnTxt(l+1)=uicontrol('Style', 'text', 'Parent',obj.varPanel,...
                         'String', obj.varList.names{l+1},'Units','Normalized',...
                         'HorizontalAlignment','left',...%'VerticalAlignment','center',...
                         'Position', [obj.varCol(c) obj.varRow(r) obj.varWidth*obj.name2valRat obj.varHeight]);
                        obj.varList.btn(l+1)=uicontrol('Style', 'edit', 'UserData',obj.varList.names{l+1},...
                            'Parent',obj.varPanel,...
                        'String', num2str(obj.varList.vars{l+1},8),'Units','Normalized',...
                         'Position',[(obj.varCol(c)+obj.varWidth*(obj.name2valRat+0.025)) obj.varRow(r) obj.varWidth*(1-obj.name2valRat-0.05) obj.varHeight], ...
                         'Callback', @(h,e)updateVarCallback(obj,h,e));
                end
                ll=ll+1;
            end
        end
        function ax=getAx(obj,num)
            %get axis handle number num (axes are numbered by order of
            %creation
            if (num>=1)&&(num<=length(obj.AxList))
                ax=double(obj.AxList{num});
            else
                ax=[];
            end
        end
        function reset(obj)
            if (sum(obj.fig==get(0,'Children'))==0) 
                %if figure was closed by user
                newObj.fig=openFigure('Pulse GUI');
                set(newObj.fig,'Position',[1300 50 1200 900]);
            else %figure still exists
                clf(obj.fig);
            end
            obj.totalAxNum=0;
            obj.drawGUI;
        end
        function h=exportAxes(obj,axNum)
            %save current figure and axes
            saveax=gca;
            savefig=gcf;
            figure(obj.fig);
            ax=obj.getAx(axNum);
            if (~isempty(ax))
                hgsave(ax,'tmpFigure');
                figh=figure;
                hgload('tmpFigure');
                ch=get(figh,'Children');
                set(ch,'Position','default');
                if (nargout>0)
                    h=figh;
                end
            else
                if (nargout>0)
                    h=[];
                end
            end
            %restore figure and axes;
            figure(savefig);
            axes(saveax);
        end
    end
end