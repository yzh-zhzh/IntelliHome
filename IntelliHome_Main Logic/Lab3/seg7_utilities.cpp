#include "seg7.h"

char convert(char digit)
{
    char leddata = 0x00;

    switch (digit) {
        case 0: leddata = 0x3F; break;
        case 1: leddata = 0x06; break;
        case 2: leddata = 0x5B; break;
        case 3: leddata = 0x4F; break;
        case 4: leddata = 0x66; break;
        case 5: leddata = 0x6D; break;
        case 6: leddata = 0x7D; break;
        case 7: leddata = 0x07; break;
        case 8: leddata = 0x7F; break;
        case 9: leddata = 0x67; break;
        default: leddata = 0x00; break;
    }
    return leddata;
}

void update(unsigned char val[], int size)
{
    if (size != 4)
        return;

    // Start from the least significant digit
    if (val[0] > 9) {
        val[0] = 0;
        val[1]++;
    }
    if (val[1] > 9) {
        val[1] = 0;
        val[2]++;
    }
    if (val[2] > 9) {
        val[2] = 0;
        val[3]++;
    }
    if (val[3] > 9) {
        val[3] = 0;
    }
}