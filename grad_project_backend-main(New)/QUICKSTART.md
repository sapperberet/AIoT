# 🎯 QUICK START - Face Recognition Backend

## 📋 TL;DR - Get Started in 5 Minutes

### 1️⃣ Find Your WiFi IP
```powershell
ipconfig
# Look for IPv4 Address: 192.168.1.7 (example)
```

### 2️⃣ Run Setup Script
```powershell
cd C:\Werk\AIoT\grad_project_backend-main(New)
.\start.ps1
```

### 3️⃣ Update Flutter App
Edit `C:\Werk\AIoT\lib\core\config\mqtt_config.dart`:
```dart
static const String localBrokerAddress = '192.168.1.7';  // YOUR IP
```

### 4️⃣ Add Face Images
```powershell
# Copy your face photo
Copy-Item "C:\path\to\your\photo.jpg" -Destination "persons\yourname.jpg"
```

### 5️⃣ Test Flutter App
```powershell
cd C:\Werk\AIoT
flutter run
# Navigate to face authentication screen
# First auth: ~20s, subsequent: <5s!
```

---

## 📁 Files You Need to Know

| File | Purpose | Action Required |
|------|---------|----------------|
| `docker-compose.yml` | Docker services | Update `BEACON_IP` with your WiFi IP |
| `.env` | Environment config | Update `MQTT_BROKER` with your WiFi IP |
| `persons/` | Face images | Add photos (filename = name) |
| `start.ps1` | Auto startup | Run this to start everything |
| `OPTIMIZED_SETUP.md` | Full guide | Read for detailed instructions |

---

## 🚀 What Makes This Setup Special?

### ⚡ Persistent Camera = 85% Faster!
- **Old way:** 20s delay on EVERY authentication
- **New way:** 20s first time, then <5s forever!

### 📡 Real-time Status Updates
- "Initializing camera..."
- "Camera ready! Look at camera..."
- "Face recognized: john"

### 🎯 Optimized for Windows
- Direct webcam access (Docker can't do this on Windows)
- Hybrid architecture (Docker for MQTT, Windows for camera)

---

## ⚙️ Configuration Cheat Sheet

**Same IP in 3 places:**
1. `docker-compose.yml` → `BEACON_IP=192.168.1.7`
2. `.env` → `MQTT_BROKER=192.168.1.7`
3. Flutter `mqtt_config.dart` → `'192.168.1.7'`

**Directories:**
- `persons/` → Face images (john.jpg, jane.jpg)
- `captures/` → Auto-created snapshots
- `venv/` → Python environment (auto-created)

---

## 🧪 Quick Tests

```powershell
# Test camera
curl http://localhost:8000/test-camera

# Test health
curl http://localhost:8000/healthz

# Check beacon
docker-compose logs broker-beacon

# View all logs
docker-compose logs -f
```

---

## 🛑 Stop Services

```powershell
.\stop.ps1
# Then close Face Service and Bridge windows (Ctrl+C)
```

---

## 📚 Full Documentation

- **SETUP_COMPLETE.md** ← You are here (Quick overview)
- **OPTIMIZED_SETUP.md** ← Full step-by-step guide
- **MIGRATION_CHANGES.md** ← Technical details
- **README.md** ← Original Docker setup

---

## 🎉 Expected Results

### First Face Authentication
```
🔍 Discovering service... (2s)
📡 Beacon found: 192.168.1.7:1883
🔌 Connecting... (1s)
✅ Connected
📸 Initializing camera... (20s) ← ONE TIME ONLY
📸 Camera ready! Look at camera
🔍 Scanning... (3s)
✅ Face recognized: john

Total: ~25s
```

### Second Face Authentication
```
🔍 Discovering service... (2s)
📡 Beacon found: 192.168.1.7:1883
🔌 Connecting... (1s)
✅ Connected
📸 Camera ready! Look at camera (instant!)
🔍 Scanning... (3s)
✅ Face recognized: john

Total: ~5s ← 80% FASTER!
```

---

## 🆘 Common Issues

**"Cannot connect to MQTT"**
→ Check IP addresses match in all 3 files

**"Camera initialization slow"**
→ Normal! First time is 20s, after that <1s

**"Face not recognized"**
→ Check image in persons/ folder, use clear front-facing photo

**"Docker not running"**
→ Start Docker Desktop, then run `.\start.ps1` again

---

**🚀 Ready? Run `.\start.ps1` and enjoy instant face authentication!**
