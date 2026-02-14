#undef __ARM_FP
#include "mbed.h"
#include "DHT11.h"
#include "lcd.h"    
#include "keypad.h" 
#include <chrono>

using namespace std::chrono;

PwmOut Aircon_En(PB_0);    
DigitalOut Aircon_In1(PC_1);  
DigitalOut Aircon_In2(PC_2);  

PwmOut curtainServo(PA_7);    
PwmOut windowServo(PB_3);     

#define DHT11_PIN PB_5  
DHT11 dht11(DHT11_PIN);

InterruptIn motionSensor(PA_0); 
AnalogIn ldr(PA_4);  
AnalogIn rainSensor(PA_5);           

DigitalOut ultrasonicTrigger(PA_1); 
InterruptIn ultrasonicEcho(PA_6);   

DigitalOut buzzer(PC_0);      
DigitalOut redLed(PB_1);      
DigitalOut greenLed(PB_2);    
DigitalOut blueLed(PC_3);     

DigitalIn keypadDataReady(PB_13); 

// BT RX to PB6, BT TX to PB7
UnbufferedSerial btUART(PB_6, PB_7);  
// TX=PC_10, RX=PC_11
UnbufferedSerial voiceUART(PC_10, PC_11); 

Timer echoTimer;
Timer graceTimer;       
Timer awayTimer;        
Timer sensorReadTimer;      
Timeout curtainStopTimeout; 

Timer manualModeTimer;

Timer intruderTimer;
bool potentialIntruder = false; 

volatile float currentDist = 0.0f;
float lastDist = 0.0f; 
volatile bool alarmTriggered = false; 

bool isPersonHome = true; 
bool acState = false;
bool isNightTime = false; 
bool isHot = false;
bool overrideAircon = false;
bool isRaining = false;

bool showingPrompt = false; 

void echo_rise() {
    echoTimer.reset();
    echoTimer.start();
}

void echo_fall() {
    echoTimer.stop();
    long duration = duration_cast<microseconds>(echoTimer.elapsed_time()).count();
    if (duration < 30000 && duration > 50) {
        currentDist = (duration * 0.0343f) / 2.0f;
    }
}

char check_keypad() {
    if (keypadDataReady == 1) return getkey(); 
    return 0;
}

char get_key_blocking() {
    char key = 0;
    while (key == 0) {
        key = getkey(); 
        wait_us(10000); 
    }
    return key;
}

void safe_lcd_clear() {
    lcd_Clear();
    ThisThread::sleep_for(2ms); 
}

void lcd_print(const char* str) {
    for (int i = 0; str[i] != '\0'; i++) {
        lcd_write_data(str[i]);
    }
}

void stopCurtainMotor() {
    curtainServo.pulsewidth_us(1500); 
    printf("[ACT] Curtain Signal CUT (Stop)\n");
}

void setCurtain(bool up) {
    curtainStopTimeout.detach(); 

    if (up) {
        printf("[ACT] Curtain UP\n");
        curtainServo.pulsewidth_us(500); 
    } else {
        printf("[ACT] Curtain DOWN\n");
        curtainServo.pulsewidth_us(2500); 
    }
}

void setWindow(bool open) {
    if (open) {
        windowServo.pulsewidth_us(2500); 
        printf("[ACT] Win OPEN\n");
    } else {
        windowServo.pulsewidth_us(1400); 
        printf("[ACT] Win CLOSED\n");
    }
}

void setAircon(bool on) {
    if (on && !acState) {
        Aircon_In1 = 1; Aircon_In2 = 0; 
        Aircon_En.write(0.15f); 
        acState = true;
        printf("[ACT] AC ON (Low Speed)\n");
    } else if (!on && acState) {
        Aircon_En.write(0.0f); 
        acState = false;
        printf("[ACT] AC OFF\n");
    }
}

void setRoomLight(bool on) {
    greenLed = on ? 1 : 0;
}

