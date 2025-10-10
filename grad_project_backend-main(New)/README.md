# 🔐 Face Authentication Backend - Optimized Version# 🧠 Face Detection + MQTT + n8n Automation Stack



**High-performance face recognition service with 77% faster subsequent authentications**This project integrates a **Python-based face detection microservice**, a **Mosquitto MQTT broker**, a **discovery beacon**, and an **n8n automation platform** — all running inside Docker. The stack enables automated workflows triggered by face recognition events and MQTT communication with other devices (e.g., ESP32, IoT lights).



------



## 🎯 What's New in This Version## 🚀 Overview



This repository contains **optimized and enhanced** version of the face authentication backend with:| Component        | Purpose                                                                 |

|------------------|-------------------------------------------------------------------------|

✅ **77% Performance Improvement** - Persistent camera (5s vs 22s on subsequent authentications)  | face-service     | FastAPI container using OpenCV & face_recognition for webcam detection.  |

✅ **Real-time Feedback** - MQTT status updates ("initializing" → "scanning" → "success")  | mosquitto        | Lightweight MQTT broker for service communication.                       |

✅ **Windows Compatible** - Fixed Docker networking for Windows  | broker-beacon    | UDP broadcaster announcing the broker’s IP for device auto-discovery.    |

✅ **One-Command Setup** - Automated startup script (`.\start.ps1`)  | n8n              | Visual automation platform orchestrating workflows via MQTT/API triggers. |

✅ **Complete Documentation** - 10 comprehensive guides covering everything

Everything is self-contained and reproducible — no manual setup required.

---

---

## 🚀 Quick Start (5 Minutes)

## 🧩 Folder Structure

### Prerequisites

- Docker Desktop installed and running```

- Python 3.11+ installedproject-root/

- Windows 10/11 (or adapt scripts for Linux/Mac)├── docker-compose.yml

├── face_service/

### Setup Steps│   ├── app.py

│   ├── Dockerfile

1. **Get your WiFi IP address:**│   └── requirements.txt

   ```powershell├── n8n_data/

   ipconfig│   └── database.sqlite        # stored & versioned via Git LFS

   # Note your IPv4 Address (e.g., 192.168.1.7)├── captures/                  # face snapshots

   ```├── persons/                   # known people

├── beacon.py                  # UDP beacon for broker discovery

2. **Update configuration files with YOUR IP:**├── scripts/

   - `docker-compose.yml` → Set `BEACON_IP`│   └── n8n-prune.sh           # database cleanup helper

   - `.env` (copy from `.env.example`) → Set `MQTT_BROKER`├── .gitattributes

   - Flutter `mqtt_config.dart` → Set `localBrokerAddress`└── .gitignore

```

3. **Run automated setup:**

   ```powershell---

   .\start.ps1

   ```## ⚙️ Prerequisites & Setup



4. **Add face images:**- **Docker** ≥ 24

   ```powershell- **Docker Compose** ≥ 2

   Copy-Item "C:\Path\To\Photo.jpg" -Destination "persons\yourname.jpg"- **Git** and **Git LFS**

   ```

Initialize Git LFS once:

5. **Test from Flutter app:**```bash

   - First authentication: ~22 secondsgit lfs install

   - Second authentication: **~5 seconds** ← 77% faster! 🚀git lfs track "n8n_data/database.sqlite"

git add .gitattributes

**Done!** Read [QUICKSTART.md](QUICKSTART.md) for details.git commit -m "Track n8n DB via LFS"

```

---

Prepare directories and known faces:

## 📚 Documentation Guide```bash

mkdir -p persons captures n8n_data scripts

### 🎯 For Backend Developer (Understanding Changes)# Add images to persons/

persons/

**Start here if you want to know what was changed and why:**├── alice/1.jpg

├── bob/1.jpg

1. **[QUICK_CHANGE_SUMMARY.md](QUICK_CHANGE_SUMMARY.md)** ⭐ **READ THIS FIRST**```

   - 5-minute overview of all changes

   - Quick stats and key improvementsBuild and start all containers:

   - Top-level summary for backend developer```bash

docker compose up -d --build

