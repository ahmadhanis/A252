#include <WiFi.h>

// Access Point credentials
const char* ssid = "Slum-ESP32-AP";
const char* password = "123456789";

WiFiServer server(80);

const int relay = 4;
bool relayState = false; // false = OFF, true = ON

void setup() {
  Serial.begin(115200);

  WiFi.softAP(ssid, password);
  IPAddress IP = WiFi.softAPIP();
  Serial.print("AP IP address: ");
  Serial.println(IP);

  pinMode(relay, OUTPUT);
  digitalWrite(relay, LOW);

  server.begin();
}

void loop() {
  WiFiClient client = server.available();

  if (client) {
    Serial.println("New Client.");
    String header = "";

    while (client.connected()) {
      if (client.available()) {

        char c = client.read();
        header += c;

        // Detect end of request
        if (c == '\n') {

          // =====================
          // CHECK BUTTON ACTION
          // =====================
          if (header.indexOf("GET /on") >= 0) {
            relayState = true;
            digitalWrite(relay, HIGH);
            Serial.println("Relay ON");
          }

          if (header.indexOf("GET /off") >= 0) {
            relayState = false;
            digitalWrite(relay, LOW);
            Serial.println("Relay OFF");
          }

          // =====================
          // SEND RESPONSE
          // =====================
          client.println("HTTP/1.1 200 OK");
          client.println("Content-type:text/html");
          client.println("Connection: close");
          client.println();

          // HTML UI
          client.println("<!DOCTYPE html><html>");
          client.println("<head>");
          client.println("<meta name='viewport' content='width=device-width, initial-scale=1'>");
          client.println("<meta charset='UTF-8'>");
          client.println("<title>ESP32 Relay Control</title>");

          // STYLE
          client.println("<style>");
          client.println("body { margin:0; font-family: 'Segoe UI'; background: linear-gradient(135deg,#1e3c72,#2a5298); color:white; text-align:center; }");
          client.println(".container { padding:20px; }");
          client.println(".card { background: rgba(255,255,255,0.1); backdrop-filter: blur(10px); border-radius:15px; padding:20px; margin:auto; width:90%; max-width:300px; box-shadow:0 4px 15px rgba(0,0,0,0.3);} ");
          client.println(".status { font-size:22px; margin:15px 0; }");
          client.println(".on { color: #00ff9f; }");
          client.println(".off { color: #ff4d4d; }");
          client.println("button { padding:12px 25px; margin:10px; border:none; border-radius:10px; font-size:16px; cursor:pointer; }");
          client.println(".btn-on { background:#00c853; color:white; }");
          client.println(".btn-off { background:#d50000; color:white; }");
          client.println("</style>");

          client.println("</head>");
          client.println("<body>");
          client.println("<div class='container'>");

          client.println("<div class='card'>");
          client.println("<h2>ESP32 Relay</h2>");

          // SHOW STATUS
          if (relayState) {
            client.println("<div class='status on'>Status: ON</div>");
          } else {
            client.println("<div class='status off'>Status: OFF</div>");
          }

          // BUTTONS
          client.println("<a href='/on'><button class='btn-on'>Turn ON</button></a>");
          client.println("<a href='/off'><button class='btn-off'>Turn OFF</button></a>");

          client.println("</div>");
          client.println("</div>");
          client.println("</body></html>");

          client.println();
          break;
        }
      }
    }

    client.stop();
    Serial.println("Client disconnected.");
  }
}