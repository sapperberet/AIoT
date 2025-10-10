# 🎯 Complete Setup Workflow - Step by Step

This guide shows you the **exact workflow** to set up the optimized face recognition backend with beacon discovery.

---

## 📋 Prerequisites Check

Run these commands to verify you have everything:

```powershell
# 1. Docker installed?
docker --version
# Expected: Docker version 24.x.x or higher

# 2. Docker running?
docker ps
# Should show table with columns (not error)

# 3. Python installed?
python --version
# Expected: Python 3.11.x or higher

# 4. In correct directory?
cd C:\Werk\AIoT\grad_project_backend-main(New)
pwd
# Expected: C:\Werk\AIoT\grad_project_backend-main(New)
```

**If any fail, install missing prerequisites first!**

---

## 🚀 Step-by-Step Setup

### Step 1: Find Your WiFi IP Address

```powershell
ipconfig
```

**Look for "Wireless LAN adapter WiFi":**
```
Wireless LAN adapter WiFi:
   IPv4 Address. . . . . . . . . . . : 192.168.1.7  ← THIS ONE!
```

**📝 Write down your IP:** `192.168.1.7` (example)

⚠️ **IMPORTANT:** Use this IP in ALL the following steps!

---

### Step 2: Update docker-compose.yml

Open `docker-compose.yml` and find the `broker-beacon` section:

```yaml
broker-beacon:
  image: python:3.11-slim
  container_name: broker-beacon
  restart: unless-stopped
  ports:
    - "18830:18830/udp"
  environment:
    - PYTHONUNBUFFERED=1
    - BEACON_IP=192.168.1.7  # ← CHANGE THIS to YOUR IP!
```

**Change `192.168.1.7` to your actual IP from Step 1.**

Save the file.

---

### Step 3: Create .env File

```powershell
# Copy template
Copy-Item .env.example .env

# Edit .env
notepad .env
```

Update these lines with YOUR IP:
```env
MQTT_BROKER=192.168.1.7  # ← YOUR IP HERE
MQTT_PORT=1883
FACE_API_URL=http://localhost:8000
PERSONS_DIR=persons
CAPTURES_DIR=captures
```

Save and close.

---

### Step 4: Run Automated Setup

```powershell
# Run the setup script
.\start.ps1
```

**The script will:**
1. ✅ Check Docker is running
2. ✅ Create Python virtual environment (if needed)
3. ✅ Install all dependencies (~5-10 minutes)
4. ✅ Create directories (persons/, captures/)
5. ✅ Start Docker services (mosquitto, broker-beacon)
6. ✅ Start Face Detection Service (new window)
7. ✅ Start MQTT Bridge (new window)
8. ✅ Test everything

**Wait for:**
```
═══════════════════════════════════════════════════════
🎉 All Services Started!
═══════════════════════════════════════════════════════

📋 Service Status:
   🐳 Docker Services: Running
   🤖 Face Detection:  http://localhost:8000
   🌉 MQTT Bridge:     Running
   📡 MQTT Broker:     192.168.1.7:1883
```

---

### Step 5: Verify Services

#### Check 1: Docker Services
```powershell
docker-compose ps
```

**Expected:**
```
NAME             STATUS          PORTS
broker-beacon    Up             0.0.0.0:18830->18830/udp
mosquitto        Up             0.0.0.0:1883->1883/tcp
```

#### Check 2: Beacon Broadcasting
```powershell
docker-compose logs --tail=10 broker-beacon
```

**Expected (every 2 seconds):**
```
[beacon] Using explicit BEACON_IP=192.168.1.7
[beacon] sent GLOBAL -> 255.255.255.255:18830 b'{"name": "face-broker", "ip": "192.168.1.7", "port": 1883}'
```

#### Check 3: Face Detection Service
Look at the **Face Service window** (auto-opened by script):

**Expected:**
```
[MQTT] Connected to broker at 192.168.1.7:1883
INFO:     Uvicorn running on http://0.0.0.0:8000 (Press CTRL+C to quit)
```

#### Check 4: MQTT Bridge
Look at the **Bridge window** (auto-opened by script):

**Expected:**
```
[BRIDGE] MQTT Broker: 192.168.1.7:1883
[MQTT] Connected to broker at 192.168.1.7:1883
[MQTT] Subscribed to home/auth/face/request
[STATUS] ready: Face authentication service ready
```

#### Check 5: Camera Test
```powershell
curl http://localhost:8000/test-camera
```

**Expected:**
```json
{
  "success": true,
  "camera_opened": true,
  "open_time": 18.5,
  "first_frame_time": 18.7,
  "total_time": 18.9
}
```

---

### Step 6: Add Face Images

