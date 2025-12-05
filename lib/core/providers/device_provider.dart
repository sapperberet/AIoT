import 'package:flutter/material.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'dart:async';
import '../services/mqtt_service.dart';
import '../services/firestore_service.dart';
import '../services/notification_service.dart';
import '../services/event_log_service.dart';
import '../models/device_model.dart';
import '../config/mqtt_config.dart';
import 'home_visualization_provider.dart';

/// Callback type for visualization sync
typedef VisualizationSyncCallback = void Function(
    String deviceType, Map<String, dynamic> state);

class DeviceProvider with ChangeNotifier {
  final MqttService _mqttService;
  final FirestoreService _firestoreService;
  final NotificationService _notificationService;
  EventLogService? _eventLogService;

  List<Device> _devices = [];
  List<AlarmEvent> _alarms = [];
  bool _isConnectedToMqtt = false;
  bool _useCloudMode = false;
  String? _userId;

  // Device states for doors, windows, buzzer, lights, fans
  // Doors: main_door, garage_door
  bool _isMainDoorOpen = false;
  bool _isGarageDoorOpen = false;
  bool _isBuzzerActive = false;

  // Windows: front_window, side_window
  Map<String, bool> _windowStates = {
    'front_window': false,
    'side_window': false,
  };

  // Lights: landscape, floor_1, floor_2, rgb (with extra properties)
  Map<String, bool> _lightStates = {
    'landscape': false,
    'floor_1': false,
    'floor_2': false,
    'rgb': false,
  };

  // Light brightness (0-100)
  Map<String, int> _lightBrightness = {
    'landscape': 100,
    'floor_1': 100,
    'floor_2': 100,
    'rgb': 100,
  };

  // RGB light color (hex)
  int _rgbLightColor = 0xFFFFFF;

  // RGB light brightness (0-100)
  int _rgbBrightness = 100;

  // Fan states: 0=off, 1=low, 2=medium, 3=high
  Map<String, int> _fanStates = {
    'living_room': 0,
    'bedroom': 0,
  };

  // Callback for visualization sync (legacy, kept for compatibility)
  VisualizationSyncCallback? _visualizationCallback;

  // Direct reference to visualization provider for guaranteed sync
  HomeVisualizationProvider? _homeVisualizationProvider;

  // Performance optimization
  Timer? _updateDebounceTimer;
  final Map<String, dynamic> _pendingUpdates = {};

  // Firebase global state sync
  StreamSubscription<Map<String, dynamic>?>? _globalStateSubscription;
  bool _isProcessingRemoteUpdate = false; // Prevent sync loops

  DeviceProvider({
    required MqttService mqttService,
    required FirestoreService firestoreService,
    required NotificationService notificationService,
    EventLogService? eventLogService,
  })  : _mqttService = mqttService,
        _firestoreService = firestoreService,
        _notificationService = notificationService,
        _eventLogService = eventLogService {
    _init();
  }

  // Getters
  List<Device> get devices => _devices;
  List<AlarmEvent> get alarms => _alarms;
  List<AlarmEvent> get activeAlarms =>
      _alarms.where((a) => !a.acknowledged).toList();
  bool get isConnectedToMqtt => _isConnectedToMqtt;
  bool get useCloudMode => _useCloudMode;

  // New device state getters
  bool get isMainDoorOpen => _isMainDoorOpen;
  bool get isGarageDoorOpen => _isGarageDoorOpen;
  bool get isBuzzerActive => _isBuzzerActive;
  Map<String, bool> get windowStates => Map.unmodifiable(_windowStates);
  Map<String, bool> get lightStates => Map.unmodifiable(_lightStates);
  Map<String, int> get lightBrightness => Map.unmodifiable(_lightBrightness);
  int get rgbLightColor => _rgbLightColor;
  int get rgbBrightness => _rgbBrightness;
  Map<String, int> get fanStates => Map.unmodifiable(_fanStates);

  // Legacy getters for compatibility
  bool get isDoorOpen => _isMainDoorOpen;
  bool get isGarageOpen => _isGarageDoorOpen;

  // Filtered device getters
  List<Device> get doors =>
      _devices.where((d) => d.type == DeviceType.door).toList();
  List<Device> get windows =>
      _devices.where((d) => d.type == DeviceType.window).toList();
  List<Device> get lights =>
      _devices.where((d) => d.type == DeviceType.light).toList();
  List<Device> get garages =>
      _devices.where((d) => d.type == DeviceType.garage).toList();
  List<Device> get buzzers =>
      _devices.where((d) => d.type == DeviceType.buzzer).toList();
  List<Device> get fans =>
      _devices.where((d) => d.type == DeviceType.fan).toList();
  List<Device> get cameras =>
      _devices.where((d) => d.type == DeviceType.camera).toList();
  List<Device> get sensors =>
      _devices.where((d) => d.type == DeviceType.sensor).toList();

  /// Set event log service (for dependency injection)
  void setEventLogService(EventLogService service) {
    _eventLogService = service;
  }

  /// Set visualization sync callback (legacy)
  void setVisualizationCallback(VisualizationSyncCallback? callback) {
    _visualizationCallback = callback;
  }

  /// Set the HomeVisualizationProvider for direct sync
  void setHomeVisualizationProvider(HomeVisualizationProvider provider) {
    _homeVisualizationProvider = provider;
  }

