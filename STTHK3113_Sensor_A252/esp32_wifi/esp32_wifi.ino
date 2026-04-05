#include <WiFi.h>
#include <DHT.h>

#define DHTPIN 4
#define DHTTYPE DHT11

DHT dht(DHTPIN, DHTTYPE);

// Tukar ikut WiFi anda
const char* ssid = "myUUM_Guest";
const char* password = "";

void setup() {
  Serial.begin(115200);
  delay(1000);

  dht.begin();

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
  float humidity = dht.readHumidity();
  float temperature = dht.readTemperature();

  if (isnan(humidity) || isnan(temperature)) {
    Serial.println("Gagal membaca data DHT11");
  } else {
    Serial.print("Suhu: ");
    Serial.print(temperature);
    Serial.print(" °C | Kelembapan: ");
    Serial.println(humidity);
  }

  delay(3000);
}