import 'package:flutter/material.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'dart:async';
import 'dart:io';
import '../services/mqtt_service.dart';
import '../services/firestore_service.dart';
import '../services/notification_service.dart';
import '../services/event_log_service.dart';
import '../services/sensor_service.dart';
import '../models/device_model.dart';
import '../models/sensor_data_model.dart';
import '../config/mqtt_config.dart';
import 'home_visualization_provider.dart';

/// Callback type for visualization sync
typedef VisualizationSyncCallback = void Function(
    String deviceType, Map<String, dynamic> state);

class DeviceProvider with ChangeNotifier {
  static const Duration _recentConnectionRetention = Duration(minutes: 5);
  static const Duration _recentStateActivityRetention = Duration(minutes: 5);
  static const Duration _disconnectStickyOnlineWindow = Duration(minutes: 20);
  static const Duration _deviceStaleOfflineTimeout = Duration(hours: 1);

  final MqttService _mqttService;
  final FirestoreService _firestoreService;
  final NotificationService _notificationService;
  EventLogService? _eventLogService;
  SensorService? _sensorService;

  List<Device> _devices = [];
  List<AlarmEvent> _alarms = [];
  bool _isConnectedToMqtt = false;
  DateTime? _lastMqttConnectedAt;
  DateTime? _lastMqttDisconnectedAt;
  DateTime? _lastDeviceStateActivityAt;
  bool _hasSeenSuccessfulMqttConnection = false;
  bool _useCloudMode = false;
  String? _userId;

  // Device states for doors, windows, buzzer, lights, fans
  // Doors: main_door, garage_door
  bool _isMainDoorOpen = false;
  bool _isGarageDoorOpen = false;
  bool _isBuzzerActive = false;

  // Windows: front_window, gate
  Map<String, bool> _windowStates = {
    'front_window': false,
    'gate': false,
  };

  // Lights: floor_1, floor_2, rgb (with extra properties)
  Map<String, bool> _lightStates = {
    'floor_1': false,
    'floor_2': false,
    'rgb': false,
  };

  // Light brightness (0-100)
  Map<String, int> _lightBrightness = {
    'floor_1': 100,
    'floor_2': 100,
    'rgb': 100,
  };

  static const Set<String> _supportedLightIds = {
    'floor_1',
    'floor_2',
    'rgb',
  };

  // RGB light color (hex)
  int _rgbLightColor = 0xFFFFFF;

  // RGB light brightness (0-100)
  int _rgbBrightness = 100;

  // Fan states: 0=off, 1=low, 2=medium, 3=high
  Map<String, int> _fanStates = {
    'kitchen': 0,
  };

  // Sensor states (latest readings)
  double _temperature = 0.0;
  double _humidity = 0.0;
  double _gasLevel = 0.0;
  double _lightLevel = 0.0; // LDR sensor
  bool _flameDetected = false;
  bool _rainDetected = false;
  double _voltage = 0.0;
  double _current = 0.0;
  double _energyConsumption = 0.0;
  bool _motionDetected = false;
  double _smokeLevel = 0.0;
  bool _waterDetected = false;
  double _soundLevel = 0.0;
  double _pressure = 0.0;
  double _airQuality = 0.0;

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

  // Sensor data getters
  double get temperature => _temperature;
  double get humidity => _humidity;
  double get gasLevel => _gasLevel;
  double get lightLevel => _lightLevel;
  bool get flameDetected => _flameDetected;
  bool get rainDetected => _rainDetected;
  double get voltage => _voltage;
  double get current => _current;
  double get energyConsumption => _energyConsumption;
  bool get motionDetected => _motionDetected;
  double get smokeLevel => _smokeLevel;
  bool get waterDetected => _waterDetected;
  double get soundLevel => _soundLevel;
  double get pressure => _pressure;
  double get airQuality => _airQuality;

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

