/************************************************************
 * PROJECT: Basic LED Blinking using ESP32
 *
 * DESCRIPTION:
 * This program demonstrates how to control a digital output
 * (LED) using the ESP32. The LED will turn ON and OFF every
 * 1 second repeatedly.
 *
 * LEARNING OBJECTIVES:
 * - Understand the structure of Arduino program (setup & loop)
 * - Learn how to configure a pin as OUTPUT
 * - Understand how digitalWrite controls voltage (HIGH/LOW)
 * - Learn how delay() affects program timing
 * - Understand how to use Serial Monitor for debugging
 * - Learn how to create and call a user-defined function
 *
 * KEY CONCEPTS:
 * - setup() → runs once at startup
 * - loop() → runs continuously
 * - pinMode() → sets pin as INPUT or OUTPUT
 * - digitalWrite() → controls ON/OFF state
 * - delay() → pauses execution
 * - Serial.println() → outputs text to Serial Monitor
 *
 ************************************************************/

#include <Arduino.h>   // Include Arduino core library (required for basic functions)

// Define LED pin (GPIO 2 on ESP32)
#define LED 2

void setup() {
  // This function runs once when the ESP32 starts

  Serial.begin(115200);   // Start serial communication (for debugging/output)
  
  pinMode(LED, OUTPUT);   // Set LED pin as OUTPUT so it can send voltage
}

void loop() {
  // This function runs repeatedly (infinite loop)

  digitalWrite(LED, HIGH);   // Turn LED ON (HIGH = 3.3V)
  Serial.println("LED is on");   // Print message to Serial Monitor
  delay(1000);   // Wait for 1 second

  digitalWrite(LED, LOW);    // Turn LED OFF (LOW = 0V)
  Serial.println("LED is off");  // Print message to Serial Monitor
  delay(1000);   // Wait for 1 second

  doithere();   // Call custom function
}

void doithere(){
  // Custom function defined by user

  Serial.println("Hello World");   // Print message to Serial Monitor
}