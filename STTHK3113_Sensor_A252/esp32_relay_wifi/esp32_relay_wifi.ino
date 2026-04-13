/************************************************************
 * PROJECT: ESP32 WiFi Web Server (Learning Version)
 *
 * DESCRIPTION:
 * This program demonstrates how the ESP32 connects to a WiFi
 * network and runs a basic web server that responds to HTTP
 * requests from a browser.
 *
 * LEARNING OBJECTIVES:
 * - Understand WiFi connection using ESP32 (WiFi Mode)
 * - Learn how a web server is implemented on ESP32
 * - Understand how HTTP requests are received and parsed
 * - Learn how HTML responses are sent to clients
 *
 * KEY CONCEPTS:
 * - WiFi.begin() → connects ESP32 to router
 * - WiFiServer → creates server on port 80
 * - WiFiClient → represents connected user
 * - HTTP request → read character by character
 * - HTTP response → send HTML back to browser
 *
 ************************************************************/

#include <WiFi.h>  // Include WiFi library for ESP32

// WiFi credentials (must match your router)
const char* ssid = "myUUM_Guest";
const char* password = "";

// Create web server object on port 80 (HTTP default)
WiFiServer server(80);
const int relay = 4;
bool relayState = false;  // false = OFF, true = ON
// String to store incoming HTTP request data
String header;

void setup() {

  // Start serial communication for debugging
  Serial.begin(115200);

  /************ WIFI CONNECTION ************/
  Serial.print("Connecting to WiFi...");

  // Attempt to connect to WiFi
  WiFi.begin(ssid, password);

  // Wait until connection is established
  while (WiFi.status() != WL_CONNECTED) {
    delay(500);         // wait 0.5 seconds
    Serial.print(".");  // show connection progress
  }

  Serial.println("\nWiFi connected.");

  // Display ESP32 IP address (used to access server)
  Serial.print("IP Address: ");
  Serial.println(WiFi.localIP());

  pinMode(relay, OUTPUT);
  digitalWrite(relay, LOW);
  // Start the web server
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