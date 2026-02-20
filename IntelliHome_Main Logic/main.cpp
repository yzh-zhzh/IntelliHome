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

DigitalOut redLed(PB_1);
DigitalOut blueLed(PB_2); 
DigitalOut greenLed(PC_3);  

UnbufferedSerial btUART(PB_6, PB_7);  
UnbufferedSerial voiceUART(PC_10, PC_11); 

Timer echoTimer;
Timer graceTimer;       
Timer awayTimer;        
Timer sensorReadTimer;      
Timer intruderTimer;
Timer stabilizationTimer; 
Timer alarmReportTimer; 

bool potentialIntruder = false; 
volatile float currentDist = 0.0f;
float lastDist = 0.0f; 
volatile bool alarmTriggered = false; 

bool isPersonHome = true; 
bool acState = false;
bool isNightMode = false; 
bool isHot = false;
bool overrideAircon = false;
bool isRaining = false;
bool overrideWindow = false; 

bool windowState = false; 
bool curtainState = false; 

char securityPin[4] = {'1', '2', '3', '4'};


void resetStabilization() {
    stabilizationTimer.reset();
    stabilizationTimer.start();
}

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
    return getkey(); 
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

void setCurtain(bool up) {
    if (curtainState == up) return;
    resetStabilization(); 
    curtainState = up;
    if (up) curtainServo.pulsewidth_us(2500); 
    else curtainServo.pulsewidth_us(400);  
}

void setWindow(bool open) {
    if (windowState == open) return; 
    resetStabilization(); 
    windowState = open;
    if (open) windowServo.pulsewidth_us(2500); 
    else windowServo.pulsewidth_us(1400); 
}

void setAircon(bool on) {
    if (acState == on) return; 
    resetStabilization(); 
    acState = on; 
    if (on) { Aircon_In1 = 1; Aircon_In2 = 0; Aircon_En.write(0.15f); } 
    else { Aircon_En.write(0.0f); }
}

void setRoomLight(bool on) {
    if (on) {
        blueLed = 1;
        greenLed = 0;
        redLed = 0;
    } else {
        blueLed = 0;
        greenLed = 0;
        redLed = 0;
    }
}

void unlockSystem() {
    safe_lcd_clear(); lcd_write_cmd(0x80);
    lcd_print("ACCESS GRANTED");
    
    redLed = 0; 
    
    if (isNightMode) blueLed = 1;
    
    alarmTriggered = false; 
    isPersonHome = true; 
    potentialIntruder = false; 
    intruderTimer.stop();
    intruderTimer.reset();
    graceTimer.reset(); graceTimer.start();
    
    printf(">>> System Unlocked via Keypad/Phone. <<<\n");
    ThisThread::sleep_for(2s); 
}

