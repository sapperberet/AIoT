# 📁 Project Structure

```
AIoT/
│
├── lib/                                    # Main application code
│   ├── main.dart                          # App entry point & providers setup
│   │
│   ├── core/                              # Core business logic
│   │   ├── config/                        # Configuration files
│   │   │   ├── firebase_options.dart      # 🔧 Firebase credentials (MUST CONFIGURE)
│   │   │   └── mqtt_config.dart           # 🔧 MQTT broker settings (MUST CONFIGURE)
│   │   │
│   │   ├── models/                        # Data models
│   │   │   ├── device_model.dart          # Device, DeviceType, DeviceStatus, AlarmEvent
│   │   │   └── user_model.dart            # UserModel
│   │   │
│   │   ├── services/                      # Business logic services
│   │   │   ├── auth_service.dart          # Firebase authentication
│   │   │   ├── mqtt_service.dart          # MQTT client & pub/sub
│   │   │   └── firestore_service.dart     # Firestore CRUD operations
│   │   │
│   │   └── providers/                     # State management
│   │       ├── auth_provider.dart         # Auth state (login, register, logout)
│   │       ├── device_provider.dart       # Device state & MQTT/Firestore integration
│   │       └── home_visualization_provider.dart  # 3D visualization state
│   │
│   └── ui/                                # User interface
│       └── screens/
│           ├── splash_screen.dart         # Initial loading screen
│           ├── auth/                      # Authentication screens
│           │   ├── login_screen.dart      # Login UI
│           │   └── register_screen.dart   # Registration UI
│           └── home/                      # Main app screens
│               ├── home_screen.dart       # Main container with bottom nav
│               ├── devices_tab.dart       # Device control & status
│               ├── visualization_tab.dart # 3D WebView integration
│               └── logs_tab.dart          # Alarm & event logs
│
├── assets/                                # Static assets
│   ├── web/                              # WebView HTML/JS files
│   │   └── home_visualization.html       # three.js 3D visualization
│   ├── 3d/                               # 3D model files
│   │   └── home_model.glb                # 🔧 Your CAD/SolidWorks export (OPTIONAL)
│   └── icons/                            # App icons
│
├── android/                              # Android-specific configuration
│   └── app/
│       └── google-services.json          # 🔧 Firebase Android config (MUST ADD)
│
├── ios/                                  # iOS-specific configuration
│   └── Runner/
│       └── GoogleService-Info.plist      # 🔧 Firebase iOS config (MUST ADD)
│
├── test/                                 # Unit & widget tests (TODO)
│
├── pubspec.yaml                          # ✅ Dependencies configuration (READY)
├── .gitignore                            # ✅ Git ignore rules
│
├── README.md                             # 📚 Comprehensive documentation
├── QUICKSTART.md                         # 🚀 Quick setup guide
├── ARCHITECTURE.md                       # 🏗️ System architecture details
└── FIRESTORE_RULES.md                    # 🔒 Database security rules
```

## 🔧 Files You MUST Configure

Before running the app, configure these files:

### 1. Firebase Configuration
**Location**: `lib/core/config/firebase_options.dart`
**Action**: Replace placeholder values with your Firebase project credentials
**How**: Get from Firebase Console > Project Settings > Your Apps

### 2. MQTT Configuration
**Location**: `lib/core/config/mqtt_config.dart`
**Action**: Update `localBrokerAddress` with your MQTT broker IP address
**Default**: `192.168.1.100` (change this!)

### 3. Firebase Config Files
**Android**: `android/app/google-services.json`
**iOS**: `ios/Runner/GoogleService-Info.plist`
**Action**: Download from Firebase Console and place in specified locations

### 4. 3D Model (Optional)
**Location**: `assets/3d/home_model.glb`
**Action**: Export your home model from CAD/SolidWorks as glTF format
**Note**: App includes a placeholder house if you skip this

## 📋 Key Files Explained

### Core Services

