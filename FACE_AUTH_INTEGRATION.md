# Face Recognition Authentication - Backend Integration Guide

## Overview

This document describes the integration between the **Computer Vision Backend** (Python FastAPI + MQTT) and the **Flutter Mobile App** for face recognition authentication.

## Architecture

```
┌─────────────────────────┐
│   Camera/Laptop with   │
│  Computer Vision Model  │
│   (grad_project_backend)│
└───────────┬─────────────┘
            │
            │ Face Recognition
            │
┌───────────▼─────────────┐
│   MQTT Broker           │
│   (Mosquitto)           │
│   Port: 1883            │
└───────────┬─────────────┘
            │
            │ MQTT Messages
            │
┌───────────▼─────────────┐
│   Flutter Mobile App    │
│   - Face Auth Service   │
│   - Auth Provider       │
└─────────────────────────┘
```

## System Components

### 1. Computer Vision Backend

**Location**: `grad_project_backend-main/`

**Components**:
- **app.py**: FastAPI server for face detection
  - `/detect-image`: Detect faces in uploaded images
  - `/detect-webcam`: Continuous face detection from webcam
  - `/stream`: MJPEG stream with face detection overlay
  - `/ui`: Web interface for testing

- **beacon.py**: UDP beacon for service discovery
  - Broadcasts service availability on UDP port 18830
  - Responds to WHO_IS queries with broker IP and port

- **mosquitto**: MQTT broker
  - Port: 1883
  - Allows anonymous connections (dev mode)

**Docker Services**:
```yaml
- mosquitto: MQTT broker
- broker-beacon: Service discovery beacon
- face-service: Face recognition API
- n8n: Workflow automation (optional)
```

### 2. Flutter Mobile App

**Location**: `lib/`

**Key Components**:
- `core/services/face_auth_service.dart`: Face authentication via MQTT
- `core/services/mqtt_service.dart`: MQTT client
- `core/providers/auth_provider.dart`: Authentication state management
- `core/models/face_auth_model.dart`: Data models
- `ui/screens/auth/face_auth_screen.dart`: Face auth UI

## MQTT Protocol

### Topics

| Topic | Direction | Purpose |
|-------|-----------|---------|
| `home/auth/face/request` | App → Backend | Request face authentication |
| `home/auth/face/response` | Backend → App | Authentication result |
| `home/auth/face/status` | Backend → App | Status updates during scan |
| `home/auth/beacon` | Backend → App | Beacon broadcasts |

### Message Formats

#### 1. Authentication Request
**Topic**: `home/auth/face/request`

```json
{
  "requestId": "uuid-v4",
  "userId": "optional-user-id",
  "deviceId": "mobile_app_timestamp",
  "timestamp": "2025-10-09T10:30:00Z",
  "metadata": {
    "app_version": "1.0.0"
  }
}
```

#### 2. Authentication Response
**Topic**: `home/auth/face/response`

```json
{
  "requestId": "uuid-v4",
  "success": true,
  "recognizedUserId": "user123",
  "recognizedUserName": "John Doe",
  "confidence": 0.95,
  "timestamp": "2025-10-09T10:30:05Z",
  "detectionData": {
    "box": {"left": 100, "top": 50, "right": 300, "bottom": 250},
    "distance": 0.05
  }
}
```

**Error Response**:
```json
{
  "requestId": "uuid-v4",
  "success": false,
  "errorMessage": "Face not recognized",
  "timestamp": "2025-10-09T10:30:05Z"
}
```

#### 3. Status Update
**Topic**: `home/auth/face/status`

```json
{
  "requestId": "uuid-v4",
  "status": "scanning",
  "message": "Looking for face..."
}
```

**Status values**:
- `scanning`: Camera is looking for a face
- `processing`: Face detected, verifying identity
- `completed`: Process finished

#### 4. Beacon Discovery
**UDP Port**: 18830

**WHO_IS Query** (App → Beacon):
```json
{
  "type": "WHO_IS",
  "name": "face-broker"
}
```

**Beacon Response** (Beacon → App):
```json
{
  "name": "face-broker",
  "ip": "192.168.1.100",
  "port": 1883
}
```

## Authentication Flow

### Complete Flow Diagram