  /// Sync a device state to visualization provider
  void _syncToVisualization(String deviceType, Map<String, dynamic> state) {
    // Always update HomeVisualizationProvider directly if available
    _homeVisualizationProvider?.syncFromDeviceState(deviceType, state);
    // Also call the legacy callback if set
    _visualizationCallback?.call(deviceType, state);
  }

  /// Handle global state updates from Firebase (synced from other devices)
  void _handleGlobalStateUpdate(Map<String, dynamic> states) {
    debugPrint('🔄 Received global state update from Firebase');
    bool hasChanges = false;

    // Sync door state
    if (states['door'] != null) {
      final doorState = states['door'] as Map<String, dynamic>;
      final isOpen = doorState['isOpen'] as bool? ?? false;
      if (_isMainDoorOpen != isOpen) {
        debugPrint(
            '🚪 Firebase: Door state changed to ${isOpen ? "OPEN" : "CLOSED"}');
        _isMainDoorOpen = isOpen;
        _syncToVisualization('door', {'isOpen': isOpen});
        hasChanges = true;
      }
    }

    // Sync garage state
    if (states['garage'] != null) {
      final garageState = states['garage'] as Map<String, dynamic>;
      final isOpen = garageState['isOpen'] as bool? ?? false;
      if (_isGarageDoorOpen != isOpen) {
        debugPrint(
            '🚗 Firebase: Garage state changed to ${isOpen ? "OPEN" : "CLOSED"}');
        _isGarageDoorOpen = isOpen;
        _syncToVisualization('garage', {'isOpen': isOpen});
        hasChanges = true;
      }
    }

    // Sync window states
    if (states['windows'] != null) {
      final windowStates = states['windows'] as Map<String, dynamic>;
      bool windowsChanged = false;
      windowStates.forEach((windowId, value) {
        final isOpen = value as bool? ?? false;
        if (_windowStates[windowId] != isOpen) {
          debugPrint(
              '🪟 Firebase: Window $windowId changed to ${isOpen ? "OPEN" : "CLOSED"}');
          _windowStates[windowId] = isOpen;
          windowsChanged = true;
          hasChanges = true;
        }
      });
      // Sync windows to visualization
      if (windowsChanged) {
        _syncToVisualization('windows', Map<String, dynamic>.from(_windowStates));
      }
    }

    // Sync light states
    if (states['lights'] != null) {
      final lightStates = states['lights'] as Map<String, dynamic>;
      lightStates.forEach((lightId, value) {
        if (value is Map<String, dynamic>) {
          final isOn = value['isOn'] as bool? ?? false;
          final brightness = value['brightness'] as int? ?? 100;
          if (_lightStates[lightId] != isOn) {
            debugPrint(
                '💡 Firebase: Light $lightId changed to ${isOn ? "ON" : "OFF"}');
            _lightStates[lightId] = isOn;
            hasChanges = true;
          }
          if (_lightBrightness[lightId] != brightness) {
            _lightBrightness[lightId] = brightness;
            hasChanges = true;
          }
        }
      });
    }

    // Sync fan states
    if (states['fans'] != null) {
      final fanStates = states['fans'] as Map<String, dynamic>;
      fanStates.forEach((fanId, value) {
        final speed = value as int? ?? 0;
        if (_fanStates[fanId] != speed) {
          debugPrint('🌀 Firebase: Fan $fanId changed to speed $speed');
          _fanStates[fanId] = speed;
          hasChanges = true;
        }
      });
    }

    // Sync buzzer state
    if (states['buzzer'] != null) {
      final buzzerState = states['buzzer'] as Map<String, dynamic>;
      final isActive = buzzerState['isActive'] as bool? ?? false;
      if (_isBuzzerActive != isActive) {
        debugPrint(
            '🔔 Firebase: Buzzer changed to ${isActive ? "ACTIVE" : "INACTIVE"}');
        _isBuzzerActive = isActive;
        _syncToVisualization('buzzer', {'isActive': isActive});
        hasChanges = true;
      }
    }

    // Sync RGB color (handle both Map and int formats)
    bool rgbChanged = false;
    if (states['rgbColor'] != null) {
      int color;
      final rgbData = states['rgbColor'];
      if (rgbData is int) {
        color = rgbData;
      } else if (rgbData is Map) {
        color = (rgbData['value'] as int?) ?? 0xFFFFFF;
      } else {
        color = 0xFFFFFF;
      }
      if (_rgbLightColor != color) {
        debugPrint('🌈 Firebase: RGB color changed to 0x${color.toRadixString(16)}');
        _rgbLightColor = color;
        rgbChanged = true;
        hasChanges = true;
      }
    }

    // Sync RGB brightness
    if (states['rgbBrightness'] != null) {
      int brightness;
      final brightnessData = states['rgbBrightness'];
      if (brightnessData is int) {
        brightness = brightnessData;
      } else if (brightnessData is Map) {
        brightness = (brightnessData['value'] as int?) ?? 100;
      } else {
        brightness = 100;
      }
      if (_rgbBrightness != brightness) {
        debugPrint('🌈 Firebase: RGB brightness changed to $brightness%');
        _rgbBrightness = brightness;
        rgbChanged = true;
        hasChanges = true;
      }
    }

    // Sync RGB to visualization if color or brightness changed
    if (rgbChanged) {
      _syncToVisualization('rgb', {
        'color': _rgbLightColor,
        'brightness': _rgbBrightness,
        'isOn': _lightStates['rgb'] ?? false,
      });
    }

    if (hasChanges) {
      notifyListeners();
    }
  }