void enterSecurityMode() {
    printf("\n>>> INTRUDER DETECTED! <<<\n");
    setAircon(false);
    
    redLed = 1;
    blueLed = 0;
    greenLed = 0;
    
    safe_lcd_clear(); lcd_write_cmd(0x80);
    lcd_print("ALARM! ENTER PIN");
    
    bool accessGranted = false;
    unsigned char inputPass[5];
    int keyIndex = 0;

    alarmReportTimer.reset();
    alarmReportTimer.start();

    while (!accessGranted) {
        if (btUART.readable()) {
            char c; btUART.read(&c, 1);
            if (c == 'U') {
                unlockSystem();
                return; 
            }
        }

        if (alarmReportTimer.elapsed_time() > 2s) {
            alarmReportTimer.reset();
            char buffer[60];
            int len = sprintf(buffer, "0.0,0.0,0.0,0,%.1f,%d,1,%d\r\n", 
                  currentDist, isPersonHome, acState);
            btUART.write(buffer, len); 
        }

        char key = getkey(); 
        if (key != 0) {
            inputPass[keyIndex] = key;
            
            lcd_write_cmd(0xC0 + keyIndex); 
            lcd_write_data('*');
            
            keyIndex++;

            if (keyIndex == 4) {
                if (inputPass[0] == securityPin[0] && inputPass[1] == securityPin[1] && 
                    inputPass[2] == securityPin[2] && inputPass[3] == securityPin[3]) {
                    unlockSystem();
                    return;
                } else {
                    safe_lcd_clear(); lcd_write_cmd(0x80);
                    lcd_print("WRONG PIN!");
                    ThisThread::sleep_for(1s);
                    safe_lcd_clear(); lcd_write_cmd(0x80);
                    lcd_print("ALARM! ENTER PIN");
                    keyIndex = 0; 
                }
            }
            ThisThread::sleep_for(200ms); 
        }
        ThisThread::sleep_for(20ms); 
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

    redLed = 0; greenLed = 0; blueLed = 0;

    ultrasonicEcho.rise(&echo_rise);
    ultrasonicEcho.fall(&echo_fall);

    graceTimer.start(); awayTimer.start(); sensorReadTimer.start(); 
    stabilizationTimer.start(); 

    lastDist = 200.0f; 

    printf("--- SYSTEM ONLINE ---\n");

    while(true) {
        
        if (alarmTriggered) enterSecurityMode(); 
        
        ultrasonicTrigger = 0; wait_us(2);
        ultrasonicTrigger = 1; wait_us(10);
        ultrasonicTrigger = 0;
        ThisThread::sleep_for(30ms); 

        if (currentDist > 0.1f) {
            bool noiseDetected = (stabilizationTimer.elapsed_time() < 2s);
            bool trigger = false;
            if (!noiseDetected && graceTimer.elapsed_time() > 5s) {
                 if ((lastDist - currentDist) > 100.0f) trigger = true;
            }
            if (!isPersonHome && currentDist < 100.0f) {
                if (!noiseDetected) trigger = true;
            }
            if (trigger && !potentialIntruder) {
                potentialIntruder = true;
                intruderTimer.reset(); intruderTimer.start();
            }
            if (potentialIntruder) {
                if (currentDist < 100.0f) {
                    if (intruderTimer.elapsed_time() > 2s) {
                        if (!alarmTriggered) {
                            alarmTriggered = true;
                            potentialIntruder = false; 
                            intruderTimer.stop();
                        }
                    }
                } else {
                    potentialIntruder = false;
                    intruderTimer.stop(); intruderTimer.reset();
                }
            }
            if (!potentialIntruder) lastDist = currentDist;
        }

        if (currentDist > 100.0f) {
            if (awayTimer.elapsed_time() > 3s) isPersonHome = false; 
        } else {
            awayTimer.reset();
        }

        if (btUART.readable()) {
            char c; btUART.read(&c, 1);
            if(c=='1') { setAircon(true); overrideAircon = true; } 
            if(c=='2') { setAircon(false); overrideAircon = true; } 
            if(c=='8') { overrideAircon = false; }
            if(c=='3') { setWindow(true); overrideWindow = true; }
            if(c=='4') { setWindow(false); overrideWindow = false; }
            if(c=='5') setCurtain(true);
            if(c=='6') setCurtain(false);
            if(c=='P') {
                 safe_lcd_clear(); lcd_write_cmd(0x80); lcd_print("Updating PIN...");
                 for(int i=0; i<4; i++) {
                     int timeout = 0;
                     while(!btUART.readable() && timeout < 500) { ThisThread::sleep_for(10ms); timeout++; }
                     if(btUART.readable()) { char d; btUART.read(&d, 1); securityPin[i] = d; }
                 }
                 safe_lcd_clear(); lcd_write_cmd(0x80); lcd_print("PIN Updated!");
                 ThisThread::sleep_for(2s);
            }
        }

        if (voiceUART.readable()) {
            char vc; voiceUART.read(&vc, 1);
            if (vc >= '2' && vc <= '8') {
                switch(vc) {
                    case '2': setAircon(true); overrideAircon = true; break;
                    case '3': setAircon(false); overrideAircon = true; break;
                    case '4': setCurtain(true); break;
                    case '5': setCurtain(false); break;
                    case '6': setWindow(true); overrideWindow = true; break;
                    case '7': setWindow(false); overrideWindow = false; break;
                    case '8': overrideAircon = false; break; 
                }
            }
        }

        if (sensorReadTimer.elapsed_time() > 2s) {
            sensorReadTimer.reset();
            
            int t = 0, h = 0;
            dht11.readTemperatureHumidity(t, h); 
            float temp = (float)t;
            float humidity = (float)h;
            float lightVal = ldr.read();           
            float rainVal = rainSensor.read();
            float dist = currentDist;
            
            char buffer[60];
            int len = sprintf(buffer, "%.1f,%.1f,%.2f,%d,%.1f,%d,%d,%d\r\n", 
                  temp, humidity, rainVal, isRaining, dist, 
                  isPersonHome, alarmTriggered, acState);
            btUART.write(buffer, len); 

            if (rainVal > 0.6f) { 
                if (!isRaining) { isRaining = true; setWindow(false); overrideWindow = false; }
            } else { isRaining = false; }

            if (isPersonHome && !alarmTriggered) {
                if (lightVal < 0.7f) { 
                    if (isNightMode) { 
                        setCurtain(false); 
                        setRoomLight(false); 
                        isNightMode = false; 
                    }
                } 
                else if (lightVal > 0.4f) { 
                    if (!isNightMode) { 
                        setCurtain(true); 
                        setRoomLight(true); 
                        isNightMode = true; 
                    }
                }

                if (!overrideAircon) {
                    if (temp > 28.0f) { setAircon(true); if (!isHot && !overrideWindow) { setWindow(false); isHot = true; } } 
                    else { setAircon(false); isHot = false; }
                }
            } else if (!isPersonHome) {
                setAircon(false); 
                setRoomLight(false); 
                if (!overrideWindow) setWindow(false); 
            }

            if (overrideAircon) {
                safe_lcd_clear(); lcd_write_cmd(0x80); 
                if (acState) lcd_print("MANUAL AC ON");
                else lcd_print("MANUAL AC OFF");
            } else {
                safe_lcd_clear(); lcd_write_cmd(0x80);
                if (isPersonHome) {
                    if (isNightMode) { 
                        lcd_print("NIGHT MODE"); 
                    } else { 
                        lcd_print("DAY MODE"); 
                    }
                } else { lcd_print("AWAY - ECO"); }
            }
        }
    }
}