%example of winfreak set freq to 910MHz
a=serial('COM2','BaudRate',9600);
fopen(a);
fprintf(a,'f910');
fclose(a)
