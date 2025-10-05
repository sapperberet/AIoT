import 'package:flutter/material.dart';

enum ConnectionMode {
  cloud,
  local,
}

class SettingsProvider with ChangeNotifier {
  // Theme settings
  ThemeMode _themeMode = ThemeMode.dark;
  ThemeMode get themeMode => _themeMode;

  // Connection mode
  ConnectionMode _connectionMode = ConnectionMode.cloud;
  ConnectionMode get connectionMode => _connectionMode;

  // MQTT settings for local mode
  String _mqttBrokerAddress = '192.168.1.100';
  int _mqttBrokerPort = 1883;
  String _mqttUsername = '';
  String _mqttPassword = '';

  String get mqttBrokerAddress => _mqttBrokerAddress;
  int get mqttBrokerPort => _mqttBrokerPort;
  String get mqttUsername => _mqttUsername;
  String get mqttPassword => _mqttPassword;

  // Notification settings
  bool _enableNotifications = true;
  bool _deviceStatusNotifications = true;
  bool _automationNotifications = true;
  bool _securityAlerts = true;
  bool _soundEnabled = true;
  bool _vibrationEnabled = true;

  bool get enableNotifications => _enableNotifications;
  bool get deviceStatusNotifications => _deviceStatusNotifications;
  bool get automationNotifications => _automationNotifications;
  bool get securityAlerts => _securityAlerts;
  bool get soundEnabled => _soundEnabled;
  bool get vibrationEnabled => _vibrationEnabled;

  // App preferences
  bool _autoConnect = true;
  bool _offlineMode = false;
  int _dataRefreshInterval = 5; // seconds

  bool get autoConnect => _autoConnect;
  bool get offlineMode => _offlineMode;
  int get dataRefreshInterval => _dataRefreshInterval;

  // Language
  String _language = 'en';
  String get language => _language;

  // Change theme
  void setThemeMode(ThemeMode mode) {
    _themeMode = mode;
    notifyListeners();
  }

  // Change connection mode
  void setConnectionMode(ConnectionMode mode) {
    _connectionMode = mode;
    notifyListeners();
  }

  // Update MQTT settings
  void updateMqttSettings({
    String? brokerAddress,
    int? brokerPort,
    String? username,
    String? password,
  }) {
    if (brokerAddress != null) _mqttBrokerAddress = brokerAddress;
    if (brokerPort != null) _mqttBrokerPort = brokerPort;
    if (username != null) _mqttUsername = username;
    if (password != null) _mqttPassword = password;
    notifyListeners();
  }

  // Toggle notification settings
  void toggleNotifications(bool value) {
    _enableNotifications = value;
    notifyListeners();
  }

  void toggleDeviceStatusNotifications(bool value) {
    _deviceStatusNotifications = value;
    notifyListeners();
  }

  void toggleAutomationNotifications(bool value) {
    _automationNotifications = value;
    notifyListeners();
  }

  void toggleSecurityAlerts(bool value) {
    _securityAlerts = value;
    notifyListeners();
  }

  void toggleSound(bool value) {
    _soundEnabled = value;
    notifyListeners();
  }

  void toggleVibration(bool value) {
    _vibrationEnabled = value;
    notifyListeners();
  }

  // Toggle app preferences
  void toggleAutoConnect(bool value) {
    _autoConnect = value;
    notifyListeners();
  }

  void toggleOfflineMode(bool value) {
    _offlineMode = value;
    notifyListeners();
  }

  void setDataRefreshInterval(int seconds) {
    _dataRefreshInterval = seconds;
    notifyListeners();
  }

  void setLanguage(String lang) {
    _language = lang;
    notifyListeners();
  }

  // Load settings from storage (to be implemented with SharedPreferences)
  Future<void> loadSettings() async {
    // TODO: Load from SharedPreferences
    notifyListeners();
  }

  // Save settings to storage
  Future<void> saveSettings() async {
    // TODO: Save to SharedPreferences
  }
}
