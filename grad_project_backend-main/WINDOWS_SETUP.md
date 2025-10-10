# Running Face Recognition Backend on Windows

## The Problem
Docker on Windows cannot access webcams via `/dev/video0` device path.

## The Solution
Run the face service directly on Windows while keeping MQTT broker in Docker.

---

## Complete Setup (10 Minutes)

### Step 1: Install Python (if not already installed)

1. Download Python 3.11+ from [python.org](https://www.python.org/downloads/)
2. **Important**: Check "Add Python to PATH" during installation
3. Verify installation:
```powershell
python --version
# Should show: Python 3.11.x or higher
```

### Step 2: Install CMake (Required for face_recognition)

**Option A: Via Chocolatey** (Recommended)
```powershell
# Install Chocolatey if you don't have it:
# Run PowerShell as Administrator
Set-ExecutionPolicy Bypass -Scope Process -Force
[System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072
iex ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))

# Install CMake
choco install cmake
```

**Option B: Manual Download**
1. Download CMake from [cmake.org](https://cmake.org/download/)
2. Run installer and check "Add CMake to PATH"

### Step 3: Install Visual Studio Build Tools

Face recognition requires C++ compiler:

1. Download [Visual Studio Build Tools](https://visualstudio.microsoft.com/downloads/#build-tools-for-visual-studio-2022)
2. Run installer
3. Select "Desktop development with C++"
4. Click Install

### Step 4: Setup Face Service

Open PowerShell in `grad_project_backend-main` folder:

```powershell
cd C:\Werk\AIoT\grad_project_backend-main

# Create virtual environment
python -m venv venv

# Activate virtual environment
.\venv\Scripts\Activate.ps1

# Upgrade pip
python -m pip install --upgrade pip

# Install dependencies
pip install fastapi uvicorn[standard] opencv-python numpy python-multipart

# Install face_recognition (this takes a few minutes)
pip install face_recognition
```

**If face_recognition fails to install**, install dlib first:
```powershell
pip install dlib
pip install face_recognition
```

### Step 5: Add Face Images

```powershell
# Create persons directory if it doesn't exist
New-Item -ItemType Directory -Force -Path "persons"

# Copy your face images
Copy-Item "C:\path\to\your\photo.jpg" -Destination "persons\yourname.jpg"
```

**Important**: The filename (without extension) becomes the recognized name.

Example:
```
persons\
├── mother.jpg
├── father.jpg
├── child1.jpg
└── child2.jpg
```

### Step 6: Start MQTT Broker (Docker)

```powershell
# Start only MQTT broker and beacon (not face-service)
docker-compose up -d mosquitto broker-beacon

# Verify they're running
docker-compose ps
```

Expected output:
```
NAME             STATUS
mosquitto        Up
broker-beacon    Up
```

### Step 7: Run Face Service Locally

```powershell
# Make sure you're in grad_project_backend-main
# And venv is activated (you should see (venv) in prompt)

# Run the server
uvicorn app:app --host 0.0.0.0 --port 8000 --reload
```

You should see:
```
INFO:     Uvicorn running on http://0.0.0.0:8000
INFO:     Application startup complete.
```

### Step 8: Test It!

1. **Open Web UI**: http://localhost:8000/ui
2. Click "Start" - You should see your webcam feed
3. Your face should be detected and labeled with green box

---

## Testing Face Recognition

### Test 1: Health Check
```powershell
curl http://localhost:8000/healthz
```
Expected: `{"ok":true}`

### Test 2: Webcam Detection (PowerShell Syntax)
```powershell
# Note: Use Invoke-WebRequest or Invoke-RestMethod in PowerShell
Invoke-RestMethod -Uri "http://localhost:8000/detect-webcam" `
  -Method POST `
  -Form @{
    persons_dir = '/data/persons'
    webcam = 0
    max_seconds = 8
    stop_on_first = 'true'
    annotated_dir = '/data/caps'
  }
```

### Test 3: Image Upload
```powershell
# Save this as a .ps1 file or run directly
$uri = "http://localhost:8000/detect-image"
$form = @{
    persons_dir = 'persons'
    model = 'hog'
    tolerance = '0.6'
    file = Get-Item -Path "path\to\test_image.jpg"
}

Invoke-RestMethod -Uri $uri -Method Post -Form $form
```

---

## Mobile App Configuration

The mobile app will discover the service automatically, but ensure:

1. **Same Network**: Phone and computer on same WiFi
2. **Firewall**: Allow port 1883 (MQTT) and 18830 (Beacon)
3. **IP Address**: Note your computer's IP:
```powershell
ipconfig
# Look for "IPv4 Address" under your WiFi adapter
```

The beacon will broadcast your IP automatically: `192.168.x.x`

---

## Troubleshooting

### ❌ "face_recognition" installation fails

**Solution**: Install Visual C++ Build Tools
```powershell
# Install dlib separately
pip install cmake
pip install dlib
pip install face_recognition
```

### ❌ "Cannot open webcam 0"

**Solutions**:
1. Close all apps using webcam (Teams, Zoom, Skype)
2. Try different webcam index:
```python
# In app.py, change webcam parameter from 0 to 1
webcam: int = Form(1)
```

3. Check camera permissions:
   - Windows Settings → Privacy → Camera
   - Enable camera access for desktop apps

### ❌ PowerShell says "curl : The request was aborted..."

**Solution**: Use `Invoke-RestMethod` or `Invoke-WebRequest` instead:
```powershell
Invoke-RestMethod http://localhost:8000/healthz
```

### ❌ Beacon not broadcasting

**Solution**: Ensure broker-beacon is running:
```powershell
docker-compose logs broker-beacon
# Should show "sent GLOBAL" messages every 2 seconds
```

### ❌ Mobile app can't connect

**Check these**:
1. Computer firewall allows ports 1883, 18830
2. Computer and phone on same network
3. MQTT broker running: `docker-compose ps`
4. Test MQTT locally:
```powershell
# Install mosquitto clients
choco install mosquitto

# Test subscription
mosquitto_sub -h localhost -t "home/#" -v
```

---

## Docker Alternative (Linux Containers on Windows)

If you have WSL2 (Windows Subsystem for Linux):

```powershell
# In WSL2 terminal
cd /mnt/c/Werk/AIoT/grad_project_backend-main

# Start all services (including face-service)
docker-compose up -d

# WSL2 can access /dev/video0
```

---

## Daily Usage

### Start Everything
```powershell
# Terminal 1: Start MQTT
cd C:\Werk\AIoT\grad_project_backend-main
docker-compose up -d mosquitto broker-beacon

# Terminal 2: Start Face Service
cd C:\Werk\AIoT\grad_project_backend-main
.\venv\Scripts\Activate.ps1
uvicorn app:app --host 0.0.0.0 --port 8000
```

### Stop Everything
```powershell
# Press Ctrl+C in Terminal 2 (face service)

# Stop MQTT broker
docker-compose down
```

---

## Integration with Flutter App

Once face service is running:

1. Open Flutter app on phone
2. Ensure phone on same WiFi as computer
3. Tap "Sign in with Face Recognition"
4. App auto-discovers at `192.168.x.x:1883`
5. Look at camera when prompted
6. Authenticated! ✅

---

## Performance Tips

### Faster Face Recognition
```python
# In app.py, use 'hog' model (faster, CPU only)
model: str = Form("hog")

# For better accuracy (requires GPU):
model: str = Form("cnn")
```

### Reduce Processing Load
```python
# Process every 10th frame instead of every 5th
frame_stride: int = Form(10)
```

### Better Recognition
- Add multiple photos of same person
- Use good lighting
- Front-facing photos
- Adjust tolerance (0.6 default, 0.7 = more lenient)

---

## Next Steps

✅ Face service running locally on Windows
✅ MQTT broker in Docker  
✅ Beacon broadcasting
✅ Ready to test with mobile app!

**Test it now**: Open `http://localhost:8000/ui` and verify your face is detected.

