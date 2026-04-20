#include <Wire.h>
#include <Adafruit_GFX.h>
#include <Adafruit_SSD1306.h>

#define SCREEN_WIDTH 128
#define SCREEN_HEIGHT 64

Adafruit_SSD1306 display(SCREEN_WIDTH, SCREEN_HEIGHT, &Wire, -1);

#define MQ135_PIN 34

void setup() {
  Serial.begin(115200);

  // OLED init
  if (!display.begin(SSD1306_SWITCHCAPVCC, 0x3C)) {
    Serial.println("OLED not found");
    while (true);
  }

  display.clearDisplay();
  display.setTextSize(1);
  display.setTextColor(WHITE);

  display.setCursor(0, 0);
  display.println("MQ135 System");
  display.println("Initializing...");
  display.display();

  delay(2000);
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

  // OLED display
  display.clearDisplay();

  display.setCursor(0, 0);
  display.setTextSize(1);
  display.println("Air Quality Monitor");

  display.setTextSize(2);
  display.setCursor(0, 20);
  display.print(sensorValue);

  display.setTextSize(1);
  display.setCursor(0, 50);
  display.print("Status: ");
  display.println(status);

  display.display();

  delay(2000);
}