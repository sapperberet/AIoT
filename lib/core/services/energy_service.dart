import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'mqtt_service.dart';

/// Model for energy readings
class EnergyReading {
  final double voltage;
  final double current;
  final double power;
  final double energy;
  final DateTime timestamp;

  EnergyReading({
    required this.voltage,
    required this.current,
    required this.power,
    required this.energy,
    required this.timestamp,
  });

  factory EnergyReading.fromMqttPayload(String payload) {
    try {
      final data = jsonDecode(payload);
      return EnergyReading(
        voltage: (data['voltage'] ?? 0).toDouble(),
        current: (data['current'] ?? 0).toDouble(),
        power: (data['power'] ?? 0).toDouble(),
        energy: (data['energy'] ?? 0).toDouble(),
        timestamp: DateTime.now(),
      );
    } catch (e) {
      return EnergyReading(
        voltage: 0,
        current: 0,
        power: 0,
        energy: 0,
        timestamp: DateTime.now(),
      );
    }
  }

  factory EnergyReading.fromJson(Map<String, dynamic> json) {
    return EnergyReading(
      voltage: (json['voltage'] ?? 0).toDouble(),
      current: (json['current'] ?? 0).toDouble(),
      power: (json['power'] ?? 0).toDouble(),
      energy: (json['energy'] ?? 0).toDouble(),
      timestamp: (json['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'voltage': voltage,
      'current': current,
      'power': power,
      'energy': energy,
      'timestamp': Timestamp.fromDate(timestamp),
    };
  }
}

/// Device energy consumption model
class DeviceEnergyConsumption {
  final String deviceId;
  final String deviceName;
  final String deviceType;
  final double consumption;
  final double percentage;

  DeviceEnergyConsumption({
    required this.deviceId,
    required this.deviceName,
    required this.deviceType,
    required this.consumption,
    required this.percentage,
  });
}

/// Service for managing energy monitoring data
class EnergyService with ChangeNotifier {
  final MqttService _mqttService;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // MQTT topics for energy monitoring
  static const String _voltageTopic = 'home/energy/voltage';
  static const String _currentTopic = 'home/energy/current';
  static const String _powerTopic = 'home/energy/power';
  static const String _energyTopic = 'home/energy/total';

  // Current readings
  EnergyReading? _currentReading;
  final List<EnergyReading> _readingHistory = [];
  StreamSubscription<MqttMessage>? _messageSubscription;

  // Connection status
  bool _isConnected = false;
  String? _lastError;

  EnergyReading? get currentReading => _currentReading;
  List<EnergyReading> get readingHistory => List.unmodifiable(_readingHistory);
  bool get isConnected => _isConnected;
  String? get lastError => _lastError;

  // Computed values
  double get currentVoltage => _currentReading?.voltage ?? 0;
  double get currentCurrent => _currentReading?.current ?? 0;
  double get currentPower => _currentReading?.power ?? 0;
  double get totalEnergy => _currentReading?.energy ?? 0;

  EnergyService({required MqttService mqttService})
      : _mqttService = mqttService {
    _initialize();
  }

  void _initialize() {
    // Listen to MQTT status
    _mqttService.statusStream.listen((status) {
      _isConnected = status == ConnectionStatus.connected;
      if (_isConnected) {
        _subscribeToEnergyTopics();
      }
      notifyListeners();
    });

    // Listen to MQTT messages
    _messageSubscription = _mqttService.messageStream.listen(_handleMessage);

    // Load historical data
    _loadHistoricalData();
  }

  void _subscribeToEnergyTopics() {
    _mqttService.subscribe(_voltageTopic);
    _mqttService.subscribe(_currentTopic);
    _mqttService.subscribe(_powerTopic);
    _mqttService.subscribe(_energyTopic);
  }

  void _handleMessage(MqttMessage message) {
    try {
      if (message.topic == _voltageTopic ||
          message.topic == _currentTopic ||
          message.topic == _powerTopic ||
          message.topic == _energyTopic) {
        // Parse the reading
        final reading = EnergyReading.fromMqttPayload(message.payload);

        _currentReading = reading;
        _readingHistory.add(reading);

        // Keep only last 100 readings in memory
        if (_readingHistory.length > 100) {
          _readingHistory.removeAt(0);
        }

        // Save to Firebase
        _saveReading(reading);

        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error handling energy message: $e');
      _lastError = e.toString();
    }
  }

  Future<void> _saveReading(EnergyReading reading) async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) return;

      await _firestore
          .collection('users')
          .doc(userId)
          .collection('energy_readings')
          .add(reading.toJson());
    } catch (e) {
      debugPrint('Error saving energy reading: $e');
    }
  }

  Future<void> _loadHistoricalData() async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) return;

      final snapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('energy_readings')
          .orderBy('timestamp', descending: true)
          .limit(100)
          .get();

      _readingHistory.clear();
      for (final doc in snapshot.docs.reversed) {
        _readingHistory.add(EnergyReading.fromJson(doc.data()));
      }

      if (_readingHistory.isNotEmpty) {
        _currentReading = _readingHistory.last;
      }

      notifyListeners();
    } catch (e) {
      debugPrint('Error loading energy history: $e');
    }
  }

  /// Get energy consumption by time period
  Future<double> getConsumptionForPeriod(Duration period) async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) return 0;

    try {
      final cutoff = DateTime.now().subtract(period);
      final snapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('energy_readings')
          .where('timestamp', isGreaterThan: Timestamp.fromDate(cutoff))
          .get();

      if (snapshot.docs.isEmpty) return 0;

      double totalEnergy = 0;
      for (final doc in snapshot.docs) {
        totalEnergy += (doc.data()['energy'] ?? 0).toDouble();
      }
      return totalEnergy;
    } catch (e) {
      debugPrint('Error getting consumption: $e');
      return 0;
    }
  }

  /// Get device breakdown (mock for now - can be expanded with real device tracking)
  List<DeviceEnergyConsumption> getDeviceBreakdown() {
    final total = totalEnergy > 0 ? totalEnergy : 100;
    return [
      DeviceEnergyConsumption(
        deviceId: 'ac',
        deviceName: 'Air Conditioner',
        deviceType: 'HVAC',
        consumption: total * 0.35,
        percentage: 35,
      ),
      DeviceEnergyConsumption(
        deviceId: 'lights',
        deviceName: 'Smart Lights',
        deviceType: 'Lighting',
        consumption: total * 0.15,
        percentage: 15,
      ),
      DeviceEnergyConsumption(
        deviceId: 'tv',
        deviceName: 'Smart TV',
        deviceType: 'Entertainment',
        consumption: total * 0.12,
        percentage: 12,
      ),
      DeviceEnergyConsumption(
        deviceId: 'washer',
        deviceName: 'Washing Machine',
        deviceType: 'Appliance',
        consumption: total * 0.10,
        percentage: 10,
      ),
      DeviceEnergyConsumption(
        deviceId: 'other',
        deviceName: 'Other Devices',
        deviceType: 'Other',
        consumption: total * 0.28,
        percentage: 28,
      ),
    ];
  }

  /// Estimate cost based on rate per kWh
  double estimateCost({double ratePerKwh = 0.12}) {
    return totalEnergy * ratePerKwh;
  }

  /// Refresh data
  Future<void> refresh() async {
    await _loadHistoricalData();
  }

  @override
  void dispose() {
    _messageSubscription?.cancel();
    super.dispose();
  }
}
