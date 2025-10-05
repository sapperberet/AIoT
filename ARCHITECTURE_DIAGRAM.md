# 🏗️ Smart Home AIoT App Architecture

## 📊 System Overview

```
┌─────────────────────────────────────────────────────────────────┐
│                     Smart Home AIoT App                          │
│                                                                   │
│  ┌─────────────┐  ┌─────────────┐  ┌──────────────┐            │
│  │   Flutter   │  │   Firebase  │  │     MQTT     │            │
│  │     App     │◄─┤  Firestore  │  │   (Local)    │◄──ESP32   │
│  └─────────────┘  └─────────────┘  └──────────────┘            │
│                                                                   │
│  [Cloud Mode] ─────────────► Firebase (Internet Required)       │
│  [Local Mode] ─────────────► MQTT Broker (Same Network)         │
└─────────────────────────────────────────────────────────────────┘
```

---

## 🔄 App Flow Diagram

```
┌──────────────┐
│ Splash Screen│
└──────┬───────┘
       │
       ▼
┌──────────────┐     No Auth    ┌──────────────┐
│ Auth Check   │────────────────►│ Login Screen │
└──────┬───────┘                 └──────┬───────┘
       │ Authenticated                  │
       ▼                                │ Login Success
┌──────────────────────────────────────┘
│
▼
┌───────────────────────────────────────────────────────┐
│                   Home Screen                         │
│  ┌─────────────┐  ┌──────────────┐  ┌─────────────┐ │
│  │  Devices    │  │Visualization │  │    Logs     │ │
│  │    Tab      │  │     Tab      │  │    Tab      │ │
│  └─────────────┘  └──────────────┘  └─────────────┘ │
└───────────────────────────────────────────────────────┘
       │
       ├─────► Drawer Menu ─┐
       │                    │
       ▼                    ▼
┌──────────────┐     ┌──────────────┐
│   Settings   │     │Notifications │
└──────────────┘     └──────────────┘
       │                    │
       ▼                    ▼
┌──────────────┐     ┌──────────────┐
│ Automations  │     │Energy Monitor│
└──────────────┘     └──────────────┘
```

---

## 🎯 State Management Architecture

```
┌─────────────────────────────────────────────────────────┐
│                    UI Layer (Screens)                    │
├─────────────────────────────────────────────────────────┤
│  Settings  │ Notifications │ Automations │ Energy       │
└────┬───────┴───────┬───────┴──────┬──────┴──────┬──────┘
     │               │              │             │
     │ Consumer/     │              │             │
     │ Watch         │              │             │
     ▼               ▼              ▼             ▼
┌─────────────────────────────────────────────────────────┐
│              Provider Layer (State Management)           │
├─────────────────────────────────────────────────────────┤
│  Settings    │ Notification │ Automation │ Device       │
│  Provider    │  Service     │  Provider  │ Provider     │
└────┬─────────┴──────┬───────┴─────┬──────┴──────┬──────┘
     │                │              │             │
     │ Uses           │              │             │
     ▼                ▼              ▼             ▼
┌─────────────────────────────────────────────────────────┐
│                Service Layer (Business Logic)            │
├─────────────────────────────────────────────────────────┤
│   Auth       │  Firestore   │     MQTT    │  Storage   │
│  Service     │   Service    │   Service   │  Service   │
└────┬─────────┴──────┬───────┴─────┬───────┴─────┬──────┘
     │                │              │             │
     │ Communicates   │              │             │
     ▼                ▼              ▼             ▼
┌─────────────────────────────────────────────────────────┐
│                External Services / APIs                  │
├─────────────────────────────────────────────────────────┤
│  Firebase Auth │ Cloud Firestore │ MQTT Broker │ etc.  │
└─────────────────────────────────────────────────────────┘
```

---

## 📡 Cloud vs Local Mode

### Cloud Mode Architecture:

```
┌─────────────┐        Internet         ┌──────────────┐
│ Flutter App │◄──────────────────────►│   Firebase   │
│             │                         │              │
│  Devices    │   HTTPS/WebSocket       │ - Firestore  │
│  Control    │                         │ - Auth       │
│             │                         │ - Storage    │
└─────────────┘                         └──────────────┘
      │
      │ Real-time Sync
      │
      ▼
┌─────────────┐
│   Device    │
│   State     │
│  (Cached)   │
└─────────────┘
```

### Local Mode Architecture:

```
┌─────────────┐      WiFi (LAN)      ┌──────────────┐
│ Flutter App │◄────────────────────►│ MQTT Broker  │
│             │                       │              │
│  Devices    │   MQTT Protocol       │ Mosquitto    │
│  Control    │   (Port 1883)         │ or HiveMQ    │
│             │                       │              │
└─────────────┘                       └──────┬───────┘
                                             │
                                             │ WiFi (LAN)
                                             │
                                             ▼
                                    ┌────────────────┐
                                    │     ESP32      │
                                    │   Devices      │
                                    │                │
                                    │ - Lights       │
                                    │ - Sensors      │
                                    │ - Switches     │
                                    └────────────────┘
```