void enterSecurityMode() {
    printf("\n>>> INTRUDER DETECTED! <<<\n");
    setAircon(false);
    setRoomLight(false);
    redLed = 1; blueLed = 0;
    
    safe_lcd_clear(); lcd_write_cmd(0x80);
    lcd_print("ALARM! ENTER PIN");
    
    buzzer = 1; ThisThread::sleep_for(500ms); buzzer = 0;

    bool accessGranted = false;
    unsigned char inputPass[5];

    while (!accessGranted) {
        lcd_write_cmd(0xC0); 
        for (int i = 0; i < 4; i++) {
            inputPass[i] = get_key_blocking(); 
            buzzer = 1; ThisThread::sleep_for(50ms); buzzer = 0;
            lcd_write_data('*');
            ThisThread::sleep_for(200ms); 
        }

        if (inputPass[0] == '1' && inputPass[1] == '2' && inputPass[2] == '3' && inputPass[3] == '4') {
            accessGranted = true;
        } else {
            safe_lcd_clear(); lcd_write_cmd(0x80);
            lcd_print("WRONG PIN!");
            buzzer = 1; ThisThread::sleep_for(200ms); buzzer = 0;
            ThisThread::sleep_for(1s);
            safe_lcd_clear(); lcd_write_cmd(0x80);
            lcd_print("ALARM! ENTER PIN");
        }
    }

    safe_lcd_clear(); lcd_write_cmd(0x80);
    lcd_print("ACCESS GRANTED");
    
    redLed = 0; alarmTriggered = false; isPersonHome = true;
    potentialIntruder = false; 
    intruderTimer.stop();
    intruderTimer.reset();
    
    graceTimer.reset(); graceTimer.start();
    printf(">>> System Unlocked. <<<\n");
    ThisThread::sleep_for(2s); 
}

void handleInput(char k) {
    if (k == '1' && overrideAircon && showingPrompt) {
        manualModeTimer.reset(); 
        showingPrompt = false;   
        
        safe_lcd_clear(); lcd_write_cmd(0x80);
        lcd_print("MANUAL EXTENDED");
        
        ThisThread::sleep_for(1s); 
        printf("Manual Mode Extended by User.\n");
    }
    else if (k == '2') {
        setAircon(false);
        overrideAircon = false; 
        showingPrompt = false;
        manualModeTimer.stop();
        manualModeTimer.reset();
        
        safe_lcd_clear(); lcd_write_cmd(0x80);
        lcd_print("AC AUTO MODE");
        ThisThread::sleep_for(1s);
        printf("AC Auto Mode Restored.\n");
    }
}

