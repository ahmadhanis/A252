#include <WiFi.h>
#include <HTTPClient.h>
#include <DHT.h>

const char* WIFI_SSID = "myUUM_Guest";
const char* WIFI_PASSWORD = "";
const char* API_URL = "http://YOUR_SERVER_IP/esp32/dht11/api.php";

const char* DEVICE_NAME = "esp32-dht11-01";

// Assumption: D4 on your board maps to GPIO 4.
const int DHT_PIN = 4;
const unsigned long SEND_INTERVAL_MS = 10000;

#define DHTTYPE DHT11

DHT dht(DHT_PIN, DHTTYPE);
unsigned long lastSendTime = 0;

void connectWiFi() {
  WiFi.mode(WIFI_STA);
  WiFi.begin(WIFI_SSID, WIFI_PASSWORD);

  Serial.print("Connecting to WiFi");
  while (WiFi.status() != WL_CONNECTED) {
    delay(500);
    Serial.print(".");
  }

  Serial.println();
  Serial.print("Connected. IP: ");
  Serial.println(WiFi.localIP());
}

void setup() {
  Serial.begin(115200);
  delay(1000);

  dht.begin();
  connectWiFi();
}

void loop() {
  if (WiFi.status() != WL_CONNECTED) {
    Serial.println("WiFi disconnected. Reconnecting...");
    connectWiFi();
  }

  if (millis() - lastSendTime < SEND_INTERVAL_MS) {
    return;
  }

  lastSendTime = millis();

  float humidity = dht.readHumidity();
  float temperature = dht.readTemperature();

  if (isnan(humidity) || isnan(temperature)) {
    Serial.println("Failed to read from DHT11 sensor.");
    return;
  }

  String url = String(API_URL) +
               "?temperature=" + String(temperature, 1) +
               "&humidity=" + String(humidity, 1) +
               "&device=" + DEVICE_NAME;

  HTTPClient http;
  Serial.print("Request URL: ");
  Serial.println(url);
  http.begin(url);

  int httpCode = http.GET();
  String response = "";
  if (httpCode > 0) {
    response = http.getString();
  }

  Serial.print("Temperature: ");
  Serial.print(temperature, 1);
  Serial.print(" C, Humidity: ");
  Serial.print(humidity, 1);
  Serial.println(" %");

  Serial.print("HTTP Code: ");
  Serial.println(httpCode);

  if (httpCode <= 0) {
    Serial.print("HTTP error: ");
    Serial.println(http.errorToString(httpCode));
  }

  Serial.println("Response:");
  Serial.println(response);
  Serial.println("--------------------");

  http.end();
}
