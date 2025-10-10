# 🌐 Understanding the Beacon Discovery System

## 📡 Why We Need Beacon Discovery

### The Docker Networking Challenge

When you run Mosquitto (MQTT broker) in Docker, there's a fundamental networking problem:

**Problem:**
- Docker containers have internal IPs (e.g., `172.17.0.2`)
- Your phone/ESP32 are on your WiFi network (e.g., `192.168.1.x`)
- **They're on different networks and can't see each other directly!**

**Without Beacon:**
```
Phone tries to connect → Where is MQTT broker?
- 127.0.0.1? No, that's the phone itself
- 192.168.1.x? Which device? Scan entire network?
- User must manually enter IP (bad UX)
```

**With Beacon:**
```
Phone listens → Beacon broadcasts "I'm at 192.168.1.7:1883"
Phone connects → Success!
```

---

## 🎯 How the Beacon System Works

### Architecture Overview

```
┌────────────────────────────────────────────────────────────┐
│                  Your PC (192.168.1.7)                     │
│                                                            │
│  ┌──────────────────────────────────────────────────┐     │
│  │           Docker Network (172.17.0.x)            │     │
│  │                                                  │     │
│  │  ┌──────────────────┐  ┌──────────────────┐     │     │
│  │  │   mosquitto      │  │  broker-beacon   │     │     │
│  │  │   172.17.0.2     │  │  172.17.0.3      │     │     │
│  │  │   port: 1883     │  │  port: 18830     │     │     │
│  │  └──────────────────┘  └──────────────────┘     │     │
│  │         ▲                      │                │     │
│  └─────────│──────────────────────│────────────────┘     │
│            │                      │                      │
│    Port mapping:           Port mapping:                 │
│    1883 → 1883            18830 → 18830                  │
│            │                      │                      │
└────────────│──────────────────────│──────────────────────┘
             │                      │
             │                      │ UDP Broadcast
             │                      ▼
    ┌────────┴────────┐    ┌────────────────────┐
    │   Flutter App   │    │  Beacon Listener   │
    │   (Phone)       │    │  Port: 18830       │
    │                 │◄───┤                    │
    │ 1. Listen UDP   │    │ Receives:          │
    │    18830        │    │ {                  │
    │                 │    │   "name": "face-   │
    │ 2. Receive:     │    │    broker",        │
    │    192.168.1.7  │    │   "ip": "192.168.  │
    │    :1883        │    │    1.7",           │
    │                 │    │   "port": 1883     │
    │ 3. Connect to   │    │ }                  │
    │    MQTT broker  │    │                    │
    │    @ that IP    │    │                    │
    └─────────────────┘    └────────────────────┘
```

### Step-by-Step Process

#### 1. **Beacon Starts Broadcasting** (Every 2 seconds)

`broker-beacon` container runs `beacon.py`:
```python
# Gets host's WiFi IP (not Docker internal IP)
ip = "192.168.1.7"  # Your actual WiFi IP

# Creates broadcast message
message = {
    "name": "face-broker",
    "ip": "192.168.1.7",    # Host WiFi IP
    "port": 1883            # MQTT port
}

# Broadcasts to entire network
socket.sendto(message, ("255.255.255.255", 18830))
```

#### 2. **Flutter App Listens**

Your Flutter app (`face_auth_service.dart`):
```dart
// Bind to UDP port 18830 to receive broadcasts
final socket = await RawDatagramSocket.bind(
  InternetAddress.anyIPv4,
  18830,  // MUST match beacon port
);

// Wait for broadcast
socket.listen((event) {
  if (event == RawSocketEvent.read) {
    final datagram = socket.receive();
    // Parse: {"name":"face-broker","ip":"192.168.1.7","port":1883}
    final beacon = FaceAuthBeacon.fromJson(json);
    
    // Now we know where to connect!
    connectToMqtt(beacon.ip, beacon.port);
  }
});
```

#### 3. **Connection Established**

```dart
// Connect to MQTT broker at discovered IP
await mqttService.connect(
  brokerAddress: "192.168.1.7",  // From beacon
  port: 1883,                     // From beacon
);
```

---

## ⚙️ Why This Architecture?

### The Developer's Rationale

From the conversation:
> "Because of the Docker setup, a device on the LAN cannot directly identify the Mosquitto container."

**Key Points:**

1. **Docker Port Mapping:**
   - Container internal: `172.17.0.2:1883`
   - Host mapping: `192.168.1.7:1883`
   - Flutter needs to connect to `192.168.1.7`, not `172.17.0.2`