```powershell
# Create persons directory (already created by script)
# Copy your face photo
Copy-Item "C:\Path\To\Your\Photo.jpg" -Destination "persons\yourname.jpg"

# Example: Add multiple people
Copy-Item "C:\Photos\john.jpg" -Destination "persons\john.jpg"
Copy-Item "C:\Photos\jane.jpg" -Destination "persons\jane.jpg"
```

**Tips:**
- **Filename = Name:** `john.jpg` → recognized as "john"
- **Clear photos:** Front-facing, good lighting
- **No accessories:** No sunglasses, hats, masks
- **Supported formats:** .jpg, .jpeg, .png

**Verify:**
```powershell
dir persons
```

Should show:
```
    Directory: C:\Werk\AIoT\grad_project_backend-main(New)\persons

Mode                 LastWriteTime         Length Name
----                 -------------         ------ ----
-a----        10/10/2025  10:30 AM         245678 john.jpg
-a----        10/10/2025  10:31 AM         198456 jane.jpg
```

---

### Step 7: Update Flutter App

Open Flutter project: `C:\Werk\AIoT`

Edit `lib/core/config/mqtt_config.dart`:

```dart
class MqttConfig {
  // MQTT Broker Configuration
  static const String localBrokerAddress = '192.168.1.7';  // ← YOUR IP HERE
  static const int localBrokerPort = 1883;
  
  // Beacon Configuration
  static const int beaconPort = 18830;
  static const String beaconServiceName = 'face-broker';
  
  // Topics
  static const String faceAuthRequestTopic = 'home/auth/face/request';
  static const String faceAuthResponseTopic = 'home/auth/face/response';
  static const String faceAuthStatusTopic = 'home/auth/face/status';
}
```

**Change `192.168.1.7` to YOUR IP from Step 1.**

Save the file.

---

### Step 8: Test Complete Flow

#### 8.1: Start Flutter App
```powershell
cd C:\Werk\AIoT
flutter run
```

#### 8.2: Navigate to Face Authentication
- Open your app
- Go to face authentication screen
- Tap "Authenticate with Face"

#### 8.3: Watch the Flow

**In Flutter app, you should see:**
```
🔍 Discovering service...
📡 Listening for beacon broadcasts...
📦 Packet received from 192.168.1.7:18830
✅ Beacon discovered: 192.168.1.7:1883
🔌 Connecting to MQTT broker...
✅ Connected
📸 Requesting face authentication...
```

**In Bridge window, you should see:**
```
[MQTT] Received message on home/auth/face/request
[REQUEST] {'requestId': 'abc-123', 'userId': 'unknown'}
[API] Calling face detection service...
```

**In Face Service window, you should see:**
```
[STATUS] initializing: Initializing camera, please wait...
[CAMERA] Initializing camera...
[CAMERA] Initialized in 18.23s
[STATUS] scanning: Camera ready! Please look at the camera for face authentication...
```

**In Flutter app:**
```
📸 Initializing camera... (wait ~20s first time)
📸 Camera ready! Look at the camera
🔍 Scanning for faces...
✅ Face recognized: john
```

#### 8.4: Test Again (Fast!)

**Second authentication:**
```
🔍 Discovering service... (2s)
✅ Beacon discovered: 192.168.1.7:1883
🔌 Connecting... (1s)
✅ Connected
📸 Camera ready! Look at camera (instant! - no 20s wait)
🔍 Scanning... (3s)
✅ Face recognized: john

Total: ~6s (vs 26s first time!)
```

---

## 📊 Expected Timings

| Phase                 | First Auth | Subsequent Auth |
|-----------------------|------------|-----------------|
| Beacon discovery      | 2s         | 2s              |
| MQTT connection       | 1s         | 1s              |
| Camera initialization | **20s**    | **0s** (cached) |
| Face scanning         | 3s         | 3s              |
| **TOTAL**             | **~26s**   | **~6s**         |

**🎯 Key: Subsequent authentications are 77% faster!**

---

## 🔍 Troubleshooting Each Step

### Issue: "Docker is not running"

```powershell
# Start Docker Desktop
# Wait for it to fully start
# Then run: .\start.ps1
```

### Issue: "pip install fails"

```powershell
# Activate venv
.\venv\Scripts\Activate.ps1

# Try dlib first
pip install dlib

# Then face_recognition
pip install face_recognition

# Then rest
pip install -r requirements.txt
```

### Issue: "Beacon not broadcasting"

```powershell
# Check beacon logs
docker-compose logs broker-beacon

# Restart beacon
docker-compose restart broker-beacon

# Check IP in docker-compose.yml matches ipconfig
```

### Issue: "Flutter can't discover beacon"

**Check 1: Beacon is broadcasting**
```powershell
docker-compose logs broker-beacon | Select-String "sent GLOBAL"
```

