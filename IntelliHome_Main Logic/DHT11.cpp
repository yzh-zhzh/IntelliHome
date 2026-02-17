#include "DHT11.h"

// Error messages
char MSG_ERROR_TIMEOUT[] = "Error 253 Reading from DHT sensor timed out.";
char MSG_ERROR_CHECKSUM[] = "Error 254 Checksum mismatch while reading from DHT sensor.";
char MSF_ERROR_UNKNOW[] = "Error Unknown.";

DHT11::DHT11(PinName pin) : _pin(pin)
{
    t.start(); 
}

void DHT11::setDelay(unsigned long delay)
{
    _delayMS = delay;
}

int DHT11::readRawData(byte data[5])
{
    DigitalInOut pin_DHT11(_pin);
    pin_DHT11.output(); 
    pin_DHT11 = 1;      
    
    // --- REMOVED BLOCKING DELAY HERE ---
    // We rely on the main loop timer to space out readings.
    
    // --- START SIGNAL ---
    pin_DHT11 = 0;        
    thread_sleep_for(20); 
    pin_DHT11 = 1;        
    wait_us(30);          
    pin_DHT11.input();    

    t.reset(); 
    
    while (pin_DHT11 == 1) 
    {
        if (duration_cast<milliseconds>(t.elapsed_time()).count() > TIMEOUT_DURATION)
        {
            return DHT11::ERROR_TIMEOUT;
        }
    }
    
    while (pin_DHT11 == 0); 
    while (pin_DHT11 == 1); 

    __disable_irq(); 

    for (int i = 0; i < 5; i++)
    {
        byte value = 0;
        for (int j = 0; j < 8; j++)
        {
            while (pin_DHT11 == 0);
            wait_us(40); 
            if (pin_DHT11 == 1)
            {
                value |= (1 << (7 - j));
            }
            while (pin_DHT11 == 1);
        }
        data[i] = value;
    }

    __enable_irq(); 

    if (data[4] == ((data[0] + data[1] + data[2] + data[3]) & 0xFF))
    {
        return 0; 
    }
    else
    {
        return DHT11::ERROR_CHECKSUM;
    }
}

int DHT11::readTemperature()
{
    byte data[5];
    int error = readRawData(data);
    if (error != 0) return error;

    int tempRaw = (data[2] << 8) | data[3];
    if (data[2] & 0x80) {
        tempRaw = -1 * ((tempRaw & 0x7FFF));
    }
    return tempRaw / 10;
}

int DHT11::readHumidity()
{
    byte data[5];
    int error = readRawData(data);
    if (error != 0) return error;

    int humRaw = (data[0] << 8) | data[1];
    return humRaw / 10;
}

int DHT11::readTemperatureHumidity(int &temperature, int &humidity)
{
    byte data[5];
    int error = readRawData(data);
    if (error != 0) return error;

    int humRaw = (data[0] << 8) | data[1];
    humidity = humRaw / 10;

    int tempRaw = (data[2] << 8) | data[3];
    if (data[2] & 0x80) {
        tempRaw = -1 * ((tempRaw & 0x7FFF));
    }
    temperature = tempRaw / 10;

    return 0; 
}

char* DHT11::getErrorString(int errorCode)
{
    switch (errorCode)
    {
        case DHT11::ERROR_TIMEOUT:
            return MSG_ERROR_TIMEOUT;
        case DHT11::ERROR_CHECKSUM:
            return MSG_ERROR_CHECKSUM;
        default:
            return MSF_ERROR_UNKNOW;
    }
}