int main() {
    lcd_init();
    btUART.baud(9600);
    voiceUART.baud(9600);
    
    printf("\n--- INITIALIZING HARDWARE ---\n");

    curtainServo.period_ms(20); curtainServo.pulsewidth_us(0); 
    windowServo.period_ms(20);  windowServo.pulsewidth_us(1500); 
    Aircon_En.write(0.0f);  

    Aircon_En = 0; blueLed = 0; redLed = 0; greenLed = 0;

    ultrasonicEcho.rise(&echo_rise);
    ultrasonicEcho.fall(&echo_fall);

    graceTimer.start(); awayTimer.start(); sensorReadTimer.start(); 
    lastDist = 200.0f; 

    printf("--- SYSTEM ONLINE ---\n");

    while(true) {
        
        if (alarmTriggered) enterSecurityMode(); 
        
        ultrasonicTrigger = 0; wait_us(2);
        ultrasonicTrigger = 1; wait_us(10);
        ultrasonicTrigger = 0;
        ThisThread::sleep_for(30ms); 

        printf("distance: %.2f\n", currentDist);

        if (currentDist > 0.1f) {
            
            if (graceTimer.elapsed_time() < 5s) {
                lastDist = currentDist;
            } 
            else {
                if (((lastDist - currentDist) > 100.0f) && !potentialIntruder) {
                    potentialIntruder = true;
                    intruderTimer.reset();
                    intruderTimer.start();
                    printf(">>> Sudden movement detected! Starting verification...\n");
                }

                if (potentialIntruder) {
                    if (currentDist < 100.0f) {
                        if (intruderTimer.elapsed_time() > 2s) {
                            if (!alarmTriggered) {
                                alarmTriggered = true;
                                isPersonHome = true;
                                potentialIntruder = false; 
                                intruderTimer.stop();
                                printf(">>> CONFIRMED INTRUDER <<<\n");
                            }
                        }
                    } 
                    else {
                        potentialIntruder = false;
                        intruderTimer.stop();
                        intruderTimer.reset();
                        printf(">>> False Alarm (Glitch). Resetting.\n");
                    }
                }


                if (currentDist > 100.0f) {
                    if (awayTimer.elapsed_time() > 3s) {
                        isPersonHome = false; 
                    }
                } else {
                    awayTimer.reset();
                    isPersonHome = true;
                }

                if (!potentialIntruder) {
                    lastDist = currentDist;
                }
            }
        }

        char k = check_keypad();
        if (k != 0) {
            printf("Keypad: %c\n", k);
            handleInput(k);
        }

        if (btUART.readable()) {
            char c; btUART.read(&c, 1);
            if(c=='1') { setAircon(true);  overrideAircon = true; manualModeTimer.reset(); manualModeTimer.start(); showingPrompt=false; }
            if(c=='2') { handleInput('2'); } 
            if(c=='3') setWindow(true);
            if(c=='4') setWindow(false);
            if(c=='5') setCurtain(true);
            if(c=='6') setCurtain(false);
        }

        if (voiceUART.readable()) {
            char vc; 
            voiceUART.read(&vc, 1);
            printf("VOICE RX: 0x%02X (%c)\n", vc, vc);

            if (vc >= '2' && vc <= '7') {
                switch(vc) {
                    case '2': 
                        setAircon(true); 
                        overrideAircon = true; 
                        manualModeTimer.reset(); manualModeTimer.start(); 
                        showingPrompt = false;
                        printf(">> VOICE: AC ON\n");
                        break;
                    case '3': 
                        handleInput('2');
                        printf(">> VOICE: AC OFF\n");
                        break;
                    case '4': setCurtain(true); printf(">> VOICE: Curtain UP\n"); break;
                    case '5': setCurtain(false); printf(">> VOICE: Curtain DOWN\n"); break;
                    case '6': setWindow(true); printf(">> VOICE: Window OPEN\n"); break;
                    case '7': setWindow(false); printf(">> VOICE: Window CLOSE\n"); break;
                }
            }
        }

        if (sensorReadTimer.elapsed_time() > 5s) {
            sensorReadTimer.reset();
            float temp = dht11.readTemperature();
            float lightVal = ldr.read();
            float rainVal = rainSensor.read(); // <-- NEW: Read rain sensor
            
            // Updated print statement
            printf("Temp: %.1f C | Light: %.2f | Rain: %.2f\n", temp, lightVal, rainVal);

            char buffer[50];
            int len = sprintf(buffer, "%.1f,%.2f,%.2f,%d\n", temp, lightVal, rainVal, isRaining);
            btUART.write(buffer, len);

            // <-- NEW: Rain detection logic -->
            // Adjust the 0.6f threshold based on your specific sensor's sensitivity
            if (rainVal > 0.6f) { 
                if (!isRaining) {
                    isRaining = true;
                    setWindow(false); // Force the window closed
                    printf("[ACT] Raining! Window CLOSED\n");
                }
            } else {
                isRaining = false;
            }

            if (isPersonHome && !alarmTriggered) {
                if (lightVal > 0.7f && !isNightTime) { setCurtain(false); setRoomLight(true); isNightTime = true; } 
                else if (lightVal < 0.4f && isNightTime) { setCurtain(true); setRoomLight(false); isNightTime = false; }

                if (!overrideAircon) {
                    if (temp > 28.0f) {
                        setAircon(true);
                        if (!isHot) { setWindow(false); isHot = true; }
                    } else {
                        setAircon(false);
                        isHot = false;
                    }
                }
            }
            else if (!isPersonHome) {
                setAircon(false); setRoomLight(false); setWindow(false); 
            }

            if (overrideAircon && manualModeTimer.elapsed_time() > 20s) {
                showingPrompt = true;
                safe_lcd_clear(); 
                lcd_write_cmd(0x80); lcd_print("Keep Manual?");
                lcd_write_cmd(0xC0); lcd_print("1: YES  2: NO");
            }
            else if (overrideAircon && !showingPrompt) {
                safe_lcd_clear(); lcd_write_cmd(0x80);
                lcd_print("MANUAL AC ON");
            }
            else if (!overrideAircon) {
                safe_lcd_clear(); lcd_write_cmd(0x80);
                if (isPersonHome) {
                    if (isNightTime) {
                        lcd_print("NIGHT MODE");
                        blueLed.write(0);}
                    else {lcd_print("DAY MODE");
                        blueLed.write(1);}
                } else {
                    lcd_print("AWAY - ECO");
                }
            }
        }
        blueLed = !blueLed; 
    }
}