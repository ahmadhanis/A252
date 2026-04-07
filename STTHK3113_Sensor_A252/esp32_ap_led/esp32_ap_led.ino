/************************************************************
 * PROJECT: ESP32 Access Point Web Server LED Control
 * AUTHOR : Rui Santos (modified with detailed comments)
 * SOURCE : https://randomnerdtutorials.com
 *
 * DESCRIPTION:
 * This project configures the ESP32 as a WiFi Access Point (AP)
 * and hosts a simple web server on port 80.
 *
 * Users can connect directly to the ESP32 network and control
 * an onboard LED (GPIO 2) via a web interface.
 *
 * SYSTEM FLOW:
 * 1. ESP32 creates its own WiFi Access Point
 * 2. User connects to ESP32 using SSID and password
 * 3. User opens browser and accesses ESP32 IP
 * 4. ESP32 serves a web page with ON/OFF buttons
 * 5. User clicks button → HTTP request sent
 * 6. ESP32 parses request → controls LED accordingly
 *
 * FEATURES:
 * - Local WiFi (no internet required)
 * - Simple HTTP server
 * - Real-time LED control
 * - Dynamic HTML response
 *
 ************************************************************/

// Include Wi-Fi library for ESP32
#include <WiFi.h>

// Access Point credentials
const char* ssid     = "Slum-ESP32-AP";
const char* password = "123456789";

// Create web server on port 80
WiFiServer server(80);

// Define LED pin (built-in LED usually GPIO 2)
#define LED 2

// Store incoming HTTP request
String header;

// Store LED state (for display purpose)
String ledState = "off";

void setup() {
  // Initialize serial communication (debugging)
  Serial.begin(115200);

  // Set LED pin as OUTPUT
  pinMode(LED, OUTPUT);

  // Ensure LED is OFF at startup
  digitalWrite(LED, LOW);

  // Start ESP32 as Access Point (AP mode)
  Serial.print("Setting AP (Access Point)…");

  WiFi.softAP(ssid, password);

  // Get AP IP address (usually 192.168.4.1)
  IPAddress IP = WiFi.softAPIP();
  Serial.print("AP IP address: ");
  Serial.println(IP);

  // Start the web server
  server.begin();
}

void loop(){

  // Check if any client is connected
  WiFiClient client = server.available();

  if (client) {
    Serial.println("New Client.");

    String currentLine = ""; // store current line

    while (client.connected()) {

      if (client.available()) {

        char c = client.read(); // read incoming data
        Serial.write(c);        // print to serial monitor

        header += c;            // append to header string

        // If newline received → end of HTTP request
        if (c == '\n') {

          // If blank line → request complete
          if (currentLine.length() == 0) {

            // Send HTTP response header
            client.println("HTTP/1.1 200 OK");
            client.println("Content-type:text/html");
            client.println("Connection: close");
            client.println();

            /************ HANDLE LED CONTROL ************/
            if (header.indexOf("GET /LED/on") >= 0) {
              Serial.println("LED on");
              ledState = "on";
              digitalWrite(LED, HIGH);
            } 
            else if (header.indexOf("GET /LED/off") >= 0) {
              Serial.println("LED off");
              ledState = "off";
              digitalWrite(LED, LOW);
            }

            /************ SEND HTML WEB PAGE ************/
            client.println("<!DOCTYPE html><html>");

            // Responsive settings
            client.println("<head><meta name=\"viewport\" content=\"width=device-width, initial-scale=1\">");
            client.println("<link rel=\"icon\" href=\"data:,\">");

            // CSS styling
            client.println("<style>");
            client.println("html { font-family: Helvetica; text-align: center;}");
            client.println(".button { background-color: #4CAF50; color: white; padding: 16px 40px; font-size: 30px;}");
            client.println(".button2 {background-color: #555555;}");
            client.println("</style></head>");

            // Page content
            client.println("<body><h1>ESP32 Web Server</h1>");

            // Display LED state
            client.println("<p>LED - State " + ledState + "</p>");

            // Dynamic button based on state
            if (ledState=="off") {
              client.println("<p><a href=\"/LED/on\"><button class=\"button\">ON</button></a></p>");
            } else {
              client.println("<p><a href=\"/LED/off\"><button class=\"button button2\">OFF</button></a></p>");
            }

            client.println("</body></html>");

            // End HTTP response
            client.println();

            break;
          } 
          else {
            // Reset line if not empty
            currentLine = "";
          }
        } 
        else if (c != '\r') {
          // Build current line
          currentLine += c;
        }
      }
    }

    // Clear request data
    header = "";

    // Disconnect client
    client.stop();

    Serial.println("Client disconnected.");
    Serial.println("");
  }
}