# ⚡ Quick Reference Card - Smart Home AIoT App

## 🚨 **CRITICAL FIRST STEP**
```powershell
# FIX SECURITY ISSUE - Remove Firebase keys from git history
# See SECURITY_FIX_GUIDE.md for complete instructions

git filter-branch --force --index-filter `
  "git rm --cached --ignore-unmatch lib/firebase_options.dart" `
  --prune-empty --tag-name-filter cat -- --all

git push origin --force --all
```

---

## 📱 **App Routes**

| Screen | Route | Description |
|--------|-------|-------------|
| Home | `/home` | Main dashboard |
| Settings | `/settings` | App configuration ✨ |
| Notifications | `/notifications` | Alerts & updates ✨ |
| Automations | `/automations` | Smart rules ✨ |
| Energy | `/energy` | Usage tracking ✨ |
| Login | `/login` | Authentication |
| Register | `/register` | New user |

---

## 🔧 **Common Commands**

### Flutter:
```bash
# Install dependencies
flutter pub get

# Run app
flutter run

# Clean build
flutter clean

# Build APK
flutter build apk --release

# Check health
flutter doctor
```

### Firebase:
```bash
# Regenerate config (after securing)
flutterfire configure --project=smart-home-aiot-app

# Login
firebase login

# Deploy rules
firebase deploy --only firestore:rules
```

### MQTT Testing:
```bash
# Subscribe to all topics
mosquitto_sub -h localhost -t 'smarthome/#' -v

# Publish test command
mosquitto_pub -h localhost -t 'smarthome/user123/devices/light_1/command' -m '{"action":"turn_on"}'

# Start broker
sudo systemctl start mosquitto  # Linux
brew services start mosquitto   # Mac
```

---

## 💻 **Code Snippets**

### Get Provider:
```dart
final settings = context.watch<SettingsProvider>();
final notifications = context.read<NotificationService>();
final automations = context.read<AutomationProvider>();
```

### Send Notification:
```dart
notificationService.notifyDeviceStatusChange('Light', true);
notificationService.notifySecurityAlert('Motion detected!');
notificationService.notifyAutomationTriggered('Good Morning');
```

### Change Theme:
```dart
settings.setThemeMode(ThemeMode.dark);
settings.setThemeMode(ThemeMode.light);
settings.setThemeMode(ThemeMode.system);
```

### Switch Mode:
```dart
// Cloud mode
settings.setConnectionMode(ConnectionMode.cloud);

// Local mode
settings.setConnectionMode(ConnectionMode.local);
settings.updateMqttSettings(
  brokerAddress: '192.168.1.100',
  brokerPort: 1883,
);
```

### Navigation:
```dart
Navigator.pushNamed(context, '/settings');
Navigator.pushNamed(context, '/notifications');
Navigator.pushNamed(context, '/automations');
Navigator.pushNamed(context, '/energy');
```

---

## 🎨 **Theme Colors**

```dart
AppTheme.primaryColor      // Cyan/Blue
AppTheme.secondaryColor    // Purple
AppTheme.darkBackground    // #0A0E27
AppTheme.darkCard          // #1E2139
AppTheme.lightText         // #FFFFFF
AppTheme.mutedText         // Grey
AppTheme.successColor      // Green
AppTheme.errorColor        // Red
AppTheme.warningColor      // Orange
```

---

## 📡 **MQTT Topics**

### Format:
```
smarthome/{userId}/devices/{deviceId}/{type}
```

### Types:
- `command` - App → ESP32
- `status` - ESP32 → App
- `data` - ESP32 → App (sensors)

### Example Commands:
```json
// Turn on
{"action": "turn_on"}

// Turn off
{"action": "turn_off"}

// Set brightness
{"action": "set_brightness", "value": 75}

// Set temperature
{"action": "set_temperature", "value": 22}
```

---

## 🔐 **Security Checklist**

- [ ] Read SECURITY_FIX_GUIDE.md
- [ ] Remove firebase_options.dart from git history
- [ ] Regenerate Firebase config
- [ ] Force push cleaned repo
- [ ] Enable Firestore
- [ ] Set up Firestore rules
- [ ] Restrict API keys in Google Cloud Console

---

## 🧪 **Testing URLs**

### Firestore:
```
https://console.firebase.google.com/project/smart-home-aiot-app/firestore
```

### Authentication:
```
https://console.firebase.google.com/project/smart-home-aiot-app/authentication
```

### API Keys:
```
https://console.cloud.google.com/apis/credentials?project=smart-home-aiot-app
```

### Enable Firestore API:
```
https://console.developers.google.com/apis/api/firestore.googleapis.com/overview?project=smart-home-aiot-app
```

---

## 📚 **Documentation Files**

| File | Purpose |
|------|---------|
| FINAL_SUMMARY.md | This guide - Quick overview |
| SECURITY_FIX_GUIDE.md | ⚠️ Fix Firebase keys |
| ENABLE_FIRESTORE.md | Enable Cloud Firestore |
| ESP32_INTEGRATION_GUIDE.md | ESP32 setup guide |
| IMPLEMENTATION_COMPLETE.md | Full feature docs |
| FEATURES_COMPLETE.md | Feature summary |

---

## 🐛 **Quick Fixes**

### Build Error:
```bash
flutter clean && flutter pub get && flutter run
```

### MQTT Not Working:
```bash
# Check broker
mosquitto -v

# Test connection
mosquitto_sub -h localhost -t '#' -v
```

### Firestore Error:
1. Check if Firestore is enabled
2. Verify firebase_options.dart exists
3. Check google-services.json exists

### Theme Not Changing:
```dart
// Hot restart (not hot reload)
// Press 'R' in terminal
```

---

## 📞 **Emergency Commands**

### Reset Everything:
```bash
flutter clean
rm -rf .dart_tool/
rm pubspec.lock
flutter pub get
flutter run
```

### Reset Firebase:
```bash
flutterfire configure --project=smart-home-aiot-app --overwrite-firebase-options
```

### Check Git Status:
```bash
git status
git log --oneline -10
```

---

## ✅ **Feature Completion**

- ✅ Settings Screen - 100%
- ✅ Notifications - 100%
- ✅ Automations - 100%
- ✅ Energy Monitor - 100%
- ✅ Cloud/Local Toggle - 100%
- ✅ Theme System - 100%
- ✅ Security Guide - 100%

**Total**: 100% Complete! 🎉

---

## 🎯 **Priority Tasks**

### Today:
1. ⚠️ Fix security (SECURITY_FIX_GUIDE.md)
2. 🔥 Enable Firestore (ENABLE_FIRESTORE.md)
3. 📱 Test app (flutter run)

### This Week:
4. 🏠 Set up ESP32 (optional)
5. 📊 Add charts (optional)
6. 🔔 Add FCM (optional)

---

## 💡 **Pro Tips**

1. **Use Hot Restart** (R) after theme changes
2. **Check console logs** for MQTT connection status
3. **Test on real device** for best experience
4. **Enable Firestore** before first cloud sync
5. **Read security guide** before deploying

---

## 🚀 **One-Command Setup**

```bash
# Complete setup in one command
flutter pub get && flutter run
```

---

**Quick Start**: `flutter run`  
**Security Fix**: See SECURITY_FIX_GUIDE.md  
**ESP32 Setup**: See ESP32_INTEGRATION_GUIDE.md  

**Happy Coding! 🎉**
