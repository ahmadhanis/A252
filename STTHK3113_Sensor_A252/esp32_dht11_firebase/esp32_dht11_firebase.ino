#include <WiFi.h>
#include <HTTPClient.h>
#include <WiFiClientSecure.h>
#include "DHT.h"
#include "time.h"

// =======================
// WiFi Configuration
// =======================
const char* ssid = "myUUM_Guest";
const char* password = "";   // Open WiFi, no password

// =======================
// Firebase Configuration
// =======================
String firebaseHost = "https://iotmessagebox.firebaseio.com";

// Change this for every ESP32 device
String deviceID = "esp32_lab01";

// =======================
// DHT11 Configuration
// =======================
#define DHTPIN 4
#define DHTTYPE DHT11

DHT dht(DHTPIN, DHTTYPE);

// =======================
// NTP Time Configuration
// Malaysia time = UTC +8
// =======================
const char* ntpServer = "pool.ntp.org";
const long gmtOffset_sec = 8 * 3600;
const int daylightOffset_sec = 0;

// =======================
// Timing
// =======================
unsigned long previousMillis = 0;
const long interval = 10000; // Send data every 10 seconds

void setup() {
  Serial.begin(115200);
  delay(1000);

  dht.begin();

  Serial.println();
  Serial.println("ESP32 Firebase DateTime Historical Data");
  Serial.println("--------------------------------------");

  connectWiFi();

  if (WiFi.status() == WL_CONNECTED) {
    setupTime();
  }
}

void loop() {
  if (WiFi.status() != WL_CONNECTED) {
    Serial.println("WiFi disconnected. Reconnecting...");
    connectWiFi();

    if (WiFi.status() == WL_CONNECTED) {
      setupTime();
    }
  }

  unsigned long currentMillis = millis();

  if (currentMillis - previousMillis >= interval) {
    previousMillis = currentMillis;

    float humidity = dht.readHumidity();
    float temperature = dht.readTemperature();

    if (isnan(humidity) || isnan(temperature)) {
      Serial.println("Failed to read from DHT11 sensor.");
      return;
    }

    String dateStr = getDateString();
    String timeStr = getTimeString();
    String dateTimeKey = getDateTimeKey();

    if (dateTimeKey == "") {
      Serial.println("Time not available. Data not sent.");
      return;
    }

    Serial.println();
    Serial.println("DHT11 Reading:");
    Serial.print("Device ID: ");
    Serial.println(deviceID);

    Serial.print("Temperature: ");
    Serial.print(temperature);
    Serial.println(" °C");

    Serial.print("Humidity: ");
    Serial.print(humidity);
    Serial.println(" %");

    Serial.print("Date: ");
    Serial.println(dateStr);

    Serial.print("Time: ");
    Serial.println(timeStr);

    sendHistoricalDataToFirebase(temperature, humidity, dateStr, timeStr, dateTimeKey);
    updateLatestDataToFirebase(temperature, humidity, dateStr, timeStr, dateTimeKey);
  }
}

void connectWiFi() {
  Serial.print("Connecting to WiFi: ");
  Serial.println(ssid);

  WiFi.mode(WIFI_STA);
  WiFi.begin(ssid);

  int retry = 0;

  while (WiFi.status() != WL_CONNECTED && retry < 30) {
    delay(500);
    Serial.print(".");
    retry++;
  }

  Serial.println();

  if (WiFi.status() == WL_CONNECTED) {
    Serial.println("WiFi connected successfully.");
    Serial.print("IP Address: ");
    Serial.println(WiFi.localIP());
  } else {
    Serial.println("Failed to connect WiFi.");
  }
}

void setupTime() {
  Serial.println("Configuring NTP time...");
  configTime(gmtOffset_sec, daylightOffset_sec, ntpServer);

  struct tm timeinfo;

  int retry = 0;
  while (!getLocalTime(&timeinfo) && retry < 20) {
    Serial.print(".");
    delay(500);
    retry++;
  }

  Serial.println();

  if (retry < 20) {
    Serial.println("Time synchronized successfully.");
    Serial.println(&timeinfo, "%Y-%m-%d %H:%M:%S");
  } else {
    Serial.println("Failed to obtain NTP time.");
  }
}

