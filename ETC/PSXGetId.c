#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <memory.h>
#include <inttypes.h>
#include <time.h>

int main(int argc, char *argv[]){
	FILE *file;
	char *buffer;
	char buf[20];
	int i;

	if(argc<2){
		printf("Error: param\n\n");
		return -2;
	}


	if(!(file = fopen(argv[1], "r"))) {
		printf("Error: Cannot open %s\n\n", argv[1]);
		return -1;
	}
	fseek(file, 0x100000, SEEK_SET);
	buffer=(char *)malloc(0x10000);
	fread(buffer,1,0x10000,file);
	fclose(file);

//metodo 1 - fixo
	if  ( check_sign(buffer,0x09340) ) {
			memset(&buf,0,20);
			memcpy(&buf,buffer+0x09340,8);
			buf[8]='.';
			memcpy(&buf[9],buffer+0x09340+8,2);
			printf("%s", buf);
			return 1;
	}

//metodo 2 - varaivel

    for (i=0; i<0x10000; i++){
    if  ( check_sign(buffer,i) ) {
                memset(&buf,0,20);
                memcpy(&buf,&buffer[i],11);
                printf("%s", buf);
                return 2;
        }
    }
    return 0;
}

int check_sign(char *buffer, int i) {
	char c1,c2,c3,c4,c5;

	c1 = buffer[i];
	c2 = buffer[i+1];
	c3 = buffer[i+2];
	c4 = buffer[i+3];
	c5 = buffer[i+4];

	//SLES / SCES
	//SLUS / SCUS
	if  ((c1=='S')&&
		((c2=='L')||(c2=='C'))&&
		((c3=='U')||(c3=='E'))&&
		 (c4=='S')&&
         (c5=='_')){
		return 1;
	} 
	
	//SLPS
	//SCPS
	//SLPM
	if  ((c1=='S')&&
		((c2=='L')||(c2=='C'))&&
		((c3=='P')&&
		 (c4=='S')||(c4=='M'))&&
         (c5=='_')){
		return 1;
	} 

	//ESPM
	//SLKA
	//SIPS
	//CPCS
	//SCAJ
	return 0;
}