| File | Purpose | Key Methods |
|------|---------|-------------|
| `auth_service.dart` | Firebase auth operations | `signIn()`, `register()`, `signOut()` |
| `mqtt_service.dart` | MQTT communication | `connect()`, `subscribe()`, `publish()` |
| `firestore_service.dart` | Firestore database ops | `getDevicesStream()`, `sendDeviceCommand()` |

### State Providers

| File | Purpose | Manages |
|------|---------|---------|
| `auth_provider.dart` | User authentication state | Current user, login status |
| `device_provider.dart` | Devices & alarms state | Device list, MQTT/Cloud mode, alarms |
| `home_visualization_provider.dart` | 3D visualization state | Visual alarms, room highlights |

### UI Screens

| File | Purpose |
|------|---------|
| `login_screen.dart` | User login form |
| `register_screen.dart` | User registration form |
| `home_screen.dart` | Main app with bottom navigation |
| `devices_tab.dart` | List and control devices |
| `visualization_tab.dart` | 3D home view with WebView |
| `logs_tab.dart` | View alarms and event logs |

## 🎨 UI Component Hierarchy

```
SplashScreen
    ↓
LoginScreen / RegisterScreen
    ↓
HomeScreen (BottomNavigationBar)
    ├── DevicesTab
    │   ├── AlarmsList (if active alarms)
    │   └── DeviceCard (for each device)
    │       ├── Switch (for lights)
    │       └── BottomSheet (device details)
    │
    ├── VisualizationTab
    │   ├── WebViewWidget (three.js)
    │   └── FloatingActionButton (reset camera)
    │
    └── LogsTab
        ├── AlarmsLog
        └── EventsLog
```

## 🔄 Data Flow

```
User Action (UI)
    ↓
Provider (State Management)
    ↓
Service (Business Logic)
    ↓
MQTT/Firestore (Backend)
    ↓
ESP32 Device
```

## 🚀 Getting Started Workflow

1. **Install dependencies**: `flutter pub get`
2. **Configure Firebase**: Add config files + update `firebase_options.dart`
3. **Configure MQTT**: Update broker address in `mqtt_config.dart`
4. **Run app**: `flutter run`
5. **Test login**: Create account through register screen
6. **Add devices**: Configure in Firestore or connect ESP32
7. **(Optional)** Add 3D model to `assets/3d/`

## 📦 Dependencies Overview

### Firebase
- `firebase_core`: Firebase initialization
- `firebase_auth`: User authentication
- `cloud_firestore`: Real-time database

### MQTT
- `mqtt_client`: MQTT protocol implementation

### UI & State
- `provider`: State management
- `webview_flutter`: WebView for 3D visualization

### Utilities
- `connectivity_plus`: Network connectivity detection
- `logger`: Logging and debugging
- `intl`: Date/time formatting

## 🧪 Testing Strategy

### Manual Testing
1. Authentication flow (register/login/logout)
2. MQTT connection (check indicator in app bar)
3. Device control (toggle switches)
4. Alarm reception (use MQTT Explorer to send test alarm)
5. 3D visualization (tap rooms, see alarm colors)

### Unit Tests (Future)
- Test providers (device state changes, auth state)
- Test services (MQTT publish/subscribe, Firestore CRUD)
- Test models (data serialization)

### Integration Tests (Future)
- Full authentication flow
- Device control end-to-end
- Alarm handling workflow

## 📈 Next Development Steps

After initial setup:

1. **Add Real Devices**: Configure your ESP32 devices
2. **Customize UI**: Brand colors, icons, themes
3. **Add Device Types**: Extend DeviceType enum and UI
4. **Implement Automation**: Add scheduling and rules
5. **Add Notifications**: Push notifications for alarms
6. **Enhance 3D**: Import your actual home model
7. **Add Tests**: Unit and integration tests
8. **Deploy**: Build release APK/IPA

---

**Need help?** Check `README.md` for detailed instructions or `QUICKSTART.md` for step-by-step setup.