2. **Beacon Solves Discovery:**
   - Beacon knows the host IP (`BEACON_IP` environment variable)
   - Broadcasts it on the LAN
   - Devices auto-discover without manual configuration

3. **Better UX:**
   - No manual IP entry
   - Works across different networks
   - Auto-adapts if IP changes

---

## 🔧 Configuration Requirements

### Critical Settings

All three must match your **actual WiFi IP**:

#### 1. **Docker Compose** - Tells beacon what to broadcast
```yaml
# docker-compose.yml
broker-beacon:
  environment:
    - BEACON_IP=192.168.1.7  # ← YOUR WIFI IP
```

#### 2. **Backend Services** - Where to connect to MQTT
```env
# .env file
MQTT_BROKER=192.168.1.7  # ← YOUR WIFI IP
```

#### 3. **Flutter Fallback** - If beacon discovery fails
```dart
// lib/core/config/mqtt_config.dart
static const String localBrokerAddress = '192.168.1.7';  // ← YOUR WIFI IP
```

### Why All Three?

- **docker-compose.yml:** Beacon broadcasts this IP
- **.env:** Backend services connect using this IP
- **Flutter:** Fallback if beacon discovery fails

---

## 🧪 Testing Beacon Discovery

### Test 1: Check Beacon is Broadcasting

```powershell
# View beacon logs
docker-compose logs -f broker-beacon

# Expected output every 2 seconds:
# [beacon] sent GLOBAL -> 255.255.255.255:18830 b'{"name": "face-broker", "ip": "192.168.1.7", "port": 1883}'
```

### Test 2: Listen for Broadcasts (Python)

Create `test_listen.py`:
```python
import socket
import json

sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
sock.bind(("", 18830))
sock.settimeout(5)

print("Listening for beacon broadcasts...")
try:
    data, addr = sock.recvfrom(1024)
    message = json.loads(data.decode())
    print(f"✅ Received from {addr}:")
    print(f"   Name: {message['name']}")
    print(f"   IP: {message['ip']}")
    print(f"   Port: {message['port']}")
except socket.timeout:
    print("❌ No beacon received in 5 seconds")
```

Run: `python test_listen.py`

### Test 3: Flutter App Discovery

In Flutter logs, look for:
```
[flutter] [FaceAuthService] Starting beacon discovery...
[flutter] [FaceAuthService] UDP socket bound to port: 18830
[flutter] [FaceAuthService] 📦 Packet #1 received from 192.168.1.7:18830
[flutter] [FaceAuthService] ✅ Beacon discovered: 192.168.1.7:1883
```

---

## 🔍 Troubleshooting

### Problem: "No beacon received"

**Check 1: Beacon is running**
```powershell
docker-compose ps broker-beacon
# Should show: Up
```

**Check 2: Beacon is broadcasting**
```powershell
docker-compose logs broker-beacon | Select-String "sent GLOBAL"
# Should show broadcasts every 2 seconds
```

**Check 3: Firewall allows UDP 18830**
```powershell
# Windows Firewall
# Allow inbound UDP on port 18830
```

**Check 4: Correct IP in docker-compose.yml**
```powershell
# Verify your WiFi IP
ipconfig
# Compare with BEACON_IP in docker-compose.yml
```

### Problem: "Flutter connects to wrong IP"

**Symptom:** App tries to connect to `127.0.0.1` or wrong IP

**Solution:** Beacon is broadcasting wrong IP
```yaml
# docker-compose.yml
environment:
  - BEACON_IP=192.168.1.7  # ← Must be YOUR WiFi IP, not localhost!
```

### Problem: "Connection refused"

**Symptom:** Beacon discovered, but MQTT connection fails

**Check 1: Mosquitto is running**
```powershell
docker-compose ps mosquitto
# Should show: Up
```

**Check 2: Port is accessible**
```powershell
# Test MQTT connection
docker exec mosquitto mosquitto_pub -t "test" -m "hello"
```

**Check 3: IP is reachable from phone**
```powershell
# From phone, ping the PC
ping 192.168.1.7
```

---

## 📊 Network Flow Diagram

### Complete Authentication Flow

