#include <WiFi.h>
#include <HTTPClient.h>
#include <DHT.h>

#define DHTPIN 4
#define DHTTYPE DHT11

DHT dht(DHTPIN, DHTTYPE);

const char* ssid = "slum_predator";
const char* password = "abcdef7812230";

// URL Flask API anda
const char* serverURL = "http://192.168.137.1:5000/api/data";

void setup() {
  Serial.begin(115200);
  WiFi.begin(ssid, password);
  dht.begin();

  Serial.println("Connecting to WiFi...");

  while (WiFi.status() != WL_CONNECTED) {
    delay(1000);
    Serial.print(".");
  }

  Serial.println("\nConnected!");
}

void loop() {
  float temp = dht.readTemperature();
  float hum = dht.readHumidity();

  if (isnan(temp) || isnan(hum)) {
    Serial.println("Sensor error");
    return;
  }

  if (WiFi.status() == WL_CONNECTED) {
    HTTPClient http;

    http.begin(serverURL);
    http.addHeader("Content-Type", "application/json");
    http.setTimeout(15000);

    String json = "{\"temperature\":" + String(temp) + ",\"humidity\":" + String(hum) + "}";

    int httpResponseCode = http.POST(json);

    Serial.print("HTTP Response: ");
    Serial.println(httpResponseCode);

    String response = http.getString();
    Serial.println(response);

    http.end();
  } else {
    Serial.println("WiFi disconnected");
  }

  delay(10000); // hantar setiap 10 saat
}