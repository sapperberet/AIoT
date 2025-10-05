# 🔌 ESP32 Integration Guide for Smart Home App

## 📋 Overview

This guide explains how to integrate ESP32 devices with your Smart Home app using MQTT protocol for local communication.

---

## 🏗️ Architecture

```
┌─────────────────┐         ┌─────────────────┐         ┌─────────────────┐
│   Flutter App   │◄───────►│  MQTT Broker    │◄───────►│     ESP32       │
│  (Local Mode)   │  WiFi   │ (Mosquitto/etc) │  WiFi   │   (Device)      │
└─────────────────┘         └─────────────────┘         └─────────────────┘
```

**OR**

```
┌─────────────────┐         ┌─────────────────┐
│   Flutter App   │◄───────►│    Firebase     │
│  (Cloud Mode)   │Internet │   Firestore     │
└─────────────────┘         └─────────────────┘
```

---

## 🛠️ Setup Steps

### 1. Install MQTT Broker

**Option A: Mosquitto (Recommended)**

**Windows**:
```powershell
# Download from: https://mosquitto.org/download/
# Install and start service
net start mosquitto
```

**Linux/Mac**:
```bash
# Install Mosquitto
sudo apt-get install mosquitto mosquitto-clients  # Ubuntu/Debian
brew install mosquitto  # macOS

# Start broker
sudo systemctl start mosquitto  # Linux
brew services start mosquitto   # macOS
```

**Option B: HiveMQ Cloud** (Free tier available)
- Sign up at: https://www.hivemq.com/mqtt-cloud-broker/
- Get connection details
- Use in app Settings

---

### 2. Configure App for Local Mode

1. Open the app
2. Go to **Settings** → **Connection Mode**
3. Select **Local (ESP32)**
4. Enter MQTT broker details:
   - **Broker Address**: `192.168.1.100` (your MQTT broker IP)
   - **Port**: `1883` (default MQTT port)
   - **Username**: (optional)
   - **Password**: (optional)

---

### 3. ESP32 Setup

#### Required Libraries:

Install via Arduino Library Manager:
- `WiFi` (Built-in)
- `PubSubClient` by Nick O'Leary

#### Basic ESP32 Code Template:

