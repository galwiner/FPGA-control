function success=DDSinit(comport,parallel,DRG,Singlemode,OSK,REF1,TCXO1)
% parallel: is a bool selection parallel port mode - selecting one of 8 profiles. 
% DRG: bool for the frequency sweep mode. the max time between freq. hops is
% in order of few microseconds. do not attemp longer wait times. use short
% jumps instead if you want to move slowly
% SingleMode: bool for single output freq. & phase. 
% OSK: bool. set to 0 unless you know you don't want to.
% REF1: bool. enable external clock
% TCX01: bool. set to 0 unless you know better. 


s3 = serial(comport,'BaudRate',115200,'DataBits',8);
  
fopen(s3);

 pause(1000e-3); 

cfr2_0_7='00';
cfr2_16_23='40';
cfr1_8_15='00' ;
 
if (parallel==1)
    
    cfr2_0_7='10';
   
end 

 if (DRG==1)
        
     cfr2_16_23='48'; 
 end

  if (OSK==1)
        
     cfr1_8_15='03';      
 end

 
tt=Singlemode;
    
cfr1_24_31='00';
cfr1_16_23='00';
cfr1_8_15='00';
cfr1_0_7='02';

cfr2_24_31='01';
%%cfr2_16_23='40';
cfr2_8_15='08';
%%cfr2_0_7='00';

cfr3_24_31= '2D';
cfr3_16_23='3F';
cfr3_8_15='C1';
cfr3_0_7='C8';

io_update_24_31='00';
io_update_16_23='00';
io_update_8_15='00';
io_update_0_7='02';

Dac_24_31='00';
Dac_16_23='00';
Dac_8_15='00';
Dac_0_7='FF';


ASF_24_31='FF';
ASF_16_23='FF';
ASF_8_15='FF';
ASF_0_7='7F';


REF='FF';
CONTROL='FF';


if REF1==1
       
REF='00';
CONTROL='00';
end

REF=hex2dec(REF);
CONTROL=hex2dec(CONTROL);


% cfr1(cfr1_24_31,cfr1_16_23,cfr1_8_15,cfr1_0_7)
% cfr2(cfr2_24_31,cfr2_16_23,cfr2_8_15,cfr2_0_7);
% cfr3(cfr3_24_31,cfr3_16_23,cfr3_8_15,cfr3_0_7);
% dac( dac_24_31,dac_16_23,dac_8_15,dac_0_7 );
% io_update(io_update_24_31,io_update_16_23,io_update_8_15,io_update_0_7 );




cfr1_address=bin2dec('00000000');

cfr1_24_31=hex2dec(cfr1_24_31);
cfr1_16_23=hex2dec(cfr1_16_23);
cfr1_8_15=hex2dec(cfr1_8_15);
cfr1_0_7=hex2dec(cfr1_0_7);

cfr2_address=bin2dec(' 00000001');

cfr2_24_31=hex2dec(cfr2_24_31);
cfr2_16_23=hex2dec(cfr2_16_23);
cfr2_8_15=hex2dec(cfr2_8_15);
cfr2_0_7=hex2dec(cfr2_0_7);

cfr3_address=bin2dec('00000010');

cfr3_24_31=hex2dec(cfr3_24_31);
cfr3_16_23=hex2dec(cfr3_16_23);
cfr3_8_15=hex2dec(cfr3_8_15);
cfr3_0_7=hex2dec(cfr3_0_7);



fwrite(s3,'a');
fwrite(s3,cfr1_address);
fwrite(s3,cfr1_24_31);

fwrite(s3,cfr1_16_23);
fwrite(s3,cfr1_8_15);
 
fwrite(s3,cfr1_0_7);
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
fwrite(s3,cfr2_address);

fwrite(s3,cfr2_24_31);

fwrite(s3,cfr2_16_23);

fwrite(s3,cfr2_8_15);

fwrite(s3,cfr2_0_7);
% %  
% 
fwrite(s3,cfr3_address);
fwrite(s3,cfr3_24_31);
fwrite(s3,cfr3_16_23);
fwrite(s3,cfr3_8_15);
fwrite(s3,cfr3_0_7);
% 
% 

io_update_address=bin2dec('00000100');

io_update_24_31=hex2dec(io_update_24_31);
io_update_16_23=hex2dec(io_update_16_23);
io_update_8_15=hex2dec(io_update_8_15);
io_update_0_7=hex2dec(io_update_0_7);


fwrite(s3,io_update_address);
fwrite(s3,io_update_24_31);
fwrite(s3,io_update_16_23);
fwrite(s3,io_update_8_15);
fwrite(s3,io_update_0_7);

Dac_address=bin2dec('00000011');

Dac_24_31=hex2dec(Dac_24_31);
Dac_16_23=hex2dec(Dac_16_23);
Dac_8_15=hex2dec(Dac_8_15);
Dac_0_7=hex2dec(Dac_0_7);

fwrite(s3,Dac_address);
fwrite(s3,Dac_24_31);
fwrite(s3,Dac_16_23);
fwrite(s3,Dac_8_15);
fwrite(s3,Dac_0_7);

% 
ASF_address=bin2dec('00001001');

ASF_24_31=hex2dec(ASF_24_31);
ASF_16_23=hex2dec(ASF_16_23);
ASF_8_15=hex2dec(ASF_8_15);
ASF_0_7=hex2dec(ASF_0_7);

fwrite(s3,ASF_address);
fwrite(s3,ASF_24_31);
fwrite(s3,ASF_16_23);
fwrite(s3,ASF_8_15);
fwrite(s3,ASF_0_7);


fwrite(s3,REF);
fwrite(s3,CONTROL);
%%%   %%%%   %%%%


 fclose(s3);

success=1; %return 1 if init sequence successful 

end

