#include <SoftwareSerial.h>

const int hc05_tx_pin = 9;  
const int hc05_rx_pin = 10; 

const int led_pin = 2;

SoftwareSerial BTSerial(hc05_rx_pin, hc05_tx_pin);

void setup() {
  Serial.begin(9600);
  Serial.println("--- HC-05 Light Controller Starting ---");

  // Initialize Software Serial for communication with the HC-05 module
  // Match this baud rate to your HC-05 configuration (9600 is standard default)
  BTSerial.begin(9600);
  Serial.println("Bluetooth Serial started at 9600 baud.");

  // Set the LED pin as an output
  pinMode(led_pin, OUTPUT);
  digitalWrite(led_pin, LOW); // Start with the LED off
}

void loop() {
  if (BTSerial.available()) {
    char command = BTSerial.read();

    if (command == '1') {
      // Command to turn ON the light
      digitalWrite(led_pin, HIGH);
      
      // Send confirmation back to the Flutter app
      BTSerial.print("LIGHT_ON\n");
      Serial.println("Received '1'. Light ON. Sent confirmation.");
      
    } else if (command == '0') {
      // Command to turn OFF the light
      digitalWrite(led_pin, LOW);
      
      // Send confirmation back to the Flutter app
      BTSerial.print("LIGHT_OFF\n");
      Serial.println("Received '0'. Light OFF. Sent confirmation.");
      
    } else {
      // Handle unrecognized command
      Serial.print("Received unknown command: ");
      Serial.println(command);
    }
  }
  
  // A small delay to keep the loop from running too fast
  delay(5);
}
