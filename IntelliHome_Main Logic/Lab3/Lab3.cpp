#undef __ARM_FP
#include "mbed.h"
#include "seg7.h"  // Include the header file

#define WAIT_TIME_MS 2
#define SEVEN_SEGMENT_MASK 0x000000FF
#define SEVEN_SEGMENT_RESET 0x00000000

// BusOut for digit control
BusOut sevenSegmentDIG(PC_8, PC_9, PC_10, PC_11);
PortOut sevenSegmentPort(PortB, SEVEN_SEGMENT_MASK);
DigitalIn button(PC_12);


unsigned char qNum[4];  // Array to store the 4-digit number