2. **[CHANGES_APPLIED.md](CHANGES_APPLIED.md)** 📖 Detailed explanations```

   - Why each change was made

   - Performance impact analysisAccess services:

   - Configuration requirements- Face detection API: [http://localhost:8000](http://localhost:8000)

   - Rollback instructions- n8n automation: [http://localhost:5678](http://localhost:5678)

- MQTT broker: port 1883

3. **[BEFORE_AFTER_COMPARISON.md](BEFORE_AFTER_COMPARISON.md)** 🔀 Code diff

   - Side-by-side code comparison---

   - Visual changes overview

   - Easy code review## 🤖 Face Detection API



### 🚀 For Setup/TestingKey endpoints:

- `GET /healthz` — Service health check

**Start here if you want to set up and run the system:**- `POST /detect-webcam` — Detect faces from webcam, save annotated frames

- `POST /detect-image` — Detect faces in uploaded image

1. **[COMPLETE_WORKFLOW.md](COMPLETE_WORKFLOW.md)** ⭐ **NEW USERS START HERE**- `GET /stream` — MJPEG live stream

   - Step-by-step setup guide (8 steps)- `GET /ui` — Simple browser interface

   - Troubleshooting for each step

   - Complete testing workflowExample webcam detection:

```bash

2. **[QUICKSTART.md](QUICKSTART.md)** ⚡ For experienced userscurl -X POST http://localhost:8000/detect-webcam \

   - 5-minute quick start  -F persons_dir=/data/persons \

   - Minimal explanations  -F webcam=0 \

   - Fast setup path  -F max_seconds=8 \

  -F annotated_dir=/data/caps

### 🏗️ For Understanding Architecture```



**Start here if you want to understand the system design:**---



1. **[BEACON_EXPLAINED.md](BEACON_EXPLAINED.md)** 📡 Beacon discovery system## 💬 MQTT Broker & Beacon

   - Why beacon exists (Docker networking)

   - How UDP broadcasting works- Mosquitto runs on port 1883, accessible for local and LAN MQTT clients.

   - Network diagrams- The beacon (`beacon.py`) broadcasts the broker’s IP and responds to WHO_IS queries for device auto-discovery.



2. **[MIGRATION_CHANGES.md](MIGRATION_CHANGES.md)** 📋 Complete technical reference---

   - Full architecture documentation

   - All code changes with explanations## 🧠 Managing n8n Data with Git + Git LFS

   - Performance measurements

   - Deployment guideAll n8n workflows, credentials, users, and executions are stored in `n8n_data/database.sqlite` and versioned via Git LFS. This enables instant backup, sync, and reproducible automation environments.



### 📑 Additional Resources### Backup & Sync

Just commit and push as usual. The prune script is automatically run by the pre-commit hook, so you do not need to run it manually.

- **[DOCUMENTATION_INDEX.md](DOCUMENTATION_INDEX.md)** - Navigation guide to all docs```bash

- **[COMPLETE_PACKAGE_SUMMARY.md](COMPLETE_PACKAGE_SUMMARY.md)** - Everything that changedgit add n8n_data/database.sqlite

- **[OPTIMIZED_SETUP.md](OPTIMIZED_SETUP.md)** - Detailed setup guidegit commit -m "Backup latest n8n state"

- **[SETUP_COMPLETE.md](SETUP_COMPLETE.md)** - Post-setup next stepsgit push

```

---

### Restore on a New Machine

## 🎓 Reading Paths by Role```bash

git clone <your-repo>

### Backend Developer (Reviewing Changes)cd <your-repo>

```git lfs install

1. QUICK_CHANGE_SUMMARY.md (5 min) - Overviewgit lfs pull

2. CHANGES_APPLIED.md (15 min) - Detailsdocker compose up -d --build

3. BEFORE_AFTER_COMPARISON.md (10 min) - Code review```

4. Test with .\start.ps1 (5 min)n8n loads with all workflows, credentials, and users intact.

```

**Total: ~35 minutes**---



### New Developer (First Setup)## 🧹 Pre-commit Hook Setup for New Users

```

1. COMPLETE_WORKFLOW.md (30 min) - Follow all stepsTo ensure the prune script runs automatically before each commit, new users must set up the pre-commit hook after cloning:

2. Test authentication (10 min)

3. SETUP_COMPLETE.md (5 min) - Next steps```bash

```# Make sure the hook script exists and is executable

**Total: ~45 minutes**chmod +x .githooks/pre-commit

# Set the hooks path for your local repo

### Experienced Developer (Quick Setup)git config core.hooksPath .githooks

``````

1. QUICKSTART.md (5 min) - Skim guide

