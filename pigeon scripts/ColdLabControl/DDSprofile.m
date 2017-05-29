function success= DDSprofile(comport,profileNum,fout,offset_phase,Adb)
%  this function sets the frequency of the DDS when it is in single freq
%  mode. 


s3 = serial(comport,'BaudRate',115200,'DataBits',8);
fopen(s3);
%   pause(1000e-3); 
%    fout=100;
   fsys=1000;
   FTW=round((2^32)*(fout)/(fsys));
   POW=(offset_phase*2^16)/360;
   ASF=round((2^14-1)*10^(Adb/20));
   
   c=dec2binvec(ASF,16);
   b=dec2binvec(POW,16);
   a=dec2binvec(FTW,32);
  
   
   
   p1=c(9:16);
   x1=binvec2dec(p1);
   p2=c(1:8);
   x2=binvec2dec(p2);
   
   p3=b(9:16);
   x3=binvec2dec(p3);
   p4=b(1:8);
   x4=binvec2dec(p4);
  
   
   
   p5=a(25:32);
   x5=binvec2dec(p5);
   
   p6=a(17:24);
   x6=binvec2dec(p6);
   
   p7=a(9: 16);
   x7=binvec2dec(p7);
   
   p8=a(1:8);
   x8=binvec2dec(p8);



fwrite(s3,'s');
if (profileNum < 8 && profileNum >=0 && rem(profileNum,1)==0)
profile=profileNum+14;
else 
    error('DDS: bad profile number! must be 0-7!')
end
%pause(1e-3); 
fwrite(s3,profile);

fwrite(s3,x1);

fwrite(s3,x2) ;

fwrite(s3,x3);
 
fwrite(s3,x4);

fwrite(s3,x5);

fwrite(s3,x6) ;

fwrite(s3,x7);
 
fwrite(s3,x8);

%    
  fclose(s3) ;


success=1;
end

