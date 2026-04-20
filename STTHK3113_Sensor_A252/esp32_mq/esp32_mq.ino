#include <Wire.h>
#define MQ135_PIN 34

void setup() {
  Serial.begin(115200);
}

void loop() {
  int sensorValue = analogRead(MQ135_PIN);

  String status;

  if (sensorValue < 1000) {
    status = "GOOD";
  } else if (sensorValue < 2000) {
    status = "MODERATE";
  } else {
    status = "POOR";
  }
  // Serial output
  Serial.print("Value: ");
  Serial.println(sensorValue);
  delay(2000);
}