String getDateString() {
  struct tm timeinfo;

  if (!getLocalTime(&timeinfo)) {
    return "";
  }

  char dateBuffer[11];
  strftime(dateBuffer, sizeof(dateBuffer), "%Y-%m-%d", &timeinfo);

  return String(dateBuffer);
}

String getTimeString() {
  struct tm timeinfo;

  if (!getLocalTime(&timeinfo)) {
    return "";
  }

  char timeBuffer[9];
  strftime(timeBuffer, sizeof(timeBuffer), "%H:%M:%S", &timeinfo);

  return String(timeBuffer);
}

String getDateTimeKey() {
  struct tm timeinfo;

  if (!getLocalTime(&timeinfo)) {
    return "";
  }

  char keyBuffer[25];

  // Firebase path cannot use some special characters.
  // So use underscore and dash instead of space and colon.
  strftime(keyBuffer, sizeof(keyBuffer), "%Y-%m-%d_%H-%M-%S", &timeinfo);

  return String(keyBuffer);
}

void sendHistoricalDataToFirebase(
  float temperature,
  float humidity,
  String dateStr,
  String timeStr,
  String dateTimeKey
) {
  if (WiFi.status() != WL_CONNECTED) {
    Serial.println("WiFi not connected. Cannot send historical data.");
    return;
  }

  WiFiClientSecure client;
  client.setInsecure();

  HTTPClient http;

  String firebasePath = "/devices/" + deviceID + "/history/" + dateTimeKey + ".json";
  String url = firebaseHost + firebasePath;

  Serial.print("Sending historical data to Firebase: ");
  Serial.println(url);

  http.begin(client, url);
  http.addHeader("Content-Type", "application/json");

  String jsonData = "{";
  jsonData += "\"deviceid\":\"" + deviceID + "\",";
  jsonData += "\"temperature\":" + String(temperature, 2) + ",";
  jsonData += "\"humidity\":" + String(humidity, 2) + ",";
  jsonData += "\"date\":\"" + dateStr + "\",";
  jsonData += "\"time\":\"" + timeStr + "\",";
  jsonData += "\"datetime\":\"" + dateStr + " " + timeStr + "\"";
  jsonData += "}";

  int httpResponseCode = http.PUT(jsonData);

  if (httpResponseCode > 0) {
    Serial.print("Historical data response code: ");
    Serial.println(httpResponseCode);
    Serial.println(http.getString());
  } else {
    Serial.print("Error sending historical data. Code: ");
    Serial.println(httpResponseCode);
  }

  http.end();
}

void updateLatestDataToFirebase(
  float temperature,
  float humidity,
  String dateStr,
  String timeStr,
  String dateTimeKey
) {
  if (WiFi.status() != WL_CONNECTED) {
    Serial.println("WiFi not connected. Cannot update latest data.");
    return;
  }

  WiFiClientSecure client;
  client.setInsecure();

  HTTPClient http;

  String firebasePath = "/devices/" + deviceID + "/latest.json";
  String url = firebaseHost + firebasePath;

  Serial.print("Updating latest data to Firebase: ");
  Serial.println(url);

  http.begin(client, url);
  http.addHeader("Content-Type", "application/json");

  String jsonData = "{";
  jsonData += "\"deviceid\":\"" + deviceID + "\",";
  jsonData += "\"temperature\":" + String(temperature, 2) + ",";
  jsonData += "\"humidity\":" + String(humidity, 2) + ",";
  jsonData += "\"date\":\"" + dateStr + "\",";
  jsonData += "\"time\":\"" + timeStr + "\",";
  jsonData += "\"datetime\":\"" + dateStr + " " + timeStr + "\",";
  jsonData += "\"history_key\":\"" + dateTimeKey + "\"";
  jsonData += "}";

  int httpResponseCode = http.PUT(jsonData);

  if (httpResponseCode > 0) {
    Serial.print("Latest data response code: ");
    Serial.println(httpResponseCode);
    Serial.println(http.getString());
  } else {
    Serial.print("Error updating latest data. Code: ");
    Serial.println(httpResponseCode);
  }

  http.end();
}