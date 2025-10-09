# Face Authentication - Quick Start Guide

## 🚀 Quick Setup (5 Minutes)

### 1. Start the Backend

**On Linux/Mac**:
```bash
cd grad_project_backend-main
docker-compose up -d
```

**On Windows**: Docker can't access webcam, see `grad_project_backend-main/WINDOWS_SETUP.md` for complete Windows setup instructions.

**Quick Windows Setup**:
```powershell
# Terminal 1: Start MQTT only
cd grad_project_backend-main
docker-compose up -d mosquitto broker-beacon

# Terminal 2: Run face service locally
.\venv\Scripts\Activate.ps1  # (after initial setup)
uvicorn app:app --host 0.0.0.0 --port 8000
```

**Verify it's running**:
```bash
docker-compose ps
# All services should be "Up"

curl http://localhost:8000/healthz
# Should return: {"ok":true}
```

### 2. Add Face Images

```bash
# Add family member photos to persons directory
cp path/to/mother.jpg grad_project_backend-main/persons/mother.jpg
cp path/to/father.jpg grad_project_backend-main/persons/father.jpg

# Restart face service to load new faces
docker-compose restart face-service
```

**File naming**: The filename (without extension) becomes the recognized user name.

### 3. Connect Mobile App

1. Ensure mobile device is on **same network** as the computer running Docker
2. Open the Smart Home app
3. On login screen, tap **"Sign in with Face Recognition"**
4. App will auto-discover the face recognition system
5. Look at the camera when prompted
6. You're logged in! ✅

## 📱 User Flow

```
Login Screen
    ↓
Tap "Sign in with Face Recognition"
    ↓
[Auto-discovery 2-5s]
    ↓
"Look at the Camera"
    ↓
[Face scanned & verified]
    ↓
Home Screen (with your settings loaded)
```

## 🛠️ Troubleshooting

### ❌ "Face recognition system not found"

**Solution 1**: Check backend is running
```bash
docker-compose ps
```

**Solution 2**: Verify you're on the same network
- Computer IP: Check with `ipconfig` (Windows) or `ifconfig` (Mac/Linux)
- Mobile IP: Settings → WiFi → Your Network → IP Address
- First 3 numbers should match: `192.168.1.xxx`

**Solution 3**: Check firewall
```bash
# Windows: Allow UDP port 18830
# Mac: System Preferences → Security & Privacy → Firewall

# Test beacon manually:
docker-compose logs broker-beacon
# Should show "sent GLOBAL" messages every 2 seconds
```

### ❌ "Failed to connect"

**Check MQTT broker**:
```bash
docker-compose logs mosquitto
# Should show "mosquitto version 2.x starting"

# Test MQTT connection:
mosquitto_sub -h localhost -t "home/#" -v
```

### ❌ "Request timed out"

**Check camera access**:
```bash
docker-compose logs face-service
# Should show successful webcam initialization

# Test the web UI:
# Open browser: http://localhost:8000/ui
# Click "Start" - you should see camera feed
```

### ❌ "Face not recognized" (but it's the right person)

**Solution**: Adjust tolerance or add more photos

**Option 1**: Lower the tolerance (more lenient)
```dart
// In face_auth_service.dart, change tolerance parameter
// Default is 0.6, try 0.7 or 0.8
```

**Option 2**: Add multiple photos
```bash
# Add multiple angles/lighting conditions
cp photo1.jpg persons/mother_1.jpg
cp photo2.jpg persons/mother_2.jpg
cp photo3.jpg persons/mother_3.jpg

docker-compose restart face-service
```

## 🔧 Configuration

### Change MQTT Broker Settings

