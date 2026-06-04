#include <WiFi.h>
#include <WebServer.h>
#include <DNSServer.h>
#include <Preferences.h>

Preferences preferences;
WebServer server(80);
DNSServer dnsServer;

const byte DNS_PORT = 53;

// BOOT button is usually GPIO 0
#define BOOT_BUTTON 0

// AP mode details
String apSSID;
const char* apPassword = "12345678";

// Saved configuration
String wifiSSID;
String wifiPassword;
String deviceID;

bool apMode = false;

// WiFi connection timeout
const unsigned long WIFI_TIMEOUT = 15000;

// BOOT long press duration while running
const unsigned long LONG_PRESS_TIME = 3000;

unsigned long bootPressStart = 0;
bool bootPressed = false;

// ===============================
// HTML CONFIG PAGE
// ===============================
String getConfigPage() {
  String html = R"rawliteral(
<!DOCTYPE html>
<html>
<head>
  <title>ESP32 WiFi Configuration</title>
  <meta name="viewport" content="width=device-width, initial-scale=1">

  <style>
    body {
      font-family: Arial, sans-serif;
      background: #f4f6f8;
      padding: 20px;
    }

    .container {
      max-width: 430px;
      margin: auto;
      background: #ffffff;
      padding: 25px;
      border-radius: 14px;
      box-shadow: 0 4px 14px rgba(0,0,0,0.15);
    }

    h2 {
      text-align: center;
      color: #222;
    }

    .info {
      background: #eef5ff;
      padding: 12px;
      border-radius: 8px;
      font-size: 14px;
      margin-bottom: 15px;
      line-height: 1.5;
    }

    label {
      font-weight: bold;
      display: block;
      margin-top: 15px;
    }

    input {
      width: 100%;
      padding: 12px;
      margin-top: 6px;
      border: 1px solid #ccc;
      border-radius: 8px;
      box-sizing: border-box;
      font-size: 15px;
    }

    button {
      width: 100%;
      margin-top: 22px;
      padding: 12px;
      background: #007bff;
      color: white;
      border: none;
      border-radius: 8px;
      font-size: 16px;
      cursor: pointer;
    }

    button:hover {
      background: #0056b3;
    }

    .danger {
      background: #dc3545;
    }

    .danger:hover {
      background: #a71d2a;
    }
  </style>
</head>

<body>
  <div class="container">
    <h2>ESP32 WiFi Setup</h2>

    <div class="info">
      Enter your WiFi SSID, password, and Device ID.<br>
      The ESP32 will save this data into memory and restart.
    </div>

    <form action="/save" method="POST">
      <label>WiFi SSID</label>
      <input type="text" name="ssid" required value=")rawliteral";

  html += wifiSSID;

  html += R"rawliteral(">

      <label>WiFi Password</label>
      <input type="password" name="password" value=")rawliteral";

  html += wifiPassword;

  html += R"rawliteral(">

      <label>Device ID</label>
      <input type="text" name="deviceid" required value=")rawliteral";

  html += deviceID;

  html += R"rawliteral(">

      <button type="submit">Save Configuration</button>
    </form>

    <form action="/clear" method="POST">
      <button class="danger" type="submit">Clear Configuration</button>
    </form>
  </div>
</body>
</html>
)rawliteral";

  return html;
}

// ===============================
// LOAD CONFIGURATION
// ===============================
void loadConfig() {
  preferences.begin("wifi-config", true);

  wifiSSID = preferences.getString("ssid", "");
  wifiPassword = preferences.getString("password", "");
  deviceID = preferences.getString("deviceid", "");

  preferences.end();

  Serial.println();
  Serial.println("Loaded saved configuration:");
  Serial.println("SSID: " + wifiSSID);
  Serial.println("Device ID: " + deviceID);
}

// ===============================
// SAVE CONFIGURATION
// ===============================
void saveConfig(String ssid, String password, String devID) {
  preferences.begin("wifi-config", false);

  preferences.putString("ssid", ssid);
  preferences.putString("password", password);
  preferences.putString("deviceid", devID);

  preferences.end();

  Serial.println("Configuration saved.");
}

// ===============================
// CLEAR CONFIGURATION
// ===============================
void clearConfig() {
  preferences.begin("wifi-config", false);
  preferences.clear();
  preferences.end();

  Serial.println("Configuration cleared.");
}

// ===============================
// CONNECT TO WIFI
// ===============================
bool connectToWiFi() {
  if (wifiSSID == "") {
    Serial.println("No saved WiFi SSID.");
    return false;
  }

  Serial.println();
  Serial.println("Trying to connect to saved WiFi...");
  Serial.println("SSID: " + wifiSSID);

  WiFi.mode(WIFI_STA);
  WiFi.begin(wifiSSID.c_str(), wifiPassword.c_str());

  unsigned long startAttemptTime = millis();

  while (WiFi.status() != WL_CONNECTED &&
         millis() - startAttemptTime < WIFI_TIMEOUT) {
    Serial.print(".");
    delay(500);
  }

  Serial.println();

  if (WiFi.status() == WL_CONNECTED) {
    Serial.println("WiFi connected.");
    Serial.print("IP Address: ");
    Serial.println(WiFi.localIP());
    Serial.print("Device ID: ");
    Serial.println(deviceID);
    return true;
  }

  Serial.println("WiFi connection failed.");
  return false;
}

