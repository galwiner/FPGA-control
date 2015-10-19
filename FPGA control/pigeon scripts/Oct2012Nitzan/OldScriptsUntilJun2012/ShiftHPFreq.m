function ShiftHPFreq(f)

gp=gpib('ni',0,6);
fopen(gp);
fprintf(gp,['FR ' num2str(f) ' MZ']);
fclose(gp);

end