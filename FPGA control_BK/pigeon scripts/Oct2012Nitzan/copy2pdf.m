function copy2pdf(fnamei)
% copy MATLAB figure to pdf at given location
%   copy2pdf(axHandle,fileName)
% if axHandle not given - choose current figure
% if fileName not given - choose working directory + date

if ~exist('fnamei')
    smallname=['copy2pdf' datestr(now,'yyyymmmdd-HH-MM')];
    fname=fullfile('E:\measrments\DataArchive\snapshots',smallname);
else
    fname=fnamei;
    
end
    [di,shortfname,ext]=fileparts(fname);
    
    set(gcf, 'PaperUnits', 'centimeters');
    mysize=[10 8]; %[5 4];
    a=annotation(gcf,'textbox','Position',[0 0 1 0.05],'String',smallname,'EdgeColor','none');
    set(gcf, 'PaperSize', mysize);
    set(gcf,'PaperPosition',[0 0 mysize*1.1]);
%     %find all axes and change their font size to smaller
%     chlst=findobj(gcf,'Type','axes');
%     for t=1:length(chlst)
%         ch=chlst(t);
%         set(ch,'FontSize',5);
%         set(get(ch,'xlabel'),'FontSize',5);
%         set(get(ch,'ylabel'),'FontSize',5);
%         set(get(ch,'title'),'FontSize',5);
%     end
    print(gcf,fname,'-dpng');
    hgsave(gcf,fname);
    latexcommand=2;
    switch latexcommand
        case 1, %centered figure
            clipboard('copy',['\begin{center} ' char(10) '\includegraphics{' strrep(fname,'\','/') '}\\' char(10) sprintf('\\tiny{\\verb|%s|}',shortfname) char(10) '\end{center}'])
        case 2, %tabulated figure
            clipboard('copy',['\begin{tabular}{p{0.44\textwidth}p{0.44\textwidth}}' char(10) ...
                '\raisebox{-\height}{\includegraphics{' strrep(fname,'\','/') '}}& \\' char(10) ...
                '{\tiny\verb|' shortfname '|} & \\' char(10) ...
                '\end{tabular}']);
    end           
%     disp(sprintf('saved %s',fname));
%     disp('use CTRL-V to paste insertion code into latex');
    emailFile({[fname '.png'],[fname '.fig']})
    delete(a);
end