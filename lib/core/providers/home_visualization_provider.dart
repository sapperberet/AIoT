import 'package:flutter/material.dart';
import 'dart:convert';

class HomeVisualizationProvider with ChangeNotifier {
  Map<String, dynamic> _homeData = {};
  Map<String, AlarmVisualization> _activeVisualAlarms = {};

  // Door state
  bool _isDoorOpen = false;
  bool _isDoorAnimating = false;

  // Garage state
  bool _isGarageOpen = false;
  bool _isGarageAnimating = false;

  // Windows state (windowId -> isOpen)
  final Map<String, bool> _windowStates = {};
  bool _isWindowsAnimating = false;

  // Lights state (lightId -> isOn)
  final Map<String, bool> _lightStates = {};

  // Buzzer state
  bool _isBuzzerActive = false;

  Map<String, dynamic> get homeData => _homeData;
  Map<String, AlarmVisualization> get activeVisualAlarms => _activeVisualAlarms;

  // Door getters
  bool get isDoorOpen => _isDoorOpen;
  bool get isDoorAnimating => _isDoorAnimating;

  // Garage getters
  bool get isGarageOpen => _isGarageOpen;
  bool get isGarageAnimating => _isGarageAnimating;

  // Window getters
  Map<String, bool> get windowStates => Map.unmodifiable(_windowStates);
  bool get isWindowsAnimating => _isWindowsAnimating;
  bool get anyWindowOpen => _windowStates.values.any((open) => open);

  // Light getters
  Map<String, bool> get lightStates => Map.unmodifiable(_lightStates);
  bool get anyLightOn => _lightStates.values.any((on) => on);

  // Buzzer getter
  bool get isBuzzerActive => _isBuzzerActive;

  // Load 3D home model data (dimensions, sections from CAD/SolidWorks)
  void loadHomeModel(Map<String, dynamic> modelData) {
    _homeData = modelData;
    notifyListeners();
  }

  // Trigger visual alarm in specific section
  void triggerVisualAlarm(String section, String alarmType, String severity) {
    _activeVisualAlarms[section] = AlarmVisualization(
      section: section,
      alarmType: alarmType,
      severity: severity,
      color: _getAlarmColor(severity),
      timestamp: DateTime.now(),
    );
    notifyListeners();
  }

  // Clear visual alarm
  void clearVisualAlarm(String section) {
    _activeVisualAlarms.remove(section);
    notifyListeners();
  }

  // Clear all visual alarms
  void clearAllVisualAlarms() {
    _activeVisualAlarms.clear();
    notifyListeners();
  }

  // Door control methods
  void setDoorOpen(bool isOpen) {
    _isDoorOpen = isOpen;
    notifyListeners();
  }

  void setDoorAnimating(bool isAnimating) {
    _isDoorAnimating = isAnimating;
    notifyListeners();
  }

  void triggerDoorOpen() {
    _isDoorAnimating = true;
    _isDoorOpen = true;
    notifyListeners();

    // Reset animating state after animation duration
    Future.delayed(const Duration(milliseconds: 1500), () {
      _isDoorAnimating = false;
      notifyListeners();
    });

    // Auto-close door after 6 seconds
    Future.delayed(const Duration(seconds: 6), () {
      _isDoorOpen = false;
      notifyListeners();
    });
  }

  // Garage control methods
  void setGarageOpen(bool isOpen) {
    _isGarageOpen = isOpen;
    notifyListeners();
  }

  void setGarageAnimating(bool isAnimating) {
    _isGarageAnimating = isAnimating;
    notifyListeners();
  }

  void triggerGarageOpen() {
    _isGarageAnimating = true;
    _isGarageOpen = true;
    notifyListeners();

    // Reset animating state after animation duration
    Future.delayed(const Duration(milliseconds: 2000), () {
      _isGarageAnimating = false;
      notifyListeners();
    });

    // Auto-close garage after 10 seconds
    Future.delayed(const Duration(seconds: 10), () {
      _isGarageOpen = false;
      notifyListeners();
    });
  }

  void triggerGarageClose() {
    _isGarageAnimating = true;
    notifyListeners();

    Future.delayed(const Duration(milliseconds: 2000), () {
      _isGarageAnimating = false;
      _isGarageOpen = false;
      notifyListeners();
    });
  }

  // Window control methods
  void setWindowOpen(String windowId, bool isOpen) {
    _windowStates[windowId] = isOpen;
    notifyListeners();
  }

  void toggleWindow(String windowId) {
    _windowStates[windowId] = !(_windowStates[windowId] ?? false);
    notifyListeners();
  }

  void setAllWindowsOpen(bool isOpen) {
    _isWindowsAnimating = true;
    notifyListeners();

    Future.delayed(const Duration(milliseconds: 1000), () {
      for (var key in _windowStates.keys) {
        _windowStates[key] = isOpen;
      }
      _isWindowsAnimating = false;
      notifyListeners();
    });
  }