  /// Save current device states to Firebase for global sync
  Future<void> _saveToFirebase() async {
    final states = {
      'door': {'isOpen': _isMainDoorOpen},
      'garage': {'isOpen': _isGarageDoorOpen},
      'windows': Map<String, dynamic>.from(_windowStates),
      'lights': _lightStates.map((key, value) => MapEntry(key, {
            'isOn': value,
            'brightness': _lightBrightness[key] ?? 100,
          })),
      'fans': Map<String, dynamic>.from(_fanStates),
      'buzzer': {'isActive': _isBuzzerActive},
      'rgbColor': _rgbLightColor,
    };

    _isProcessingRemoteUpdate = true;
    await _firestoreService.saveGlobalDeviceStates(states);
    _isProcessingRemoteUpdate = false;
  }

  /// Save a single device state to Firebase
  Future<void> _saveDeviceToFirebase(
      String deviceType, Map<String, dynamic> state) async {
    _isProcessingRemoteUpdate = true;
    await _firestoreService.updateGlobalDeviceState(deviceType, state);
    _isProcessingRemoteUpdate = false;
  }

  void _init() {
    // Listen to MQTT connection status
    _mqttService.statusStream.listen((status) {
      _isConnectedToMqtt = status == ConnectionStatus.connected;
      notifyListeners();
    });

    // Listen to MQTT messages with debouncing for performance
    _mqttService.messageStream.listen(_handleMqttMessage);

    // Check connectivity and decide on local vs cloud
    _checkConnectivity();
  }

  Future<void> initialize(String userId) async {
    _userId = userId;

    // Load devices from Firestore
    _firestoreService.getDevicesStream(userId).listen((devices) {
      _devices = devices;
      _syncDeviceStates();
      notifyListeners();
    });

    // Load alarms from Firestore
    _firestoreService.getAlarmsStream(userId).listen((alarms) {
      _alarms = alarms;
      notifyListeners();
    });

    // Listen for global device state changes (real-time sync across all devices)
    _globalStateSubscription?.cancel();
    _globalStateSubscription =
        _firestoreService.getGlobalDeviceStatesStream().listen(
      (states) {
        if (states != null && !_isProcessingRemoteUpdate) {
          _handleGlobalStateUpdate(states);
        }
      },
      onError: (e) {
        debugPrint('❌ Error listening to global states: $e');
      },
    );

    // Try to connect to local MQTT
    await connectToMqtt();
  }

  /// Sync device states from loaded devices
  void _syncDeviceStates() {
    for (var device in _devices) {
      switch (device.type) {
        case DeviceType.door:
          _isMainDoorOpen = device.isOpen;
          break;
        case DeviceType.garage:
          _isGarageDoorOpen = device.isOpen;
          break;
        case DeviceType.window:
          _windowStates[device.id] = device.isOpen;
          break;
        case DeviceType.light:
          _lightStates[device.id] = device.isLightOn;
          break;
        case DeviceType.buzzer:
          _isBuzzerActive = device.isBuzzerActive;
          break;
        default:
          break;
      }
    }
  }

  Future<void> _checkConnectivity() async {
    final connectivityResult = await Connectivity().checkConnectivity();
    _useCloudMode = connectivityResult == ConnectivityResult.mobile ||
        connectivityResult == ConnectivityResult.none;
    notifyListeners();
  }

  Future<void> connectToMqtt() async {
    try {
      await _mqttService.connect(useCloud: _useCloudMode);

      // Subscribe to all device topics
      _subscribeToTopics();
    } catch (e) {
      debugPrint('Failed to connect to MQTT: $e');
    }
  }

  void _subscribeToTopics() {
    // Subscribe to all alarm topics
    _mqttService.subscribe(MqttConfig.fireAlarmTopic);
    _mqttService.subscribe(MqttConfig.motionAlarmTopic);
    _mqttService.subscribe(MqttConfig.doorAlarmTopic);

    // Subscribe to door, window, garage, buzzer topics
    _mqttService.subscribe(MqttConfig.doorStatusTopic);
    _mqttService.subscribe(MqttConfig.windowStatusTopic);
    _mqttService.subscribe(MqttConfig.garageStatusTopic);
    _mqttService.subscribe(MqttConfig.buzzerStatusTopic);
    _mqttService.subscribe(MqttConfig.allLightsStatusTopic);
    _mqttService.subscribe(MqttConfig.deviceSyncTopic);

    // Subscribe to face detection topics (Version 2)
    _mqttService.subscribe(MqttConfig.faceRecognizedTopic);
    _mqttService.subscribe(MqttConfig.faceUnrecognizedTopic);

    // Subscribe to device status topics
    for (var device in _devices) {
      _mqttService.subscribe(MqttConfig.deviceStatusTopic(device.id));
    }
  }

