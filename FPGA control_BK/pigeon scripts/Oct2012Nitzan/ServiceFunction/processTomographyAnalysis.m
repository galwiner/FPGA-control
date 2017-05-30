function chi=processTomographyAnalysis(Input)

if isstr(Input)
    l=load(fullFilepath,'PTMatrix');
    spin=l.PTMatrix;
elseif isequal(size(Input),[16,16])
    spin=Input;
else
    disp('Error: unknown input !!!');
    return;
end

% general definitions
s{1}=[1 0 ; 0 1]; 
s{2}=[0 1; 1 0]; 
s{3}=[0 -1i; 1i 0];
s{4}=[1 0; 0 -1];
debug=0;

% analyze two qubit process tomography
% use these lines for Nir data
% l=load('\\OZERI8-PC\measrments\DataArchive\archive30-Sep-2012\GateQPT-30Sep12-122841','spin');
% spin=l.spin;
% use these lines for Nitzan data

if debug
    f1=OpenFigure('Input States'); clf; 
    f2=OpenFigure('Outout States');clf; 
    f3=OpenFigure('Output States-simple input basis'); clf; 
end
% define the 16 input states rho{1},..,rho{16}
z=[1;0]; %up
mz=[0;1]; %down
x=[1;1]/sqrt(2); %x
y=[1;1i]/sqrt(2); %y
inputorder{1}=x; inputorder{2}=y; inputorder{3}=z; inputorder{4}=mz;
inStr{1}='x'; inStr{2}='y'; inStr{3}='up'; inStr{4}='down'; 
% display all input states
if debug; figure(f1);end;
for inputState=1:16
    r=1+rem(inputState-1,4);
    l=1+idivide(int16(inputState-1),4,'floor');
    psi=kron(inputorder{l},inputorder{r});
    rhoinput{inputState}=psi*psi';
    rhoinputStr{inputState}=[inStr{l} ' ' inStr{r}];
    if debug
        subplot(4,4,inputState);
        imagesc(0:3,0:3,abs(rhoinput{inputState}));caxis([-1 1]);
        title(rhoinputStr{inputState});
        set(gca,'XTickLabel',{'uu ','ud','du','dd'});
        set(gca,'YTickLabel',{'uu ','ud','du','dd'});
    end
end

% display all output matrices for each input state
if debug; figure(f2);end;
for inputState=1:16
    r=1+rem(inputState-1,4);
    l=1+idivide(int16(inputState-1),4,'floor');
    
%     output{inputState}=0.5*sig2reg(spin(:,:,inputState)); % nir data
    output{inputState}=0.5*sig2reg(reshape(spin(inputState,:),4,4)'); % Nitzan data
    if debug
        subplot(4,4,inputState);
        imagesc(0:3,0:3,abs(output{inputState}));caxis([-1 1]);
        title(rhoinputStr{inputState});
        set(gca,'XTickLabel',{'uu ','ud','du','dd'});
        set(gca,'YTickLabel',{'uu ','ud','du','dd'});
    end
end

% translate the input state into a more convinient basis -
% sigma{i}\otimes\sigma{j}
baseTrans{1}=[0;0;1;1]; %I=upup+downdown
baseTrans{2}=[2;0;-1;-1]; %sig_X=2xx -(upup+downdown)
baseTrans{3}=[0;2;-1;-1]; %sig_Y=2yy-(upup+downdow)
baseTrans{4}=[0;0;1;-1]; %sig_Z=upup-downdown
newStr={'I','X','Y','Z'};
if debug; figure(f3); end;
for inputState=1:16
    r=1+rem(inputState-1,4);
    l=1+idivide(int16(inputState-1),4,'floor');
    coff=kron(baseTrans{l},baseTrans{r});
    tmp=zeros(4,4); m=zeros(4,4);
    for t=1:16
        tmp=tmp+coff(t)*rhoinput{t};
        m=m+coff(t)*output{t};
    end
    rho{inputState}=tmp;
    measurements{inputState}=m;
    rhoStr{inputState}=[newStr{l} ' ' newStr{r}];
    if debug
        subplot(4,4,inputState);
        imagesc(0:3,0:3,real(measurements{inputState}));
        title(rhoStr{inputState});
        set(gca,'XTickLabel',{'uu ','ud','du','dd'});
        set(gca,'YTickLabel',{'uu ','ud','du','dd'});
    end
end

% define the E_m basis
outputorder=s; % I X Y Z
outStr{1}='I'; outStr{2}='X'; outStr{3}='Y'; outStr{4}='Z'; 
for opIdx=1:16
    r=1+rem(opIdx-1,4);
    l=1+idivide(int16(opIdx-1),4,'floor');
    E{opIdx}=kron(outputorder{l},outputorder{r});
    Estr{opIdx}=[ outStr{l} ' ' outStr{r} ];
end

% calculate the beta matix
%   by definiton, beta_{(jk),(mn)}rho_k=E_m rho_j E_n^\dagger
beta=zeros(256,256);
for j=1:16
    for k=1:16
        a=(j-1)*16+k;
        m=measurements{j};
        lambda(a)=trace(rho{k}'*m);
        for m=1:16
            for n=1:16
                b=(m-1)*16+n;
                beta(a,b)=trace(rho{k}'*E{m}*rho{j}*E{n}');
            end
        end
    end
end

% now use Penrose inverse to find chi
chi=reshape(pinv(beta)*lambda',16,16);
figure;
title('Process Matrix');
bar3(abs(chi));
set(gca,'ZLim',[0 1]);
set(gca,'XTick',1:16);set(gca,'XTickLabel',Estr);
set(gca,'YTick',1:16);set(gca,'YTickLabel',Estr);
% showData='bar3(abs(chi)); set(gca,''ZLim'',[0 1]); set(gca,''XTick'',1:16);set(gca,''XTickLabel'',Estr);set(gca,''YTick'',1:16);set(gca,''YTickLabel'',Estr);';
% save('chi30Sep12-122841','chi','Estr','showData');

    function out=sig2reg(in)
        %translate a density matrix written in the sig\otimes sig basis
        %into the regular up up up down down up down down
        out=zeros(4,4);
        for t=1:4
            for u=1:4
                out=out+in(t,u)*kron(s{t},s{u})/2;
            end
        end
    end
    function out=reg2sig(in)
        %translate density matrix witten in up up.. down down basis to
        %sigma basis
        for q=1:4
            for w=1:4
                out(q,w)=trace(in*kron(s{q},s{w}))/2;
            end
        end
    end
end