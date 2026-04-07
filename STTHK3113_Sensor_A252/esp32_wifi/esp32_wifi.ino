/************************************************************
 * PROJECT: ESP32 WiFi Web Server (Educational Version)
 *
 * PURPOSE:
 * This code demonstrates how an ESP32 connects to a WiFi
 * network and creates a simple web server that can handle
 * HTTP requests from a browser.
 *
 * LEARNING OBJECTIVES:
 * - Understand how ESP32 connects to WiFi (Station Mode)
 * - Learn how a basic web server works on ESP32
 * - Understand how HTTP requests are received and processed
 * - Learn client-server interaction in IoT systems
 *
 * KEY CONCEPTS:
 * 1. WiFi.begin() → Connect to router
 * 2. WiFiServer → Create a web server
 * 3. WiFiClient → Handle incoming users
 * 4. HTTP request parsing using String
 * 5. Sending HTML response to browser
 *
 ************************************************************/

#include <WiFi.h>   // Library to handle WiFi functions

// WiFi credentials (must match your router)
const char* ssid     = "YOUR_WIFI_NAME";
const char* password = "YOUR_WIFI_PASSWORD";

// Create a server object on port 80 (standard HTTP port)
WiFiServer server(80);

// String to store incoming HTTP request
String header;

void setup() {

  // Start serial communication (used for debugging)
  Serial.begin(115200);

  /************ CONNECT TO WIFI ************/
  Serial.print("Connecting to WiFi...");

  // Attempt to connect to WiFi network
  WiFi.begin(ssid, password);

  // Keep checking until connection is successful
  while (WiFi.status() != WL_CONNECTED) {
    delay(500);              // wait 0.5 seconds
    Serial.print(".");       // show progress
  }

  Serial.println("\nWiFi connected.");

  // Print the assigned IP address (important to access server)
  Serial.print("IP Address: ");
  Serial.println(WiFi.localIP());

  // Start the web server
  server.begin();
}

void loop(){

  // Check if a client (user) has connected to the server
  WiFiClient client = server.available();

  // If a new client is connected
  if (client) {
    Serial.println("New Client connected.");

    String currentLine = "";   // store current line of request

    // While the client is still connected
    while (client.connected()) {

      // If there is data available from client
      if (client.available()) {

        char c = client.read();     // read one character
        Serial.write(c);            // print it (debugging)

        header += c;                // store character in header

        // If newline character is received
        if (c == '\n') {

          // If current line is empty → end of HTTP request
          if (currentLine.length() == 0) {

            /************ SEND RESPONSE ************/

            // Send HTTP response status
            client.println("HTTP/1.1 200 OK");

            // Inform browser that content is HTML
            client.println("Content-type:text/html");

            // Close connection after response
            client.println("Connection: close");
            client.println();

            // Send simple HTML page
            client.println("<!DOCTYPE html><html>");
            client.println("<head><title>ESP32 Web Server</title></head>");
            client.println("<body><h1>Hello from ESP32</h1></body>");
            client.println("</html>");

            client.println();   // end of response

            break;              // exit loop after response
          } 
          else {
            // Reset current line if not empty
            currentLine = "";
          }
        } 
        else if (c != '\r') {
          // Add character to current line (ignore carriage return)
          currentLine += c;
        }
      }
    }

    // Clear header for next request
    header = "";

    // Close connection with client
    client.stop();

    Serial.println("Client disconnected.");
  }
}