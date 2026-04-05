#include <DHT.h>

#define DHTPIN 4
#define DHTTYPE DHT11

DHT dht(DHTPIN, DHTTYPE);

void setup() {
  Serial.begin(115200);
  delay(1000);

  Serial.println("Memulakan DHT11...");
  dht.begin();
}

void loop() {
  float humidity = dht.readHumidity();
  float temperature = dht.readTemperature();

  if (isnan(humidity) || isnan(temperature)) {
    Serial.println("Gagal membaca data daripada DHT11");
  } else {
    Serial.print("Suhu: ");
    Serial.print(temperature);
    Serial.print(" °C | Kelembapan: ");
    Serial.print(humidity);
    Serial.println(" %");
  }

  delay(2000);
}