```
┌──────────────┐                  ┌──────────────┐                  ┌──────────────┐
│  Mobile App  │                  │     Beacon   │                  │   Backend    │
└──────┬───────┘                  └──────┬───────┘                  └──────┬───────┘
       │                                  │                                  │
       │ 1. UDP Broadcast (WHO_IS)        │                                  │
       ├─────────────────────────────────>│                                  │
       │                                  │                                  │
       │ 2. Beacon Response (IP:Port)     │                                  │
       │<─────────────────────────────────┤                                  │
       │                                  │                                  │
       │ 3. Connect to MQTT Broker        │                                  │
       ├────────────────────────────────────────────────────────────────────>│
       │                                  │                                  │
       │ 4. Subscribe to response topic   │                                  │
       │<────────────────────────────────────────────────────────────────────┤
       │                                  │                                  │
       │ 5. Publish auth request          │                                  │
       ├────────────────────────────────────────────────────────────────────>│
       │                                  │                         Scanning │
       │                                  │                         Camera   │
       │ 6. Status: scanning              │                                  │
       │<────────────────────────────────────────────────────────────────────┤
       │                                  │                         Face     │
       │                                  │                         Detected │
       │ 7. Status: processing            │                                  │
       │<────────────────────────────────────────────────────────────────────┤
       │                                  │                         Verify   │
       │                                  │                         Identity │
       │ 8. Auth response (success/fail)  │                                  │
       │<────────────────────────────────────────────────────────────────────┤
       │                                  │                                  │
       │ 9. Navigate to home or show error│                                  │
       │                                  │                                  │
```

### Step-by-Step Process

1. **Beacon Discovery**
   - App broadcasts WHO_IS message on UDP port 18830
   - Beacon responds with MQTT broker IP and port
   - Timeout: 10 seconds

2. **MQTT Connection**
   - App connects to MQTT broker at discovered IP:port
   - Subscribes to `home/auth/face/response`
   - Subscribes to `home/auth/face/status`

3. **Authentication Request**
   - User taps "Authenticate with Face" button
   - App generates unique request ID (UUID)
   - Publishes request to `home/auth/face/request`

4. **Backend Processing**
   - Backend receives request via MQTT
   - Activates camera and starts scanning
   - Publishes status updates to `home/auth/face/status`
   - Captures face image and runs recognition
   - Compares with known faces in `persons/` directory

5. **Response**
   - Backend publishes result to `home/auth/face/response`
   - App receives response and matches by requestId
   - Timeout: 30 seconds

6. **UI Update**
   - Success: Navigate to home screen, load user settings
   - Failure: Show error message, option to retry

## Multi-User Support

### Current Implementation

The backend stores face encodings in the `persons/` directory:
```
persons/
  ├── mother.jpg
  ├── father.jpg
  ├── child1.jpg
  └── child2.jpg
```

Each image filename becomes the recognized user name.

### Recommended Approach

**Option 1: Single Authentication, Multiple Profiles**
- Backend recognizes which family member is present
- Response includes `recognizedUserName` (e.g., "mother")
- App links this to specific Firebase user account
- Each family member has their own Firebase account with saved settings

**Option 2: Request-Based Recognition**
- App sends `userId` in request to indicate which user to verify
- Backend only checks if the scanned face matches the requested user
- More secure but requires user selection first

**Mapping Face Recognition to Firebase Users**:

```dart
// In AuthProvider.authenticateWithFace()
final response = await _faceAuthService.requestFaceAuth();

if (response != null && response.success) {
  // Map face recognition name to Firebase user
  final email = _mapFaceNameToEmail(response.recognizedUserName);
  
  // Sign in to Firebase with mapped credentials
  // OR retrieve user preferences based on recognized name
}

String _mapFaceNameToEmail(String? faceName) {
  // Mapping stored in Firestore or local config
  const faceToEmail = {
    'mother': 'mother@family.com',
    'father': 'father@family.com',
    'child1': 'child1@family.com',
    'child2': 'child2@family.com',
  };
  return faceToEmail[faceName] ?? '';
}
```

## User Settings Storage

### Firestore Structure

```
users/
  └── {userId}/
      ├── profile/
      │   ├── email
      │   ├── displayName
      │   └── faceRecognitionName  // Links to backend face model
      │
      ├── settings/
      │   └── preferences/
      │       ├── themeMode: "dark"
      │       ├── language: "en"
      │       ├── mqttBrokerAddress: "192.168.1.100"
      │       ├── enableNotifications: true
      │       └── ...
      │
      ├── settings/
      │   └── automations/
      │       └── rules: [...]
      │
      └── devices/
          ├── {deviceId}/
          │   ├── name
          │   ├── type
          │   ├── state
          │   └── lastUpdated
          └── ...
```

### Settings Sync Flow

1. **On Login** (Email or Face):
   - `SettingsProvider` listens to auth state
   - When user authenticated, loads settings from Firestore
   - Applies theme, language, MQTT config, etc.

2. **On Settings Change**:
   - User modifies setting in UI
   - `SettingsProvider` updates local state
   - Auto-saves to Firestore
   - Settings persist across devices

3. **On Logout**:
   - Settings reset to defaults
   - Local state cleared

## Backend Setup Requirements

### Starting the Backend

```bash
cd grad_project_backend-main

# Start all services
docker-compose up -d

# Check status
docker-compose ps

# View logs
docker-compose logs -f face-service
docker-compose logs -f broker-beacon
```

### Testing the Backend

1. **Test Face Detection API**:
```bash
curl http://localhost:8000/healthz
```

2. **Test Web UI**:
```
http://localhost:8000/ui
```

