# Smart Home IoT Application

A comprehensive Flutter-based smart home mobile application with ESP32 integration, 3D home visualization, and dual local/cloud control capabilities.

## 🏗️ Project Overview

This application provides:
- **User Authentication** with Firebase
- **Real-time IoT Control** via MQTT (local) and Firestore (cloud)
- **3D Home Visualization** using three.js with interactive alarm indicators
- **Full-duplex Communication** with ESP32 devices
- **Computer Vision Integration** support
- **Event Logging** and alarm management

## 🎯 Features

### 1. Authentication System
- Email/password registration and login
- Firebase Authentication integration
- User profile management
- Secure session handling

### 2. IoT Device Control
- Real-time device status monitoring
- Control lights, locks, sensors, and more
- Automatic failover between local (MQTT) and cloud (Firestore)
- Support for multiple device types: lights, alarms, sensors, cameras, thermostats, locks

### 3. 3D Home Visualization
- Interactive 3D model of your home
- Real-time alarm visualization by room
- Click-to-control room devices
- Visual alerts with color-coded severity (critical: red, warning: orange, info: blue)
- CAD/SolidWorks model import support (glTF format)

### 4. Dual Communication Modes
- **Local Mode**: Direct MQTT communication with ESP32 on local network
- **Cloud Mode**: Firebase Firestore for remote control when not on local network
- Automatic connectivity detection and mode switching

### 5. Alarm & Event Management
- Real-time alarm notifications
- Categorized alarms (fire, motion, door, etc.)
- Alarm acknowledgment system
- Complete event logging

## 📋 Prerequisites

Before you begin, ensure you have:

- **Flutter SDK**: 3.0.0 or higher
- **Dart**: 3.0.0 or higher
- **Android Studio** or **VS Code** with Flutter extensions
- **Firebase Account**: For authentication and cloud services
- **MQTT Broker**: Mosquitto on Raspberry Pi or cloud broker (optional for local mode)
- **ESP32 Device(s)**: With appropriate sensors and actuators

## 🚀 Getting Started

### Step 1: Clone and Install Dependencies

```bash
cd AIoT
flutter pub get
```

### Step 2: Firebase Setup