  void _handleMqttMessage(MqttMessage message) {
    final payload = message.jsonPayload;
    if (payload == null) return;

    // Check for face detection events (Version 2)
    if (message.topic == MqttConfig.faceUnrecognizedTopic) {
      _handleUnrecognizedFace(payload);
      return;
    } else if (message.topic == MqttConfig.faceRecognizedTopic) {
      _handleRecognizedFace(payload);
      return;
    }

    // Handle door, window, garage, buzzer, light, fan status
    if (message.topic.contains('/door/status')) {
      _handleDoorStatus(payload);
      return;
    } else if (message.topic.contains('/window/status')) {
      _handleWindowStatus(message.topic, payload);
      return;
    } else if (message.topic.contains('/garage/status')) {
      _handleGarageStatus(payload);
      return;
    } else if (message.topic.contains('/buzzer/status')) {
      _handleBuzzerStatus(payload);
      return;
    } else if (message.topic.contains('/light/status')) {
      _handleLightStatus(message.topic, payload);
      return;
    } else if (message.topic.contains('/fan/status')) {
      _handleFanStatus(message.topic, payload);
      return;
    }

    // Check if it's an alarm
    if (message.topic.contains('alarm')) {
      _handleAlarm(message.topic, payload);
    } else {
      _handleDeviceUpdate(message.topic, payload);
    }
  }

  /// Handle door status from backend
  void _handleDoorStatus(Map<String, dynamic> payload) {
    final isOpen = payload['state'] == 'open';
    final previousState = _isMainDoorOpen;
    _isMainDoorOpen = isOpen;

    // Log event if state changed
    if (previousState != isOpen &&
        _userId != null &&
        _eventLogService != null) {
      _eventLogService!.logDoorEvent(
        userId: _userId!,
        isOpen: isOpen,
        location: payload['location'] as String? ?? 'main',
        triggeredBy: payload['triggeredBy'] as String?,
      );
    }

    // Notify for security (door opened)
    if (isOpen && !previousState) {
      _notificationService.notifySecurityAlert(
        '🚪 Door opened at ${payload['location'] ?? 'main entrance'}',
        priority: NotificationPriority.high,
      );
    }

    // Sync with visualization
    _syncToVisualization('door', {'isOpen': isOpen});
    notifyListeners();
  }

  /// Handle window status from backend
  void _handleWindowStatus(String topic, Map<String, dynamic> payload) {
    // Extract window ID from topic: home/{room}/window/status
    final parts = topic.split('/');
    final windowId = parts.length > 1 ? parts[1] : 'main';
    final isOpen = payload['state'] == 'open';
    final previousState = _windowStates[windowId] ?? false;
    _windowStates[windowId] = isOpen;

    // Log event if state changed
    if (previousState != isOpen &&
        _userId != null &&
        _eventLogService != null) {
      _eventLogService!.logWindowEvent(
        userId: _userId!,
        isOpen: isOpen,
        location: windowId,
      );
    }

    // Notify for security (window opened)
    if (isOpen && !previousState) {
      _notificationService.notifySecurityAlert(
        '🪟 Window opened in $windowId',
        priority: NotificationPriority.medium,
      );
    }

    // Sync with visualization
    _visualizationCallback
        ?.call('window', {'windowId': windowId, 'isOpen': isOpen});
    notifyListeners();
  }

  /// Handle garage status from backend
  void _handleGarageStatus(Map<String, dynamic> payload) {
    final isOpen = payload['state'] == 'open';
    final previousState = _isGarageDoorOpen;
    _isGarageDoorOpen = isOpen;

    // Log event if state changed
    if (previousState != isOpen &&
        _userId != null &&
        _eventLogService != null) {
      _eventLogService!.logGarageEvent(
        userId: _userId!,
        isOpen: isOpen,
      );
    }

    // Notify for security (garage opened/closed)
    if (isOpen != previousState) {
      _notificationService.notifySecurityAlert(
        isOpen ? '🚗 Garage door opened' : '🚗 Garage door closed',
        priority: NotificationPriority.high,
      );
    }

    // Sync with visualization
    _syncToVisualization('garage', {'isOpen': isOpen});
    notifyListeners();
  }

  /// Handle buzzer status from backend
  void _handleBuzzerStatus(Map<String, dynamic> payload) {
    final isActive = payload['active'] == true;
    final previousState = _isBuzzerActive;
    _isBuzzerActive = isActive;

    // Log event if state changed
    if (previousState != isActive &&
        _userId != null &&
        _eventLogService != null) {
      _eventLogService!.logBuzzerEvent(
        userId: _userId!,
        isActive: isActive,
        reason: payload['reason'] as String?,
      );
    }

    // Sync with visualization
    _syncToVisualization('buzzer', {'isActive': isActive});
    notifyListeners();
  }

  /// Handle light status from backend
  void _handleLightStatus(String topic, Map<String, dynamic> payload) {
    // Extract light/room ID from topic: home/{room}/light/status
    final parts = topic.split('/');
    final lightId = parts.length > 1 ? parts[1] : 'main';
    final isOn = payload['state'] == 'on';
    final previousState = _lightStates[lightId] ?? false;
    _lightStates[lightId] = isOn;

    // Log event if state changed
    if (previousState != isOn && _userId != null && _eventLogService != null) {
      _eventLogService!.logLightEvent(
        userId: _userId!,
        isOn: isOn,
        location: lightId,
        brightness: payload['brightness'] as int?,
      );
    }

    // Sync with visualization
    _syncToVisualization('light', {
      'lightId': lightId,
      'isOn': isOn,
      'brightness': payload['brightness'],
    });
    notifyListeners();
  }