3. **Test MQTT Broker**:
```bash
# Install mosquitto-clients
mosquitto_sub -h localhost -t "home/#" -v
```

4. **Test Beacon**:
```bash
# Send WHO_IS query
echo '{"type":"WHO_IS","name":"face-broker"}' | nc -u -w1 255.255.255.255 18830
```

## Security Considerations

### Current Implementation (Development)
- Anonymous MQTT connections
- No TLS encryption
- Local network only

### Production Recommendations

1. **MQTT Security**:
   - Enable authentication (username/password)
   - Use TLS/SSL (port 8883)
   - Configure ACLs (Access Control Lists)

2. **Network Security**:
   - Use VPN for remote access
   - Firewall rules to restrict MQTT port
   - Separate network for IoT devices

3. **Face Recognition**:
   - Store face encodings securely
   - Implement liveness detection
   - Add timeout/retry limits
   - Log authentication attempts

4. **Data Privacy**:
   - Don't transmit face images over MQTT
   - Store minimal personal data
   - Comply with data protection regulations

## Troubleshooting

### App Cannot Discover Beacon

**Symptoms**: "Face recognition system not found"

**Solutions**:
1. Check backend is running: `docker-compose ps`
2. Ensure mobile device on same network
3. Check firewall allows UDP port 18830
4. Verify beacon is broadcasting: `docker-compose logs broker-beacon`

### MQTT Connection Failed

**Symptoms**: "Failed to connect to face broker"

**Solutions**:
1. Verify MQTT broker running on port 1883
2. Check broker IP matches beacon response
3. Test with MQTT client: `mosquitto_sub -h <ip> -t "home/#"`
4. Check mosquitto logs: `docker-compose logs mosquitto`

### Authentication Timeout

**Symptoms**: "Request timed out"

**Solutions**:
1. Ensure face-service can access camera: `docker-compose logs face-service`
2. Check `persons/` directory has face images
3. Verify MQTT broker receives requests
4. Check backend `/detect-webcam` endpoint works

### Face Not Recognized

**Symptoms**: "Face not recognized" despite correct face

**Solutions**:
1. Adjust `tolerance` parameter (default: 0.6)
2. Add more training images to `persons/` directory
3. Ensure good lighting conditions
4. Check face detection model (`hog` vs `cnn`)

## Development Workflow

### Adding New Face to System

1. Add image to `persons/` directory:
```bash
cp ~/mother_photo.jpg grad_project_backend-main/persons/mother.jpg
```

2. Restart face-service:
```bash
docker-compose restart face-service
```

3. Test recognition:
```bash
curl -X POST http://localhost:8000/detect-image \
  -F "persons_dir=/data/persons" \
  -F "file=@test_image.jpg"
```

### Testing MQTT Integration

```python
# test_mqtt.py
import paho.mqtt.client as mqtt
import json

def on_message(client, userdata, msg):
    print(f"Topic: {msg.topic}")
    print(f"Message: {msg.payload.decode()}")

client = mqtt.Client()
client.on_message = on_message
client.connect("localhost", 1883, 60)
client.subscribe("home/auth/face/#")

# Publish test request
request = {
    "requestId": "test-123",
    "deviceId": "test-device",
    "timestamp": "2025-10-09T10:00:00Z"
}
client.publish("home/auth/face/request", json.dumps(request))

client.loop_forever()
```

## Future Enhancements

1. **WebRTC Integration**: Stream camera feed directly to mobile app
2. **Cloud MQTT**: Use cloud MQTT broker for remote access
3. **Multi-Camera Support**: Multiple entry points
4. **Liveness Detection**: Prevent photo spoofing
5. **Facial Expression Recognition**: Emotion-based automation
6. **Age/Gender Detection**: Enhanced user profiles
7. **Access Control Integration**: Physical door locks
8. **Audit Logging**: Track all authentication attempts

## API Reference

### FaceAuthService Methods

```dart
// Discover beacon
Future<FaceAuthBeacon?> discoverBeacon()

// Connect to broker
Future<bool> connectToFaceBroker({FaceAuthBeacon? beacon})

// Request authentication
Future<FaceAuthResponse?> requestFaceAuth({String? userId, Map<String, dynamic>? metadata})

// Cancel authentication
void cancelAuth()

// Reset state
void reset()
```

### AuthProvider Face Auth Methods

```dart
// Discover face recognition system
Future<bool> discoverFaceAuthBeacon()

// Connect to face recognition broker
Future<bool> connectToFaceBroker()

// Authenticate using face recognition
Future<bool> authenticateWithFace({String? userId})

// Cancel face authentication
void cancelFaceAuth()

// Reset face auth state
void resetFaceAuth()
```

## Conclusion

This integration provides a seamless, secure way to authenticate users using face recognition while maintaining the separation between the computer vision backend and the mobile application. The MQTT-based architecture allows for real-time communication and supports multiple users through Firebase integration.

For questions or issues, refer to:
- Backend: `grad_project_backend-main/README.md`
- App: This documentation and code comments