---

## 🔌 MQTT Communication Flow

```
App Sends Command:
┌─────────────┐
│ User Taps   │
│ Button      │
└─────┬───────┘
      │
      ▼
┌─────────────────────────────────────┐
│ DeviceProvider                      │
│  - Creates JSON command             │
│  - Publishes to MQTT topic          │
└─────┬───────────────────────────────┘
      │
      │ MQTT Publish
      │ Topic: smarthome/user/device/command
      │ Payload: {"action": "turn_on"}
      │
      ▼
┌─────────────────────────────────────┐
│ MQTT Broker                         │
│  - Receives message                 │
│  - Routes to subscribers            │
└─────┬───────────────────────────────┘
      │
      │ MQTT Deliver
      │
      ▼
┌─────────────────────────────────────┐
│ ESP32 Device                        │
│  - Receives command                 │
│  - Parses JSON                      │
│  - Executes action                  │
│  - Updates hardware                 │
└─────┬───────────────────────────────┘
      │
      │ MQTT Publish
      │ Topic: smarthome/user/device/status
      │ Payload: {"state": "on"}
      │
      ▼
┌─────────────────────────────────────┐
│ MQTT Broker                         │
└─────┬───────────────────────────────┘
      │
      │ MQTT Deliver
      │
      ▼
┌─────────────────────────────────────┐
│ Flutter App                         │
│  - Receives status update           │
│  - Updates UI                       │
│  - Shows new state                  │
└─────────────────────────────────────┘
```

---

## 🗄️ Data Models

```
User
├─ uid: String
├─ email: String
├─ displayName: String
├─ photoURL: String?
└─ createdAt: DateTime

Device
├─ id: String
├─ userId: String
├─ name: String
├─ type: DeviceType (light, switch, sensor, etc.)
├─ roomId: String
├─ isOn: bool
├─ status: DeviceStatus (online, offline, error)
├─ brightness: int?
├─ temperature: double?
└─ lastSeen: DateTime

Automation
├─ id: String
├─ name: String
├─ description: String
├─ isEnabled: bool
├─ triggers: List<AutomationTrigger>
├─ conditions: List<AutomationCondition>
├─ actions: List<AutomationAction>
├─ createdAt: DateTime
└─ lastTriggered: DateTime?

Notification
├─ id: String
├─ title: String
├─ message: String
├─ type: NotificationType
├─ priority: NotificationPriority
├─ timestamp: DateTime
├─ isRead: bool
└─ data: Map<String, dynamic>?
```

---

## 🎨 UI Component Hierarchy

```
MaterialApp
└── MultiProvider
    ├── AuthProvider
    ├── DeviceProvider
    ├── SettingsProvider
    ├── NotificationService
    └── AutomationProvider
        │
        └── Consumer<SettingsProvider>
            │
            └── MaterialApp
                ├── theme: lightTheme
                ├── darkTheme: darkTheme
                └── themeMode: settingsProvider.themeMode
                    │
                    ├── Splash Screen
                    │
                    ├── Home Screen
                    │   ├── AppBar
                    │   ├── Drawer (CustomDrawer)
                    │   ├── Body
                    │   │   ├── Devices Tab
                    │   │   ├── Visualization Tab
                    │   │   └── Logs Tab
                    │   └── Bottom Navigation
                    │
                    ├── Settings Screen ✨
                    │   ├── Profile Section
                    │   ├── Connection Mode
                    │   ├── Appearance
                    │   ├── Notifications
                    │   ├── Preferences
                    │   ├── Account
                    │   └── About
                    │
                    ├── Notifications Screen ✨
                    │   ├── Filter Chips
                    │   └── Notification List
                    │       └── Notification Cards
                    │
                    ├── Automations Screen ✨
                    │   └── Automation Cards
                    │       ├── Triggers
                    │       ├── Conditions
                    │       └── Actions
                    │
                    └── Energy Monitor Screen ✨
                        ├── Period Selector
                        ├── Total Consumption
                        ├── Chart
                        ├── Device Breakdown
                        └── Energy Tips
```

---

## 🔐 Security Architecture

```
┌─────────────────────────────────────────────────────────┐
│                  Client App (Flutter)                    │
├─────────────────────────────────────────────────────────┤
│  - API Keys in .gitignore                               │
│  - User Authentication Required                          │
│  - Local data encryption                                 │
└────────────────────┬────────────────────────────────────┘
                     │
                     │ HTTPS/WSS
                     │ (Encrypted)
                     ▼
┌─────────────────────────────────────────────────────────┐
│                  Firebase Platform                       │
├─────────────────────────────────────────────────────────┤
│  Authentication                                          │
│  ├─ Email/Password                                      │
│  ├─ Email Verification                                  │
│  └─ Session Management                                  │
│                                                          │
│  Firestore Security Rules                               │
│  ├─ User Isolation (userId check)                       │
│  ├─ Read: auth.uid == resource.data.userId             │
│  └─ Write: auth.uid == request.resource.data.userId    │
│                                                          │
│  API Key Restrictions                                   │
│  ├─ Android package name                                │
│  ├─ SHA-1 fingerprint                                   │
│  └─ Referrer restrictions                               │
└─────────────────────────────────────────────────────────┘
```