  /// Handle fan status from backend
  void _handleFanStatus(String topic, Map<String, dynamic> payload) {
    // Extract fan/room ID from topic: home/{room}/fan/status
    final parts = topic.split('/');
    final fanId = parts.length > 1 ? parts[1] : 'main';
    final speed = payload['speed'] as int? ?? 0;
    final previousSpeed = _fanStates[fanId] ?? 0;
    _fanStates[fanId] = speed;

    // Log event if state changed
    if (previousSpeed != speed && _userId != null && _eventLogService != null) {
      _eventLogService!.logFanEvent(
        userId: _userId!,
        speed: speed,
        location: fanId,
      );
    }

    // Sync with visualization
    _syncToVisualization('fan', {
      'fanId': fanId,
      'speed': speed,
    });
    notifyListeners();
  }

  void _handleUnrecognizedFace(Map<String, dynamic> payload) {
    // Create security alarm for unrecognized person
    final alarm = AlarmEvent(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      location: 'entrance',
      type: 'unrecognized_person',
      severity: 'high',
      message: 'Unrecognized person detected at entrance',
      timestamp: DateTime.now(),
    );

    // Add to local list
    _alarms.insert(0, alarm);

    // Save to Firestore
    if (_userId != null) {
      _firestoreService.addAlarmEvent(_userId!, alarm);
    }

    // Send notification
    _notificationService.notifyUnrecognizedPerson(location: 'entrance');

    notifyListeners();
  }

  void _handleRecognizedFace(Map<String, dynamic> payload) {
    final name = payload['name'] ?? 'Unknown';

    // Create info log for recognized person
    final alarm = AlarmEvent(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      location: 'entrance',
      type: 'person_recognized',
      severity: 'info',
      message: '$name detected at entrance',
      timestamp: DateTime.now(),
      acknowledged: true, // Auto-acknowledge for recognized faces
    );

    // Add to local list
    _alarms.insert(0, alarm);

    // Save to Firestore
    if (_userId != null) {
      _firestoreService.addAlarmEvent(_userId!, alarm);
    }

    // Send notification
    _notificationService.notifyPersonRecognized(name, location: 'entrance');

    notifyListeners();
  }

  void _handleAlarm(String topic, Map<String, dynamic> payload) {
    // Extract location from topic (e.g., home/garage/fire_alarm -> garage)
    final parts = topic.split('/');
    final location = parts.length > 1 ? parts[1] : 'unknown';
    final alarmType = parts.last;

    final alarm = AlarmEvent(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      location: location,
      type: alarmType,
      severity: payload['severity'] ?? 'warning',
      message: payload['message'] ?? 'Alarm triggered',
      timestamp: DateTime.now(),
    );

    // Add to local list
    _alarms.insert(0, alarm);

    // Save to Firestore
    if (_userId != null) {
      _firestoreService.addAlarmEvent(_userId!, alarm);
    }

    notifyListeners();
  }

  void _handleDeviceUpdate(String topic, Map<String, dynamic> payload) {
    // Extract device ID from topic
    final parts = topic.split('/');
    if (parts.length < 2) return;

    final deviceId = parts[1];
    final deviceIndex = _devices.indexWhere((d) => d.id == deviceId);

    if (deviceIndex != -1) {
      _devices[deviceIndex] = _devices[deviceIndex].copyWith(
        state: payload,
        status: DeviceStatus.online,
        lastUpdated: DateTime.now(),
      );

      // Update Firestore
      if (_userId != null) {
        _firestoreService.updateDeviceState(_userId!, deviceId, payload);
      }

      notifyListeners();
    }
  }

  Future<void> sendCommand(
      String deviceId, Map<String, dynamic> command) async {
    if (_isConnectedToMqtt && !_useCloudMode) {
      // Send via MQTT for local control
      final topic = MqttConfig.deviceCommandTopic(deviceId);
      _mqttService.publishJson(topic, command);
    } else if (_userId != null) {
      // Send via Firestore for cloud control
      await _firestoreService.sendDeviceCommand(_userId!, deviceId, command);
    }
  }

  Future<void> toggleLight(String deviceId) async {
    final device = _devices.firstWhere((d) => d.id == deviceId);
    final currentState = device.state['state'] == 'on';

    await sendCommand(deviceId, {
      'action': 'toggle',
      'state': currentState ? 'off' : 'on',
    });
  }

  /// Toggle door open/closed
  Future<void> toggleDoor() async {
    final newState = !_isMainDoorOpen;
    final command = {
      'action': 'toggle',
      'state': newState ? 'open' : 'closed',
      'deviceId': 'main_door',
      'timestamp': DateTime.now().toIso8601String(),
    };

    if (_isConnectedToMqtt && !_useCloudMode) {
      _mqttService.publishJson(MqttConfig.doorCommandTopic, command);
    }

    // Optimistic update
    _isMainDoorOpen = newState;
    _syncToVisualization('door', {'isOpen': _isMainDoorOpen});

    // Save to Firebase for global sync
    _saveDeviceToFirebase('door', {'isOpen': _isMainDoorOpen});

    // Notify user
    if (newState) {
      _notificationService.notifyDoorOpened(location: 'Main Door');
    } else {
      _notificationService.notifyDoorClosed(location: 'Main Door');
    }

    // Log event
    if (_userId != null && _eventLogService != null) {
      _eventLogService!.logDoorEvent(
        userId: _userId!,
        isOpen: newState,
        location: 'Main Door',
        triggeredBy: 'App User',
      );
    }

    notifyListeners();
  }

