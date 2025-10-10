# Beacon Network Discovery Fix

## Problem

The beacon is broadcasting Docker's internal IP (`192.168.65.3`) instead of your computer's actual WiFi IP (`192.168.1.7`), so your phone can't find it.

## Quick Fix

### Option 1: Use Manual Configuration (Fastest)

Skip beacon discovery and connect directly:

1. **In your app**, go to Settings → Connection Mode → Local
2. Set MQTT Broker Address: `192.168.1.7` (your computer's IP)
3. Set Port: `1883`
4. Save
5. Now face authentication will connect directly without beacon discovery

### Option 2: Fix Beacon IP (Recommended)

Update the beacon to broadcast your actual IP:

1. **Stop the beacon**:
   ```powershell
   cd C:\Werk\AIoT\grad_project_backend-main
   docker-compose stop broker-beacon
   ```

2. **Edit `docker-compose.yml`** - Add environment variable:
   ```yaml
   broker-beacon:
     image: python:3.11-slim
     container_name: broker-beacon
     command: python /app/beacon.py
     volumes:
       - ./beacon.py:/app/beacon.py
     ports:
       - "18830:18830/udp"
     environment:
       - BEACON_IP=192.168.1.7  # ADD THIS LINE - Your computer's WiFi IP
     network_mode: host  # ADD THIS LINE - Use host network
   ```

3. **Restart beacon**:
   ```powershell
   docker-compose up -d broker-beacon
   ```

4. **Verify**:
   ```powershell
   docker-compose logs --tail=5 broker-beacon
   # Should show: "sent GLOBAL -> ... 192.168.1.7"
   ```

### Option 3: Increase Discovery Timeout (Temporary)

If you want to keep trying beacon discovery, increase the timeout:

In `lib/core/services/face_auth_service.dart`, change:
```dart
static const Duration _beaconDiscoveryTimeout = Duration(seconds: 10);
```
To:
```dart
static const Duration _beaconDiscoveryTimeout = Duration(seconds: 30);
```

Then hot reload the app (`r` in terminal).

## Verify Connection

After applying the fix:

1. Open the app
2. Tap "Face Recognition"
3. Should show "Discovering..." then "Connecting..."
4. Should connect successfully

If still not working:

1. Check both devices are on same WiFi network
2. Check Windows Firewall allows port 18830 (UDP)
3. Check your computer's IP hasn't changed: `ipconfig`

## Current Network Info

- **Computer IP**: `192.168.1.7`
- **Phone IP**: Should be `192.168.1.x` (check in phone WiFi settings)
- **Beacon broadcasting**: `192.168.65.3` (Docker internal - WRONG)
- **Need to broadcast**: `192.168.1.7` (Your WiFi IP)

## Windows Firewall Rule

If beacon still not discovered, allow UDP port:

```powershell
# Run as Administrator
New-NetFirewallRule -DisplayName "Face Auth Beacon" -Direction Inbound -Protocol UDP -LocalPort 18830 -Action Allow
```

---

**Recommended**: Use **Option 1** (Manual Configuration) for immediate testing, then apply **Option 2** for permanent fix.
