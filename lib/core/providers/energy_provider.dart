import 'dart:async';
import 'package:flutter/foundation.dart';
import '../services/energy_service.dart';
import '../services/mqtt_service.dart';

/// Provider for managing energy monitoring state and real-time MQTT data
class EnergyProvider extends ChangeNotifier {
  final EnergyService _energyService;
  final MqttService _mqttService;

  // Loading states
  bool _isLoading = false;
  bool get isLoading => _isLoading;

  // Error handling
  String? _error;
  String? get error => _error;

  // Power usage trend (positive = increasing, negative = decreasing)
  double _usageTrend = 0.0;
  double get usageTrend => _usageTrend;

  // Previous readings for trend calculation
  double _previousPower = 0.0;

  EnergyProvider({
    required EnergyService energyService,
    required MqttService mqttService,
  })  : _energyService = energyService,
        _mqttService = mqttService;

  /// Initialize the provider
  Future<void> initialize() async {
    _isLoading = true;
    notifyListeners();

    try {
      // Listen to energy service changes
      _energyService.addListener(_onEnergyServiceUpdate);

      _isLoading = false;
      _error = null;
      notifyListeners();
    } catch (e) {
      _error = 'Failed to initialize energy monitoring: $e';
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Handle updates from the energy service
  void _onEnergyServiceUpdate() {
    // Calculate trend based on power change
    final currentPower = _energyService.currentPower;
    if (_previousPower > 0 && currentPower > 0) {
      _usageTrend = ((currentPower - _previousPower) / _previousPower * 100);
    }
    _previousPower = currentPower;

    notifyListeners();
  }

  /// Check if connected to MQTT
  bool get isConnected => _energyService.isConnected;

  /// Get current energy reading
  EnergyReading? get currentEnergy => _energyService.currentReading;

  /// Get total energy today (kWh)
  double get totalEnergyToday => _energyService.totalEnergy;

  /// Get current power in watts
  double get currentPower => _energyService.currentPower;

  /// Get current voltage
  double get currentVoltage => _energyService.currentVoltage;

  /// Get current amperage
  double get currentCurrent => _energyService.currentCurrent;

  /// Power factor (placeholder - not all meters report this)
  double get powerFactor => 1.0;

  /// Get estimated cost for today
  double getEstimatedCost({double ratePerKwh = 0.12}) {
    return _energyService.estimateCost(ratePerKwh: ratePerKwh);
  }

  /// Check if any energy meters are detected
  bool get hasEnergyMeters {
    return isConnected && currentEnergy != null;
  }

  /// Get list of detected energy devices
  List<String> get detectedDevices {
    if (currentEnergy == null) return [];
    return ['Main Meter'];
  }

  /// Get device breakdown
  Map<String, double> get deviceBreakdown {
    final breakdown = _energyService.getDeviceBreakdown();
    return {
      for (var device in breakdown) device.deviceName: device.consumption
    };
  }

  /// Refresh all energy data
  Future<void> refresh() async {
    _isLoading = true;
    notifyListeners();

    try {
      await _energyService.refresh();
      _error = null;
    } catch (e) {
      _error = 'Failed to refresh: $e';
    }

    _isLoading = false;
    notifyListeners();
  }

  @override
  void dispose() {
    _energyService.removeListener(_onEnergyServiceUpdate);
    super.dispose();
  }
}
