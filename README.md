# Smart Home IoT System with STM32 & Flutter

A comprehensive IoT-based smart home automation and security system built using the STM32 Nucleo-F103RB microcontroller. This system integrates environmental monitoring, automated control of windows and curtains, intruder detection, and remote control via a Flutter mobile application over Bluetooth.

## 📌 Project Overview

This project simulates a smart home environment where various sensors monitor real-time conditions (temperature, light, rain, and motion) to automate household appliances. The system features a security mode with password protection and offers manual overrides through a physical keypad or a mobile app.

### Key Features
* **Automated Climate Control:** * **Fan/AC:** Automatically turns on when temperature exceeds 28°C.
    * [cite_start]**Windows:** Automatically closes if rain is detected[cite: 2].
* **Smart Lighting & Curtains:**
    * **Curtains:** Automatically open/close based on light levels (Day/Night mode).
    * **Lights:** Turn on automatically when it gets dark.
* **Security System:**
    * **Intruder Detection:** Uses an ultrasonic sensor to detect sudden movements or presence when the user is "Away".
    * **Alarm:** Triggers a buzzer and red LED upon detection.
    * **Access Control:** Requires a 4-digit PIN entry via a 4x3 keypad to disarm the system.
* **Remote Control:**
    * **Mobile App:** Flutter-based app connects via Bluetooth (HC-05/06) to view sensor data and control appliances.
    * **Voice Control:** Supports voice commands via the mobile interface.

## 🛠️ Hardware Components

* [cite_start]**Microcontroller:** STM32 Nucleo-F103RB [cite: 1]
* **Sensors:**
    * DHT11 Temperature & Humidity Sensor
    * LDR (Light Dependent Resistor)
    * [cite_start]Rain Sensor (Analog) [cite: 2]
    * HC-SR04 Ultrasonic Distance Sensor
    * PIR Motion Sensor (Interrupt-based)
* **Actuators:**
    * Servo Motors (x2): For Window and Curtain control
    * DC Motor (with Fan blade): Simulates Air Conditioning
    * LEDs (Red, Green, Blue): Status indicators
    * Buzzer: Alarm system
* **Interface:**
    * 16x2 LCD Display
    * 4x3 Matrix Keypad
    * HC-05/HC-06 Bluetooth Module

## 🔌 Pin Configuration

| Component | Pin | Type |
| :--- | :--- | :--- |
| **DHT11 Sensor** | PB_5 | Digital I/O |
| **LDR (Light)** | PA_4 | Analog In |
| **Rain Sensor** | PA_5 | Analog In |
| **Ultrasonic Trigger** | PA_1 | Digital Out |
| **Ultrasonic Echo** | PA_6 | Interrupt In |
| **Motion Sensor** | PA_0 | Interrupt In |
| **Servo (Curtain)** | PA_7 | PWM Out |
| **Servo (Window)** | PB_3 | PWM Out |
| **DC Motor (AC)** | PB_0 (En), PC_1, PC_2 | PWM / Digital Out |
| **Bluetooth TX/RX** | PB_6, PB_7 | UART |
| **Keypad Rows** | PB_9, PB_14, PB_13, PB_11 | Digital Out |
| **Keypad Cols** | PB_10, PB_8, PB_12 | Digital In (PullUp) |
| **LCD Data** | PA_8 - PA_11 | Port Out |
| **LCD Control** | PA_12 (EN), PA_13 (WR), PA_14 (RS) | Digital Out |

## 💻 Software Architecture

### Firmware (C++ / Mbed OS)
The STM32 firmware is written in C++ using the Mbed OS API. It utilizes a super-loop architecture with timer-based polling for sensors and interrupts for critical events.
* `main.cpp`: Core logic, state machine, and sensor polling loop.
* `DHT11.cpp/h`: Driver for temperature sensor.
* [cite_start]`lcd_utilities.cpp`: Driver for 16x2 LCD in 4-bit mode[cite: 1].
* `keypad_utilities.cpp`: Driver for scanning the matrix keypad.

### Mobile App (Flutter)
The companion app is built with Flutter and communicates via Bluetooth Classic (Serial Port Profile).
* **Data Format:** Receives CSV string `Temp,Light,Rain,IsRaining` (e.g., `28.5,0.80,0.10,0`).
* **Commands:** Sends single-character commands to trigger actions (e.g., '1' for AC ON, '3' for Window Open).

## 🚀 Getting Started

### Prerequisites
* **Hardware:** STM32 Nucleo board, sensors, and connecting wires.
* **Software:** Keil Studio Cloud, Mbed Studio, or STM32CubeIDE.
* **Mobile:** Android device with Bluetooth support.

### Installation
1.  **Clone the Repo:**
    ```bash
    git clone [https://github.com/yourusername/stm32-smart-home.git](https://github.com/yourusername/stm32-smart-home.git)
    ```
2.  **Flash the Firmware:**
    * Open the project in your preferred IDE.
    * Compile `main.cpp` and flash the `.bin` file to the Nucleo board.
3.  **Install the App:**
    * Navigate to the `flutter_app` directory (if applicable).
    * Run `flutter run` on your connected Android device.

## 🎮 How to Use

1.  **Auto Mode:** The system starts in Auto Mode. It will react to light and temperature changes automatically.
2.  **Manual Override:**
    * Press keys on the Keypad or use the Mobile App to force appliances on/off.
    * [cite_start]**Note:** If it is raining, the Window Open command will be blocked for safety[cite: 2].
3.  **Security Mode:**
    * If "Away" (no motion for set time), the system arms itself.
    * If movement is detected, the alarm triggers.
    * Enter `1234` on the keypad to disarm.