```cpp
#include <WiFi.h>
#include <PubSubClient.h>
#include <ArduinoJson.h>

// WiFi credentials
const char* ssid = "YOUR_WIFI_SSID";
const char* password = "YOUR_WIFI_PASSWORD";

// MQTT Broker
const char* mqtt_server = "192.168.1.100";  // Your MQTT broker IP
const int mqtt_port = 1883;

// Device Info
const char* device_id = "light_1";
const char* user_id = "YOUR_USER_ID";  // From Firebase Auth

// MQTT Topics
String topic_command;
String topic_status;
String topic_data;

WiFiClient espClient;
PubSubClient client(espClient);

// Device pins
const int RELAY_PIN = 2;  // Built-in LED or relay pin
const int STATUS_LED = 2;

// Device state
bool deviceState = false;
int brightness = 100;

void setup() {
  Serial.begin(115200);
  
  // Setup pins
  pinMode(RELAY_PIN, OUTPUT);
  pinMode(STATUS_LED, OUTPUT);
  digitalWrite(RELAY_PIN, LOW);
  
  // Setup topics
  topic_command = "smarthome/" + String(user_id) + "/devices/" + String(device_id) + "/command";
  topic_status = "smarthome/" + String(user_id) + "/devices/" + String(device_id) + "/status";
  topic_data = "smarthome/" + String(user_id) + "/devices/" + String(device_id) + "/data";
  
  // Connect to WiFi
  setup_wifi();
  
  // Setup MQTT
  client.setServer(mqtt_server, mqtt_port);
  client.setCallback(callback);
}

void setup_wifi() {
  delay(10);
  Serial.println();
  Serial.print("Connecting to ");
  Serial.println(ssid);

  WiFi.begin(ssid, password);

  while (WiFi.status() != WL_CONNECTED) {
    delay(500);
    Serial.print(".");
  }

  Serial.println("");
  Serial.println("WiFi connected");
  Serial.println("IP address: ");
  Serial.println(WiFi.localIP());
}

void callback(char* topic, byte* payload, unsigned int length) {
  Serial.print("Message arrived [");
  Serial.print(topic);
  Serial.print("] ");
  
  // Convert payload to string
  String message = "";
  for (int i = 0; i < length; i++) {
    message += (char)payload[i];
  }
  Serial.println(message);
  
  // Parse JSON command
  StaticJsonDocument<200> doc;
  DeserializationError error = deserializeJson(doc, message);
  
  if (error) {
    Serial.print("JSON parse failed: ");
    Serial.println(error.c_str());
    return;
  }
  
  // Handle commands
  const char* action = doc["action"];
  
  if (strcmp(action, "turn_on") == 0) {
    deviceState = true;
    digitalWrite(RELAY_PIN, HIGH);
    publishStatus();
  } 
  else if (strcmp(action, "turn_off") == 0) {
    deviceState = false;
    digitalWrite(RELAY_PIN, LOW);
    publishStatus();
  }
  else if (strcmp(action, "set_brightness") == 0) {
    brightness = doc["value"];
    // Implement PWM for brightness control
    analogWrite(RELAY_PIN, map(brightness, 0, 100, 0, 255));
    publishStatus();
  }
  else if (strcmp(action, "get_status") == 0) {
    publishStatus();
  }
}

void publishStatus() {
  StaticJsonDocument<200> doc;
  doc["device_id"] = device_id;
  doc["state"] = deviceState ? "on" : "off";
  doc["brightness"] = brightness;
  doc["timestamp"] = millis();
  
  String output;
  serializeJson(doc, output);
  
  client.publish(topic_status.c_str(), output.c_str());
  Serial.println("Published status: " + output);
}

void publishData() {
  StaticJsonDocument<200> doc;
  doc["device_id"] = device_id;
  doc["temperature"] = 25.5;  // Example sensor data
  doc["humidity"] = 60.0;
  doc["timestamp"] = millis();
  
  String output;
  serializeJson(doc, output);
  
  client.publish(topic_data.c_str(), output.c_str());
}

void reconnect() {
  while (!client.connected()) {
    Serial.print("Attempting MQTT connection...");
    
    // Create a random client ID
    String clientId = "ESP32Client-";
    clientId += String(random(0xffff), HEX);
    
    // Attempt to connect
    if (client.connect(clientId.c_str())) {
      Serial.println("connected");
      
      // Subscribe to command topic
      client.subscribe(topic_command.c_str());
      Serial.println("Subscribed to: " + topic_command);
      
      // Publish initial status
      publishStatus();
    } else {
      Serial.print("failed, rc=");
      Serial.print(client.state());
      Serial.println(" try again in 5 seconds");
      delay(5000);
    }
  }
}

void loop() {
  if (!client.connected()) {
    reconnect();
  }
  client.loop();
  
  // Publish data every 10 seconds
  static unsigned long lastPublish = 0;
  if (millis() - lastPublish > 10000) {
    publishData();
    lastPublish = millis();
  }
}
```

---

## 📡 MQTT Topic Structure

### Command Topic (App → ESP32)
```
smarthome/{userId}/devices/{deviceId}/command
```

**Payload Examples**:

**Turn On**:
```json
{
  "action": "turn_on"
}
```

**Turn Off**:
```json
{
  "action": "turn_off"
}
```

**Set Brightness**:
```json
{
  "action": "set_brightness",
  "value": 75
}
```

**Set Temperature**:
```json
{
  "action": "set_temperature",
  "value": 22
}
```

---

### Status Topic (ESP32 → App)
```
smarthome/{userId}/devices/{deviceId}/status
```

**Payload Example**:
```json
{
  "device_id": "light_1",
  "state": "on",
  "brightness": 75,
  "timestamp": 123456789
}
```

---

### Data Topic (ESP32 → App - Sensor Data)
```
smarthome/{userId}/devices/{deviceId}/data
```

**Payload Example**:
```json
{
  "device_id": "sensor_1",
  "temperature": 25.5,
  "humidity": 60.0,
  "pressure": 1013.25,
  "timestamp": 123456789
}
```

---

## 🔧 Device Types & Commands

### 1. Light
```cpp
// Commands
- turn_on
- turn_off
- set_brightness (0-100)
- set_color (RGB hex)

// Status
{
  "state": "on",
  "brightness": 75,
  "color": "#FF5733"
}
```

### 2. Thermostat
```cpp
// Commands
- set_temperature (value)
- set_mode ("heat", "cool", "auto", "off")

// Status
{
  "current_temp": 22.5,
  "target_temp": 24,
  "mode": "heat"
}
```

### 3. Door Lock
```cpp
// Commands
- lock
- unlock

// Status
{
  "state": "locked",
  "battery": 85
}
```

### 4. Motion Sensor
```cpp
// Data (no commands)
{
  "motion_detected": true,
  "timestamp": 123456789
}
```

### 5. Temperature Sensor
```cpp
// Data (no commands)
{
  "temperature": 25.5,
  "humidity": 60.0
}
```

---

## 🧪 Testing

