function emailFile(fname,to)
if ~exist('to')
    to='shlomi.kotler@weizmann.ac.il';
end
maxsizebytes=1e7;
setpref('Internet','SMTP_Server','smtp-out.weizmann.ac.il');
setpref('Internet','E_mail','shlomi.kotler@weizmann.ac.il');
sendmail(to,'Dictator Report',['ozeri8-pc\n' cell2mat(fname)],fname);
end