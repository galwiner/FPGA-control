
close all;
clear all;
instrreset

%calibration of PSU
PSU_setup_script;

fopen(t1);
results=zeros(1,2);
for ind=1:220
    voltToAmp=2^15/220 * ind; %FPGA D2A has 16 bit. 2^15 is 10V
    setCurrent(voltToAmp)
    pause(0.1);
    fprintf(t1,'meas:current?');
    
    results(ind)=str2double(fscanf(t1));
end

figure;
hold on;
yyaxis left
plot(1:220,results,'o'); 
xlabel('set current [A]');
ylabel('PSU current [A]');
f=fit([1:220]',results','poly1');
plot(1:220,f(1:220),'r-');
plot(1:220,1:220,'g--')
yyaxis right
x = 1:220;
plot(x,results - x,'m--');
ylabel('Actual current - Meassured courent [A]');
legend('Measured current','fit','Set current','Meassurment error');