**In mobile app**:
1. Settings → Connection Mode → Local
2. MQTT Broker Address: `192.168.1.100` (change to your computer's IP)
3. Port: `1883`

**Get your computer's IP**:
```bash
# Windows
ipconfig
# Look for "IPv4 Address" under your WiFi adapter

# Mac/Linux
ifconfig
# Look for "inet" under en0 or wlan0
```

### Multiple Users Setup

**Add all family members**:
```bash
persons/
├── mother.jpg      # Mom's photo
├── father.jpg      # Dad's photo
├── child1.jpg      # First child
└── child2.jpg      # Second child
```

**Link to Firebase accounts** (in app code):
```dart
// In AuthProvider, map face names to Firebase users
final faceToEmail = {
  'mother': 'mom@family.com',
  'father': 'dad@family.com',
  'child1': 'kid1@family.com',
  'child2': 'kid2@family.com',
};
```

## 📊 System Status

### Check Everything is Working

```bash
# 1. Backend services
docker-compose ps
# Expected: mosquitto, broker-beacon, face-service all "Up"

# 2. MQTT broker
mosquitto_sub -h localhost -t "home/#" -v
# Should connect without errors

# 3. Beacon
echo '{"type":"WHO_IS","name":"face-broker"}' | nc -u -w1 255.255.255.255 18830
# Should return: {"name":"face-broker","ip":"...","port":1883}

# 4. Face service
curl http://localhost:8000/healthz
# Should return: {"ok":true}

# 5. Web UI
# Open: http://localhost:8000/ui
# Should show camera feed and face detection
```

## 🎯 Testing Locally

### Manual MQTT Test

**Terminal 1 - Subscribe to responses**:
```bash
mosquitto_sub -h localhost -t "home/auth/face/response" -v
```

**Terminal 2 - Send auth request**:
```bash
mosquitto_pub -h localhost -t "home/auth/face/request" \
  -m '{"requestId":"test-123","deviceId":"test","timestamp":"2025-10-09T10:00:00Z"}'
```

**Expected**: Terminal 1 should receive a response with recognized face

### Test Face Detection

```bash
# Upload a test image
curl -X POST http://localhost:8000/detect-image \
  -F "persons_dir=/data/persons" \
  -F "file=@test_photo.jpg" \
  -F "model=hog" \
  -F "tolerance=0.6"

# Expected response:
# {
#   "detections": [
#     {
#       "name": "mother",
#       "distance": 0.45,
#       "box": {...}
#     }
#   ]
# }
```

## 📝 User Settings (Firestore)

Each user's settings are automatically saved to Firestore:

**Firestore Structure**:
```
users/{userId}/settings/preferences/
├── themeMode: "dark"
├── language: "en"
├── mqttBrokerAddress: "192.168.1.100"
├── enableNotifications: true
└── ... (all other settings)
```

**What's Saved**:
- ✅ Theme (dark/light/system)
- ✅ Language (en/de/ar)
- ✅ MQTT connection settings
- ✅ Notification preferences
- ✅ Automation rules
- ✅ Device favorites

**When Settings Sync**:
- 📥 **On Login**: Settings loaded from Firestore
- 💾 **On Change**: Auto-saved to Firestore
- 🔄 **Cross-Device**: Same settings on all devices

## 🔐 Security Notes

**Current Setup**: Development mode (not secure)
- Anonymous MQTT connections
- No encryption
- Local network only

**For Production**: Enable these security features
- ✅ MQTT username/password
- ✅ TLS/SSL encryption (port 8883)
- ✅ Firewall rules
- ✅ VPN for remote access

## 📚 More Documentation

- **Full Integration Guide**: `FACE_AUTH_INTEGRATION.md` (26 pages)
- **Implementation Summary**: `FACE_AUTH_IMPLEMENTATION_SUMMARY.md`
- **Backend README**: `grad_project_backend-main/README.md`

## 🆘 Getting Help

**Check logs**:
```bash
# All services
docker-compose logs -f

# Specific service
docker-compose logs -f face-service
docker-compose logs -f broker-beacon
docker-compose logs -f mosquitto
```

**Common Issues**:
1. **Port conflicts**: Stop other services using ports 1883, 8000, 18830
2. **Camera busy**: Close other apps using webcam
3. **Network issues**: Disable VPN, use same WiFi network
4. **Docker issues**: `docker-compose down` then `docker-compose up -d`

## ✅ Verification Checklist

- [ ] Docker services running (`docker-compose ps`)
- [ ] Beacon broadcasting (`docker-compose logs broker-beacon`)
- [ ] MQTT broker accepting connections (`mosquitto_sub -h localhost -t "#"`)
- [ ] Face service healthy (`curl http://localhost:8000/healthz`)
- [ ] Camera working (`http://localhost:8000/ui`)
- [ ] Face images in `persons/` directory
- [ ] Mobile on same network as computer
- [ ] Mobile app can discover beacon
- [ ] Face authentication completes successfully

---

**Ready to test!** 🎉

Just run `docker-compose up -d` and tap "Sign in with Face Recognition" in the app.