### 1. Test MQTT Broker

**Subscribe to all topics**:
```bash
mosquitto_sub -h localhost -t 'smarthome/#' -v
```

**Publish test command**:
```bash
mosquitto_pub -h localhost -t 'smarthome/user123/devices/light_1/command' -m '{"action":"turn_on"}'
```

### 2. Test from App

1. Open app in Local Mode
2. Go to Devices tab
3. Toggle a device
4. Check ESP32 serial monitor for received command
5. Verify device responds

---

## 📊 Device Registration

### In Firestore (Cloud Mode)

Add device document:
```javascript
devices/{deviceId}
  ├─ userId: "user123"
  ├─ name: "Living Room Light"
  ├─ type: "light"
  ├─ roomId: "living_room"
  ├─ state: "off"
  ├─ brightness: 0
  └─ lastSeen: timestamp
```

### In App Code

```dart
final device = Device(
  id: 'light_1',
  name: 'Living Room Light',
  type: DeviceType.light,
  roomId: 'living_room',
  status: DeviceStatus.offline,
  isOn: false,
);

await deviceProvider.addDevice(device);
```

---

## 🔐 Security Best Practices

### MQTT Security

1. **Use Authentication**:
```cpp
client.connect(clientId.c_str(), "username", "password");
```

2. **Use TLS/SSL** (Port 8883):
```cpp
WiFiClientSecure espClient;
espClient.setCACert(ca_cert);
client.setServer(mqtt_server, 8883);
```

3. **Firewall Rules**:
```bash
# Allow only local network
sudo ufw allow from 192.168.1.0/24 to any port 1883
```

---

## 🐛 Troubleshooting

### ESP32 Not Connecting to WiFi
- Check SSID and password
- Verify WiFi is 2.4GHz (ESP32 doesn't support 5GHz)
- Check WiFi range

### MQTT Connection Failed
- Verify broker is running: `sudo systemctl status mosquitto`
- Check broker IP address
- Test with `mosquitto_sub` command
- Check firewall rules

### App Not Receiving Updates
- Verify app is in Local Mode
- Check MQTT broker address in Settings
- Ensure device is publishing to correct topic
- Check userId matches in topic

### Device Not Responding
- Check ESP32 serial monitor for errors
- Verify topic subscription
- Test with `mosquitto_pub` command
- Check JSON payload format

---

## 📚 Additional Resources

- [ESP32 Documentation](https://docs.espressif.com/projects/esp-idf/en/latest/esp32/)
- [PubSubClient Library](https://github.com/knolleary/pubsubclient)
- [Mosquitto Documentation](https://mosquitto.org/documentation/)
- [MQTT Protocol](https://mqtt.org/)
- [ArduinoJson](https://arduinojson.org/)

---

## 💡 Example Projects

### Simple LED Control
```cpp
// Turn on/off built-in LED via MQTT
if (action == "turn_on") {
  digitalWrite(LED_BUILTIN, HIGH);
} else if (action == "turn_off") {
  digitalWrite(LED_BUILTIN, LOW);
}
```

### PWM Brightness Control
```cpp
const int PWM_CHANNEL = 0;
const int PWM_FREQ = 5000;
const int PWM_RESOLUTION = 8;

void setup() {
  ledcSetup(PWM_CHANNEL, PWM_FREQ, PWM_RESOLUTION);
  ledcAttachPin(LED_PIN, PWM_CHANNEL);
}

void setBrightness(int brightness) {
  int dutyCycle = map(brightness, 0, 100, 0, 255);
  ledcWrite(PWM_CHANNEL, dutyCycle);
}
```

### DHT22 Temperature Sensor
```cpp
#include <DHT.h>

DHT dht(DHT_PIN, DHT22);

void publishSensorData() {
  float temp = dht.readTemperature();
  float humidity = dht.readHumidity();
  
  StaticJsonDocument<200> doc;
  doc["temperature"] = temp;
  doc["humidity"] = humidity;
  doc["timestamp"] = millis();
  
  String output;
  serializeJson(doc, output);
  client.publish(topic_data.c_str(), output.c_str());
}
```

---

## ✅ Quick Checklist

- [ ] MQTT broker installed and running
- [ ] ESP32 connected to WiFi
- [ ] MQTT topics configured correctly
- [ ] App in Local Mode with correct broker address
- [ ] Device registered in app
- [ ] Test commands working
- [ ] Status updates received in app
- [ ] Error handling implemented
- [ ] Security enabled (authentication, TLS)

---

**🎉 Your ESP32 is now ready for Smart Home control!**

For more help, check the main documentation in `IMPLEMENTATION_COMPLETE.md`