```
1. BEACON DISCOVERY (2s)
   ┌──────────┐                        ┌───────────┐
   │ Flutter  │  UDP Listen :18830    │  Beacon   │
   │   App    │◄──────────────────────│ Container │
   └──────────┘  {"ip":"192.168.1.7"} └───────────┘

2. MQTT CONNECTION (1s)
   ┌──────────┐                        ┌───────────┐
   │ Flutter  │  TCP Connect :1883    │ Mosquitto │
   │   App    │───────────────────────►│ Container │
   └──────────┘                        └───────────┘

3. FACE AUTH REQUEST (via MQTT)
   ┌──────────┐  Publish: home/auth/  ┌───────────┐
   │ Flutter  │  face/request         │   MQTT    │
   │   App    │──────────────────────►│  Bridge   │
   └──────────┘                        └───────────┘
                                            │
                                            ▼
                                       ┌───────────┐
                                       │Face API   │
                                       │(app.py)   │
                                       └───────────┘

4. CAMERA INITIALIZATION (20s first time)
   ┌───────────┐                       ┌───────────┐
   │Face API   │  Initialize Camera   │  Webcam   │
   │(app.py)   │─────────────────────►│           │
   └───────────┘                       └───────────┘

5. STATUS UPDATES (via MQTT)
   ┌───────────┐  Publish: home/auth/ ┌───────────┐
   │Face API   │  face/status         │ Flutter   │
   │(app.py)   │─────────────────────►│   App     │
   └───────────┘  "initializing..."   └───────────┘
   
   ┌───────────┐  Publish: home/auth/ ┌───────────┐
   │Face API   │  face/status         │ Flutter   │
   │(app.py)   │─────────────────────►│   App     │
   └───────────┘  "scanning..."       └───────────┘

6. AUTHENTICATION RESPONSE (via MQTT)
   ┌───────────┐  Publish: home/auth/ ┌───────────┐
   │   MQTT    │  face/response       │ Flutter   │
   │  Bridge   │─────────────────────►│   App     │
   └───────────┘  {"success": true}   └───────────┘

Total Time: 2s + 1s + 20s + 3s = ~26s (first time)
           2s + 1s + 0s + 3s = ~6s (subsequent)
```

---

## 🎯 Key Takeaways

### Why the Beacon is Essential

1. **Auto-Discovery:** No manual IP configuration needed
2. **Network Adaptation:** Works when IP changes (DHCP)
3. **Cross-Platform:** Same mechanism for Flutter, ESP32, any device
4. **Reliable:** Broadcasts every 2s, hard to miss

### Why Environment Variable Matters

```yaml
# docker-compose.yml
BEACON_IP=192.168.1.7  # ⚠️ CRITICAL!
```

**This tells the beacon:** 
- "You're running in Docker at `172.17.0.3`"
- "But tell everyone to connect to `192.168.1.7`"
- "Because that's where the port is mapped on the host"

**Without it:**
- Beacon auto-detects IP (might get Docker internal IP)
- Flutter connects to wrong IP
- Connection fails

### Why It's Better Than the Old Way

**Old approach:**
```dart
// Hardcoded IP - breaks when IP changes
static const String brokerAddress = '192.168.1.7';
```

**New approach:**
```dart
// Auto-discovery - adapts to network changes
final beacon = await discoverBeacon();
final brokerAddress = beacon.ip;  // Always correct!
```

---

## ✅ Setup Checklist

- [ ] Docker installed and running
- [ ] `docker-compose.yml` has correct `BEACON_IP`
- [ ] `.env` has correct `MQTT_BROKER`
- [ ] Flutter `mqtt_config.dart` has correct fallback IP
- [ ] Beacon broadcasting (check logs)
- [ ] Mosquitto running (check `docker ps`)
- [ ] Firewall allows UDP 18830
- [ ] Flutter can receive beacon broadcasts

---

## 🎓 Advanced: How beacon.py Works

```python
#!/usr/bin/env python3
import json, socket, time, sys, os

PORT = 18830
NAME = "face-broker"
BROKER_PORT = 1883

def host_ip():
    # 1. Check environment variable (from docker-compose.yml)
    explicit_ip = os.getenv("BEACON_IP", "").strip()
    if explicit_ip:
        return explicit_ip  # Use this!
    
    # 2. Fallback: Auto-detect (might be wrong in Docker)
    s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    s.connect(("1.1.1.1", 80))  # Trick to get routing IP
    ip = s.getsockname()[0]
    s.close()
    return ip

# Main loop
while True:
    ip = host_ip()
    msg = json.dumps({
        "name": NAME,
        "ip": ip,           # 192.168.1.7 (your WiFi IP)
        "port": BROKER_PORT # 1883 (MQTT port)
    }).encode()
    
    # Broadcast to everyone on network
    tx.sendto(msg, ("255.255.255.255", PORT))
    
    time.sleep(2)  # Every 2 seconds
```

**Key insight:** 
- `BEACON_IP` environment variable overrides auto-detection
- Ensures correct IP is broadcast even from Docker

---

**🚀 Now you understand why the beacon is crucial and how the entire discovery system works!**
