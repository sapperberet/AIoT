# Smart Home Project - Quick Start Guide

## Project Setup Checklist

### ✅ Phase 1: Development Environment
- [ ] Install Flutter SDK (3.0.0+)
- [ ] Install Android Studio / Xcode
- [ ] Run `flutter doctor` and resolve any issues
- [ ] Clone/download this project
- [ ] Run `flutter pub get`

### ✅ Phase 2: Firebase Configuration
- [ ] Create Firebase project at https://console.firebase.google.com/
- [ ] Enable Authentication > Email/Password
- [ ] Create Firestore Database (Start in test mode initially)
- [ ] Download config files:
  - Android: `google-services.json` → `android/app/`
  - iOS: `GoogleService-Info.plist` → `ios/Runner/`
- [ ] Update `lib/core/config/firebase_options.dart` with your credentials
- [ ] Set up Firestore security rules (see FIRESTORE_RULES.md)

### ✅ Phase 3: MQTT Broker Setup
- [ ] Choose broker option:
  - **Option A**: Raspberry Pi + Mosquitto (local)
  - **Option B**: Cloud MQTT service
- [ ] Configure broker IP in `lib/core/config/mqtt_config.dart`
- [ ] Test broker with MQTT Explorer

### ✅ Phase 4: ESP32 Setup
- [ ] Flash ESP32 with example code (see README.md)
- [ ] Configure WiFi credentials
- [ ] Set MQTT broker address
- [ ] Test device connection

### ✅ Phase 5: 3D Model (Optional)
- [ ] Export home model from CAD/SolidWorks as glTF
- [ ] Name room meshes appropriately
- [ ] Place model in `assets/3d/home_model.glb`
- [ ] Uncomment GLTFLoader in `assets/web/home_visualization.html`

### ✅ Phase 6: Testing
- [ ] Run app: `flutter run`
- [ ] Test user registration
- [ ] Verify MQTT connection
- [ ] Send test alarm from ESP32
- [ ] Check 3D visualization
- [ ] Review logs

## Quick Commands

```bash
# Get dependencies
flutter pub get

# Run on connected device
flutter run

# Build for release
flutter build apk --release  # Android
flutter build ios --release  # iOS

# Check setup
flutter doctor -v
```

## Default Login (After First Registration)
- Create your own account through the app

## MQTT Test Message

Use MQTT Explorer or command line to test:

```bash
# Publish fire alarm
mosquitto_pub -h localhost -t home/garage/fire_alarm -m '{"alarm":true,"severity":"critical","message":"Fire detected!"}'

# Publish light status
mosquitto_pub -h localhost -t home/living_room/light/status -m '{"state":"on"}'
```

## Next Steps

1. Review `README.md` for detailed documentation
2. Check `ESP32_GUIDE.md` for device integration
3. See `API_INTEGRATION.md` for computer vision setup
4. Configure devices in Firestore following the structure in README

## Getting Help

- **Firebase Issues**: Check Firebase console and error messages
- **MQTT Issues**: Use MQTT Explorer to debug broker connection
- **3D Model Issues**: Check WebView console logs
- **Build Issues**: Run `flutter clean` then `flutter pub get`

---

Good luck building your smart home! 🏠✨
