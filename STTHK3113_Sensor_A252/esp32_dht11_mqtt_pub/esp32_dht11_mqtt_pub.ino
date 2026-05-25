#include <WiFi.h>
#include <PubSubClient.h>
#include "DHT.h"
#include <ESP32Servo.h>

// =======================
// WiFi Configuration
// =======================
const char* ssid = "myUUM_Guest";
const char* password = "";   // No password

// =======================
// MQTT Configuration
// =======================
const char* mqtt_server = "10.19.28.53";
const int mqtt_port = 1883;

// MQTT publish topics
const char* topic_temperature = "esp32/dht11/temperature";
const char* topic_humidity    = "esp32/dht11/humidity";
const char* topic_status      = "esp32/status";

// MQTT subscribe topic for servo
const char* topic_servo_control = "esp32/servo/control";
const char* topic_servo_status  = "esp32/servo/status";

// =======================
// DHT11 Configuration
// =======================
#define DHTPIN 4
#define DHTTYPE DHT11

DHT dht(DHTPIN, DHTTYPE);

// =======================
// Servo Configuration
// =======================
#define SERVO_PIN 13

Servo myServo;

const int SERVO_CLOSE = 0;
const int SERVO_OPEN  = 90;

int currentServoAngle = SERVO_CLOSE;

// =======================
// MQTT Client
// =======================
WiFiClient espClient;
PubSubClient client(espClient);

// Send DHT data every 5 seconds
unsigned long previousMillis = 0;
const long interval = 5000;

// =======================
// Connect to WiFi
// =======================
void setup_wifi() {
  delay(10);

  Serial.println();
  Serial.print("Connecting to WiFi: ");
  Serial.println(ssid);

  WiFi.begin(ssid, password);

  while (WiFi.status() != WL_CONNECTED) {
    delay(500);
    Serial.print(".");
  }

  Serial.println();
  Serial.println("WiFi connected.");
  Serial.print("ESP32 IP address: ");
  Serial.println(WiFi.localIP());
}

// =======================
// Publish Servo Status
// =======================
void publishServoStatus(String message) {
  client.publish(topic_servo_status, message.c_str());

  Serial.print("Servo Status: ");
  Serial.println(message);
}

// =======================
// Move Servo
// =======================
void moveServoTo(int angle) {
  if (angle < 0) {
    angle = 0;
  }

  if (angle > 180) {
    angle = 180;
  }

  myServo.write(angle);
  currentServoAngle = angle;

  String statusMessage = "Servo moved to " + String(angle) + " degrees";
  publishServoStatus(statusMessage);
}

// =======================
// MQTT Callback
// This runs when ESP32 receives MQTT message
// =======================
void mqttCallback(char* topic, byte* payload, unsigned int length) {
  String message = "";

  for (unsigned int i = 0; i < length; i++) {
    message += (char)payload[i];
  }

  message.trim();

  Serial.print("Message received from topic: ");
  Serial.println(topic);

  Serial.print("Message: ");
  Serial.println(message);

  if (String(topic) == topic_servo_control) {
    if (message == "OPEN" || message == "open") {
      moveServoTo(SERVO_OPEN);
    } 
    else if (message == "CLOSE" || message == "close") {
      moveServoTo(SERVO_CLOSE);
    } 
    else {
      int angle = message.toInt();

      if (angle >= 0 && angle <= 180) {
        moveServoTo(angle);
      } else {
        publishServoStatus("Invalid servo command");
      }
    }
  }
}

// =======================
// Reconnect to MQTT Broker
// =======================
void reconnect_mqtt() {
  while (!client.connected()) {
    Serial.print("Connecting to MQTT broker... ");

    String clientId = "ESP32_DHT11_SERVO_";
    clientId += String(random(0xffff), HEX);

    if (client.connect(clientId.c_str())) {
      Serial.println("connected.");

      client.publish(topic_status, "ESP32 connected to MQTT broker");

      client.subscribe(topic_servo_control);

      Serial.print("Subscribed to: ");
      Serial.println(topic_servo_control);

    } else {
      Serial.print("failed, rc=");
      Serial.print(client.state());
      Serial.println(" retrying in 5 seconds...");
      delay(5000);
    }
  }
}

// =======================
// Setup
// =======================
void setup() {
  Serial.begin(115200);

  dht.begin();

  myServo.setPeriodHertz(50);
  myServo.attach(SERVO_PIN, 500, 2400);
  myServo.write(SERVO_CLOSE);

  setup_wifi();

  client.setServer(mqtt_server, mqtt_port);
  client.setCallback(mqttCallback);

  Serial.println("ESP32 DHT11 MQTT Servo started.");
}

// =======================
// Main Loop
// =======================
void loop() {
  if (!client.connected()) {
    reconnect_mqtt();
  }

  client.loop();

  unsigned long currentMillis = millis();

  if (currentMillis - previousMillis >= interval) {
    previousMillis = currentMillis;

    float humidity = dht.readHumidity();
    float temperature = dht.readTemperature();

    if (isnan(humidity) || isnan(temperature)) {
      Serial.println("Failed to read from DHT11 sensor.");
      client.publish(topic_status, "Failed to read DHT11 sensor");
      return;
    }

    char tempString[8];
    char humString[8];

    dtostrf(temperature, 1, 2, tempString);
    dtostrf(humidity, 1, 2, humString);

    Serial.print("Temperature: ");
    Serial.print(tempString);
    Serial.println(" °C");

    Serial.print("Humidity: ");
    Serial.print(humString);
    Serial.println(" %");

    client.publish(topic_temperature, tempString);
    client.publish(topic_humidity, humString);

    Serial.println("DHT11 data published to MQTT.");
    Serial.println("-------------------------");
  }
}