  /// Set door state explicitly
  Future<void> setDoorState(bool isOpen) async {
    final command = {
      'action': 'set',
      'state': isOpen ? 'open' : 'closed',
    };

    if (_isConnectedToMqtt && !_useCloudMode) {
      _mqttService.publishJson(MqttConfig.doorCommandTopic, command);
    }

    _isMainDoorOpen = isOpen;
    _syncToVisualization('door', {'isOpen': isOpen});

    // Save to Firebase for global sync
    _saveDeviceToFirebase('door', {'isOpen': isOpen});

    notifyListeners();
  }

  /// Toggle garage open/closed
  Future<void> toggleGarage() async {
    final newState = !_isGarageDoorOpen;
    final command = {
      'action': 'toggle',
      'state': newState ? 'open' : 'closed',
      'deviceId': 'garage',
      'timestamp': DateTime.now().toIso8601String(),
    };

    if (_isConnectedToMqtt && !_useCloudMode) {
      _mqttService.publishJson(MqttConfig.garageCommandTopic, command);
    }

    // Optimistic update
    _isGarageDoorOpen = newState;
    _syncToVisualization('garage', {'isOpen': _isGarageDoorOpen});

    // Save to Firebase for global sync
    _saveDeviceToFirebase('garage', {'isOpen': _isGarageDoorOpen});

    // Notify user
    if (newState) {
      _notificationService.notifyGarageOpened();
    } else {
      _notificationService.notifyGarageClosed();
    }

    // Log event
    if (_userId != null && _eventLogService != null) {
      _eventLogService!.logGarageEvent(
        userId: _userId!,
        isOpen: newState,
      );
    }

    notifyListeners();
  }

  /// Set garage state explicitly
  Future<void> setGarageState(bool isOpen) async {
    final command = {
      'action': 'set',
      'state': isOpen ? 'open' : 'closed',
    };

    if (_isConnectedToMqtt && !_useCloudMode) {
      _mqttService.publishJson(MqttConfig.garageCommandTopic, command);
    }

    _isGarageDoorOpen = isOpen;
    _syncToVisualization('garage', {'isOpen': isOpen});

    // Save to Firebase for global sync
    _saveDeviceToFirebase('garage', {'isOpen': isOpen});

    notifyListeners();
  }

  /// Toggle window open/closed
  Future<void> toggleWindow(String windowId) async {
    final isOpen = _windowStates[windowId] ?? false;
    final newState = !isOpen;
    final windowName = _formatWindowName(windowId);
    final command = {
      'action': 'toggle',
      'state': newState ? 'open' : 'closed',
      'windowId': windowId,
      'deviceId': 'window_$windowId',
      'timestamp': DateTime.now().toIso8601String(),
    };

    if (_isConnectedToMqtt && !_useCloudMode) {
      final topic = MqttConfig.windowCommandTopic.replaceFirst('+', windowId);
      _mqttService.publishJson(topic, command);
    }

    // Optimistic update
    _windowStates[windowId] = newState;
    _visualizationCallback
        ?.call('window', {'windowId': windowId, 'isOpen': newState});

    // Save to Firebase for global sync
    _saveDeviceToFirebase('windows', Map<String, dynamic>.from(_windowStates));

    // Notify user
    if (newState) {
      _notificationService.notifyWindowOpened(location: windowName);
    } else {
      _notificationService.notifyWindowClosed(location: windowName);
    }

    // Log event
    if (_userId != null && _eventLogService != null) {
      _eventLogService!.logWindowEvent(
        userId: _userId!,
        isOpen: newState,
        location: windowName,
      );
    }

    notifyListeners();
  }

  /// Format window ID to display name
  String _formatWindowName(String windowId) {
    return windowId
        .split('_')
        .map((word) => word.isNotEmpty
            ? '${word[0].toUpperCase()}${word.substring(1)}'
            : '')
        .join(' ');
  }

  /// Toggle all windows
  Future<void> toggleAllWindows() async {
    final anyOpen = _windowStates.values.any((isOpen) => isOpen);
    final newState = !anyOpen;

    for (var windowId in _windowStates.keys) {
      _windowStates[windowId] = newState;
    }

    final command = {
      'action': 'setAll',
      'state': newState ? 'open' : 'closed',
    };

    if (_isConnectedToMqtt && !_useCloudMode) {
      _mqttService.publishJson(
          '${MqttConfig.topicPrefix}/windows/command', command);
    }

    _syncToVisualization('windows', {'allOpen': newState});

    // Save to Firebase for global sync
    _saveDeviceToFirebase('windows', Map<String, dynamic>.from(_windowStates));

    notifyListeners();
  }