  /// Set sensor service (for dependency injection)
  void setSensorService(SensorService service) {
    _sensorService = service;
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
    _lastDeviceStateActivityAt = DateTime.now();
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

        // Legacy model compatibility: side_window was replaced by fan behavior.
        if (windowId == 'side_window') {
          final mappedFanSpeed = isOpen ? 1 : 0;
          if (_fanStates['kitchen'] != mappedFanSpeed) {
            debugPrint(
                '🌀 Firebase: Mapping legacy side_window to kitchen fan speed $mappedFanSpeed');
            _fanStates['kitchen'] = mappedFanSpeed;
            _syncToVisualization(
                'fan', {'fanId': 'kitchen', 'speed': mappedFanSpeed});
            hasChanges = true;
          }
          return;
        }

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
        _syncToVisualization(
            'windows', Map<String, dynamic>.from(_windowStates));
      }
    }

    // Sync light states
    if (states['lights'] != null) {
      final lightStates = states['lights'] as Map<String, dynamic>;
      lightStates.forEach((lightId, value) {
        if (!_supportedLightIds.contains(lightId)) {
          debugPrint('⚠️ Ignoring unsupported light in sync: $lightId');
          return;
        }
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
        debugPrint(
            '🌈 Firebase: RGB color changed to 0x${color.toRadixString(16)}');
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
      _applyConnectivityStatusToDevices();
      notifyListeners();
    }
  }

  void _applyConnectivityStatusToDevices() {
    if (_devices.isEmpty) return;

    final now = DateTime.now();
    final hasRecentMqtt = _lastMqttConnectedAt != null &&
        now.difference(_lastMqttConnectedAt!) < _recentConnectionRetention;
    final hasRecentStateActivity = _lastDeviceStateActivityAt != null &&
        now.difference(_lastDeviceStateActivityAt!) <
            _recentStateActivityRetention;
    final inReconnectGrace = _hasSeenSuccessfulMqttConnection &&
        _lastMqttDisconnectedAt != null &&
        now.difference(_lastMqttDisconnectedAt!) <
            _disconnectStickyOnlineWindow;

    final shouldTreatAsOnline = _isConnectedToMqtt ||
        hasRecentMqtt ||
        hasRecentStateActivity ||
        inReconnectGrace;

    _devices = _devices.map((device) {
      if (shouldTreatAsOnline) {
        if (device.status == DeviceStatus.online) {
          return device;
        }
        return device.copyWith(
          status: DeviceStatus.online,
          lastUpdated: now,
        );
      }

      final recentlySeen =
          now.difference(device.lastUpdated) < _deviceStaleOfflineTimeout;
      if (recentlySeen) {
        return device;
      }

      if (device.status == DeviceStatus.offline) {
        return device;
      }

      return device.copyWith(status: DeviceStatus.offline);
    }).toList();
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
      final now = DateTime.now();
      _isConnectedToMqtt = status == ConnectionStatus.connected;
      if (_isConnectedToMqtt) {
        _hasSeenSuccessfulMqttConnection = true;
        _lastMqttConnectedAt = now;
        _lastMqttDisconnectedAt = null;
      } else if (status == ConnectionStatus.disconnected ||
          status == ConnectionStatus.error) {
        // Keep reconnect grace alive while retries are in progress.
        _lastMqttDisconnectedAt = now;
      }
      _applyConnectivityStatusToDevices();
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
      _applyConnectivityStatusToDevices();
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

  /// Connect to MQTT broker with proper error handling
  Future<void> connectToMqtt() async {
    try {
      debugPrint('🔗 DeviceProvider: Connecting to MQTT broker...');
      debugPrint(
          '📍 Broker: ${MqttConfig.localBrokerAddress}:${MqttConfig.localBrokerPort}');

      final originalBrokerAddress = MqttConfig.localBrokerAddress;
      if (originalBrokerAddress.trim().isEmpty) {
        debugPrint(
            '❌ DeviceProvider: No beacon broker configured, skipping MQTT connect');
        return;
      }

      // Fast path: try the currently configured broker first with no probe delay.
      final primarySuccess = await _mqttService.connect(
        brokerAddress: originalBrokerAddress,
        port: MqttConfig.localBrokerPort,
        useCloud: _useCloudMode,
        scheduleReconnectOnFailure: false,
      );

      if (primarySuccess) {
        debugPrint(
            '✅ DeviceProvider: MQTT connected quickly on primary broker $originalBrokerAddress');
        _subscribeToTopics();
        return;
      }

      // Give the backend a brief warm-up window in case MQTT service was just
      // restarted, then retry primary once before scanning fallbacks.
      final primaryReachable = await _isBrokerReachable(
        originalBrokerAddress,
        MqttConfig.localBrokerPort,
      );
      if (primaryReachable) {
        debugPrint(
            '⏳ DeviceProvider: Primary broker reachable, retrying after warm-up delay...');
        await Future.delayed(const Duration(milliseconds: 1200));
        final warmupRetrySuccess = await _mqttService.connect(
          brokerAddress: originalBrokerAddress,
          port: MqttConfig.localBrokerPort,
          useCloud: _useCloudMode,
          scheduleReconnectOnFailure: false,
        );
        if (warmupRetrySuccess) {
          debugPrint(
              '✅ DeviceProvider: MQTT connected on warm-up retry $originalBrokerAddress');
          _subscribeToTopics();
          return;
        }
      }

      // Beacon-only policy: retry only the resolved beacon broker.
      unawaited(_mqttService.connect(
        brokerAddress: originalBrokerAddress,
        port: MqttConfig.localBrokerPort,
        useCloud: _useCloudMode,
        scheduleReconnectOnFailure: true,
      ));
      debugPrint(
          '❌ DeviceProvider: MQTT connection failed (retry broker: $originalBrokerAddress)');
    } catch (e) {
      debugPrint('❌ DeviceProvider: MQTT connection error: $e');
    }
  }

  Future<bool> _isBrokerReachable(String host, int port) async {
    try {
      final socket = await Socket.connect(
        host,
        port,
        timeout: const Duration(milliseconds: 700),
      );
      socket.destroy();
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Subscribe to all relevant MQTT topics
  void _subscribeToTopics() {
    debugPrint('📬 DeviceProvider: Subscribing to MQTT topics...');

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

    // Subscribe to sensor topics
    _mqttService.subscribe(MqttConfig.allSensorsTopic);
    _mqttService.subscribe(MqttConfig.temperatureTopic);
    _mqttService.subscribe(MqttConfig.humidityTopic);
    _mqttService.subscribe(MqttConfig.gasTopic);
    _mqttService.subscribe(MqttConfig.ldrTopic);
    _mqttService.subscribe(MqttConfig.flameTopic);
    _mqttService.subscribe(MqttConfig.rainTopic);
    _mqttService.subscribe(MqttConfig.voltageTopic);
    _mqttService.subscribe(MqttConfig.currentTopic);

    // Subscribe to backend actuator command topics (n8n -> app sync)
    _mqttService.subscribe('${MqttConfig.topicPrefix}/actuators/#');
    _mqttService.subscribe(MqttConfig.fanCommandTopic);
    _mqttService.subscribe(MqttConfig.lightFloor1Topic);
    _mqttService.subscribe(MqttConfig.lightFloor2Topic);
    _mqttService.subscribe(MqttConfig.lightRgbTopic);
    _mqttService.subscribe(MqttConfig.buzzerCommandTopic);
    _mqttService.subscribe(MqttConfig.garageMotorTopic);
    _mqttService.subscribe(MqttConfig.frontWindowMotorTopic);
    _mqttService.subscribe(MqttConfig.doorMotorTopic);
    _mqttService.subscribe(MqttConfig.gateMotorTopic);

    // Subscribe to n8n agent response topics
    _mqttService.subscribe(MqttConfig.agentResponseTopic);
    _mqttService.subscribe(MqttConfig.agentStatusTopic);

    // Subscribe to n8n door status
    _mqttService.subscribe(MqttConfig.n8nDoorStatusTopic);

    // Subscribe to device status topics
    for (var device in _devices) {
      _mqttService.subscribe(MqttConfig.deviceStatusTopic(device.id));
    }

    debugPrint(
        '✅ DeviceProvider: Subscribed to ${_mqttService.getConnectionInfo()['subscribedTopics']?.length ?? 0} topics');
  }

  void _handleMqttMessage(AppMqttMessage message) {
    final now = DateTime.now();
    _hasSeenSuccessfulMqttConnection = true;
    _lastMqttConnectedAt = now;
    _lastMqttDisconnectedAt = null;
    _lastDeviceStateActivityAt = now;
    _applyConnectivityStatusToDevices();

    final payload = message.jsonPayload;
    final rawPayload = message.payload.trim().toLowerCase();

    // Check for face detection events (Version 2)
    if (message.topic == MqttConfig.faceUnrecognizedTopic) {
      if (payload == null) return;
      _handleUnrecognizedFace(payload);
      return;
    } else if (message.topic == MqttConfig.faceRecognizedTopic) {
      if (payload == null) return;
      _handleRecognizedFace(payload);
      return;
    }

    // Handle sensor data
    if (message.topic.contains('/sensors/')) {
      _handleSensorData(message.topic, message.payload, payload: payload);
      return;
    }

    // Handle actuator command topics (backend-origin updates)
    if (message.topic.contains('/actuators/')) {
      _handleActuatorTopicMessage(message.topic, rawPayload, payload: payload);
      return;
    }

    // Handle door, window, garage, buzzer, light, fan status
    if (message.topic.contains('/door/status')) {
      _handleDoorStatus(_normalizeStatePayload(message.payload, payload));
      return;
    } else if (message.topic.contains('/window/status')) {
      _handleWindowStatus(
          message.topic, _normalizeStatePayload(message.payload, payload));
      return;
    } else if (message.topic.contains('/garage/status')) {
      _handleGarageStatus(_normalizeStatePayload(message.payload, payload));
      return;
    } else if (message.topic.contains('/buzzer/status')) {
      _handleBuzzerStatus(_normalizeStatePayload(message.payload, payload));
      return;
    } else if (message.topic.contains('/light/status')) {
      _handleLightStatus(
          message.topic, _normalizeStatePayload(message.payload, payload));
      return;
    } else if (message.topic.contains('/fan/status')) {
      _handleFanStatus(
          message.topic, _normalizeStatePayload(message.payload, payload));
      return;
    }

    // Check if it's an alarm
    if (message.topic.contains('alarm')) {
      if (payload == null) return;
      _handleAlarm(message.topic, payload);
    } else {
      _handleDeviceUpdate(
        message.topic,
        payload ?? {'value': message.payload, 'state': message.payload},
      );
    }
  }

  void _handleActuatorTopicMessage(
    String topic,
    String rawPayload, {
    Map<String, dynamic>? payload,
  }) {
    bool changed = false;
    final command = _extractActuatorCommand(rawPayload, payload);
    final normalizedTopic = topic.toLowerCase();

    if (_isFanTopic(normalizedTopic)) {
      int speed;
      switch (command) {
        case 'in':
          speed = 1;
          break;
        case 'out':
          speed = 2;
          break;
        case 'on':
          speed = 1;
          break;
        default:
          speed = 0;
      }
      if (_fanStates['kitchen'] != speed) {
        _fanStates['kitchen'] = speed;
        _syncToVisualization('fan', {'fanId': 'kitchen', 'speed': speed});
        if (_userId != null && _eventLogService != null) {
          _eventLogService!.logFanEvent(
            userId: _userId!,
            speed: speed,
            location: 'Kitchen',
          );
        }
        changed = true;
      }
    } else if (_isFloor1LightTopic(normalizedTopic)) {
      final isOn = command == 'on';
      if (_lightStates['floor_1'] != isOn) {
        _lightStates['floor_1'] = isOn;
        _syncToVisualization('light', {'lightId': 'floor_1', 'isOn': isOn});
        if (_userId != null && _eventLogService != null) {
          _eventLogService!.logLightEvent(
            userId: _userId!,
            isOn: isOn,
            location: 'Floor 1',
            brightness: _lightBrightness['floor_1'],
          );
        }
        changed = true;
      }
    } else if (_isFloor2LightTopic(normalizedTopic)) {
      final isOn = command == 'on';
      if (_lightStates['floor_2'] != isOn) {
        _lightStates['floor_2'] = isOn;
        _syncToVisualization('light', {'lightId': 'floor_2', 'isOn': isOn});
        if (_userId != null && _eventLogService != null) {
          _eventLogService!.logLightEvent(
            userId: _userId!,
            isOn: isOn,
            location: 'Floor 2',
            brightness: _lightBrightness['floor_2'],
          );
        }
        changed = true;
      }
    } else if (_isRgbLightTopic(normalizedTopic)) {
      if (command == 'off') {
        if (_lightStates['rgb'] != false) {
          _lightStates['rgb'] = false;
          changed = true;
        }
      } else if (command.startsWith('b ')) {
        final brightness = int.tryParse(command.substring(2).trim());
        if (brightness != null) {
          final clamped = brightness.clamp(0, 100);
          if (_rgbBrightness != clamped) {
            _rgbBrightness = clamped;
            _lightBrightness['rgb'] = clamped;
            _lightStates['rgb'] = clamped > 0;
            changed = true;
          }
        }
      } else if (command.startsWith('c ')) {
        final colorText = command.substring(2).trim().replaceFirst('#', '');
        final parsedColor = int.tryParse(colorText, radix: 16);
        if (parsedColor != null) {
          _rgbLightColor = parsedColor & 0xFFFFFF;
          // Color updates should not force ON state. ON/OFF is brightness-based.
          _lightStates['rgb'] = _rgbBrightness > 0;
          changed = true;
        }
      }

      if (changed) {
        _syncToVisualization('rgb', {
          'color': _rgbLightColor,
          'brightness': _rgbBrightness,
          'isOn': _lightStates['rgb'] ?? false,
        });
      }
    } else if (_isBuzzerTopic(normalizedTopic)) {
      final isActive = command == 'on';
      if (_isBuzzerActive != isActive) {
        _isBuzzerActive = isActive;
        _syncToVisualization('buzzer', {'isActive': isActive});
        if (_userId != null && _eventLogService != null) {
          _eventLogService!.logBuzzerEvent(
            userId: _userId!,
            isActive: isActive,
            reason: 'MQTT actuator update',
          );
        }
        changed = true;
      }
    } else if (_isGarageTopic(normalizedTopic)) {
      final isOpen = command == 'open';
      if (_isGarageDoorOpen != isOpen) {
        _isGarageDoorOpen = isOpen;
        _syncToVisualization('garage', {'isOpen': isOpen});
        if (_userId != null && _eventLogService != null) {
          _eventLogService!.logGarageEvent(
            userId: _userId!,
            isOpen: isOpen,
          );
        }
        changed = true;
      }
    } else if (_isFrontWindowTopic(normalizedTopic)) {
      final isOpen = command == 'open';
      if (_windowStates['front_window'] != isOpen) {
        _windowStates['front_window'] = isOpen;
        _syncToVisualization(
            'window', {'windowId': 'front_window', 'isOpen': isOpen});
        if (_userId != null && _eventLogService != null) {
          _eventLogService!.logWindowEvent(
            userId: _userId!,
            isOpen: isOpen,
            location: 'Front Window',
          );
        }
        changed = true;
      }
    } else if (_isDoorTopic(normalizedTopic)) {
      final isOpen = command == 'open';
      if (_isMainDoorOpen != isOpen) {
        _isMainDoorOpen = isOpen;
        _syncToVisualization('door', {'isOpen': isOpen});
        if (_userId != null && _eventLogService != null) {
          _eventLogService!.logDoorEvent(
            userId: _userId!,
            isOpen: isOpen,
            location: 'Main Door',
            triggeredBy: 'MQTT actuator update',
          );
        }
        changed = true;
      }
    } else if (_isGateTopic(normalizedTopic)) {
      final isOpen = command == 'open';
      if (_windowStates['gate'] != isOpen) {
        _windowStates['gate'] = isOpen;
        _syncToVisualization('window', {'windowId': 'gate', 'isOpen': isOpen});
        if (_userId != null && _eventLogService != null) {
          _eventLogService!.logWindowEvent(
            userId: _userId!,
            isOpen: isOpen,
            location: 'Gate',
          );
        }
        changed = true;
      }
    } else {
      debugPrint('⚠️ Unhandled actuator topic: $topic (command: $command)');
    }

    if (changed) {
      notifyListeners();
    }
  }

  String _extractActuatorCommand(
    String rawPayload,
    Map<String, dynamic>? payload,
  ) {
    if (payload != null) {
      final commandValue = payload['command'] ??
          payload['action'] ??
          payload['state'] ??
          payload['value'];
      if (commandValue is String) {
        return commandValue.trim().toLowerCase();
      }
      if (commandValue is num) {
        return commandValue.toString();
      }
    }

    return rawPayload.trim().toLowerCase();
  }

  bool _isFanTopic(String topic) => topic.endsWith('/actuators/fan');
  bool _isFloor1LightTopic(String topic) =>
      topic.endsWith('/actuators/lights/floor1') ||
      topic.endsWith('/actuators/lights/floor_1');
  bool _isFloor2LightTopic(String topic) =>
      topic.endsWith('/actuators/lights/floor2') ||
      topic.endsWith('/actuators/lights/floor_2');
  bool _isRgbLightTopic(String topic) =>
      topic.endsWith('/actuators/lights/rgb');
  bool _isBuzzerTopic(String topic) => topic.endsWith('/actuators/buzzer');
  bool _isGarageTopic(String topic) =>
      topic.endsWith('/actuators/motors/garage');
  bool _isFrontWindowTopic(String topic) =>
      topic.endsWith('/actuators/motors/frontwindow');
  bool _isDoorTopic(String topic) => topic.endsWith('/actuators/motors/door');
  bool _isGateTopic(String topic) => topic.endsWith('/actuators/motors/gate');

  Map<String, dynamic> _normalizeStatePayload(
    String rawPayload,
    Map<String, dynamic>? parsedPayload,
  ) {
    if (parsedPayload != null) {
      return parsedPayload;
    }

    final state = rawPayload.trim().toLowerCase();
    return {
      'state': state,
      'active': state == 'on' || state == 'active' || state == '1',
      'speed': state == 'in'
          ? 1
          : state == 'out'
              ? 2
              : 0,
      'value': rawPayload.trim(),
    };
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
    final isActive = payload['active'] == true || payload['state'] == 'on';
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
    if (!_supportedLightIds.contains(lightId)) {
      debugPrint('⚠️ Ignoring unsupported light status topic id: $lightId');
      return;
    }
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

  /// Handle sensor data from MQTT
  void _handleSensorData(
    String topic,
    String rawPayload, {
    Map<String, dynamic>? payload,
  }) {
    debugPrint('📊 Sensor data received on $topic: $payload');

    // Extract sensor type from topic: */sensors/{type}
    final parts = topic.split('/');
    final sensorsIndex =
        parts.indexWhere((part) => part.toLowerCase() == 'sensors');
    final sensorType = (sensorsIndex >= 0 && sensorsIndex + 1 < parts.length)
        ? parts[sensorsIndex + 1].toLowerCase()
        : (parts.length > 2 ? parts[2].toLowerCase() : '');

    // Extract value from payload
    final value = _extractSensorValue(
      rawPayload,
      payload,
      sensorType: sensorType,
    );

    // Store sensor data using sensor service if available
    SensorType? type;

    // Update sensor state based on type
    switch (sensorType) {
      case 'temperature':
      case 'temp':
        _temperature = value;
        type = SensorType.temperature;
        debugPrint('🌡️ Temperature: ${value}°C');
        break;
      case 'humidity':
        _humidity = value;
        type = SensorType.humidity;
        debugPrint('💧 Humidity: $value%');
        break;
      case 'gas':
      case 'mq135':
      case 'mq2':
      case 'mq-2':
      case 'mq_2':
      case 'co2':
      case 'co':
      case 'lpg':
      case 'gaslevel':
      case 'gas_level':
        _gasLevel = value;
        type = SensorType.gas;
        debugPrint('☣️ Gas: ${value}ppm');
        // Check if gas level is dangerous
        if (value > 300.0 && _userId != null) {
          _createGasAlarm(value);
        }
        break;
      case 'ldr':
      case 'light':
        _lightLevel = value;
        type = SensorType.ldr;
        debugPrint('☀️ Light Level: ${value}lux');
        break;
      case 'flame':
        _flameDetected = value > 0;
        type = SensorType.motion;
        debugPrint('🔥 Flame: ${_flameDetected ? "DETECTED" : "Clear"}');
        break;
      case 'rain':
        _rainDetected = value > 0;
        type = SensorType.water;
        debugPrint('🌧️ Rain: ${_rainDetected ? "DETECTED" : "Dry"}');
        break;
      case 'voltage':
        _voltage = value;
        _energyConsumption = _voltage * _current;
        type = SensorType.energy;
        debugPrint('🔌 Voltage: ${value}V');
        break;
      case 'current':
        _current = value;
        _energyConsumption = _voltage * _current;
        type = SensorType.energy;
        debugPrint('⚡ Current: ${value}A');
        break;
      case 'energy':
      case 'power':
        _energyConsumption = value;
        type = SensorType.energy;
        debugPrint('⚡ Energy: ${value}kWh');
        break;
      case 'motion':
        _motionDetected = value > 0;
        type = SensorType.motion;
        debugPrint('🏃 Motion: ${_motionDetected ? "DETECTED" : "Clear"}');
        break;
      case 'smoke':
        _smokeLevel = value;
        type = SensorType.smoke;
        debugPrint('🔥 Smoke: ${value}ppm');
        if (value > 100.0 && _userId != null) {
          _createSmokeAlarm(value);
        }
        break;
      case 'water':
        _waterDetected = value > 0;
        type = SensorType.water;
        debugPrint('💦 Water: ${_waterDetected ? "DETECTED" : "Dry"}');
        if (_waterDetected && _userId != null) {
          _createWaterAlarm();
        }
        break;
      case 'sound':
        _soundLevel = value;
        type = SensorType.sound;
        debugPrint('🔊 Sound: ${value}dB');
        break;
      case 'pressure':
        _pressure = value;
        type = SensorType.pressure;
        debugPrint('🌡️ Pressure: ${value}hPa');
        break;
      case 'air_quality':
      case 'airquality':
        _airQuality = value;
        type = SensorType.airQuality;
        debugPrint('🌬️ Air Quality: $value AQI');
        break;
      default:
        debugPrint('⚠️ Unknown sensor type: $sensorType');
    }

    // Store sensor data in service for history and analytics
    if (type != null && _sensorService != null) {
      _sensorService!.processSensorReading(
        sensorId: sensorType,
        type: type,
        value: value,
        metadata: {
          'topic': topic,
          'raw_payload': rawPayload,
          'json_payload': payload,
        },
      );
    }

    notifyListeners();
  }

  double _extractSensorValue(String rawPayload, Map<String, dynamic>? payload,
      {String? sensorType}) {
    final sensorKey = (sensorType ?? '').toLowerCase();

    if (payload != null) {
      final candidateKeys = <String>[
        'value',
        if (sensorKey == 'temperature' || sensorKey == 'temp') ...[
          'temperature',
          'temp',
          'celsius',
        ],
        if (sensorKey == 'humidity') ...['humidity', 'rh'],
        if (sensorKey == 'gas' ||
            sensorKey.startsWith('mq') ||
            sensorKey == 'co2') ...[
          'gas',
          'ppm',
          'mq2',
          'mq-2',
          'mq135',
          'co2',
          'co',
          'lpg',
          'gas_level',
        ],
        if (sensorKey == 'ldr' || sensorKey == 'light') ...[
          'ldr',
          'light',
          'lux'
        ],
        if (sensorKey == 'voltage') ...['voltage', 'v'],
        if (sensorKey == 'current') ...['current', 'a'],
        if (sensorKey == 'flame') ...['flame', 'detected'],
        if (sensorKey == 'rain') ...['rain', 'detected'],
        'reading',
        'data',
      ];

      for (final key in candidateKeys) {
        if (!payload.containsKey(key)) continue;
        final parsed = _toDouble(payload[key]);
        if (parsed != null) {
          return parsed;
        }
      }

      final nestedData = payload['data'];
      if (nestedData is Map<String, dynamic>) {
        for (final key in candidateKeys) {
          if (!nestedData.containsKey(key)) continue;
          final parsed = _toDouble(nestedData[key]);
          if (parsed != null) {
            return parsed;
          }
        }
      }
    }

    final normalized = rawPayload.trim();
    return double.tryParse(normalized) ?? 0.0;
  }

  double? _toDouble(dynamic raw) {
    if (raw is num) {
      return raw.toDouble();
    }
    if (raw is String) {
      return double.tryParse(raw.trim());
    }
    if (raw is bool) {
      return raw ? 1.0 : 0.0;
    }
    return null;
  }

  /// Create gas alarm when dangerous levels detected
  void _createGasAlarm(double level) {
    final alarm = AlarmEvent(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      location: 'home',
      type: 'gas_leak',
      severity: 'critical',
      message: 'Dangerous gas level detected: ${level.toStringAsFixed(1)} ppm',
      timestamp: DateTime.now(),
    );
    _alarms.insert(0, alarm);
    if (_userId != null) {
      _firestoreService.addAlarmEvent(_userId!, alarm);
    }
    _notificationService.addNotification(
      title: '⚠️ GAS LEAK ALERT',
      message: 'Dangerous gas level: ${level.toStringAsFixed(1)} ppm',
      type: NotificationType.security,
    );
  }

  /// Create smoke alarm
  void _createSmokeAlarm(double level) {
    final alarm = AlarmEvent(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      location: 'home',
      type: 'smoke_detected',
      severity: 'critical',
      message: 'Smoke detected: ${level.toStringAsFixed(1)} ppm',
      timestamp: DateTime.now(),
    );
    _alarms.insert(0, alarm);
    if (_userId != null) {
      _firestoreService.addAlarmEvent(_userId!, alarm);
    }
    _notificationService.addNotification(
      title: '🔥 SMOKE ALERT',
      message: 'Smoke detected: ${level.toStringAsFixed(1)} ppm',
      type: NotificationType.security,
    );
  }

  /// Create water alarm
  void _createWaterAlarm() {
    final alarm = AlarmEvent(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      location: 'home',
      type: 'water_leak',
      severity: 'high',
      message: 'Water leak detected!',
      timestamp: DateTime.now(),
    );
    _alarms.insert(0, alarm);
    if (_userId != null) {
      _firestoreService.addAlarmEvent(_userId!, alarm);
    }
    _notificationService.addNotification(
      title: '💦 WATER LEAK ALERT',
      message: 'Water detected in sensor area',
      type: NotificationType.security,
    );
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
      _lastDeviceStateActivityAt = DateTime.now();
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
    // ESP32 expects simple string: "open" or "close"
    final message = newState ? 'open' : 'close';

    if (_isConnectedToMqtt && !_useCloudMode) {
      // Publish simple string to ESP32 actuator topic
      _mqttService.publish(MqttConfig.doorMotorTopic, message);
      debugPrint('🚪 MQTT: Door command sent - $message');
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
    if (_isMainDoorOpen == isOpen) {
      debugPrint(
          '🚪 MQTT: Door already in target state (${isOpen ? 'open' : 'close'}), skipping command');
      return;
    }

    // ESP32 expects simple string: "open" or "close"
    final message = isOpen ? 'open' : 'close';

    if (_isConnectedToMqtt && !_useCloudMode) {
      _mqttService.publish(MqttConfig.doorMotorTopic, message);
      debugPrint('🚪 MQTT: Door state set - $message');
    }

    _isMainDoorOpen = isOpen;
    _syncToVisualization('door', {'isOpen': isOpen});

    if (_userId != null && _eventLogService != null) {
      _eventLogService!.logDoorEvent(
        userId: _userId!,
        isOpen: isOpen,
        location: 'Main Door',
        triggeredBy: 'App User',
      );
    }

    // Save to Firebase for global sync
    _saveDeviceToFirebase('door', {'isOpen': isOpen});

    notifyListeners();
  }

  /// Toggle garage open/closed
  Future<void> toggleGarage() async {
    final newState = !_isGarageDoorOpen;
    // ESP32 expects simple string: "open" or "close"
    final message = newState ? 'open' : 'close';

    if (_isConnectedToMqtt && !_useCloudMode) {
      _mqttService.publish(MqttConfig.garageMotorTopic, message);
      debugPrint('🚗 MQTT: Garage command sent - $message');
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
    if (_isGarageDoorOpen == isOpen) {
      debugPrint(
          '🚗 MQTT: Garage already in target state (${isOpen ? 'open' : 'close'}), skipping command');
      return;
    }

    // ESP32 expects simple string: "open" or "close"
    final message = isOpen ? 'open' : 'close';

    if (_isConnectedToMqtt && !_useCloudMode) {
      _mqttService.publish(MqttConfig.garageMotorTopic, message);
      debugPrint('🚗 MQTT: Garage state set - $message');
    }

    _isGarageDoorOpen = isOpen;
    _syncToVisualization('garage', {'isOpen': isOpen});

    if (_userId != null && _eventLogService != null) {
      _eventLogService!.logGarageEvent(
        userId: _userId!,
        isOpen: isOpen,
      );
    }

    // Save to Firebase for global sync
    _saveDeviceToFirebase('garage', {'isOpen': isOpen});

    notifyListeners();
  }

  /// Toggle window open/closed
  Future<void> toggleWindow(String windowId) async {
    final isOpen = _windowStates[windowId] ?? false;
    final newState = !isOpen;
    final windowName = _formatWindowName(windowId);
    // ESP32 expects simple string: "open" or "close"
    final message = newState ? 'open' : 'close';

    if (_isConnectedToMqtt && !_useCloudMode) {
      // Get the correct topic for this window
      final topic = MqttConfig.windowCommandTopic(windowId);
      _mqttService.publish(topic, message);
      debugPrint('🪟 MQTT: Window command sent - $windowId $message');
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
    // ESP32 expects simple string: "open" or "close"
    final message = newState ? 'open' : 'close';

    for (var windowId in _windowStates.keys) {
      _windowStates[windowId] = newState;
    }

    if (_isConnectedToMqtt && !_useCloudMode) {
      // Send to each window individually
      _mqttService.publish(MqttConfig.frontWindowMotorTopic, message);
      _mqttService.publish(MqttConfig.gateMotorTopic, message);
    }

    _syncToVisualization('windows', {'allOpen': newState});

    // Save to Firebase for global sync
    _saveDeviceToFirebase('windows', Map<String, dynamic>.from(_windowStates));

    notifyListeners();
  }

  /// Toggle buzzer on/off
  Future<void> toggleBuzzer() async {
    final newState = !_isBuzzerActive;
    // ESP32 expects simple string: "on" or "off"
    final message = newState ? 'on' : 'off';

    if (_isConnectedToMqtt && !_useCloudMode) {
      _mqttService.publish(MqttConfig.buzzerCommandTopic, message);
      debugPrint('🔔 MQTT: Buzzer command sent - $message');
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
    // ESP32 expects simple string: "on" or "off"
    final message = isActive ? 'on' : 'off';

    if (_isConnectedToMqtt && !_useCloudMode) {
      _mqttService.publish(MqttConfig.buzzerCommandTopic, message);
    }

    _isBuzzerActive = isActive;
    _syncToVisualization('buzzer', {'isActive': isActive});

    if (_userId != null && _eventLogService != null) {
      _eventLogService!.logBuzzerEvent(
        userId: _userId!,
        isActive: isActive,
        reason: reason ?? 'App User',
      );
    }

    // Save to Firebase for global sync
    _saveDeviceToFirebase('buzzer', {'isActive': isActive});

    notifyListeners();
  }

  /// Toggle a specific light
  Future<void> toggleLightById(String lightId) async {
    if (!_supportedLightIds.contains(lightId)) {
      debugPrint('⚠️ Ignoring toggle for unsupported light id: $lightId');
      return;
    }
    final isOn = _lightStates[lightId] ?? false;
    final newState = !isOn;
    final lightName = _formatWindowName(lightId); // Reuse name formatter
    // RGB must use brightness payloads only. Other lights use on/off.
    final message = lightId == 'rgb' ? null : (newState ? 'on' : 'off');
    final int rgbPublishBrightness = newState
        ? ((_rgbBrightness > 0 ? _rgbBrightness : 100).clamp(1, 100))
        : 0;

    if (_isConnectedToMqtt && !_useCloudMode) {
      final topic = MqttConfig.lightCommandTopic(lightId);
      if (lightId == 'rgb') {
        _mqttService.publish(topic, 'b $rgbPublishBrightness');
        debugPrint(
            '🌈 MQTT: RGB brightness command sent - b $rgbPublishBrightness');
      } else {
        _mqttService.publish(topic, message!);
        debugPrint('💡 MQTT: Light command sent - $lightId $message');
      }
    }

    // Optimistic update
    _lightStates[lightId] = newState;
    if (lightId == 'rgb') {
      _rgbBrightness = rgbPublishBrightness;
      _lightBrightness['rgb'] = rgbPublishBrightness;
      _syncToVisualization('rgb', {
        'color': _rgbLightColor,
        'brightness': _rgbBrightness,
        'isOn': _lightStates['rgb'] ?? false,
      });
    }
    _visualizationCallback
        ?.call('light', {'lightId': lightId, 'isOn': newState});

    // Save to Firebase for global sync
    _saveDeviceToFirebase(
        'lights',
        _lightStates.map((key, value) => MapEntry(key, {
              'isOn': value,
              'brightness': _lightBrightness[key] ?? 100,
            })));
    if (lightId == 'rgb') {
      _saveDeviceToFirebase('rgbBrightness', {'value': _rgbBrightness});
    }

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
    // ESP32 expects simple string: "on" or "off"
    final message = newState ? 'on' : 'off';

    for (var lightId in _lightStates.keys) {
      _lightStates[lightId] = newState;
    }

    if (_isConnectedToMqtt && !_useCloudMode) {
      // Send to each light individually
      _mqttService.publish(MqttConfig.lightFloor1Topic, message);
      _mqttService.publish(MqttConfig.lightFloor2Topic, message);
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

  /// Set light brightness (only works for RGB light)
  Future<void> setLightBrightness(String lightId, int brightness) async {
    final clampedBrightness = brightness.clamp(0, 100);
    _lightBrightness[lightId] = clampedBrightness;

    // Only RGB light supports brightness: "b <brightness>"
    if (lightId == 'rgb' && _isConnectedToMqtt && !_useCloudMode) {
      _mqttService.publish(MqttConfig.lightRgbTopic, 'b $clampedBrightness');
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
    _lightStates['rgb'] = _rgbBrightness > 0;
    _lightBrightness['rgb'] = _rgbBrightness;

    // ESP32 expects: "c <color_string>" (hex format)
    final colorHex = _rgbLightColor.toRadixString(16).padLeft(6, '0');

    if (_isConnectedToMqtt && !_useCloudMode) {
      _mqttService.publish(
          MqttConfig.lightRgbTopic, 'c #${colorHex.toUpperCase()}');
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
    _lightBrightness['rgb'] = _rgbBrightness;
    _lightStates['rgb'] = _rgbBrightness > 0;

    // ESP32 expects: "b <brightness>"
    if (_isConnectedToMqtt && !_useCloudMode) {
      _mqttService.publish(MqttConfig.lightRgbTopic, 'b $_rgbBrightness');
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

  /// Toggle fan (cycles through off -> in -> out -> off)
  Future<void> toggleFan(String fanId) async {
    final currentSpeed = _fanStates[fanId] ?? 0;
    // Cycle: 0 (off) -> 1 (in) -> 2 (out) -> 0 (off)
    final newSpeed = (currentSpeed + 1) % 3;
    await setFanSpeed(fanId, newSpeed);
  }

  /// Set fan speed/mode (0=off, 1=in, 2=out)
  /// ESP32 expects: "off" / "in" / "out" / "on"
  Future<void> setFanSpeed(String fanId, int speed) async {
    final clampedSpeed = speed.clamp(0, 2);
    final fanName = _formatWindowName(fanId);
    // ESP32 fan modes: off, in, out
    final speedLabels = ['off', 'in', 'out'];
    final message = speedLabels[clampedSpeed];

    if (_isConnectedToMqtt && !_useCloudMode) {
      _mqttService.publish(MqttConfig.fanCommandTopic, message);
      debugPrint('🌀 MQTT: Fan command sent - $message');
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

  /// Toggle all fans (turn all off if any is on, otherwise turn to "in")
  Future<void> toggleAllFans() async {
    final anyOn = _fanStates.values.any((speed) => speed > 0);
    final newSpeed = anyOn ? 0 : 1; // All off or all "in"
    // ESP32 expects: "off" / "in" / "out"
    final message = newSpeed == 0 ? 'off' : 'in';

    for (var fanId in _fanStates.keys) {
      _fanStates[fanId] = newSpeed;
    }

    if (_isConnectedToMqtt && !_useCloudMode) {
      _mqttService.publish(MqttConfig.fanCommandTopic, message);
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
