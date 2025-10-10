# 🚀 Optimized Setup Guide - Face Recognition Backend

This guide provides the **most optimal setup** for running the face recognition backend with Flutter app integration, combining Docker efficiency with Windows compatibility.

---

## 📋 Table of Contents

1. [Architecture Overview](#architecture-overview)
2. [Prerequisites](#prerequisites)
3. [Setup Options](#setup-options)
   - [Option A: Full Docker Setup (Linux/WSL2)](#option-a-full-docker-setup-linuxwsl2)
   - [Option B: Hybrid Setup (Windows - **RECOMMENDED**)](#option-b-hybrid-setup-windows---recommended)
4. [Configuration](#configuration)
5. [Running the Stack](#running-the-stack)
6. [Testing & Verification](#testing--verification)
7. [Troubleshooting](#troubleshooting)

---

## 🏗️ Architecture Overview

### Hybrid Architecture (Windows - **RECOMMENDED**)
```
┌──────────────────┐          ┌──────────────────┐
│   Docker         │          │   Windows Host   │
│   Compose        │          │                  │
├──────────────────┤          ├──────────────────┤
│ mosquitto        │◄────────►│ app.py           │  ← Face detection (direct webcam)
│ (MQTT broker)    │          │                  │
│                  │          │ face_auth_bridge │  ← MQTT bridge
│ broker-beacon    │          │                  │
│ (UDP discovery)  │          │ venv/            │  ← Python environment
│                  │          │ persons/         │  ← Known faces
│ n8n (optional)   │          │ captures/        │  ← Face snapshots
│ (Automation)     │          │                  │
└──────────────────┘          └──────────────────┘
         │                             │
         └─────────────────────────────┘
                 Network: 192.168.1.x
```

**Why Hybrid?**
- ✅ Windows Docker can't access webcam directly
- ✅ Python on Windows has direct webcam access
- ✅ Persistent camera = **instant** authentication (no 20s delay)
- ✅ MQTT broker in Docker = reliable, isolated service
- ✅ Best performance and reliability

---

## ⚙️ Prerequisites

### All Platforms
- **Docker** ≥ 24
- **Docker Compose** ≥ 2
- **Git** and **Git LFS**

### Windows Only (for Hybrid Setup)
- **Python 3.11+** from [python.org](https://www.python.org/downloads/)
- **CMake** for face_recognition compilation
- **Visual Studio Build Tools** for C++ compilation

---

## 🎯 Setup Options

### Option A: Full Docker Setup (Linux/WSL2)

**Use when:** Running on Linux or WSL2 with webcam access

#### 1. Initialize Git LFS
```bash
git lfs install
git lfs track "n8n_data/database.sqlite"
git add .gitattributes
```

#### 2. Find Your IP Address
```bash
# Linux
ip addr show | grep inet | grep -v 127.0.0.1

# Output example: 192.168.1.7
```

#### 3. Update Configuration

Edit `docker-compose.yml`:
```yaml
broker-beacon:
  environment:
    - BEACON_IP=192.168.1.7  # ← YOUR WIFI IP HERE
```

Edit `.env` file (create if doesn't exist):
```env
MQTT_BROKER=localhost
MQTT_PORT=1883
FACE_API_URL=http://localhost:8000
PERSONS_DIR=/data/persons
CAPTURES_DIR=/data/caps
```

#### 4. Prepare Directories and Faces
```bash
mkdir -p persons captures n8n_data
# Add face images to persons/
# Example: persons/john.jpg, persons/jane.jpg
```

#### 5. Build and Start
```bash
docker compose up -d --build
```

#### 6. Access Services
- Face API: http://localhost:8000
- Face UI: http://localhost:8000/ui
- n8n: http://localhost:5678
- MQTT: localhost:1883

---

### Option B: Hybrid Setup (Windows - **RECOMMENDED**)

**Use when:** Running on Windows (Docker can't access webcam)

This is the **optimal setup** with persistent camera and instant authentication.

#### Step 1: Find Your WiFi IP Address

```powershell
ipconfig

# Look for "IPv4 Address" under WiFi adapter
# Example: 192.168.1.7
```

**Save this IP - you'll need it multiple times!**

---

#### Step 2: Install Python Environment

##### 2.1 Install Python 3.11+
- Download from [python.org](https://www.python.org/downloads/)
- ✅ Check "Add Python to PATH" during installation
- Verify: `python --version`

##### 2.2 Install CMake

**Option A: Via Chocolatey (Recommended)**
```powershell
# Run PowerShell as Administrator
Set-ExecutionPolicy Bypass -Scope Process -Force
[System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072
iex ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))

# Install CMake
choco install cmake
```

**Option B: Manual**
- Download from [cmake.org](https://cmake.org/download/)
- Check "Add CMake to PATH" during installation

##### 2.3 Install Visual Studio Build Tools
- Download [Build Tools](https://visualstudio.microsoft.com/downloads/#build-tools-for-visual-studio-2022)
- Select "Desktop development with C++"
- Install

---

#### Step 3: Setup Python Virtual Environment

```powershell
cd C:\Werk\AIoT\grad_project_backend-main(New)

# Create virtual environment
python -m venv venv

# Activate virtual environment
.\venv\Scripts\Activate.ps1

# If you get execution policy error, run:
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser

# Upgrade pip
python -m pip install --upgrade pip

# Install dependencies (this takes 5-10 minutes)
pip install -r requirements.txt
```

**If face_recognition fails**, install dlib first:
```powershell
pip install dlib
pip install face_recognition
```

---

#### Step 4: Configure Environment Variables

Create `.env` file in the project root:

```env
# MQTT Configuration - Use your WiFi IP
MQTT_BROKER=192.168.1.7

# API Configuration
MQTT_PORT=1883
FACE_API_URL=http://localhost:8000

# Directories (Windows paths)
PERSONS_DIR=persons
CAPTURES_DIR=captures
```

**⚠️ IMPORTANT:** Replace `192.168.1.7` with YOUR actual WiFi IP!

---

#### Step 5: Update docker-compose.yml

Edit `docker-compose.yml` and update the beacon IP:

```yaml
broker-beacon:
  image: python:3.11-slim
  container_name: broker-beacon
  restart: unless-stopped
  ports:
    - "18830:18830/udp"
  environment:
    - BEACON_IP=192.168.1.7  # ← YOUR WIFI IP HERE
  volumes:
    - ./beacon.py:/app/beacon.py:ro
  command: ["python", "/app/beacon.py"]
```

---

#### Step 6: Add Face Images

```powershell
# Create persons directory
New-Item -ItemType Directory -Force -Path "persons"

# Copy your face images
# Copy-Item "C:\path\to\your\photo.jpg" -Destination "persons\yourname.jpg"
```

**Important:** 
- Filename (without extension) = person's name
- Example: `persons\john.jpg` → recognized as "john"
- Use clear, front-facing photos
- One person per image

Example structure:
```
persons\
├── john.jpg
├── jane.jpg
├── alice.jpg
└── bob.jpg
```

---

#### Step 7: Start Docker Services (MQTT + Beacon)

```powershell
# Start only mosquitto and beacon in Docker
docker-compose up -d mosquitto broker-beacon

# Verify they're running
docker-compose ps

# Check logs
docker-compose logs -f broker-beacon
# Should see: [beacon] sent GLOBAL -> 255.255.255.255:18830
```

---

#### Step 8: Start Face Service on Windows

```powershell
# Make sure venv is activated
.\venv\Scripts\Activate.ps1

# Start face detection service
python app.py
```

**You should see:**
```
[MQTT] Connected to broker at 192.168.1.7:1883
INFO:     Uvicorn running on http://0.0.0.0:8000
```

**Leave this terminal running!**

---

#### Step 9: Start MQTT Bridge (New Terminal)

Open a **new PowerShell window**:

```powershell
cd C:\Werk\AIoT\grad_project_backend-main(New)
.\venv\Scripts\Activate.ps1

# Start MQTT bridge
python face_auth_bridge.py
```

**You should see:**
```
[BRIDGE] Starting Face Authentication MQTT Bridge
[BRIDGE] MQTT Broker: 192.168.1.7:1883
[MQTT] Connected to broker at 192.168.1.7:1883
[MQTT] Subscribed to home/auth/face/request
[STATUS] ready: Face authentication service ready
```

**Leave this terminal running too!**

---

## 🔧 Configuration

### Update Flutter App Configuration

Edit `lib/core/config/mqtt_config.dart`:

```dart
class MqttConfig {
  // MQTT Broker Configuration
  static const String localBrokerAddress = '192.168.1.7';  // ← YOUR WIFI IP
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

### Verify Timeouts

File: `lib/core/services/face_auth_service.dart`

```dart
// Timeouts - These are optimized for Windows camera initialization
static const Duration _beaconDiscoveryTimeout = Duration(seconds: 2);
static const Duration _cameraInitTimeout = Duration(seconds: 27);  // Windows camera takes ~20s
static const Duration _authResponseTimeout = Duration(seconds: 50);  // Full auth cycle
```

---

## 🚀 Running the Stack

### Hybrid Setup (Windows)

**Terminal 1 - Docker Services:**
```powershell
docker-compose up -d mosquitto broker-beacon
```

**Terminal 2 - Face Service:**
```powershell
.\venv\Scripts\Activate.ps1
python app.py
```

**Terminal 3 - MQTT Bridge:**
```powershell
.\venv\Scripts\Activate.ps1
python face_auth_bridge.py
```

**Terminal 4 - Flutter App:**
```powershell
cd C:\Werk\AIoT
flutter run
```

### Quick Start Script (Optional)

Create `start.ps1`:
```powershell
# Start Docker services
docker-compose up -d mosquitto broker-beacon

# Wait for services to start
Start-Sleep -Seconds 5

# Start face service in new window
Start-Process powershell -ArgumentList "-NoExit", "-Command", "cd '$PWD'; .\venv\Scripts\Activate.ps1; python app.py"

# Wait a bit
Start-Sleep -Seconds 3

# Start bridge in new window
Start-Process powershell -ArgumentList "-NoExit", "-Command", "cd '$PWD'; .\venv\Scripts\Activate.ps1; python face_auth_bridge.py"

Write-Host "✅ All services started!"
Write-Host "Face API: http://localhost:8000"
Write-Host "MQTT Broker: 192.168.1.7:1883"
```

Run with: `.\start.ps1`

---

## 🧪 Testing & Verification

### 1. Test Camera Initialization

```powershell
curl http://localhost:8000/test-camera
```

**Expected output:**
```json
{
  "success": true,
  "camera_opened": true,
  "open_time": 18.5,
  "first_frame_time": 18.7,
  "total_time": 18.9
}
```

### 2. Test Beacon Discovery

Create `test_beacon.py`:
```python
import socket, json

sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
sock.bind(("", 18830))
sock.settimeout(5)

print("Listening for beacon...")
try:
    data, addr = sock.recvfrom(1024)
    print(f"✅ Received from {addr}: {data.decode()}")
except socket.timeout:
    print("❌ No beacon received")
```

Run: `python test_beacon.py`

### 3. Test MQTT Connection

Use MQTT Explorer or mosquitto_sub:
```powershell
# Subscribe to status topic
docker exec mosquitto mosquitto_sub -t "home/auth/face/status"
```

### 4. Test Face Detection API

```powershell
# Health check
curl http://localhost:8000/healthz

# Test webcam detection
curl -X POST http://localhost:8000/detect-webcam `
  -F "persons_dir=persons" `
  -F "webcam=0" `
  -F "max_seconds=8" `
  -F "annotated_dir=captures"
```

### 5. Test Full Authentication Flow

From Flutter app:
1. Navigate to face authentication screen
2. Click "Authenticate with Face"
3. **First time:** Wait ~20s for camera init (one-time only!)
4. **Subsequent times:** Instant camera access (<1s)
5. Look at camera for 2-3 seconds
6. Should recognize your face

**Status messages you should see:**
```
🔍 Discovering service...
📡 Beacon found: 192.168.1.7:1883
🔌 Connecting...
✅ Connected
📸 Initializing camera... (first time only)
📸 Camera ready! Look at the camera
✅ Face recognized: john
```

---

## 🔧 Troubleshooting

### Camera Issues

**Problem:** "Cannot open webcam"
```powershell
# Check if camera is in use
# Close other apps using camera (Zoom, Teams, etc.)

# Test camera
python -c "import cv2; cap = cv2.VideoCapture(0); print('OK' if cap.isOpened() else 'FAIL')"
```

**Problem:** Camera initialization takes too long
- **This is normal on Windows!** First init: ~20s
- Subsequent authentications: <1s (persistent camera)
- Don't restart app.py between authentications

### Beacon Discovery Issues

**Problem:** Flutter can't find beacon

```powershell
# Check beacon is broadcasting
docker-compose logs broker-beacon
# Should see: [beacon] sent GLOBAL -> 255.255.255.255:18830

# Check firewall
# Windows Firewall → Allow UDP port 18830

# Verify IP is correct
ipconfig  # Should match BEACON_IP in docker-compose.yml
```

### MQTT Connection Issues

**Problem:** Bridge can't connect to MQTT

```powershell
# Check mosquitto is running
docker-compose ps mosquitto

# Test MQTT connection
docker exec mosquitto mosquitto_pub -t "test" -m "hello"

# Check IP address matches
# app.py: MQTT_BROKER = "192.168.1.7"
# face_auth_bridge.py: MQTT_BROKER = "192.168.1.7"
# docker-compose.yml: BEACON_IP=192.168.1.7
# Flutter: localBrokerAddress = '192.168.1.7'
```

### Face Recognition Issues

**Problem:** Face not recognized

1. **Check face image quality:**
   - Clear, front-facing photo
   - Good lighting
   - Face not too small
   - No sunglasses/mask

2. **Check person directory:**
   ```powershell
   dir persons
   # Should show: john.jpg, jane.jpg, etc.
   ```

3. **Adjust tolerance:**
   - Lower = stricter (default: 0.6)
   - Higher = more lenient
   - Edit in face_auth_bridge.py: `"tolerance": "0.6"`

### Performance Issues

**Problem:** Slow response

- **First auth:** 20-25s (camera init)
- **Subsequent:** 3-5s (scan + process)
- **If always slow:** Camera not persisting, check app.py using `get_camera()`

---

## 📊 Performance Benchmarks

| Metric                    | First Auth | Subsequent Auths |
|---------------------------|------------|------------------|
| Camera initialization     | 18-20s     | 0s (cached)      |
| Beacon discovery          | 1-2s       | 1-2s             |
| Face scanning             | 2-8s       | 2-8s             |
| MQTT round-trip           | <100ms     | <100ms           |
| **Total Time**            | **22-30s** | **3-10s**        |

**Key Optimization:** Persistent camera reduces subsequent authentications by **85%**!

---

## 🎯 Best Practices

### 1. Keep Camera Service Running
- Don't restart app.py between authentications
- Camera persists across requests
- First auth: slow (20s), subsequent: fast (<5s)

### 2. Add Quality Face Images
- Front-facing, well-lit photos
- Consistent naming: `firstname.jpg`
- Multiple angles per person (optional): `john_front.jpg`, `john_side.jpg`

### 3. Monitor Services
```powershell
# Check all services
docker-compose ps

# Watch logs
docker-compose logs -f

# Check face service
curl http://localhost:8000/healthz
```

### 4. IP Address Management
- Use static IP on your WiFi network
- Or update all configs when IP changes
- Files to update:
  - `docker-compose.yml` → `BEACON_IP`
  - `.env` → `MQTT_BROKER`
  - Flutter → `mqtt_config.dart`

---

## 🔄 Stopping Services

### Hybrid Setup
```powershell
# Stop Docker services
docker-compose down

# Stop Windows services
# Press Ctrl+C in app.py terminal
# Press Ctrl+C in face_auth_bridge.py terminal
```

### Restart Everything
```powershell
# Stop all
docker-compose down
# Kill any Python processes

# Start fresh
docker-compose up -d mosquitto broker-beacon
.\venv\Scripts\Activate.ps1
python app.py  # Terminal 1
python face_auth_bridge.py  # Terminal 2
```

---

## 📚 Additional Resources

- **MIGRATION_CHANGES.md**: Detailed changes from old to new version
- **README.md**: Original Docker-based setup documentation
- **Python Dependencies**: See `requirements.txt`
- **Docker Services**: See `docker-compose.yml`

---

## ✅ Quick Reference

### Essential Files to Configure

| File                          | What to Change                  | Example Value       |
|-------------------------------|---------------------------------|---------------------|
| `docker-compose.yml`          | `BEACON_IP`                     | `192.168.1.7`       |
| `.env`                        | `MQTT_BROKER`                   | `192.168.1.7`       |
| Flutter `mqtt_config.dart`    | `localBrokerAddress`            | `'192.168.1.7'`     |
| `persons/`                    | Add face images                 | `john.jpg`          |

### Essential Commands

```powershell
# Find your IP
ipconfig

# Start Docker
docker-compose up -d mosquitto broker-beacon

# Start Face Service
.\venv\Scripts\Activate.ps1 ; python app.py

# Start Bridge
.\venv\Scripts\Activate.ps1 ; python face_auth_bridge.py

# Test Camera
curl http://localhost:8000/test-camera

# View Logs
docker-compose logs -f
```

---

**🎉 You're all set!** Your face recognition backend is optimized for maximum performance and reliability.
