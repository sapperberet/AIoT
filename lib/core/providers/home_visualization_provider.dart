import 'package:flutter/material.dart';
import 'dart:convert';

class HomeVisualizationProvider with ChangeNotifier {
  Map<String, dynamic> _homeData = {};
  Map<String, AlarmVisualization> _activeVisualAlarms = {};

  // Door state
  bool _isDoorOpen = false;
  bool _isDoorAnimating = false;

  Map<String, dynamic> get homeData => _homeData;
  Map<String, AlarmVisualization> get activeVisualAlarms => _activeVisualAlarms;
  bool get isDoorOpen => _isDoorOpen;
  bool get isDoorAnimating => _isDoorAnimating;

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