  // Light control methods
  void setLightOn(String lightId, bool isOn) {
    _lightStates[lightId] = isOn;
    notifyListeners();
  }

  void toggleLight(String lightId) {
    _lightStates[lightId] = !(_lightStates[lightId] ?? false);
    notifyListeners();
  }

  void setAllLightsOn(bool isOn) {
    for (var key in _lightStates.keys) {
      _lightStates[key] = isOn;
    }
    notifyListeners();
  }

  void toggleAllLights() {
    final anyOn = _lightStates.values.any((on) => on);
    for (var key in _lightStates.keys) {
      _lightStates[key] = !anyOn;
    }
    notifyListeners();
  }

  // Buzzer control methods
  void setBuzzerActive(bool isActive) {
    _isBuzzerActive = isActive;
    notifyListeners();
  }

  void triggerBuzzer({Duration duration = const Duration(seconds: 3)}) {
    _isBuzzerActive = true;
    notifyListeners();

    Future.delayed(duration, () {
      _isBuzzerActive = false;
      notifyListeners();
    });
  }

  /// Update state from device provider sync
  void syncFromDeviceState(String deviceType, Map<String, dynamic> state) {
    switch (deviceType) {
      case 'door':
        _isDoorOpen = state['isOpen'] ?? false;
        _isDoorAnimating = true;
        Future.delayed(const Duration(milliseconds: 1500), () {
          _isDoorAnimating = false;
          notifyListeners();
        });
        break;
      case 'garage':
        _isGarageOpen = state['isOpen'] ?? false;
        _isGarageAnimating = true;
        Future.delayed(const Duration(milliseconds: 2000), () {
          _isGarageAnimating = false;
          notifyListeners();
        });
        break;
      case 'window':
        final windowId = state['windowId'] as String?;
        if (windowId != null) {
          _windowStates[windowId] = state['isOpen'] ?? false;
        }
        break;
      case 'windows':
        final allOpen = state['allOpen'] ?? false;
        for (var key in _windowStates.keys) {
          _windowStates[key] = allOpen;
        }
        break;
      case 'light':
        final lightId = state['lightId'] as String?;
        if (lightId != null) {
          _lightStates[lightId] = state['isOn'] ?? false;
        }
        break;
      case 'lights':
        final allOn = state['allOn'] ?? false;
        for (var key in _lightStates.keys) {
          _lightStates[key] = allOn;
        }
        break;
      case 'buzzer':
        _isBuzzerActive = state['isActive'] ?? false;
        break;
    }
    notifyListeners();
  }

  Color _getAlarmColor(String severity) {
    switch (severity) {
      case 'critical':
        return Colors.red;
      case 'warning':
        return Colors.orange;
      case 'info':
        return Colors.blue;
      default:
        return Colors.yellow;
    }
  }

  // Get message to send to JavaScript/three.js
  String getVisualizationCommand() {
    return jsonEncode({
      'alarms': _activeVisualAlarms.map((key, value) => MapEntry(
            key,
            {
              'section': value.section,
              'type': value.alarmType,
              'severity': value.severity,
              'color': '#${value.color.value.toRadixString(16).substring(2)}',
            },
          )),
    });
  }

  /// Get full state command for JavaScript sync
  String getFullStateCommand() {
    return jsonEncode({
      'door': {
        'isOpen': _isDoorOpen,
        'isAnimating': _isDoorAnimating,
      },
      'garage': {
        'isOpen': _isGarageOpen,
        'isAnimating': _isGarageAnimating,
      },
      'windows': _windowStates,
      'lights': _lightStates,
      'buzzer': {
        'isActive': _isBuzzerActive,
      },
      'alarms': _activeVisualAlarms.map((key, value) => MapEntry(
            key,
            {
              'section': value.section,
              'type': value.alarmType,
              'severity': value.severity,
              'color': '#${value.color.value.toRadixString(16).substring(2)}',
            },
          )),
    });
  }

  /// Get specific device command for JavaScript
  String getDeviceCommand(String deviceType) {
    switch (deviceType) {
      case 'door':
        return jsonEncode({
          'door': {'isOpen': _isDoorOpen}
        });
      case 'garage':
        return jsonEncode({
          'garage': {'isOpen': _isGarageOpen}
        });
      case 'windows':
        return jsonEncode({'windows': _windowStates});
      case 'lights':
        return jsonEncode({'lights': _lightStates});
      case 'buzzer':
        return jsonEncode({
          'buzzer': {'isActive': _isBuzzerActive}
        });
      default:
        return '{}';
    }
  }
}

class AlarmVisualization {
  final String section;
  final String alarmType;
  final String severity;
  final Color color;
  final DateTime timestamp;

  AlarmVisualization({
    required this.section,
    required this.alarmType,
    required this.severity,
    required this.color,
    required this.timestamp,
  });
}
