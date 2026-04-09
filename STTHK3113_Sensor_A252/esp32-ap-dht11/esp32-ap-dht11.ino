// Include Wi-Fi library for ESP32
#include <WiFi.h>
#include "DHT.h"

#define DHTPIN 4
#define DHTTYPE DHT11

// Access Point credentials
const char* ssid = "Slum-ESP32-AP";
const char* password = "123456789";

DHT dht(DHTPIN, DHTTYPE);
WiFiServer server(80);

void setup() {
  Serial.begin(115200);

  Serial.print("Setting AP (Access Point)...");

  WiFi.softAP(ssid, password);

  IPAddress IP = WiFi.softAPIP();
  Serial.print("AP IP address: ");
  Serial.println(IP);

  server.begin();
  dht.begin();
}

void loop() {
  WiFiClient client = server.available();

  if (client) {
    Serial.println("New Client.");

    float h = dht.readHumidity();
    float t = dht.readTemperature();

    // ✅ FIX: Handle sensor error
    if (isnan(h) || isnan(t)) {
      Serial.println("Failed to read from DHT sensor!");
      h = 0;
      t = 0;
    }

    String currentLine = "";

    while (client.connected()) {
      if (client.available()) {

        char c = client.read();
        Serial.write(c);

        if (c == '\n') {

          if (currentLine.length() == 0) {

            // HTTP Response
            client.println("HTTP/1.1 200 OK");
            client.println("Content-type:text/html");
            client.println("Connection: close");
            client.println();

            /************ MODERN UI ************/
            client.println("<!DOCTYPE html><html>");

            client.println("<head>");
            client.println("<meta name=\"viewport\" content=\"width=device-width, initial-scale=1\">");
            client.println("<meta charset=\"UTF-8\">");
            client.println("<title>ESP32 Dashboard</title>");

            client.println("<style>");
            client.println("body { margin:0; font-family: 'Segoe UI', sans-serif; background: linear-gradient(135deg, #1e3c72, #2a5298); color:white; text-align:center; }");
            client.println(".container { padding:20px; }");
            client.println(".title { font-size:28px; font-weight:bold; margin-bottom:20px; }");
            client.println(".card { background: rgba(255,255,255,0.1); backdrop-filter: blur(10px); border-radius:15px; padding:20px; margin:15px auto; width:90%; max-width:300px; box-shadow:0 4px 15px rgba(0,0,0,0.3);} ");
            client.println(".value { font-size:36px; font-weight:bold; margin-top:10px; }");
            client.println(".label { font-size:18px; opacity:0.8; }");
            client.println(".icon { font-size:30px; }");
            client.println("</style>");

            // Auto refresh
            client.println("<script>");
            client.println("setTimeout(function(){ location.reload(); }, 3000);");
            client.println("</script>");

            client.println("</head>");

            client.println("<body>");
            client.println("<div class='container'>");

            client.println("<div class='title'>ESP32 Environment Monitor</div>");

            // Temperature Card
            client.println("<div class='card'>");
            client.println("<div class='icon'>🌡️</div>");
            client.println("<div class='label'>Temperature</div>");
            client.println("<div class='value'>" + String(t) + " °C</div>");
            client.println("</div>");

            // Humidity Card
            client.println("<div class='card'>");
            client.println("<div class='icon'>💧</div>");
            client.println("<div class='label'>Humidity</div>");
            client.println("<div class='value'>" + String(h) + " %</div>");
            client.println("</div>");

            client.println("</div>");
            client.println("</body></html>");

            client.println();
            break;

          } else {
            currentLine = "";
          }

        } else if (c != '\r') {
          currentLine += c;
        }
      }
    }

    client.stop();
    Serial.println("Client disconnected.");
    Serial.println("");
  }
}