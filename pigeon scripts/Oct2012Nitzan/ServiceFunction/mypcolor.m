function ax=mypcolor(x,y,z)
[a,b]=size(z);
bigZ=zeros(a+1,b+1);
dx=x(2)-x(1);
dy=y(2)-y(1);
bigX=[x (max(x)+dx)]-dx/2;
bigY=[y (max(y)+dy)]-dy/2;
bigZ(1:end-1,1:end-1)=z;
ax=pcolor(bigX,bigY,bigZ);
shading flat;
end