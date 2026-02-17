#undef __ARM_FP
#include "mbed.h"
#include "DHT11.h"
#include "lcd.h"    
#include "keypad.h" 
#include <chrono>

using namespace std::chrono;

// --- HARDWARE DEFINITIONS ---
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

UnbufferedSerial btUART(PB_6, PB_7);  
UnbufferedSerial voiceUART(PC_10, PC_11); 

// --- TIMERS ---
Timer echoTimer;
Timer graceTimer;       
Timer awayTimer;        
Timer sensorReadTimer;      
Timer intruderTimer;
Timer stabilizationTimer; 

// --- STATE VARIABLES ---
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
bool overrideWindow = false; 

bool windowState = false; 
bool curtainState = false; 

// --- HELPER FUNCTIONS ---

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

// --- ACTUATOR FUNCTIONS ---

void setCurtain(bool up) {
    if (curtainState == up) return;
    resetStabilization(); 
    curtainState = up;
    
    if (up) {
        printf("[ACT] Curtain UP (Angle 180)\n");
        curtainServo.pulsewidth_us(2500); 
    } else {
        printf("[ACT] Curtain DOWN (Angle 0)\n");
        curtainServo.pulsewidth_us(400);  
    }
}

void setWindow(bool open) {
    if (windowState == open) return; 
    resetStabilization(); 
    windowState = open;
    
    if (open) {
        windowServo.pulsewidth_us(2500); 
        printf("[ACT] Win OPEN\n");
    } else {
        windowServo.pulsewidth_us(1400); 
        printf("[ACT] Win CLOSED\n");
    }
}

void setAircon(bool on) {
    if (acState == on) return; 
    resetStabilization(); 
    acState = on; 
    
    if (on) {
        Aircon_In1 = 1; Aircon_In2 = 0; 
        Aircon_En.write(0.15f); 
        printf("[ACT] AC ON (Low Speed)\n");
    } else {
        Aircon_En.write(0.0f); 
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
    
    redLed = 0; alarmTriggered = false; 
    isPersonHome = true; 
    potentialIntruder = false; 
    intruderTimer.stop();
    intruderTimer.reset();
    graceTimer.reset(); graceTimer.start();
    printf(">>> System Unlocked. <<<\n");
    ThisThread::sleep_for(2s); 
}

// --- MAIN FUNCTION ---

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
    stabilizationTimer.start(); 

    lastDist = 200.0f; 

    printf("--- SYSTEM ONLINE ---\n");

    while(true) {
        
        if (alarmTriggered) enterSecurityMode(); 
        
        ultrasonicTrigger = 0; wait_us(2);
        ultrasonicTrigger = 1; wait_us(10);
        ultrasonicTrigger = 0;
        ThisThread::sleep_for(30ms); 

        // --- INTRUDER LOGIC ---
        if (currentDist > 0.1f) {
            bool noiseDetected = (stabilizationTimer.elapsed_time() < 2s);
            bool trigger = false;

            if (!noiseDetected && graceTimer.elapsed_time() > 5s) {
                 if ((lastDist - currentDist) > 100.0f) {
                     trigger = true;
                     printf(">>> TRIGGER: Sudden Movement! (Delta: %.1f)\n", lastDist - currentDist);
                 }
            }

            if (!isPersonHome && currentDist < 100.0f) {
                if (!noiseDetected) {
                    trigger = true;
                    printf(">>> TRIGGER: Breach in Away Mode! (Dist: %.1f)\n", currentDist);
                }
            }
            
            if (trigger && !potentialIntruder) {
                potentialIntruder = true;
                intruderTimer.reset();
                intruderTimer.start();
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
                    intruderTimer.stop();
                    intruderTimer.reset();
                    printf(">>> Threat Cleared (Ghost).\n");
                }
            }

            if (!potentialIntruder) lastDist = currentDist;
        }

        // --- AWAY LOGIC ---
        if (currentDist > 100.0f) {
            if (awayTimer.elapsed_time() > 3s) isPersonHome = false; 
        } else {
            awayTimer.reset();
        }

        // --- BLUETOOTH COMMANDS ---
        if (btUART.readable()) {
            char c; btUART.read(&c, 1);
            if(c=='1') { setAircon(true); overrideAircon = true; } // Manual ON
            if(c=='2') { setAircon(false); overrideAircon = true; } // Manual OFF
            
            // --- NEW: AUTO MODE COMMAND ---
            if(c=='8') { overrideAircon = false; } 

            if(c=='3') { setWindow(true); overrideWindow = true; }
            if(c=='4') { setWindow(false); overrideWindow = false; }
            if(c=='5') setCurtain(true);
            if(c=='6') setCurtain(false);
        }

        // --- VOICE COMMANDS ---
        if (voiceUART.readable()) {
            char vc; voiceUART.read(&vc, 1);
            // Assuming voice module can send '8' or mapped character
            if (vc >= '2' && vc <= '8') {
                switch(vc) {
                    case '2': setAircon(true); overrideAircon = true; break;
                    case '3': setAircon(false); overrideAircon = true; break;
                    case '4': setCurtain(true); break;
                    case '5': setCurtain(false); break;
                    case '6': setWindow(true); overrideWindow = true; break;
                    case '7': setWindow(false); overrideWindow = false; break;
                    case '8': overrideAircon = false; break; // Voice Auto
                }
            }
        }

        if (sensorReadTimer.elapsed_time() > 2s) {
            sensorReadTimer.reset();
            
            float temp = dht11.readTemperature();
            float humidity = dht11.readHumidity();
            float lightVal = ldr.read();           
            float rainVal = rainSensor.read();
            float dist = currentDist;
            
            printf("T:%.1f | R:%.2f | D:%.1f | Home:%d\n", temp, rainVal, dist, isPersonHome);

            char buffer[60];
            int len = sprintf(buffer, "%.1f,%.1f,%.2f,%d,%.1f,%d,%d,%d\r\n", 
                  temp, humidity, rainVal, isRaining, dist, 
                  isPersonHome, alarmTriggered, acState);
            btUART.write(buffer, len); 

            blueLed = 1; ThisThread::sleep_for(100ms); blueLed = 0;

            // --- AUTO LOGIC ---
            if (rainVal > 0.6f) { 
                if (!isRaining) { 
                    isRaining = true; 
                    setWindow(false); 
                    overrideWindow = false; 
                    printf("[WARN] Rain detected (%.2f). Closing Window.\n", rainVal);
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
                        if (!isHot && !overrideWindow) { setWindow(false); isHot = true; } 
                    } else { 
                        setAircon(false); isHot = false; 
                    }
                }
            } else if (!isPersonHome) {
                setAircon(false); setRoomLight(false); 
                if (!overrideWindow) setWindow(false); 
            }

            // --- LCD DISPLAY UPDATE ---
            if (overrideAircon) {
                safe_lcd_clear(); lcd_write_cmd(0x80); 
                if (acState) lcd_print("MANUAL AC ON");
                else lcd_print("MANUAL AC OFF");
            } else {
                safe_lcd_clear(); lcd_write_cmd(0x80);
                if (isPersonHome) {
                    if (isNightTime) { lcd_print("NIGHT MODE"); blueLed.write(0); }
                    else { lcd_print("DAY MODE"); blueLed.write(1); }
                } else { lcd_print("AWAY - ECO"); }
            }
        }
        blueLed = !blueLed; 
    }
}