2. Update configs + .\start.ps1 (5 min)This only needs to be done once per clone.

3. Test (5 min)

```---

**Total: ~15 minutes**

## 🧱 Maintenance Commands

---

| Task                  | Command                          |

## 🔧 What Changed?|-----------------------|----------------------------------|

| Start all containers  | docker compose up -d             |

### Modified Files (5)| Stop all containers   | docker compose down              |

1. **`app.py`** - Added persistent camera, MQTT integration, new endpoints| View logs             | docker compose logs -f           |

2. **`beacon.py`** - Added environment variable support for BEACON_IP| Prune n8n DB          | ./scripts/n8n-prune.sh           |

3. **`docker-compose.yml`** - Changed to port mapping (Windows fix)| Rebuild images        | docker compose build --no-cache  |

4. **`requirements.txt`** - Added paho-mqtt, requests

5. **`.gitignore`** - Added .env, venv, captures/---



### New Files (2 + 2 + 10)## 🧩 Summary

**Services:**

- `face_auth_bridge.py` - MQTT ↔ HTTP bridgeYou now have a complete system that:

- `.env.example` - Configuration template- Detects faces via face-service

- Broadcasts broker presence with broker-beacon

**Automation:**- Syncs data in n8n via Git + LFS

- `start.ps1` - Automated startup- Is 100% reproducible and portable

- `stop.ps1` - Clean shutdown

Clone, pull, and run — no setup required 🎯

**Documentation:**

- 10 comprehensive guides (see above)---


---

## ⚡ Performance Improvements

| Metric | Before | After | Improvement |
|--------|--------|-------|-------------|
| **First Auth** | 22s | 22s | Baseline |
| **Second Auth** | 22s | **5s** | **77% faster** |
| **Third+ Auth** | 22s | **5s** | **77% faster** |
| **User Feedback** | None | Real-time | **Much better** |
| **Setup Time** | 30 min | 5 min | **83% faster** |

**Key Improvement:** Persistent camera eliminates 15-20s camera initialization on every authentication after the first one!

---

## 🏗️ Architecture Overview

```
Flutter App (Mobile)
    │
    ├─── 1. Discover via UDP :18830 ──────┐
    │                                      │
    ▼                                      ▼
Receives Beacon IP                    Beacon Service
{"ip": "192.168.1.7"}                 (Docker Container)
    │                                      
    ├─── 2. Connect MQTT :1883 ───────────┤
    │                                      │
    ▼                                      ▼
MQTT Broker (Mosquitto)               Your PC (192.168.1.7)
    │                                      │
    ├─── 3. Publish request ──────────────┤
    │                                      │
    ▼                                      ▼
MQTT Bridge Service                   Face API (app.py)
(face_auth_bridge.py)                     │
    │                                  ┌───┴────┐
    │                                  │        │
    ▼                                  ▼        ▼
Get response                        Camera   Persons/
    │                              (persistent) (faces)
    │                                  │
    ├─── 4. Publish response ─────────┤
    │                                  │
    ▼                                  ▼
Back to Flutter                   Recognition
    │
    ▼
Show result: "Welcome, John!"
```

---

## 📋 Core Features

### 🎯 Face Recognition
- OpenCV + face_recognition library
- Persistent camera instance (performance)
- Configurable tolerance
- Automatic face capture storage

### 📡 MQTT Integration
- Real-time status updates
- Request/response pattern
- Auto-reconnection
- Topic-based messaging

### 🔍 Beacon Discovery
- UDP broadcasting (port 18830)
- Auto IP discovery for Flutter app
- Docker network compatibility
- Environment-based configuration

### 🐳 Docker Deployment
- Mosquitto MQTT broker
- Beacon service (UDP broadcaster)
- Docker Compose orchestration
- Windows/Linux compatible

### 🤖 Automation
- One-command startup (`.\start.ps1`)
- Prerequisite checking
- Automatic dependency installation
- Service health verification

---

## 🔧 Configuration

### Required Configuration Files

**1. docker-compose.yml**
```yaml
broker-beacon:
  environment:
    - BEACON_IP=192.168.1.7  # ← YOUR IP HERE
