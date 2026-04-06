#include <WiFi.h>

// Replace with your network credentials
const char* ssid = "myUUM_Guest";
const char* password = "";

// Set web server port number to 80
WiFiServer server(80);
#define LED 2

// Variable to store the HTTP request
String header;

// Auxiliar variables to store the current output state
String ledState = "off";

void setup() {
  // put your setup code here, to run once:
  Serial.begin(115200);
  // Initialize the output variables as outputs
  pinMode(LED, OUTPUT);

  // Set outputs to LOW
  digitalWrite(LED, LOW);

  Serial.println("Connecting to WiFi...");
  WiFi.begin(ssid, password);

  // Tunggu sampai connect
  while (WiFi.status() != WL_CONNECTED) {
    delay(1000);
    Serial.print(".");
  }

  Serial.println("\nWiFi Connected!");
  Serial.print("IP Address: ");
  Serial.println(WiFi.localIP());
}

void loop() {
  // put your main code here, to run repeatedly:
}
