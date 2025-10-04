# System Architecture Overview

## High-Level Architecture

```
┌─────────────────────────────────────────────────────────────────────┐
│                        FLUTTER MOBILE APP                            │
├─────────────────────────────────────────────────────────────────────┤
│                                                                       │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────────────────┐  │
│  │ Auth Module  │  │ IoT Control  │  │  3D Visualization        │  │
│  │              │  │              │  │  (three.js/WebView)      │  │
│  │ - Login      │  │ - Devices    │  │  - Interactive 3D model  │  │
│  │ - Register   │  │ - Controls   │  │  - Alarm visualization   │  │
│  │ - User Mgmt  │  │ - Status     │  │  - Room interaction      │  │
│  └──────┬───────┘  └──────┬───────┘  └───────────┬──────────────┘  │
│         │                  │                       │                 │
│         └──────────┬───────┴──────────────────────┘                 │
│                    │                                                 │
│         ┌──────────▼──────────────────────────┐                     │
│         │   State Management (Provider)       │                     │
│         │  - AuthProvider                     │                     │
│         │  - DeviceProvider                   │                     │
│         │  - HomeVisualizationProvider        │                     │
│         └──────────┬──────────────────────────┘                     │
│                    │                                                 │
│         ┌──────────▼──────────────────────────┐                     │
│         │         Services Layer               │                     │
│         │  - AuthService                       │                     │
│         │  - MqttService                       │                     │
│         │  - FirestoreService                  │                     │
│         └──────────┬──────────────────────────┘                     │
│                    │                                                 │
└────────────────────┼─────────────────────────────────────────────────┘
                     │
        ┌────────────┴────────────┐
        │                         │
        ▼                         ▼
┌──────────────┐          ┌──────────────────┐
│   FIREBASE   │          │  MQTT BROKER     │
│              │          │  (Local/Cloud)   │
│ - Auth       │          │                  │
│ - Firestore  │          │ - Mosquitto      │
│ - Storage    │          │ - HiveMQ Cloud   │
└──────┬───────┘          └─────────┬────────┘
       │                            │
       │                            │
       └────────┬───────────────────┘
                │
                ▼
       ┌─────────────────┐
       │   ESP32 DEVICES │
       │                 │
       │ - Sensors       │
       │ - Actuators     │
       │ - Lights        │
       │ - Alarms        │
       └─────────────────┘
```

## Communication Flow

### 1. Local Mode (MQTT)
```
Mobile App ←──→ MQTT Broker ←──→ ESP32 Devices
   (WiFi)        (Raspberry Pi)      (WiFi)
```

**Advantages:**
- Low latency
- Works without internet
- Real-time control
- No cloud costs

### 2. Cloud Mode (Firestore)
```
Mobile App ──→ Firebase Firestore ←── ESP32 Devices
   (4G/WiFi)                          (WiFi + Firebase SDK)
```

**Advantages:**
- Remote access from anywhere
- Automatic data backup
- Works when not on local network
- Integration with cloud services

### 3. Hybrid Mode (Recommended)
```
Mobile App ←─┬─→ MQTT (when on local network)
             └─→ Firestore (when remote or fallback)
                    ↕
              ESP32 Devices (dual connectivity)
```

## Data Flow Examples

### Example 1: Light Control (Local MQTT)
```
1. User taps "Toggle Light" in app
2. DeviceProvider.toggleLight()
3. MqttService.publish("home/living_room/light/set", {"state": "on"})
4. ESP32 subscribes to topic, receives command
5. ESP32 turns on light
6. ESP32 publishes status: "home/living_room/light/status" {"state": "on"}
7. App receives status update via MQTT subscription
8. UI updates to show light is ON
```

### Example 2: Fire Alarm (ESP32 → App)
```
1. ESP32 detects fire (sensor reading)
2. ESP32 publishes: "home/garage/fire_alarm" 
   {"alarm": true, "severity": "critical", "message": "Fire!"}
3. App's MqttService receives message
4. DeviceProvider._handleAlarm() creates AlarmEvent
5. Alarm added to Firestore for persistence
6. HomeVisualizationProvider.triggerVisualAlarm("garage", ...)
7. JavaScript in WebView receives alarm data
8. 3D model: garage section turns red with pulsing effect
9. User sees notification and visual indicator
```

### Example 3: Computer Vision Integration
```
1. CV Service (external) detects person via camera
2. CV API sends POST request to Cloud Function
3. Cloud Function writes to Firestore: users/{uid}/alarms/
4. FirestoreService.getAlarmsStream() receives update
5. DeviceProvider gets new alarm event
6. App shows notification
7. 3D visualization highlights camera location
```

## Technology Stack Summary

| Layer | Technology | Purpose |
|-------|-----------|---------|
| **Frontend** | Flutter | Cross-platform mobile UI |
| **State Management** | Provider | Reactive state updates |
| **Authentication** | Firebase Auth | User management |
| **Cloud Database** | Cloud Firestore | Real-time NoSQL database |
| **Local Communication** | MQTT | Lightweight IoT messaging |
| **3D Visualization** | three.js | WebGL 3D rendering |
| **Bridge** | WebView + JavaScript Channels | Flutter ↔ JavaScript communication |
| **IoT Devices** | ESP32 | Microcontroller with WiFi |
| **Broker** | Mosquitto | MQTT message broker |

## Security Considerations

1. **Authentication**: Firebase handles secure auth with tokens
2. **Firestore Rules**: User-scoped data access (see FIRESTORE_RULES.md)
3. **MQTT**: Can use TLS/SSL for encrypted communication
4. **Local Network**: Devices only accessible on trusted WiFi
5. **API Keys**: Never commit Firebase config to public repos

## Scalability

### Single Home
- Current architecture works perfectly
- Local MQTT for best performance
- Cloud for remote access

### Multiple Homes
- Each home = separate Firestore user document
- Multiple MQTT brokers (one per home)
- Or cloud-only mode with device grouping

### Community/Building
- Multi-tenant Firestore structure
- Shared MQTT broker with topic namespacing
- Role-based access control

## Performance Optimization

1. **MQTT QoS Levels**:
   - QoS 0: Fire and forget (status updates)
   - QoS 1: At least once (commands)
   - QoS 2: Exactly once (critical alarms)

2. **Firestore Optimization**:
   - Index queries for fast access
   - Limit real-time listeners
   - Batch writes when possible
   - Clean up old logs periodically

3. **3D Model**:
   - Use simplified geometry
   - Optimize texture sizes
   - Lazy load non-essential rooms
   - Level of detail (LOD) rendering

## Future Enhancements

- [ ] Voice control integration (Google Assistant/Alexa)
- [ ] Machine learning for automation patterns
- [ ] Energy consumption monitoring
- [ ] Multi-user permissions (family members)
- [ ] Scheduling and automation rules
- [ ] Integration with smart home ecosystems (HomeKit, SmartThings)
- [ ] Offline mode with local database (SQLite)
- [ ] Widget support for quick controls
- [ ] Apple Watch/Wear OS companion app

---

This architecture is designed to be:
- ✅ **Flexible**: Choose local, cloud, or hybrid mode
- ✅ **Scalable**: From single room to entire building
- ✅ **Maintainable**: Clean separation of concerns
- ✅ **Extensible**: Easy to add new device types and features
- ✅ **Real-time**: Instant status updates and control
- ✅ **Visual**: Interactive 3D home representation