```

**2. .env** (copy from .env.example)
```env
MQTT_BROKER=192.168.1.7  # ← YOUR IP HERE
MQTT_PORT=1883
FACE_API_URL=http://localhost:8000
```

**3. Flutter mqtt_config.dart**
```dart
static const String localBrokerAddress = '192.168.1.7';  // ← YOUR IP
```

**All three IPs MUST match your WiFi IP!**

---

## 🧪 Testing

### Automated Tests (via start.ps1)
The startup script automatically tests:
- ✅ Docker is running
- ✅ Virtual environment created
- ✅ Dependencies installed
- ✅ Docker services started
- ✅ Face service responding
- ✅ MQTT bridge connected

### Manual Tests

**Camera test:**
```powershell
curl http://localhost:8000/test-camera
```

**Health check:**
```powershell
curl http://localhost:8000/healthz
```

**Beacon check:**
```powershell
docker-compose logs broker-beacon
# Should show broadcasts every 2 seconds
```

**Performance test:**
1. Authenticate once (~22s)
2. Authenticate again (~5s) ← Should be much faster!

---

## 🛑 Stopping Services

**Automated:**
```powershell
.\stop.ps1
```

**Manual:**
```powershell
docker-compose down
# Then close Face Service and MQTT Bridge windows
```

---

## 🐛 Troubleshooting

### Camera is always slow (20s every time)
→ Persistent camera not working. Check `app.py` uses `get_camera()`, not `cv2.VideoCapture(0)`

### Beacon not found by Flutter
→ Check firewall allows UDP 18830. Verify IP in `docker-compose.yml` matches `ipconfig`

### MQTT connection fails
→ Verify all 3 IPs match (docker-compose.yml, .env, mqtt_config.dart)

### Face not recognized
→ Check face image exists in `persons/`. Try lower tolerance (0.5 instead of 0.6)

**Full troubleshooting:** See [COMPLETE_WORKFLOW.md](COMPLETE_WORKFLOW.md) section "Troubleshooting Each Step"

---

## 📞 Support

### Documentation
- **Quick questions:** [QUICK_CHANGE_SUMMARY.md](QUICK_CHANGE_SUMMARY.md)
- **Setup issues:** [COMPLETE_WORKFLOW.md](COMPLETE_WORKFLOW.md)
- **Architecture questions:** [BEACON_EXPLAINED.md](BEACON_EXPLAINED.md)
- **Complete reference:** [MIGRATION_CHANGES.md](MIGRATION_CHANGES.md)

### Common Issues
Check the troubleshooting sections in:
- [COMPLETE_WORKFLOW.md](COMPLETE_WORKFLOW.md) - Step-by-step troubleshooting
- [CHANGES_APPLIED.md](CHANGES_APPLIED.md) - Known issues and solutions
- [OPTIMIZED_SETUP.md](OPTIMIZED_SETUP.md) - Detailed troubleshooting guide

---

## 🎯 Key Success Metric

**The persistent camera is working if:**
- First authentication: ~20-25 seconds (normal)
- Second authentication: **~5-6 seconds** (should be much faster!)
- Third+ authentication: **~5-6 seconds** (consistently fast)

**If second auth is still ~20s, something is wrong!** Check the troubleshooting guide.

---

## 📦 Dependencies

```txt
# Core
fastapi
uvicorn
opencv-python
face-recognition
dlib
numpy

# MQTT (NEW)
paho-mqtt>=2.0.0
requests>=2.31.0
```

Install with:
```powershell
pip install -r requirements.txt
```

---

## 🚀 Next Steps After Setup

1. ✅ Test performance (verify 2nd auth is fast)
2. ✅ Add multiple face images to `persons/`
3. ✅ Test from different devices on WiFi
4. ✅ Integrate with ESP32 (if applicable)
5. ✅ Read [SETUP_COMPLETE.md](SETUP_COMPLETE.md) for advanced features

---

## 📖 Original README

The original README from the repository has been preserved as [README_ORIGINAL.md](README_ORIGINAL.md).

---

## ✨ Credits

**Original Version:** Face recognition backend  
**Optimizations Applied:** October 10, 2025  
**Key Improvements:**
- Persistent camera (77% performance boost)
- MQTT integration (real-time feedback)
- Windows compatibility (Docker fixes)
- Comprehensive documentation (10 guides)
- Automated setup (one-command startup)

---

## 📄 License

See original repository license.

---

**🎉 Ready to use! Start with [COMPLETE_WORKFLOW.md](COMPLETE_WORKFLOW.md) or run `.\start.ps1` to begin!**