  /// Toggle buzzer on/off
  Future<void> toggleBuzzer() async {
    final newState = !_isBuzzerActive;
    final command = {
      'action': 'toggle',
      'active': newState,
      'deviceId': 'buzzer',
      'timestamp': DateTime.now().toIso8601String(),
    };

    if (_isConnectedToMqtt && !_useCloudMode) {
      _mqttService.publishJson(MqttConfig.buzzerCommandTopic, command);
    }

    // Optimistic update
    _isBuzzerActive = newState;
    _syncToVisualization('buzzer', {'isActive': _isBuzzerActive});

    // Save to Firebase for global sync
    _saveDeviceToFirebase('buzzer', {'isActive': _isBuzzerActive});

    // Notify user if activated
    if (newState) {
      _notificationService.notifyBuzzerActivated(reason: 'Activated from app');
    }

    // Log event
    if (_userId != null && _eventLogService != null) {
      _eventLogService!.logBuzzerEvent(
        userId: _userId!,
        isActive: newState,
        reason: 'User triggered from app',
      );
    }

    notifyListeners();
  }

  /// Set buzzer state explicitly
  Future<void> setBuzzerState(bool isActive, {String? reason}) async {
    final command = {
      'action': 'set',
      'active': isActive,
      if (reason != null) 'reason': reason,
    };

    if (_isConnectedToMqtt && !_useCloudMode) {
      _mqttService.publishJson(MqttConfig.buzzerCommandTopic, command);
    }

    _isBuzzerActive = isActive;
    _syncToVisualization('buzzer', {'isActive': isActive});

    // Save to Firebase for global sync
    _saveDeviceToFirebase('buzzer', {'isActive': isActive});

    notifyListeners();
  }

  /// Toggle a specific light
  Future<void> toggleLightById(String lightId) async {
    final isOn = _lightStates[lightId] ?? false;
    final newState = !isOn;
    final lightName = _formatWindowName(lightId); // Reuse name formatter
    final command = {
      'action': 'toggle',
      'state': newState ? 'on' : 'off',
      'lightId': lightId,
      'deviceId': 'light_$lightId',
      'timestamp': DateTime.now().toIso8601String(),
    };

    if (_isConnectedToMqtt && !_useCloudMode) {
      final topic = MqttConfig.roomLightCommandTopic(lightId);
      _mqttService.publishJson(topic, command);
    }

    // Optimistic update
    _lightStates[lightId] = newState;
    _visualizationCallback
        ?.call('light', {'lightId': lightId, 'isOn': newState});

    // Save to Firebase for global sync
    _saveDeviceToFirebase(
        'lights',
        _lightStates.map((key, value) => MapEntry(key, {
              'isOn': value,
              'brightness': _lightBrightness[key] ?? 100,
            })));

    // Log event
    if (_userId != null && _eventLogService != null) {
      _eventLogService!.logLightEvent(
        userId: _userId!,
        isOn: newState,
        location: lightName,
      );
    }

    notifyListeners();
  }

  /// Toggle all lights
  Future<void> toggleAllLights() async {
    final anyOn = _lightStates.values.any((isOn) => isOn);
    final newState = !anyOn;

    for (var lightId in _lightStates.keys) {
      _lightStates[lightId] = newState;
    }

    final command = {
      'action': 'setAll',
      'state': newState ? 'on' : 'off',
    };

    if (_isConnectedToMqtt && !_useCloudMode) {
      _mqttService.publishJson(
          '${MqttConfig.topicPrefix}/lights/command', command);
    }

    _syncToVisualization('lights', {'allOn': newState});

    // Save to Firebase for global sync
    _saveDeviceToFirebase(
        'lights',
        _lightStates.map((key, value) => MapEntry(key, {
              'isOn': value,
              'brightness': _lightBrightness[key] ?? 100,
            })));

    notifyListeners();
  }

  /// Set light brightness
  Future<void> setLightBrightness(String lightId, int brightness) async {
    final clampedBrightness = brightness.clamp(0, 100);
    _lightBrightness[lightId] = clampedBrightness;

    final command = {
      'action': 'setBrightness',
      'brightness': clampedBrightness,
      'lightId': lightId,
    };

    if (_isConnectedToMqtt && !_useCloudMode) {
      final topic = MqttConfig.roomLightCommandTopic(lightId);
      _mqttService.publishJson(topic, command);
    }

    // Save to Firebase for global sync
    _saveDeviceToFirebase(
        'lights',
        _lightStates.map((key, value) => MapEntry(key, {
              'isOn': value,
              'brightness': _lightBrightness[key] ?? 100,
            })));

    notifyListeners();
  }

  /// Set RGB light color
  Future<void> setRgbLightColor(int color) async {
    _rgbLightColor = color & 0xFFFFFF; // Ensure it's 24-bit RGB

    // Extract RGB components
    final r = (color >> 16) & 0xFF;
    final g = (color >> 8) & 0xFF;
    final b = color & 0xFF;

    final command = {
      'action': 'setColor',
      'color': _rgbLightColor,
      'r': r,
      'g': g,
      'b': b,
      'hex':
          '#${_rgbLightColor.toRadixString(16).padLeft(6, '0').toUpperCase()}',
    };

    if (_isConnectedToMqtt && !_useCloudMode) {
      final topic = MqttConfig.roomLightCommandTopic('rgb');
      _mqttService.publishJson(topic, command);
    }

    // Sync RGB to visualization with color and brightness
    _syncToVisualization('rgb', {
      'color': _rgbLightColor,
      'brightness': _rgbBrightness,
      'isOn': _lightStates['rgb'] ?? false,
    });

    // Save to Firebase for global sync
    _saveDeviceToFirebase('rgbColor', {'value': _rgbLightColor});
    _saveDeviceToFirebase('rgbBrightness', {'value': _rgbBrightness});

    notifyListeners();
  }