1. **Create a Firebase Project**
   - Go to [Firebase Console](https://console.firebase.google.com/)
   - Create a new project
   - Enable **Authentication** (Email/Password)
   - Enable **Cloud Firestore**

2. **Configure Firebase for Your Platforms**

   **For Android:**
   ```bash
   flutter pub global activate flutterfire_cli
   flutterfire configure
   ```

   Or manually:
   - Download `google-services.json` from Firebase Console
   - Place it in `android/app/`

   **For iOS:**
   - Download `GoogleService-Info.plist`
   - Add it to your Xcode project

3. **Update Firebase Configuration**
   - Open `lib/core/config/firebase_options.dart`
   - Replace placeholder values with your Firebase configuration

### Step 3: MQTT Broker Setup (Local Mode)

**Option A: Mosquitto on Raspberry Pi**

```bash
# On Raspberry Pi
sudo apt update
sudo apt install mosquitto mosquitto-clients
sudo systemctl enable mosquitto
sudo systemctl start mosquitto
```

**Option B: Cloud MQTT Broker**
- Use services like [HiveMQ Cloud](https://www.hivemq.com/mqtt-cloud-broker/) or [CloudMQTT](https://www.cloudmqtt.com/)

**Update Configuration:**
- Open `lib/core/config/mqtt_config.dart`
- Update `localBrokerAddress` with your MQTT broker IP
- Optionally configure cloud broker settings

### Step 4: Firestore Database Structure

Create the following Firestore collections:

```
users/
  {userId}/
    - email
    - displayName
    - createdAt
    - preferences
    
    devices/
      {deviceId}/
        - id
        - name
        - type (light, alarm, sensor, etc.)
        - room
        - status
        - state
        - lastUpdated
        
        commands/ (sub-collection)
          {commandId}/
            - action
            - state
            - timestamp
            - executed
    
    alarms/
      {alarmId}/
        - location
        - type
        - severity
        - message
        - timestamp
        - acknowledged
    
    logs/
      {logId}/
        - event
        - data
        - timestamp
```

### Step 5: Run the Application

```bash
flutter run
```

## 🔌 ESP32 Integration

### ESP32 Setup

1. **Install Required Libraries**
   - `PubSubClient` for MQTT
   - `ArduinoJson` for JSON handling
   - `WiFi` for network connectivity
   - (Optional) `FirebaseESP32` for cloud mode

2. **Example ESP32 Code** (Arduino/PlatformIO)

```cpp
#include <WiFi.h>
#include <PubSubClient.h>
#include <ArduinoJson.h>

// WiFi credentials
const char* ssid = "YOUR_WIFI_SSID";
const char* password = "YOUR_WIFI_PASSWORD";

// MQTT Broker
const char* mqtt_server = "192.168.1.100"; // Your broker IP
const int mqtt_port = 1883;
const char* mqtt_client_id = "esp32-device-01";

// Topics
const char* status_topic = "home/living_room/light/status";
const char* command_topic = "home/living_room/light/set";

WiFiClient espClient;
PubSubClient client(espClient);

// LED pin
const int LED_PIN = 2;
bool ledState = false;

void setup() {
  Serial.begin(115200);
  pinMode(LED_PIN, OUTPUT);
  
  // Connect to WiFi
  WiFi.begin(ssid, password);
  while (WiFi.status() != WL_CONNECTED) {
    delay(500);
    Serial.print(".");
  }
  Serial.println("\nWiFi connected");
  
  // Setup MQTT
  client.setServer(mqtt_server, mqtt_port);
  client.setCallback(mqttCallback);
  
  connectMQTT();
}

void loop() {
  if (!client.connected()) {
    connectMQTT();
  }
  client.loop();
  
  // Publish status every 10 seconds
  static unsigned long lastPublish = 0;
  if (millis() - lastPublish > 10000) {
    publishStatus();
    lastPublish = millis();
  }
}

void connectMQTT() {
  while (!client.connected()) {
    Serial.print("Connecting to MQTT...");
    if (client.connect(mqtt_client_id)) {
      Serial.println("connected");
      client.subscribe(command_topic);
      publishStatus();
    } else {
      Serial.print("failed, rc=");
      Serial.println(client.state());
      delay(5000);
    }
  }
}

void mqttCallback(char* topic, byte* payload, unsigned int length) {
  Serial.print("Message received on ");
  Serial.println(topic);
  
  // Parse JSON
  StaticJsonDocument<200> doc;
  deserializeJson(doc, payload, length);
  
  String action = doc["action"];
  String state = doc["state"];
  
  if (action == "toggle" || action == "set") {
    ledState = (state == "on");
    digitalWrite(LED_PIN, ledState ? HIGH : LOW);
    publishStatus();
  }
}

void publishStatus() {
  StaticJsonDocument<200> doc;
  doc["state"] = ledState ? "on" : "off";
  doc["device"] = "living_room_light";
  doc["timestamp"] = millis();
  
  char buffer[256];
  serializeJson(doc, buffer);
  
  client.publish(status_topic, buffer);
  Serial.println("Status published");
}

// Fire alarm example
void triggerFireAlarm() {
  StaticJsonDocument<200> doc;
  doc["alarm"] = true;
  doc["severity"] = "critical";
  doc["message"] = "Fire detected in garage!";
  
  char buffer[256];
  serializeJson(doc, buffer);
  
  client.publish("home/garage/fire_alarm", buffer);
}
```

### MQTT Topic Structure

The app uses the following topic convention:

```
home/{room}/{device_type}/{action}

Examples:
- home/living_room/light/status      (ESP32 publishes)
- home/living_room/light/set          (App publishes, ESP32 subscribes)
- home/garage/fire_alarm              (ESP32 publishes alarms)
- home/bedroom/motion                 (ESP32 publishes motion detection)
- home/front_door/door                (ESP32 publishes door status)
```

## 🎨 3D Visualization Setup

### Preparing Your CAD Model

1. **Export from CAD/SolidWorks**
   - Export your home model as STL or OBJ

2. **Convert to glTF Format**
   - Use [Blender](https://www.blender.org/):
     - Import your STL/OBJ file
     - Name each room mesh clearly (e.g., "living_room", "garage", "kitchen")
     - Simplify geometry if needed
     - Export as glTF 2.0 (.glb format recommended)

3. **Add to Your Project**
   - Place the `.glb` file in `assets/3d/home_model.glb`
   - Update `assets/web/home_visualization.html` to load it (uncomment the GLTFLoader section)

### Room Naming Convention

Name your room meshes in the 3D model to match your device locations:
- `living_room`
- `kitchen`
- `bedroom`
- `garage`
- `bathroom`
- etc.

This ensures alarms are displayed on the correct rooms.

## 🌐 Computer Vision Integration

The app is designed to receive processed data from computer vision services. Here's how to integrate:

### API Integration Example

```dart
// Add to lib/core/services/cv_service.dart

class ComputerVisionService {
  final String apiEndpoint = 'YOUR_CV_API_ENDPOINT';
  
  Future<void> sendFrame(File imageFile) async {
    final request = http.MultipartRequest('POST', Uri.parse(apiEndpoint));
    request.files.add(await http.MultipartFile.fromPath('image', imageFile.path));
    
    final response = await request.send();
    final responseData = await response.stream.bytesToString();
    
    // Process CV results
    final data = jsonDecode(responseData);
    handleCVResults(data);
  }
  
  void handleCVResults(Map<String, dynamic> data) {
    // If person detected, trigger alarm
    if (data['person_detected'] == true) {
      // Send to device provider as if from ESP32
      final alarm = AlarmEvent(
        id: DateTime.now().toString(),
        location: data['camera_location'],
        type: 'motion',
        severity: 'warning',
        message: 'Person detected by camera',
        timestamp: DateTime.now(),
      );
      // Add to Firestore or publish via MQTT
    }
  }
}
```

## 📱 App Architecture

```
lib/
├── main.dart                          # App entry point
├── core/
│   ├── config/
│   │   ├── firebase_options.dart      # Firebase configuration
│   │   └── mqtt_config.dart           # MQTT configuration
│   ├── models/
│   │   ├── device_model.dart          # Device and Alarm models
│   │   └── user_model.dart            # User model
│   ├── services/
│   │   ├── auth_service.dart          # Firebase auth
│   │   ├── mqtt_service.dart          # MQTT client
│   │   └── firestore_service.dart     # Firestore operations
│   └── providers/
│       ├── auth_provider.dart         # Auth state management
│       ├── device_provider.dart       # Device state management
│       └── home_visualization_provider.dart  # 3D viz state
└── ui/
    └── screens/
        ├── splash_screen.dart
        ├── auth/
        │   ├── login_screen.dart
        │   └── register_screen.dart
        └── home/
            ├── home_screen.dart
            ├── devices_tab.dart       # Device control UI
            ├── visualization_tab.dart  # 3D home view
            └── logs_tab.dart          # Event logs
```

## 🔧 Configuration Files

### Important Configuration Points

1. **`lib/core/config/firebase_options.dart`**
   - Replace with your Firebase credentials

2. **`lib/core/config/mqtt_config.dart`**
   - Update `localBrokerAddress` with your MQTT broker IP
   - Configure topic structure as needed

3. **`pubspec.yaml`**
   - All dependencies are pre-configured
   - Run `flutter pub get` after any changes

## 🐛 Troubleshooting

### Common Issues

**1. Firebase connection fails**
- Verify `firebase_options.dart` has correct credentials
- Check Firebase project settings
- Ensure SHA-1/SHA-256 fingerprints are added (Android)

**2. MQTT not connecting**
- Verify broker IP address in `mqtt_config.dart`
- Check if broker is running: `sudo systemctl status mosquitto`
- Test with MQTT Explorer desktop app
- Ensure device is on same network (local mode)

**3. 3D model not loading**
- Check file path in `home_visualization.html`
- Verify `.glb` file is in `assets/3d/`
- Check browser console in WebView for errors
- Ensure model meshes are named correctly

**4. WebView shows blank screen**
- Enable JavaScript in WebView settings
- Check for console errors
- Verify three.js CDN links are accessible

## 📊 Testing

### Manual Testing Checklist

- [ ] User registration and login
- [ ] MQTT connection status indicator
- [ ] Device control (toggle lights)
- [ ] Alarm notifications
- [ ] 3D visualization loads
- [ ] Room interaction in 3D view
- [ ] Alarm visualization in 3D
- [ ] Log viewing
- [ ] Cloud/local mode switching

### Using MQTT Explorer for Testing

1. Download [MQTT Explorer](http://mqtt-explorer.com/)
2. Connect to your broker
3. Publish test messages:
   ```json
   Topic: home/garage/fire_alarm
   Payload: {"alarm": true, "severity": "critical", "message": "Fire detected!"}
   ```
4. Verify app receives and displays the alarm

## 🚀 Deployment

### Android

```bash
flutter build apk --release
# APK will be in build/app/outputs/flutter-apk/
```

### iOS

```bash
flutter build ios --release
# Open in Xcode for final signing and distribution
```

## 📄 License

This project is open source and available under the MIT License.

## 🤝 Contributing

Contributions are welcome! Please feel free to submit pull requests or open issues.

## 📧 Support

For issues and questions:
- Check the troubleshooting section
- Review ESP32 code examples
- Verify Firestore structure
- Test MQTT connection independently

---

**Built with Flutter 💙**