**Check 2: Firewall allows UDP 18830**
- Open Windows Firewall
- Allow inbound UDP on port 18830

**Check 3: Phone/PC on same WiFi**
- Both must be on same network
- Check phone WiFi settings

**Check 4: IP is correct**
```powershell
ipconfig  # Get current IP
# Compare with docker-compose.yml BEACON_IP
```

### Issue: "Face not recognized"

**Check 1: Image exists**
```powershell
dir persons
# Should show yourname.jpg
```

**Check 2: Image quality**
- Clear, front-facing photo
- Good lighting
- Face clearly visible

**Check 3: Filename**
- `john.jpg` → recognized as "john"
- Must match exactly (case-sensitive on Linux)

**Check 4: Try lower tolerance**
Edit `face_auth_bridge.py`:
```python
"tolerance": "0.5",  # Instead of 0.6 (stricter)
```

### Issue: "Camera initialization always slow"

**This means camera is not persisting!**

**Check 1: Face service didn't restart**
- Keep Face Service window open
- Don't press Ctrl+C between authentications

**Check 2: Using get_camera()**
Check `app.py` has:
```python
cap = get_camera()  # NOT cv2.VideoCapture(0)
```

**Check 3: Camera not released in finally**
```python
finally:
    pass  # DON'T call cap.release()
```

---

## 🛑 Stopping Everything

### Quick Stop
```powershell
.\stop.ps1
```

### Manual Stop

**1. Close Windows (Ctrl+C in each):**
- Face Detection Service window
- MQTT Bridge window

**2. Stop Docker:**
```powershell
docker-compose down
```

**3. Verify:**
```powershell
docker-compose ps
# Should show no running containers
```

---

## 🔄 Restarting After Stop

```powershell
# Start everything
.\start.ps1

# Or manual:
docker-compose up -d mosquitto broker-beacon
.\venv\Scripts\Activate.ps1
python app.py  # Terminal 1
python face_auth_bridge.py  # Terminal 2
```

---

## ✅ Success Checklist

After completing all steps, verify:

- [ ] `ipconfig` shows WiFi IP (e.g., 192.168.1.7)
- [ ] `docker-compose.yml` has BEACON_IP set to your WiFi IP
- [ ] `.env` has MQTT_BROKER set to your WiFi IP
- [ ] Flutter `mqtt_config.dart` has localBrokerAddress set to your WiFi IP
- [ ] `docker-compose ps` shows mosquitto and broker-beacon running
- [ ] `docker-compose logs broker-beacon` shows broadcasts every 2s
- [ ] `curl http://localhost:8000/healthz` returns `{"ok":true}`
- [ ] `curl http://localhost:8000/test-camera` shows success
- [ ] Face Service window shows "Connected to broker"
- [ ] MQTT Bridge window shows "Subscribed to home/auth/face/request"
- [ ] `dir persons` shows face images
- [ ] Flutter app discovers beacon (check logs)
- [ ] First authentication works (~26s)
- [ ] **Second authentication is FAST (~6s)** ← CRITICAL!
- [ ] Face is correctly recognized

---

## 📚 What Next?

### If Everything Works:
1. **Test with multiple faces** (add more images to persons/)
2. **Test from different rooms** (WiFi range)
3. **Test ESP32 integration** (if you have one)
4. **Explore n8n automation** (optional, advanced)

### If Issues Persist:
1. Read `BEACON_EXPLAINED.md` for deep dive
2. Check `OPTIMIZED_SETUP.md` for detailed troubleshooting
3. Review `MIGRATION_CHANGES.md` for technical details
4. Check service logs for specific errors

---

## 🎓 Understanding the Flow

```
Your Phone (Flutter App)
    │
    ├─── 1. Listen UDP :18830 ────────┐
    │                                  │
    ▼                                  ▼
Receives Beacon                   Beacon Broadcasts
{"ip":"192.168.1.7"}              (every 2 seconds)
    │                                  ▲
    │                                  │
    ├─── 2. Connect TCP :1883 ────────┤
    │                                  │
    ▼                                  ▼
MQTT Broker (mosquitto)           Your PC (192.168.1.7)
    │                                  │
    ├─── 3. Publish request ──────────┤
    │                                  │
    ▼                                  ▼
MQTT Bridge                       Face API (app.py)
    │                                  │
    │                              ┌───┴────┐
    │                              │        │
    ▼                              ▼        ▼
Gets response                   Camera   Persons/
    │                            (20s)   (john.jpg)
    │                              │
    ├─── 4. Publish response ─────┤
    │                              │
    ▼                              ▼
Back to Flutter               "john" recognized
    │
    ▼
Show result: "Welcome, john!"
```

---

**🚀 You're ready! Start with `.\start.ps1` and enjoy instant face authentication!**
