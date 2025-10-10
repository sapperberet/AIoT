# Migration Changes from Working Version to New Architecture

This document details all the changes, improvements, and customizations made to the face recognition backend that need to be migrated to the new architecture.

**Date:** October 10, 2025  
**Source:** `grad_project_backend-main` (working version)  
**Target:** `grad_project_backend-main(New)` (new repository structure)

---

## 📋 Table of Contents

1. [Overview of Changes](#overview-of-changes)
2. [New Files Added](#new-files-added)
3. [Modified Files](#modified-files)
4. [Configuration Changes](#configuration-changes)
5. [Network & Discovery Improvements](#network--discovery-improvements)
6. [Camera Management Enhancements](#camera-management-enhancements)
7. [MQTT Integration](#mqtt-integration)
8. [Timeout & Delay Configurations](#timeout--delay-configurations)
9. [Logging Improvements](#logging-improvements)
10. [Windows Support](#windows-support)
11. [Testing & Debugging Tools](#testing--debugging-tools)
12. [Architecture Differences](#architecture-differences)

---

## 📊 Overview of Changes

The working version includes several critical enhancements over the original:

- **MQTT Bridge**: New `face_auth_bridge.py` for Flutter app integration
- **Persistent Camera**: Global camera instance to avoid 20s initialization delays
- **Enhanced Beacon**: IP environment variable support and better logging
- **Status Publishing**: Real-time MQTT status updates during face authentication
- **Extended Timeouts**: Proper timeout handling for camera initialization (27s) and full auth flow (50s)
- **Camera Release API**: Explicit camera release endpoint
- **Windows Setup Guide**: Complete documentation for running on Windows
- **Testing Scripts**: UDP beacon testing utilities
- **Improved Error Handling**: Better timeout and error recovery

---

## 🆕 New Files Added

### 1. `face_auth_bridge.py` ⭐ **CRITICAL**
**Purpose:** MQTT bridge connecting Flutter app to face recognition REST API

**Key Features:**
- Listens on `home/auth/face/request` topic for authentication requests
- Calls `/detect-webcam` REST API endpoint
- Publishes results to `home/auth/face/response`
- Publishes real-time status updates to `home/auth/face/status`
- Handles camera release after authentication
- Uses paho-mqtt 2.0+ with CallbackAPIVersion.VERSION1

**Configuration:**
```python
MQTT_BROKER = "192.168.1.7"
MQTT_PORT = 1883
FACE_API_URL = "http://localhost:8000"
PERSONS_DIR = "persons"
CAPTURES_DIR = "captures"

# MQTT Topics
TOPIC_REQUEST = "home/auth/face/request"
TOPIC_RESPONSE = "home/auth/face/response"
TOPIC_STATUS = "home/auth/face/status"
```

**Timeout Configuration:**
```python
timeout=35  # Request timeout: camera init (20s) + scan (8s) + processing (7s buffer)
```

**Status Flow:**
1. Request received → `"requesting_scan"` (sent by app)
2. Backend sends → `"initializing"` (right before camera init)
3. Camera ready → `"scanning"` (user should look at camera)
4. Processing → `"processing"` (face detection running)
5. Complete → `"success"` or `"failed"`

**Important Notes:**
- Does NOT send "initializing" status - lets backend send it at proper time
- Releases camera explicitly after authentication completes
- Handles timeouts and errors gracefully

---

### 2. `WINDOWS_SETUP.md` 📖
**Purpose:** Complete guide for running face service on Windows (Docker can't access webcams on Windows)

**Contents:**
- Python 3.11+ installation
- CMake installation (required for face_recognition)
- Visual Studio Build Tools setup
- Virtual environment creation
- Dependency installation
- MQTT broker setup (Docker)
- Face images setup
- Running instructions

**Key Commands:**
```powershell
# Create and activate venv
python -m venv venv
.\venv\Scripts\Activate.ps1

# Install dependencies
pip install fastapi uvicorn[standard] opencv-python numpy python-multipart face_recognition paho-mqtt

# Run services
docker-compose up -d mosquitto broker-beacon  # Start MQTT & beacon
python app.py                                   # Run face service on Windows
python face_auth_bridge.py                      # Run MQTT bridge
```

---

### 3. `simple_udp_test.py` 🧪
**Purpose:** Test UDP beacon reception without beacon running

**Usage:**
```bash
python simple_udp_test.py
```

**Features:**
- Binds to port 18830
- Listens for any UDP broadcasts
- Shows packet count and contents
- Helps diagnose network/firewall issues

---

### 4. `test_beacon_receive.py` 🧪
**Purpose:** Test beacon discovery by sending WHO_IS and receiving responses

**Usage:**
```bash
python test_beacon_receive.py
```

**Features:**
- Sends WHO_IS query broadcasts
- Listens for beacon responses
- Shows detailed packet information
- Re-sends WHO_IS every few seconds

---

## 🔧 Modified Files

### 1. `app.py` - Major Enhancements ⭐

#### A. MQTT Integration Added

```python
from paho.mqtt import client as mqtt_client

# MQTT Configuration
MQTT_BROKER = "192.168.1.7"
MQTT_PORT = 1883
MQTT_CLIENT_ID = "face-detection-service"
TOPIC_STATUS = "home/auth/face/status"

# Global MQTT client
mqtt_client_instance = None

def get_mqtt_client():
    """Get or initialize MQTT client"""
    global mqtt_client_instance
    if mqtt_client_instance is None:
        try:
            mqtt_client_instance = mqtt_client.Client(
                client_id=MQTT_CLIENT_ID,
                callback_api_version=mqtt_client.CallbackAPIVersion.VERSION1
            )
            mqtt_client_instance.connect(MQTT_BROKER, MQTT_PORT, 60)
            mqtt_client_instance.loop_start()
            print(f"[MQTT] Connected to broker at {MQTT_BROKER}:{MQTT_PORT}")
        except Exception as e:
            print(f"[MQTT] Connection failed: {e}")
            mqtt_client_instance = None
    return mqtt_client_instance

def publish_status(status: str, message: str = ""):
    """Publish status update to MQTT"""
    try:
        client = get_mqtt_client()
        if client:
            payload = {
                "status": status,
                "message": message,
                "timestamp": time.time()
            }
            client.publish(TOPIC_STATUS, json.dumps(payload))
            print(f"[STATUS] {status}: {message}")
    except Exception as e:
        print(f"[MQTT] Failed to publish status: {e}")
```

**Why:** Enables real-time status updates to Flutter app during authentication process.

---

#### B. Persistent Camera Management ⭐ **CRITICAL**

**Problem:** Every `cv2.VideoCapture(0)` call takes 15-20 seconds to initialize on Windows.

**Solution:** Global camera instance that persists across requests.

```python
# Global camera instance - initialize once and reuse
camera = None
camera_lock = None

def get_camera():
    """Get or initialize the global camera instance"""
    global camera, camera_lock
    import threading
    
    if camera_lock is None:
        camera_lock = threading.Lock()
    
    with camera_lock:
        if camera is None or not camera.isOpened():
            print("[CAMERA] Initializing camera...")
            start_time = time.time()
            camera = cv2.VideoCapture(0)
            init_time = time.time() - start_time
            print(f"[CAMERA] Initialized in {init_time:.2f}s")
            
            if not camera.isOpened():
                print("[CAMERA] Failed to open camera!")
                return None
        return camera
```

**Benefits:**
- First authentication: 20s (one-time camera init)
- Subsequent authentications: <1s (instant camera access)
- Thread-safe with lock
- Automatic re-initialization if camera becomes unavailable

---

#### C. Camera Release API

```python
@app.post("/camera/release")
def release_camera():
    """Release the global camera instance (close camera after authentication)"""
    global camera
    import threading
    
    if camera_lock is None:
        return {"status": "no_lock", "message": "Camera lock not initialized"}
    
    with camera_lock:
        if camera is not None and camera.isOpened():
            camera.release()
            camera = None
            print("[CAMERA] Camera released successfully")
            return {"status": "released", "message": "Camera has been released"}
        else:
            return {"status": "not_open", "message": "Camera was not open"}
```

**Why:** Allows explicit camera release after authentication to free resources.

---

#### D. Camera Test Endpoint

```python
@app.get("/test-camera")
def test_camera():
    """Quick camera test - just try to open and close"""
    import time
    start = time.time()
    try:
        cap = cv2.VideoCapture(0)
        open_time = time.time() - start
        
        if not cap.isOpened():
            return {"error": "Camera failed to open", "time_elapsed": open_time}
        
        # Try to read one frame
        ok, frame = cap.read()
        read_time = time.time() - start
        
        cap.release()
        total_time = time.time() - start
        
        return {
            "success": True,
            "camera_opened": ok,
            "open_time": open_time,
            "first_frame_time": read_time,
            "total_time": total_time
        }
    except Exception as e:
        return {"error": str(e), "time_elapsed": time.time() - start}
```

**Why:** Quick diagnostic to measure camera initialization time.

---

#### E. Modified `/detect-webcam` Endpoint

**Changes:**

1. **Status Updates Added:**
```python
# Notify user that camera is initializing BEFORE we try to get it
publish_status("initializing", "Initializing camera, please wait...")

# Use persistent camera instead of creating new one
cap = get_camera()
if cap is None:
    return JSONResponse(status_code=500, content={"error": "Cannot open webcam - camera unavailable"})

# Camera is ready - notify user to look at camera
publish_status("scanning", "Camera ready! Please look at the camera for face authentication...")
```

2. **No Camera Release in Finally Block:**
```python
try:
    # ... detection logic ...
finally:
    # Don't release the camera - keep it open for next request
    pass
```

**Old behavior:**
```python
cap = cv2.VideoCapture(int(webcam))  # 20s delay every time
try:
    # ...
finally:
    cap.release()  # Always closed
```

**New behavior:**
```python
cap = get_camera()  # 20s first time, instant after
try:
    # ...
finally:
    pass  # Keep camera open, release manually via /camera/release
```

---

### 2. `beacon.py` - Environment Variable Support

**Changes:**

#### A. BEACON_IP Environment Variable

```python
import os

def host_ip():
    """
    Return primary LAN IP. First checks BEACON_IP environment variable,
    then falls back to socket trick (no deps).
    """
    # Check for explicit IP from environment variable
    explicit_ip = os.getenv("BEACON_IP", "").strip()
    if explicit_ip:
        print(f"[beacon] Using explicit BEACON_IP={explicit_ip}")
        sys.stdout.flush()
        return explicit_ip
    
    # Fallback to auto-detection
    try:
        s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        s.connect(("1.1.1.1", 80))
        ip = s.getsockname()[0]
        s.close()
        print(f"[beacon] Auto-detected IP={ip}")
        sys.stdout.flush()
        return ip
    except Exception as e:
        print(f"[beacon] host_ip error: {e}", file=sys.stderr)
        return None
```

**Why:** Allows manual IP configuration when auto-detection fails or wrong interface is selected.

#### B. Enhanced Logging

```python
print(f"[beacon] Using explicit BEACON_IP={explicit_ip}")
print(f"[beacon] Auto-detected IP={ip}")
```

**Why:** Better debugging and visibility of which IP is being broadcast.

---

### 3. `docker-compose.yml` - Beacon Configuration

**Changes:**

```yaml
broker-beacon:
  image: python:3.11-slim
  container_name: broker-beacon
  restart: unless-stopped
  ports:
    - "18830:18830/udp"          # Map UDP port for beacon broadcasts
  environment:
    - BEACON_IP=192.168.1.7      # Set to your WiFi IP address
  volumes:
    - ./beacon.py:/app/beacon.py:ro
  command: ["python", "/app/beacon.py"]
```

**Old version:**
```yaml
broker-beacon:
  network_mode: host  # Required host mode for broadcasts
```

**New version (working):**
```yaml
broker-beacon:
  ports:
    - "18830:18830/udp"
  environment:
    - BEACON_IP=192.168.1.7  # Explicit IP configuration
```

**Why:** 
- Avoids `network_mode: host` which can cause issues on some Docker setups
- Explicit IP configuration ensures correct interface is used
- More portable across different network configurations

---

## ⚙️ Configuration Changes

### 1. MQTT Broker IP Address

**Location:** Multiple files need to be synchronized

#### `face_auth_bridge.py`:
```python
MQTT_BROKER = "192.168.1.7"  # ← UPDATE THIS
```

#### `app.py`:
```python
MQTT_BROKER = "192.168.1.7"  # ← UPDATE THIS
```

#### `docker-compose.yml`:
```yaml
environment:
  - BEACON_IP=192.168.1.7  # ← UPDATE THIS
```

#### Flutter App (`lib/core/config/mqtt_config.dart`):
```dart
static const String localBrokerAddress = '192.168.1.7';  // ← UPDATE THIS
```

**Important:** All must match your actual WiFi IP address. Find it with:
```powershell
# Windows
ipconfig
# Look for "IPv4 Address" under your WiFi adapter

# Linux
ip addr show | grep inet
```

---

### 2. Timeout Values

#### Face Auth Service (Flutter - `face_auth_service.dart`):
```dart
static const Duration _beaconDiscoveryTimeout = Duration(seconds: 2);
static const Duration _cameraInitTimeout = Duration(seconds: 27);  // Camera initialization
static const Duration _authResponseTimeout = Duration(seconds: 50);  // Total authentication time
```

**Why these values:**
- **Beacon discovery (2s):** Beacon broadcasts every 2s, so we listen for at least one broadcast
- **Camera init (27s):** Windows camera initialization takes 15-20s, added 7s buffer
- **Auth response (50s):** Camera init (20s) + scanning (8s) + processing (10s) + network (12s buffer)

#### MQTT Bridge (`face_auth_bridge.py`):
```python
timeout=35  # API request timeout
```

**Why:** Camera init (20s) + scan (8s) + processing (7s buffer) = 35s

---

### 3. Camera Scan Duration

#### `face_auth_bridge.py`:
```python
response = requests.post(
    f"{FACE_API_URL}/detect-webcam",
    data={
        "max_seconds": "8",  # How long to scan for faces
        "stop_on_first": "true",  # Stop as soon as known face found
        # ...
    }
)
```

**Why:** 8 seconds is enough to capture a face while not being too slow. `stop_on_first` exits immediately when recognized.

---

## 🌐 Network & Discovery Improvements

### 1. Beacon Broadcasting Strategy

**Old approach:**
- Passive listening for WHO_IS queries
- Required client to send query first

**New approach (working version):**
- **Periodic broadcasts every 2 seconds** automatically
- Still responds to WHO_IS queries (backward compatible)
- Client can passively listen or actively query

**Code:**
```python
# Periodic global broadcast every 2s
if now - last_adv > 2.0:
    ip = host_ip()
    if ip:
        msg = json.dumps({"name": NAME, "ip": ip, "port": BROKER_PORT}).encode()
        tx.sendto(msg, ("255.255.255.255", PORT))
        print(f"[beacon] sent GLOBAL -> 255.255.255.255:{PORT} {msg}")
    last_adv = now
```

**Flutter side (passive listening):**
```dart
// Bind to beacon port to receive broadcasts
final socket = await RawDatagramSocket.bind(
  InternetAddress.anyIPv4,
  MqttConfig.beaconPort,  // 18830
);
socket.broadcastEnabled = true;

// Just listen - no need to send WHO_IS
socket.listen((event) {
  if (event == RawSocketEvent.read) {
    final datagram = socket.receive();
    // Process beacon message
  }
});
```

**Benefits:**
- No need for client to send WHO_IS query
- Faster discovery (receive broadcast within 2s)
- More reliable (broadcasts continue even if client misses first one)

---

### 2. Fallback Mechanism

**Flutter side:**
```dart
Future<FaceAuthBeacon?> discoverBeacon() async {
  try {
    // Try UDP discovery first
    final result = await completer.future;
    
    // If discovery failed, use fallback
    if (result == null) {
      _logger.w('Beacon discovery failed, trying fallback to ${MqttConfig.localBrokerAddress}');
      final fallbackBeacon = FaceAuthBeacon(
        name: MqttConfig.beaconServiceName,
        ip: MqttConfig.localBrokerAddress,
        port: MqttConfig.localBrokerPort,
        discoveredAt: DateTime.now(),
      );
      return fallbackBeacon;
    }
    
    return result;
  } catch (e) {
    // Even on exception, try fallback
    return fallbackBeacon;
  }
}
```

**Why:** If beacon discovery fails (firewall, network issues), automatically fall back to configured IP.

---

## 📷 Camera Management Enhancements

### Problem: Camera Initialization Delay

**Measured timings on Windows:**
- `cv2.VideoCapture(0)` first call: **15-20 seconds**
- `cv2.VideoCapture(0)` subsequent calls: **15-20 seconds each time**
- Camera.read() after initialized: **<100ms**

**Impact:**
- Old approach: 20s delay on EVERY authentication request
- New approach: 20s delay on FIRST request, instant on subsequent requests

### Solution: Global Camera Instance

**Implementation details:**

1. **Thread-safe singleton:**
```python
camera = None
camera_lock = threading.Lock()

def get_camera():
    with camera_lock:
        if camera is None or not camera.isOpened():
            camera = cv2.VideoCapture(0)
        return camera
```

2. **Persistent across requests:**
```python
# detect-webcam endpoint
cap = get_camera()  # Reuses existing camera
try:
    # ... use camera ...
finally:
    pass  # Don't release!
```

3. **Manual release:**
```python
# POST /camera/release endpoint
with camera_lock:
    if camera is not None:
        camera.release()
        camera = None
```

**Usage pattern:**
```python
# face_auth_bridge.py
try:
    # Request face detection
    response = requests.post(f"{FACE_API_URL}/detect-webcam", ...)
    
    # ... process response ...
    
finally:
    # Always release camera after authentication completes
    try:
        requests.post(f"{FACE_API_URL}/camera/release", timeout=5)
    except:
        pass
```

---

## 📡 MQTT Integration

### Status Publishing Flow

**Complete status flow during authentication:**

```
1. Flutter App sends request to home/auth/face/request
   ↓
2. face_auth_bridge receives request
   ↓
3. Backend publishes to home/auth/face/status:
   {"status": "initializing", "message": "Initializing camera, please wait...", "timestamp": 1234567890.123}
   ↓
4. Backend initializes camera (20s on first run)
   ↓
5. Backend publishes to home/auth/face/status:
   {"status": "scanning", "message": "Camera ready! Please look at the camera for face authentication...", "timestamp": 1234567910.456}
   ↓
6. Backend scans for faces (up to 8s)
   ↓
7. Backend sends response to home/auth/face/response:
   {
     "success": true/false,
     "requestId": "uuid",
     "userId": "person_name",
     "confidence": 0.95,
     "timestamp": 1234567918.789,
     "message": "Welcome, John!"
   }
   ↓
8. face_auth_bridge releases camera via POST /camera/release
```

### Status Message Schema

```python
{
    "status": str,      # One of: "initializing", "scanning", "processing", "success", "failed", "error"
    "message": str,     # Human-readable message
    "timestamp": float  # Unix timestamp in seconds
}
```

### Response Message Schema

```python
{
    "success": bool,
    "requestId": str,
    "userId": str,          # Recognized person name (if success=true)
    "confidence": float,    # 0.0 to 1.0 (if success=true)
    "timestamp": float,
    "message": str,         # Welcome message or error
    "error": str            # Error message (if success=false)
}
```

### Topics Summary

| Topic                        | Direction     | Purpose                          |
|------------------------------|---------------|----------------------------------|
| `home/auth/face/request`     | App → Bridge  | Request face authentication      |
| `home/auth/face/response`    | Bridge → App  | Authentication result            |
| `home/auth/face/status`      | Backend → App | Real-time status updates         |

---

## ⏱️ Timeout & Delay Configurations

### Summary Table

| Component                 | Timeout/Delay | Reason                                              |
|---------------------------|---------------|-----------------------------------------------------|
| Beacon discovery          | 2s            | Beacon broadcasts every 2s                          |
| Camera initialization     | 27s           | Windows camera takes 15-20s + buffer                |
| Total auth response       | 50s           | Init(20s) + scan(8s) + process(10s) + network(12s) |
| MQTT bridge API request   | 35s           | Init(20s) + scan(8s) + buffer(7s)                   |
| Camera scan duration      | 8s            | Balance between speed and accuracy                  |
| Camera release timeout    | 5s            | Quick release request                               |

### Code Locations

#### Flutter App (`face_auth_service.dart`):
```dart
static const Duration _beaconDiscoveryTimeout = Duration(seconds: 2);
static const Duration _cameraInitTimeout = Duration(seconds: 27);
static const Duration _authResponseTimeout = Duration(seconds: 50);
```

#### MQTT Bridge (`face_auth_bridge.py`):
```python
timeout=35  # requests.post() timeout

# Also release camera with timeout
requests.post(f"{FACE_API_URL}/camera/release", timeout=5)
```

#### Face Service (`face_auth_bridge.py`):
```python
data={
    "max_seconds": "8",  # Camera scan duration
}
```

---

## 📝 Logging Improvements

### 1. Beacon Logging

**Enhanced with:**
- IP detection method (explicit vs auto-detected)
- Broadcast confirmations
- Error details

```python
print(f"[beacon] Using explicit BEACON_IP={explicit_ip}")
print(f"[beacon] Auto-detected IP={ip}")
print(f"[beacon] sent GLOBAL -> 255.255.255.255:{PORT} {msg}")
print(f"[beacon] reply -> {addr}: {msg}")
```

### 2. Camera Logging

**Added:**
- Initialization time tracking
- Status updates

```python
print("[CAMERA] Initializing camera...")
print(f"[CAMERA] Initialized in {init_time:.2f}s")
print("[CAMERA] Failed to open camera!")
print("[CAMERA] Camera released successfully")
```

### 3. MQTT Logging

**Added:**
- Connection status
- Status publishing confirmations
- Error details

```python
print(f"[MQTT] Connected to broker at {MQTT_BROKER}:{MQTT_PORT}")
print(f"[STATUS] {status}: {message}")
print(f"[MQTT] Failed to publish status: {e}")
```

### 4. Bridge Logging

**Detailed logging:**
```python
print(f"[MQTT] Connected to broker at {MQTT_BROKER}:{MQTT_PORT}")
print(f"[MQTT] Subscribed to {TOPIC_REQUEST}")
print(f"[REQUEST] {request_data}")
print(f"[API] Calling face detection service...")
print(f"[API] Detection result: {result}")
print(f"[RESPONSE] {auth_response}")
print(f"[CAMERA] Released after timeout")
print(f"[ERROR] {error_msg}")
```

---

## 🪟 Windows Support

### Why Windows-Specific Setup Needed

**Problem:** Docker on Windows cannot access `/dev/video0` (webcam device)

**Solution:** Run face service directly on Windows, keep MQTT broker in Docker

### Key Steps (from `WINDOWS_SETUP.md`)

1. **Install Python 3.11+**
2. **Install CMake** (required for face_recognition)
3. **Install Visual Studio Build Tools** (required for C++ compilation)
4. **Create virtual environment:**
   ```powershell
   python -m venv venv
   .\venv\Scripts\Activate.ps1
   ```
5. **Install dependencies:**
   ```powershell
   pip install fastapi uvicorn[standard] opencv-python numpy python-multipart face_recognition paho-mqtt
   ```
6. **Run MQTT broker in Docker:**
   ```powershell
   docker-compose up -d mosquitto broker-beacon
   ```
7. **Run face service on Windows:**
   ```powershell
   python app.py
   ```
8. **Run MQTT bridge on Windows:**
   ```powershell
   python face_auth_bridge.py
   ```

### Additional Requirements

```txt
# Add to requirements.txt for MQTT support
paho-mqtt==2.0.0
```

---

## 🧪 Testing & Debugging Tools

### 1. `simple_udp_test.py`

**Purpose:** Verify UDP broadcasts are reaching the network

**Usage:**
```bash
python simple_udp_test.py
```

**Output:**
```
[TEST] Listening for UDP broadcasts on 0.0.0.0:18830
[TEST] ✅ Successfully bound to port 18830
[TEST] ⏳ Waiting for broadcasts...

[TEST] 📦 Packet #1 from 192.168.1.7:18830
[TEST] 📨 Content: {"name": "face-broker", "ip": "192.168.1.7", "port": 1883}
```

**Troubleshooting:**
- No packets: Beacon not running or firewall blocking
- Wrong IP: Update BEACON_IP environment variable

---

### 2. `test_beacon_receive.py`

**Purpose:** Test active beacon discovery (WHO_IS query)

**Usage:**
```bash
python test_beacon_receive.py
```

**Output:**
```
[TEST] Listening for UDP broadcasts on port 18830...
[TEST] Sent WHO_IS broadcast: {...}

[TEST] 📦 Packet #1 from 192.168.1.7:18830
[TEST] 📨 Raw: {"name": "face-broker", "ip": "192.168.1.7", "port": 1883}
[TEST] ✅ Parsed: {'name': 'face-broker', 'ip': '192.168.1.7', 'port': 1883}
```

---

### 3. `/test-camera` Endpoint

**Purpose:** Quick camera initialization test

**Usage:**
```bash
curl http://localhost:8000/test-camera
```

**Output:**
```json
{
  "success": true,
  "camera_opened": true,
  "open_time": 18.234,
  "first_frame_time": 18.456,
  "total_time": 18.567
}
```

**Why:** Helps diagnose camera issues and measure initialization time.

---

## 🏗️ Architecture Differences

### Old Architecture (original repo)
```
┌─────────────┐
│   Docker    │
│ Compose     │
├─────────────┤
│ mosquitto   │  (MQTT broker)
│ beacon      │  (UDP beacon - host mode)
│ face-service│  (FastAPI - needs /dev/video0)
│ n8n         │  (Automation)
└─────────────┘
```

### Working Architecture (current setup)
```
┌──────────────────┐          ┌──────────────────┐
│   Docker         │          │   Windows        │
│   Compose        │          │   Host           │
├──────────────────┤          ├──────────────────┤
│ mosquitto        │◄────────►│ app.py           │  (FastAPI - direct webcam)
│ (MQTT broker)    │          │ face_auth_bridge │  (MQTT bridge)
│                  │          │                  │
│ beacon           │          │ venv/            │  (Python env)
│ (UDP broadcast)  │          │ persons/         │  (Face images)
│                  │          │ captures/        │  (Snapshots)
│ n8n              │          │                  │
│ (Automation)     │          │                  │
└──────────────────┘          └──────────────────┘
         │                             │
         └─────────────────────────────┘
                 Network: 192.168.1.x
```

**Key differences:**
- Face service runs on Windows host (not in Docker)
- Direct webcam access (no /dev/video0 needed)
- MQTT bridge connects Docker broker to host service
- Beacon broadcasts from Docker but uses explicit IP

### New Architecture (target repo)

Based on new repo README:
```
┌─────────────┐
│   Docker    │
│ Compose     │
├─────────────┤
│ mosquitto   │  (MQTT broker)
│ beacon      │  (UDP beacon - host mode)
│ face-service│  (FastAPI in face_service/ folder)
│ n8n         │  (Automation with LFS database)
└─────────────┘
       │
       └──► n8n_data/ (Git LFS tracked)
```

**Structural changes:**
- Face service in `face_service/` subdirectory
- n8n database tracked via Git LFS
- Cleanup scripts in `scripts/`
- More modular structure

---

## 📦 Dependency Changes

### Requirements.txt Enhancement

**Add to new version:**
```txt
# Existing in both
fastapi==0.115.0
uvicorn[standard]==0.30.6
face_recognition==1.3.0
opencv-python==4.10.0.84
numpy>=1.24
python-multipart==0.0.9

# NEW: Add for MQTT support
paho-mqtt==2.0.0
```

---

## 🔄 Migration Checklist

### Files to Copy/Create

- [ ] Copy `face_auth_bridge.py` to new repo root
- [ ] Copy `WINDOWS_SETUP.md` to new repo root
- [ ] Copy `simple_udp_test.py` to new repo root
- [ ] Copy `test_beacon_receive.py` to new repo root

### Files to Modify

- [ ] Update `app.py`:
  - [ ] Add MQTT client initialization
  - [ ] Add `publish_status()` function
  - [ ] Add `get_camera()` function
  - [ ] Add `/camera/release` endpoint
  - [ ] Add `/test-camera` endpoint
  - [ ] Modify `/detect-webcam` to use persistent camera
  - [ ] Add status publishing calls

- [ ] Update `beacon.py`:
  - [ ] Add `os` import
  - [ ] Add BEACON_IP environment variable support
  - [ ] Add enhanced logging

- [ ] Update `docker-compose.yml`:
  - [ ] Change beacon from `network_mode: host` to port mapping
  - [ ] Add `BEACON_IP` environment variable
  - [ ] Update ports section

- [ ] Update `requirements.txt`:
  - [ ] Add `paho-mqtt==2.0.0`

### Configuration Updates

- [ ] Set MQTT broker IP in all files:
  - [ ] `face_auth_bridge.py` → `MQTT_BROKER`
  - [ ] `app.py` → `MQTT_BROKER`
  - [ ] `docker-compose.yml` → `BEACON_IP`
  - [ ] Flutter app → `localBrokerAddress`

- [ ] Verify timeout values:
  - [ ] Flutter: `_cameraInitTimeout` = 27s
  - [ ] Flutter: `_authResponseTimeout` = 50s
  - [ ] Bridge: API timeout = 35s
  - [ ] Bridge: Camera scan = 8s

### Testing Steps

1. [ ] Test beacon discovery:
   ```bash
   python simple_udp_test.py
   ```

2. [ ] Test camera initialization:
   ```bash
   curl http://localhost:8000/test-camera
   ```

3. [ ] Test MQTT connection:
   ```bash
   python face_auth_bridge.py
   # Should show: [MQTT] Connected to broker
   ```

4. [ ] Test full authentication flow:
   - [ ] Start Docker services
   - [ ] Start app.py
   - [ ] Start face_auth_bridge.py
   - [ ] Test from Flutter app

---

## 📌 Important Notes

### 1. Camera Persistence is Critical

**DO NOT** release camera in `/detect-webcam` endpoint! This causes 20s delay on every request.

**Correct pattern:**
```python
# detect-webcam
cap = get_camera()  # Persistent
try:
    # ... use camera ...
finally:
    pass  # DON'T RELEASE

# Separate release endpoint
@app.post("/camera/release")
def release_camera():
    camera.release()
```

### 2. Status Publishing Timing

**CRITICAL:** Backend must send "initializing" status **immediately before** calling `get_camera()`, not from the bridge.

**Why:** Ensures user sees "Initializing..." message at the right time (when 20s delay actually starts).

**Correct:**
```python
# app.py - /detect-webcam
publish_status("initializing", "Initializing camera, please wait...")
cap = get_camera()  # ← 20s delay happens HERE
publish_status("scanning", "Camera ready! Please look at the camera...")
```

**Wrong:**
```python
# face_auth_bridge.py - DON'T DO THIS
publish_status("initializing", ...)  # Too early!
response = requests.post(...)  # Status sent before camera init starts
```

### 3. IP Address Must Match

All services must use the same IP address (your WiFi IP):
- `face_auth_bridge.py` → `MQTT_BROKER`
- `app.py` → `MQTT_BROKER`
- `docker-compose.yml` → `BEACON_IP`
- Flutter app → `MqttConfig.localBrokerAddress`

**Find your IP:**
```powershell
ipconfig | findstr IPv4
```

### 4. Beacon Port Binding

**Flutter must bind to beacon port 18830 to receive broadcasts:**

```dart
final socket = await RawDatagramSocket.bind(
  InternetAddress.anyIPv4,
  18830,  // MUST bind to beacon port
);
```

**Why:** UDP broadcasts are sent TO port 18830, so listener must bind to that port.

### 5. Timeout Relationship

```
_authResponseTimeout (50s)
    ├─ Camera init (20s)
    ├─ Scanning (8s)
    ├─ Processing (10s)
    └─ Network buffer (12s)

Bridge API timeout (35s)
    ├─ Camera init (20s)
    ├─ Scanning (8s)
    └─ Processing buffer (7s)
```

**Rule:** `_authResponseTimeout` > Bridge timeout > (camera init + scan duration)

---

## 🎯 Summary of Critical Changes

| Change                        | Impact                          | Priority |
|-------------------------------|--------------------------------|----------|
| Persistent camera             | 20s → instant on repeat auths  | ⭐⭐⭐⭐⭐ |
| MQTT bridge (`face_auth_bridge.py`) | Enables Flutter integration    | ⭐⭐⭐⭐⭐ |
| Status publishing             | Real-time user feedback        | ⭐⭐⭐⭐   |
| Beacon IP environment variable| Fixes discovery issues         | ⭐⭐⭐⭐   |
| Extended timeouts             | Prevents premature timeouts    | ⭐⭐⭐⭐   |
| Camera release endpoint       | Explicit resource management   | ⭐⭐⭐    |
| Testing scripts               | Debugging beacon/network       | ⭐⭐⭐    |
| Windows setup guide           | Essential for Windows users    | ⭐⭐⭐    |

---

## 📞 Next Steps

1. **Review this document** carefully
2. **Apply changes** to new repository following checklist
3. **Test each component** individually (beacon, camera, MQTT, bridge)
4. **Test full flow** from Flutter app
5. **Update documentation** in new repo with any additional findings
6. **Commit changes** with descriptive messages referencing this migration guide

---

## 📚 Additional Resources

- **WINDOWS_SETUP.md**: Complete Windows installation guide
- **simple_udp_test.py**: Beacon broadcast testing
- **test_beacon_receive.py**: Beacon discovery testing
- **Flutter app logs**: Check status message timing and beacon discovery

---

**Document Version:** 1.0  
**Last Updated:** October 10, 2025  
**Author:** Migration Documentation System