---

## 📦 Package Dependencies

```
Core Packages:
├─ flutter (Framework)
├─ firebase_core (Firebase SDK)
├─ firebase_auth (Authentication)
├─ cloud_firestore (Database)
└─ provider (State Management)

Connectivity:
├─ mqtt_client (MQTT Protocol)
└─ connectivity_plus (Network Status)

UI/UX:
├─ iconsax (Icons)
├─ animate_do (Animations)
├─ glassmorphism (UI Effects)
└─ google_fonts (Typography)

Utilities:
├─ intl (Internationalization)
├─ shared_preferences (Local Storage)
└─ logger (Logging)
```

---

## 🔄 Automation Engine Flow

```
Automation Engine:

┌─────────────────┐
│  Timer Service  │ ──► Check every minute
└────────┬────────┘
         │
         ▼
┌─────────────────────────────────┐
│  For each enabled automation:  │
│                                 │
│  1. Check Triggers              │
│     ├─ Time match?             │
│     ├─ Device state?           │
│     └─ Sun event?              │
│                                 │
│  2. Evaluate Conditions         │
│     ├─ Time range?             │
│     ├─ Day of week?            │
│     └─ Device state?           │
│                                 │
│  3. Execute Actions             │
│     ├─ Turn on/off devices     │
│     ├─ Set brightness/temp     │
│     └─ Send notification       │
│                                 │
│  4. Update Last Triggered       │
└─────────────────────────────────┘
```

---

## 📊 Energy Monitoring Flow

```
Energy Monitor:

┌─────────────┐
│   Devices   │
└─────┬───────┘
      │ Report consumption
      │ every 10 seconds
      ▼
┌─────────────────────┐
│  Energy Service     │
│  - Collect data     │
│  - Aggregate        │
│  - Calculate cost   │
└─────┬───────────────┘
      │
      │ Update
      ▼
┌─────────────────────┐
│  Energy Provider    │
│  - Store history    │
│  - Calculate trends │
│  - Generate tips    │
└─────┬───────────────┘
      │
      │ Display
      ▼
┌─────────────────────┐
│ Energy Monitor UI   │
│  - Charts           │
│  - Breakdown        │
│  - Cost estimate    │
│  - Saving tips      │
└─────────────────────┘
```

---

## 🎯 Connection Mode Decision Tree

```
App Starts
    │
    ▼
┌────────────────────┐
│ Read Settings      │
│ Connection Mode    │
└────────┬───────────┘
         │
         ├─► Cloud Mode? ──► Initialize Firebase
         │                   ├─ Auth Service
         │                   ├─ Firestore Service
         │                   └─ Storage Service
         │
         └─► Local Mode? ──► Initialize MQTT
                            ├─ Connect to Broker
                            ├─ Subscribe to Topics
                            └─ Start Heartbeat
```

---

## 🚀 Build & Deploy Process

```
Development
    │
    ├─► Write Code
    │   ├─ Screens
    │   ├─ Providers
    │   └─ Services
    │
    ├─► Test Locally
    │   └─ flutter run
    │
    ├─► Fix Bugs
    │   └─ Hot Reload/Restart
    │
    ▼
Build
    │
    ├─► Clean
    │   └─ flutter clean
    │
    ├─► Get Dependencies
    │   └─ flutter pub get
    │
    ├─► Build APK
    │   └─ flutter build apk --release
    │
    └─► Build App Bundle
        └─ flutter build appbundle
            │
            ▼
Deploy
    │
    ├─► Test on Device
    │
    ├─► Internal Testing
    │
    ├─► Beta Testing
    │
    └─► Production Release
        └─ Google Play Store
```

---

## 📱 User Journey

```
New User:
Splash → Login → Register → Verify Email → Home

Returning User:
Splash → Home (Auto-login)

Control Device (Cloud):
Home → Select Device → Toggle/Adjust
  → Firebase Update → Real-time Sync → UI Update

Control Device (Local):
Home → Select Device → Toggle/Adjust
  → MQTT Publish → ESP32 Execute → Status Update → UI Update

Create Automation:
Menu → Automations → New → Configure
  → Set Triggers → Add Conditions → Define Actions → Save

View Notifications:
Menu → Notifications → Filter/View → Mark Read → Delete

Check Energy:
Menu → Energy Monitor → Select Period → View Details
```

---

This architecture ensures:
- ✅ **Separation of Concerns**: Clear layers
- ✅ **Scalability**: Easy to add features
- ✅ **Maintainability**: Organized structure
- ✅ **Testability**: Isolated components
- ✅ **Flexibility**: Cloud or Local modes
- ✅ **Security**: Multiple layers of protection

**Total Implementation**: 100% Complete! 🎉
