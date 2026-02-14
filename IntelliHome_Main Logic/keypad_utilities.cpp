#undef __ARM_FP
#include "mbed.h"

DigitalOut Row1(PB_9);
DigitalOut Row2(PB_14);
DigitalOut Row3(PB_13); 
DigitalOut Row4(PB_11); 

DigitalIn Col1(PB_10); 
DigitalIn Col2(PB_8);
DigitalIn Col3(PB_12);


char getkey(void) {
    Col1.mode(PullUp); Col2.mode(PullUp); Col3.mode(PullUp);
    Row1 = 1; Row2 = 1; Row3 = 1; Row4 = 1;

    Row1 = 0; 
    if (Col1 == 0) { wait_us(10000); while(Col1==0); Row1=1; return '1'; }
    if (Col2 == 0) { wait_us(10000); while(Col2==0); Row1=1; return '2'; }
    if (Col3 == 0) { wait_us(10000); while(Col3==0); Row1=1; return '3'; }
    Row1 = 1; 

    Row2 = 0;
    if (Col1 == 0) { wait_us(10000); while(Col1==0); Row2=1; return '4'; }
    if (Col2 == 0) { wait_us(10000); while(Col2==0); Row2=1; return '5'; }
    if (Col3 == 0) { wait_us(10000); while(Col3==0); Row2=1; return '6'; }
    Row2 = 1;

    Row3 = 0;
    if (Col1 == 0) { wait_us(10000); while(Col1==0); Row3=1; return '7'; }
    if (Col2 == 0) { wait_us(10000); while(Col2==0); Row3=1; return '8'; }
    if (Col3 == 0) { wait_us(10000); while(Col3==0); Row3=1; return '9'; }
    Row3 = 1;

    Row4 = 0;
    if (Col1 == 0) { wait_us(10000); while(Col1==0); Row4=1; return '*'; }
    if (Col2 == 0) { wait_us(10000); while(Col2==0); Row4=1; return '0'; }
    if (Col3 == 0) { wait_us(10000); while(Col3==0); Row4=1; return '#'; }
    Row4 = 1;

    return 0; 
}