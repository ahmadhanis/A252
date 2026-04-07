/************************************************************
 * PROJECT: ESP32 WiFi Web Server (Learning Version)
 *
 * DESCRIPTION:
 * This program demonstrates how the ESP32 connects to a WiFi
 * network and runs a basic web server that responds to HTTP
 * requests from a browser.
 *
 * LEARNING OBJECTIVES:
 * - Understand WiFi connection using ESP32 (Station Mode)
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

#include <WiFi.h>   // Include WiFi library for ESP32

// WiFi credentials (must match your router)
const char* ssid     = "YOUR_WIFI_NAME";
const char* password = "YOUR_WIFI_PASSWORD";

// Create web server object on port 80 (HTTP default)
WiFiServer server(80);

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
    delay(500);              // wait 0.5 seconds
    Serial.print(".");       // show connection progress
  }

  Serial.println("\nWiFi connected.");

  // Display ESP32 IP address (used to access server)
  Serial.print("IP Address: ");
  Serial.println(WiFi.localIP());

  // Start the web server
  server.begin();
}

void loop(){

  // Check if a client (browser/user) is connecting
  WiFiClient client = server.available();

  // If a new client connects
  if (client) {
    Serial.println("New Client connected.");

    String currentLine = "";   // stores current line of request

    // Loop while client remains connected
    while (client.connected()) {

      // Check if client has sent data
      if (client.available()) {

        char c = client.read();     // read one character from request
        Serial.write(c);            // print for debugging

        header += c;                // store full request

        // Detect end of line (newline character)
        if (c == '\n') {

          // If blank line → end of HTTP request
          if (currentLine.length() == 0) {

            /************ SEND HTTP RESPONSE ************/

            // Send HTTP status code (200 = OK)
            client.println("HTTP/1.1 200 OK");

            // Specify content type as HTML
            client.println("Content-type:text/html");

            // Close connection after response
            client.println("Connection: close");
            client.println();

            /************ HTML CONTENT ************/

            // Send simple HTML page to browser
            client.println("<!DOCTYPE html><html>");
            client.println("<head><title>ESP32 Web Server</title></head>");
            client.println("<body>");
            client.println("<h1>ESP32 Web Server</h1>");
            client.println("<p>This is a simple response from ESP32</p>");
            client.println("</body></html>");

            client.println();   // end of response

            break;              // exit loop after sending response
          } 
          else {
            // Reset line if not empty
            currentLine = "";
          }
        } 
        else if (c != '\r') {
          // Add character to current line (ignore carriage return)
          currentLine += c;
        }
      }
    }

    // Clear stored request for next client
    header = "";

    // Close client connection
    client.stop();

    Serial.println("Client disconnected.");
  }
}