  /// Set RGB light brightness (0-100)
  Future<void> setRgbBrightness(int brightness) async {
    _rgbBrightness = brightness.clamp(0, 100);

    final command = {
      'action': 'setBrightness',
      'brightness': _rgbBrightness,
      'color': _rgbLightColor,
    };

    if (_isConnectedToMqtt && !_useCloudMode) {
      final topic = MqttConfig.roomLightCommandTopic('rgb');
      _mqttService.publishJson(topic, command);
    }

    // Sync RGB to visualization with brightness
    _syncToVisualization('rgb', {
      'color': _rgbLightColor,
      'brightness': _rgbBrightness,
      'isOn': _lightStates['rgb'] ?? false,
    });

    // Save to Firebase for global sync
    _saveDeviceToFirebase('rgbBrightness', {'value': _rgbBrightness});

    notifyListeners();
  }

  /// Toggle a specific fan (cycles through off -> low -> medium -> high -> off)
  Future<void> toggleFan(String fanId) async {
    final currentSpeed = _fanStates[fanId] ?? 0;
    final newSpeed = (currentSpeed + 1) % 4; // Cycle 0 -> 1 -> 2 -> 3 -> 0
    await setFanSpeed(fanId, newSpeed);
  }

  /// Set fan speed (0=off, 1=low, 2=medium, 3=high)
  Future<void> setFanSpeed(String fanId, int speed) async {
    final clampedSpeed = speed.clamp(0, 3);
    final fanName = _formatWindowName(fanId);
    final speedLabels = ['off', 'low', 'medium', 'high'];

    final command = {
      'action': 'setSpeed',
      'speed': clampedSpeed,
      'speedLabel': speedLabels[clampedSpeed],
      'fanId': fanId,
      'deviceId': 'fan_$fanId',
      'timestamp': DateTime.now().toIso8601String(),
    };

    if (_isConnectedToMqtt && !_useCloudMode) {
      final topic = MqttConfig.roomFanCommandTopic(fanId);
      _mqttService.publishJson(topic, command);
    }

    // Optimistic update
    _fanStates[fanId] = clampedSpeed;
    _visualizationCallback
        ?.call('fan', {'fanId': fanId, 'speed': clampedSpeed});

    // Save to Firebase for global sync
    _saveDeviceToFirebase('fans', Map<String, dynamic>.from(_fanStates));

    // Log event
    if (_userId != null && _eventLogService != null) {
      _eventLogService!.logFanEvent(
        userId: _userId!,
        speed: clampedSpeed,
        location: fanName,
      );
    }

    notifyListeners();
  }

  /// Toggle all fans (turn all off if any is on, otherwise turn all to low)
  Future<void> toggleAllFans() async {
    final anyOn = _fanStates.values.any((speed) => speed > 0);
    final newSpeed = anyOn ? 0 : 1; // All off or all low

    for (var fanId in _fanStates.keys) {
      _fanStates[fanId] = newSpeed;
    }

    final command = {
      'action': 'setAll',
      'speed': newSpeed,
    };

    if (_isConnectedToMqtt && !_useCloudMode) {
      _mqttService.publishJson(
          '${MqttConfig.topicPrefix}/fans/command', command);
    }

    _syncToVisualization('fans', {'allSpeed': newSpeed});

    // Save to Firebase for global sync
    _saveDeviceToFirebase('fans', Map<String, dynamic>.from(_fanStates));

    notifyListeners();
  }

  /// Get current state summary for visualization sync
  Map<String, dynamic> getDeviceStatesSummary() {
    return {
      'door': {'isOpen': _isMainDoorOpen},
      'garage': {'isOpen': _isGarageDoorOpen},
      'buzzer': {'isActive': _isBuzzerActive},
      'windows': _windowStates,
      'lights': _lightStates,
      'fans': _fanStates,
    };
  }

  /// Force sync all states to visualization
  void syncAllToVisualization() {
    _syncToVisualization('door', {'isOpen': _isMainDoorOpen});
    _syncToVisualization('garage', {'isOpen': _isGarageDoorOpen});
    _syncToVisualization('buzzer', {'isActive': _isBuzzerActive});

    for (var entry in _windowStates.entries) {
      _syncToVisualization('window', {
        'windowId': entry.key,
        'isOpen': entry.value,
      });
    }

    for (var entry in _lightStates.entries) {
      _syncToVisualization('light', {
        'lightId': entry.key,
        'isOn': entry.value,
      });
    }

    for (var entry in _fanStates.entries) {
      _syncToVisualization('fan', {
        'fanId': entry.key,
        'speed': entry.value,
      });
    }
  }

  Future<void> acknowledgeAlarm(String alarmId) async {
    final index = _alarms.indexWhere((a) => a.id == alarmId);
    if (index != -1 && _userId != null) {
      await _firestoreService.acknowledgeAlarm(_userId!, alarmId);
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _updateDebounceTimer?.cancel();
    _pendingUpdates.clear();
    _globalStateSubscription?.cancel();
    _mqttService.dispose();
    super.dispose();
  }
}
