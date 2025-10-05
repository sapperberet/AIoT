# 🚀 Quick Start Commands

## ⚡ Essential Commands

### 1. Enable Authentication (DO THIS FIRST!)
Open this link and enable Email/Password:
```
https://console.firebase.google.com/project/smart-home-aiot-app/authentication
```

### 2. Accept Android Licenses (if needed)
```powershell
flutter doctor --android-licenses
```

### 3. Run the App
```powershell
flutter run
```

### 4. Clean Build (if issues occur)
```powershell
flutter clean
flutter pub get
flutter run
```

## 🧪 Testing Your App

### Test Registration Flow:
1. Run the app: `flutter run`
2. Tap "Create Account" on login screen
3. Enter email and password
4. Submit registration
5. Check email for verification link
6. Return to app and login

### Test Login Flow:
1. Enter registered email
2. Enter password
3. Tap login
4. Should redirect to home screen

## 📱 Build APK for Testing

```powershell
# Debug APK
flutter build apk --debug

# Release APK (requires signing configuration)
flutter build apk --release
```

## 🔧 Common Commands

```powershell
# Check connected devices
flutter devices

# View app logs
flutter logs

# Hot reload (while app is running)
# Press 'r' in terminal

# Hot restart (while app is running)
# Press 'R' in terminal

# Update dependencies
flutter pub upgrade

# Check for outdated packages
flutter pub outdated
```

## 🎯 Your Firebase Project

**Project:** smart-home-aiot-app  
**Console:** https://console.firebase.google.com/project/smart-home-aiot-app

### Quick Links:
- [Authentication Users](https://console.firebase.google.com/project/smart-home-aiot-app/authentication/users)
- [Firestore Database](https://console.firebase.google.com/project/smart-home-aiot-app/firestore)
- [Storage Files](https://console.firebase.google.com/project/smart-home-aiot-app/storage)

## ✅ Setup Checklist

- [x] Flutter installed
- [x] Firebase project created (`smart-home-aiot-app`)
- [x] FlutterFire CLI configured
- [x] `firebase_options.dart` generated
- [x] `google-services.json` downloaded
- [x] Android build files updated
- [x] Dependencies installed
- [ ] **Enable Email/Password auth in Firebase Console** ⚠️ 
- [ ] Run the app
- [ ] Test registration
- [ ] Test login

## 🎉 You're Ready!

Just enable authentication in the Firebase Console and run `flutter run`!
