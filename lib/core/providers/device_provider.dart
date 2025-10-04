import 'package:flutter/material.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../services/mqtt_service.dart';
import '../services/firestore_service.dart';
import '../models/device_model.dart';
import '../config/mqtt_config.dart';

class DeviceProvider with ChangeNotifier {
  final MqttService _mqttService;
  final FirestoreService _firestoreService;

  List<Device> _devices = [];
  List<AlarmEvent> _alarms = [];
  bool _isConnectedToMqtt = false;
  bool _useCloudMode = false;
  String? _userId;

  DeviceProvider({
    required MqttService mqttService,
    required FirestoreService firestoreService,
  })  : _mqttService = mqttService,
        _firestoreService = firestoreService {
    _init();
  }

  List<Device> get devices => _devices;
  List<AlarmEvent> get alarms => _alarms;
  List<AlarmEvent> get activeAlarms =>
      _alarms.where((a) => !a.acknowledged).toList();
  bool get isConnectedToMqtt => _isConnectedToMqtt;
  bool get useCloudMode => _useCloudMode;

  void _init() {
    // Listen to MQTT connection status
    _mqttService.statusStream.listen((status) {
      _isConnectedToMqtt = status == ConnectionStatus.connected;
      notifyListeners();
    });

    // Listen to MQTT messages
    _mqttService.messageStream.listen(_handleMqttMessage);

    // Check connectivity and decide on local vs cloud
    _checkConnectivity();
  }

  Future<void> initialize(String userId) async {
    _userId = userId;

    // Load devices from Firestore
    _firestoreService.getDevicesStream(userId).listen((devices) {
      _devices = devices;
      notifyListeners();
    });

    // Load alarms from Firestore
    _firestoreService.getAlarmsStream(userId).listen((alarms) {
      _alarms = alarms;
      notifyListeners();
    });

    // Try to connect to local MQTT
    await connectToMqtt();
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

    // Subscribe to device status topics
    for (var device in _devices) {
      _mqttService.subscribe(MqttConfig.deviceStatusTopic(device.id));
    }
  }

  void _handleMqttMessage(MqttMessage message) {
    final payload = message.jsonPayload;
    if (payload == null) return;

    // Check if it's an alarm
    if (message.topic.contains('alarm')) {
      _handleAlarm(message.topic, payload);
    } else {
      _handleDeviceUpdate(message.topic, payload);
    }
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

  Future<void> acknowledgeAlarm(String alarmId) async {
    final index = _alarms.indexWhere((a) => a.id == alarmId);
    if (index != -1 && _userId != null) {
      await _firestoreService.acknowledgeAlarm(_userId!, alarmId);
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _mqttService.dispose();
    super.dispose();
  }
}
