/*
 * File:   lcd utilities.cpp
 * Optimized for speed to prevent blocking Bluetooth
 */
#undef __ARM_FP

#include "mbed.h"
#include "lcd.h"

#define DISPLAY_LCD_MASK 0x00000F00 // PORT A: PA_8 to PA_11
#define DISPLAY_LCD_RESET 0x00000000

PortOut lcdPort(PortA, DISPLAY_LCD_MASK);
DigitalOut LCD_RS(PA_14);   // Register Select
DigitalOut LCD_EN(PA_12);   // Enable
DigitalOut LCD_WR(PA_13);   // Write

void lcd_strobe(void);

//--- Function for writing a command byte to the LCD in 4 bit mode -------------
void lcd_write_cmd(unsigned char cmd)
{
    unsigned char temp2;
    int tempLCDPort = 0;

    LCD_RS = 0;             // Select LCD for command mode
    wait_us(1);             // Small delay
    
    // --- Upper Nibble ---
    temp2 = cmd;
    temp2 = temp2 >> 4;     
    temp2 = temp2 & 0x0F;
    
    tempLCDPort = (int) temp2;
    tempLCDPort =  tempLCDPort << 8;
    tempLCDPort = tempLCDPort & 0x00000F00;
    lcdPort = tempLCDPort;

    wait_us(5);             // Setup time
    lcd_strobe();
    
    // --- Lower Nibble ---
    temp2 = cmd;            
    temp2 = temp2 & 0x0F;   
    
    tempLCDPort = (int) temp2;
    tempLCDPort =  tempLCDPort << 8;
    tempLCDPort = tempLCDPort & 0x00000F00;
    lcdPort = tempLCDPort;

    wait_us(5);             // Setup time
    lcd_strobe();
    
    wait_us(50);            // Execution time (most cmds take < 40us)
}

//---- Function to write a character data to the LCD ---------------------------
void lcd_write_data(char data)
{
    char temp1;
    int tempLCDPort = 0;

    LCD_RS = 1;             // Select LCD for data mode
    wait_us(1);             // Small delay

    // --- Upper Nibble ---
    temp1 = data;
    temp1 = temp1 >> 4;
    temp1 = temp1 & 0x0F;

    tempLCDPort = (int) temp1;
    tempLCDPort =  tempLCDPort << 8;
    tempLCDPort = tempLCDPort & 0x00000F00;
    lcdPort = tempLCDPort;

    wait_us(5);             // Setup time
    lcd_strobe();

    // --- Lower Nibble ---
    temp1 = data;
    temp1 = temp1 & 0x0F;
    tempLCDPort = (int) temp1;  
    tempLCDPort =  tempLCDPort << 8;
    tempLCDPort = tempLCDPort & 0x00000F00;
    lcdPort = tempLCDPort;

    wait_us(5);             // Setup time
    lcd_strobe();   
    
    wait_us(50);            // Execution time
}

//-- Function to generate the strobe signal -----------------------------------
void lcd_strobe(void)
{
    LCD_EN = 1;             // E = 1
    wait_us(2);             // Pulse width > 450ns
    LCD_EN = 0;             // E = 0
    wait_us(2);             // Hold time
}

//---- Function to initialise LCD module --------------------------------------
void lcd_init(void)
{
    lcdPort = DISPLAY_LCD_RESET;
    LCD_EN = 0;
    LCD_RS = 0;
    LCD_WR = 0;
   
    thread_sleep_for(100);  // Power-on delay (100ms is plenty)

    // Initialization Sequence
    lcd_write_cmd(0x33);
    lcd_write_cmd(0x32);
      
    lcd_write_cmd(0x28);    // 4-bit, 2 lines, 5x7
    lcd_write_cmd(0x0E);    // Display ON, Cursor ON
    lcd_write_cmd(0x06);    // Increment Cursor
    lcd_write_cmd(0x01);    // Clear Display
 
    thread_sleep_for(2);    // Clear command needs ~2ms
}

void lcd_Clear(void)
{
    lcd_write_cmd(0x01);    // Clear Display
    thread_sleep_for(2);    // Clear command needs ~2ms
}