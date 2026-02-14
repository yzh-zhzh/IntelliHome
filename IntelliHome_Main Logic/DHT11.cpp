#include "DHT11.h"

// Error messages
char MSG_ERROR_TIMEOUT[] = "Error 253 Reading from DHT sensor timed out.";
char MSG_ERROR_CHECKSUM[] = "Error 254 Checksum mismatch while reading from DHT sensor.";
char MSF_ERROR_UNKNOW[] = "Error Unknown.";

/**
* Constructor for the DHT11 class.
* Initializes the pin to be used for communication and sets it to output mode.
*/
DHT11::DHT11(PinName pin) : _pin(pin)
{
    t.start(); // start timer
}

/**
* Sets the delay between consecutive sensor readings.
*/
void DHT11::setDelay(unsigned long delay)
{
    _delayMS = delay;
}

/**
* Reads raw data from the DHT sensor.
* MODIFIED for STM32 speed and Interrupt safety.
*/
int DHT11::readRawData(byte data[5])
{
    DigitalInOut pin_DHT11(_pin);
    pin_DHT11.output(); // set as output pin
    pin_DHT11 = 1;      // initial state: set pin as HIGH
    thread_sleep_for(_delayMS);

    // --- START SIGNAL ---
    pin_DHT11 = 0;        // Pull low
    thread_sleep_for(20); // Keep low for at least 18ms (DHT22 needs >1ms, DHT11 needs >18ms)
    pin_DHT11 = 1;        // Pull high
    wait_us(30);          // Wait for sensor to respond
    pin_DHT11.input();    // Set as input to read response

    t.reset(); // reset the timer
    
    // Wait for the sensor to pull low (Response)
    while (pin_DHT11 == 1) 
    {
        if (duration_cast<milliseconds>(t.elapsed_time()).count() > TIMEOUT_DURATION)
        {
            return DHT11::ERROR_TIMEOUT;
        }
    }
    
    // Wait for the sensor to pull high, then low again (Start of transmission)
    while (pin_DHT11 == 0); 
    while (pin_DHT11 == 1); 

    // >>> CRITICAL SECTION: DISABLE INTERRUPTS <<<
    // This prevents the Ultrasonic sensor from interrupting the delicate timing
    __disable_irq(); 

    for (int i = 0; i < 5; i++)
    {
        byte value = 0;
        for (int j = 0; j < 8; j++)
        {
            // Wait for the start of the bit (Low voltage)
            while (pin_DHT11 == 0);
            
            // TIMING ADJUSTMENT: Wait 40us to check if it's a 0 or 1
            // 0 bit is ~26us, 1 bit is ~70us. 40us is the safe middle ground.
            wait_us(40); 
            
            if (pin_DHT11 == 1)
            {
                value |= (1 << (7 - j));
            }
            
            // Wait for the end of the bit (High voltage)
            while (pin_DHT11 == 1);
        }
        data[i] = value;
    }

    // >>> CRITICAL SECTION END: ENABLE INTERRUPTS <<<
    __enable_irq(); 

    // Checksum Verification
    // (Byte 0 + Byte 1 + Byte 2 + Byte 3) & 0xFF must equal Byte 4
    if (data[4] == ((data[0] + data[1] + data[2] + data[3]) & 0xFF))
    {
        return 0; // Success
    }
    else
    {
        return DHT11::ERROR_CHECKSUM;
    }
}

/**
* MODIFIED FOR DHT22: Reads Temperature
* DHT22 sends data as (High Byte + Low Byte) / 10
*/
int DHT11::readTemperature()
{
    byte data[5];
    int error = readRawData(data);
    if (error != 0)
    {
        return error;
    }

    // DHT22 Math: Combine Byte 2 (High) and Byte 3 (Low)
    int tempRaw = (data[2] << 8) | data[3];

    // Handle Negative Temperatures (High bit set)
    if (data[2] & 0x80) {
        tempRaw = -1 * ((tempRaw & 0x7FFF));
    }

    // Return integer part (e.g., 256 -> 25 degrees)
    return tempRaw / 10;
}

/**
* MODIFIED FOR DHT22: Reads Humidity
* DHT22 sends data as (High Byte + Low Byte) / 10
*/
int DHT11::readHumidity()
{
    byte data[5];
    int error = readRawData(data);
    if (error != 0)
    {
        return error;
    }

    // DHT22 Math: Combine Byte 0 (High) and Byte 1 (Low)
    int humRaw = (data[0] << 8) | data[1];

    // Return integer part (e.g., 520 -> 52%)
    return humRaw / 10;
}

/**
* MODIFIED FOR DHT22: Reads Both
*/
int DHT11::readTemperatureHumidity(int &temperature, int &humidity)
{
    byte data[5];
    int error = readRawData(data);
    if (error != 0)
    {
        return error;
    }

    // Calculate Humidity (DHT22)
    int humRaw = (data[0] << 8) | data[1];
    humidity = humRaw / 10;

    // Calculate Temperature (DHT22)
    int tempRaw = (data[2] << 8) | data[3];
    if (data[2] & 0x80) {
        tempRaw = -1 * ((tempRaw & 0x7FFF));
    }
    temperature = tempRaw / 10;

    return 0; // Success
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