// ===============================
// START AP CONFIG MODE
// ===============================
void startAPMode() {
  apMode = true;

  WiFi.disconnect(true);
  delay(500);

  uint64_t chipid = ESP.getEfuseMac();
  apSSID = "ESP32_Config_" + String((uint32_t)(chipid & 0xFFFFFFFF), HEX);

  WiFi.mode(WIFI_AP);
  WiFi.softAP(apSSID.c_str(), apPassword);

  IPAddress apIP = WiFi.softAPIP();

  Serial.println();
  Serial.println("=================================");
  Serial.println("AP CONFIG MODE STARTED");
  Serial.println("Connect to this WiFi:");
  Serial.println("SSID: " + apSSID);
  Serial.println("Password: " + String(apPassword));
  Serial.print("Open browser: ");
  Serial.println(apIP);
  Serial.println("=================================");

  dnsServer.start(DNS_PORT, "*", apIP);

  server.on("/", HTTP_GET, []() {
    server.send(200, "text/html", getConfigPage());
  });

  server.on("/save", HTTP_POST, []() {
    String ssid = server.arg("ssid");
    String password = server.arg("password");
    String devID = server.arg("deviceid");

    ssid.trim();
    password.trim();
    devID.trim();

    if (ssid.length() == 0 || devID.length() == 0) {
      server.send(400, "text/html", "<h2>Error</h2><p>SSID and Device ID are required.</p>");
      return;
    }

    saveConfig(ssid, password, devID);

    server.send(200, "text/html",
                "<h2>Configuration Saved</h2><p>ESP32 will restart and connect to WiFi.</p>");

    delay(2000);
    ESP.restart();
  });

  server.on("/clear", HTTP_POST, []() {
    clearConfig();

    server.send(200, "text/html",
                "<h2>Configuration Cleared</h2><p>ESP32 will restart.</p>");

    delay(2000);
    ESP.restart();
  });

  server.onNotFound([]() {
    server.sendHeader("Location", "/", true);
    server.send(302, "text/plain", "");
  });

  server.begin();
  Serial.println("Web server started.");
}

// ===============================
// CHECK BOOT BUTTON LONG PRESS
// ===============================
void checkBootButtonLongPress() {
  int buttonState = digitalRead(BOOT_BUTTON);

  if (buttonState == LOW && !bootPressed) {
    bootPressed = true;
    bootPressStart = millis();
    Serial.println("BOOT button pressed...");
  }

  if (buttonState == LOW && bootPressed) {
    if (millis() - bootPressStart >= LONG_PRESS_TIME) {
      Serial.println("BOOT button long press detected.");
      Serial.println("Restarting into AP configuration mode...");

      clearConfig();
      delay(1000);
      ESP.restart();
    }
  }

  if (buttonState == HIGH && bootPressed) {
    bootPressed = false;
    bootPressStart = 0;
    Serial.println("BOOT button released.");
  }
}

// ===============================
// SETUP
// ===============================
void setup() {
  Serial.begin(115200);
  delay(1000);

  pinMode(BOOT_BUTTON, INPUT_PULLUP);

  Serial.println();
  Serial.println("ESP32 WiFi Configuration System");

  loadConfig();

  // Check BOOT button during startup
  if (digitalRead(BOOT_BUTTON) == LOW) {
    Serial.println("BOOT button held during startup.");
    Serial.println("Starting AP configuration mode.");
    startAPMode();
    return;
  }

  // If no saved configuration
  if (wifiSSID == "" || deviceID == "") {
    Serial.println("No saved configuration found.");
    startAPMode();
    return;
  }

  // Try connect to saved WiFi
  bool connected = connectToWiFi();

  if (!connected) {
    Serial.println("WiFi failed. Starting AP configuration mode.");
    startAPMode();
    return;
  }

  Serial.println("Normal operation mode started.");
}

// ===============================
// LOOP
// ===============================
void loop() {
  if (apMode) {
    dnsServer.processNextRequest();
    server.handleClient();
  } else {
    checkBootButtonLongPress();

    static unsigned long lastPrint = 0;

    if (millis() - lastPrint >= 5000) {
      lastPrint = millis();

      Serial.println();
      Serial.println("Normal Mode");
      Serial.print("Device ID: ");
      Serial.println(deviceID);
      Serial.print("WiFi IP: ");
      Serial.println(WiFi.localIP());
    }

    if (WiFi.status() != WL_CONNECTED) {
      Serial.println("WiFi disconnected. Restarting...");
      delay(2000);
      ESP.restart();
    }
  }
}