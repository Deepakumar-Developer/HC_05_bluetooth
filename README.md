# Project Documentation: HC-05 Two-Way Light Control with Flutter

Just wrapped up a fun IoT project demonstrating reliable, two-way communication between a **Flutter app** and an **Arduino NANO** via the classic **HC-05** Bluetooth module. This isn't just about turning a light on; it’s about conquering specific mobile-hardware integration challenges.

---

<img src="https://github.com/Deepakumar-Developer/HC_05_bluetooth/blob/main/assets/hardware.jpg" alt="Hardware Image" width="400"/>
Hardware setup of HC-05, Arduino, and LED wiring.


https://www.linkedin.com/feed/update/urn:li:groupPost:10408911-7386959624857481216?utm_source=social_share_send&utm_medium=member_desktop_web&rcm=ACoAAEZ7oaUBYzuL4DvxdCx6oNq_rTZ_xFo8cOg

Demonstration of Flutter App Controlling LED via HC-05 Bluetooth Module.

---

## What the Project Does:

I built a Flutter app to control an LED connected to an Arduino. Every time the light state changes, the system handles real-time feedback and local logging.

---

## 1. System Overview and Components

| **Component**             | **Role**                        | **Notes**                                               |
|----------------------------|----------------------------------|---------------------------------------------------------|
| **Arduino Uno/Nano**       | Microcontroller / Logic          | Executes control and confirmation logic.               |
| **HC-05 Module**           | Bluetooth Transceiver            | Provides Bluetooth Classic (SPP) communication.         |
| **LED**                    | Controlled Output                | Connected to Arduino Pin 2.                             |
| **Flutter Application**    | User Interface / Controller      | Sends commands ('1' or '0') and logs state confirmations. |
| **flutter_bluetooth_serial** | Flutter Package                | Essential for Bluetooth Classic (SPP) support.          |

---

## 2. Hardware Setup and Wiring

⚠️ **CRITICAL WARNING: HC-05 Logic Level**

> The HC-05 operates on **3.3V logic**.  
> Connecting the Arduino's **5V TX pin** directly to the HC-05's **3.3V RX pin** without a **voltage divider** or **logic level converter** will **damage the HC-05 over time**.

### Connection Table

| **Arduino Pin** | **Connection** | **HC-05 Pin** | **Function** |
|-----------------|----------------|----------------|---------------|
| GND             | →              | GND            | Ground        |
| 5V              | →              | VCC            | Power         |
| D9 (Software TX)| →              | RX             | Sends data from Arduino *(must use voltage divider)* |
| D10 (Software RX)| ←             | TX             | Receives data to Arduino *(3.3V logic, safe for Arduino)* |
| D2              | →              | LED Anode (+), LED Cathode (-) → GND via 220Ω Resistor | Light Control Output |

---

## 3. Arduino Firmware (Sketch)

The firmware uses **SoftwareSerial** to communicate with the **HC-05**.  
It listens for single-character commands (`'1'` or `'0'`) and immediately sends back a confirmation message:

- `"LIGHT_ON\n"` — when LED is turned ON
- `"LIGHT_OFF\n"` — when LED is turned OFF

---

```cpp
#include <SoftwareSerial.h>

SoftwareSerial BTSerial(10, 9); // RX, TX
const int ledPin = 2;

void setup() {
  pinMode(ledPin, OUTPUT);
  Serial.begin(9600);
  BTSerial.begin(9600);
  Serial.println("HC-05 Two-Way Light Control Ready");
}

void loop() {
  if (BTSerial.available()) {
    char command = BTSerial.read();
    if (command == '1') {
      digitalWrite(ledPin, HIGH);
      BTSerial.println("LIGHT_ON");
      Serial.println("LED ON");
    } else if (command == '0') {
      digitalWrite(ledPin, LOW);
      BTSerial.println("LIGHT_OFF");
      Serial.println("LED OFF");
    }
  }
}
```

---

## 4. Flutter Application Architecture

The Flutter app (`main.dart`) uses three primary architectural components:

### 4.1. Core Bluetooth Communication

* **Package:** `flutter_bluetooth_serial`
* **Command Sending:** The `_sendData('1'/'0')` function writes data to `_connection!.output`.
* **Data Reception (`_listenForData`):** A listener handles the incoming byte stream, decodes it, buffers it, and specifically waits for the confirmed messages: `"LIGHT_ON\n"` or `"LIGHT_OFF\n"`. The light log is only updated upon receiving these confirmations.

### 4.2. Android 12+ Crash Fix (Safe Device Selection)

To resolve the permission crash (`java.lang.SecurityException`) on modern Android devices, the direct, immediate call to `getBondedDevices()` was removed.

* **Implementation:** The main screen's **CONNECT** button now navigates to a new widget, **`SelectDevicePage`**.
* **Function:** `SelectDevicePage` safely executes the protected `FlutterBluetoothSerial.instance.getBondedDevices()` call in its own context (`FutureBuilder`), displays the list of paired devices, and returns the selected device to the main screen for connection.

### 4.3. Local Logging (`List<LocalLightLog>`)

* **Data Structure:** `List<LocalLightLog>` is used to store `status` and `timestamp`.
* **Trigger:** The `_logLightStatus()` function is called immediately after a confirmed signal (`"LIGHT_ON"` or `"LIGHT_OFF"`) is received from the Arduino.
* **Behavior:** The log history is stored only in the application's memory and is displayed in real-time on the main screen.

---

## 5. Operating Instructions

1.  **Pair Device (OS Level):** Before running the app, go to your phone's Bluetooth settings and manually pair with your HC-05 module.
2.  **Enable Permissions:** Ensure the necessary Bluetooth permissions (`BLUETOOTH_CONNECT`, `BLUETOOTH_SCAN`, etc.) are included in your Android Manifest file.
3.  **Run App:** Launch the Flutter application.
4.  **Connect:** Tap the **SELECT & CONNECT DEVICE** button.
5.  **Select HC-05:** Choose your paired HC-05 module from the list on the new screen.
6.  **Control:** Once connected, use the **Toggle Switch** to send commands. Watch the Arduino Serial Monitor for confirmation and the Flutter Log History for the timestamped activity logs.
