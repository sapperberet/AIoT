import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/firestore_service.dart';
import '../services/auth_service.dart';

enum ConnectionMode {
  cloud,
  local,
}

class SettingsProvider with ChangeNotifier {
  final FirestoreService? _firestoreService;
  final AuthService? _authService;
  String? _currentUserId;

  SettingsProvider({
    FirestoreService? firestoreService,
    AuthService? authService,
  })  : _firestoreService = firestoreService,
        _authService = authService {
    _init();
  }

  void _init() async {
    // Load settings from local storage first
    await _loadFromLocalStorage();

    // Listen to auth changes to load user-specific settings
    _authService?.authStateChanges.listen((user) {
      if (user != null && user.uid != _currentUserId) {
        _currentUserId = user.uid;
        loadSettings();
      } else if (user == null) {
        _currentUserId = null;
        // Keep local settings when logged out (don't reset)
      }
    });
  }

  void _resetToDefaults() {
    _themeMode = ThemeMode.dark;
    _connectionMode = ConnectionMode.cloud;
    _mqttBrokerAddress = '192.168.1.100';
    _mqttBrokerPort = 1883;
    _mqttUsername = '';
    _mqttPassword = '';
    _enableNotifications = true;
    _deviceStatusNotifications = true;
    _automationNotifications = true;
    _securityAlerts = true;
    _soundEnabled = true;
    _vibrationEnabled = true;
    _autoConnect = true;
    _offlineMode = false;
    _dataRefreshInterval = 5;
    _language = 'en';
    _enableEmailPasswordAuth = false;
    _userEmail = '';
    _userPassword = '';
    _enableAuthAudio = true;
    notifyListeners();
  }

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

  // Authentication settings
  bool _enableEmailPasswordAuth = false; // Default: OFF (only face auth)
  String _userEmail = '';
  String _userPassword = '';
  bool _enableAuthAudio = true; // Default: ON (audio notifications during auth)

  bool get enableEmailPasswordAuth => _enableEmailPasswordAuth;
  String get userEmail => _userEmail;
  String get userPassword => _userPassword;
  bool get enableAuthAudio => _enableAuthAudio;

  // AI Chat settings
  String _aiServerUrl = 'http://localhost:5678/webhook-test/agent';
  String? get aiServerUrl => _aiServerUrl;

  // Change theme
  void setThemeMode(ThemeMode mode) {
    _themeMode = mode;
    notifyListeners();
    saveSettings(); // Auto-save
  }

  // Change connection mode
  void setConnectionMode(ConnectionMode mode) {
    _connectionMode = mode;
    notifyListeners();
    saveSettings(); // Auto-save
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
    saveSettings(); // Auto-save
  }

  // Toggle notification settings
  void toggleNotifications(bool value) {
    _enableNotifications = value;
    notifyListeners();
    saveSettings(); // Auto-save
  }

  void toggleDeviceStatusNotifications(bool value) {
    _deviceStatusNotifications = value;
    notifyListeners();
    saveSettings(); // Auto-save
  }

  void toggleAutomationNotifications(bool value) {
    _automationNotifications = value;
    notifyListeners();
    saveSettings(); // Auto-save
  }

  void toggleSecurityAlerts(bool value) {
    _securityAlerts = value;
    notifyListeners();
    saveSettings(); // Auto-save
  }

  void toggleSound(bool value) {
    _soundEnabled = value;
    notifyListeners();
    saveSettings(); // Auto-save
  }

  void toggleVibration(bool value) {
    _vibrationEnabled = value;
    notifyListeners();
    saveSettings(); // Auto-save
  }

  // Toggle app preferences
  void toggleAutoConnect(bool value) {
    _autoConnect = value;
    notifyListeners();
    saveSettings(); // Auto-save
  }

  void toggleOfflineMode(bool value) {
    _offlineMode = value;
    notifyListeners();
    saveSettings(); // Auto-save
  }

  void setDataRefreshInterval(int seconds) {
    _dataRefreshInterval = seconds;
    notifyListeners();
    saveSettings(); // Auto-save
  }

  void setLanguage(String lang) {
    _language = lang;
    notifyListeners();
    saveSettings(); // Auto-save
  }

  // Toggle email/password authentication
  void toggleEmailPasswordAuth(bool value) {
    _enableEmailPasswordAuth = value;
    notifyListeners();
    saveSettings(); // Auto-save
  }

  // Set email/password credentials
  void setEmailPasswordCredentials({
    String? email,
    String? password,
  }) {
    if (email != null) _userEmail = email;
    if (password != null) _userPassword = password;
    notifyListeners();
    saveSettings(); // Auto-save
  }

  // Toggle authentication audio notifications
  void toggleAuthAudio(bool value) {
    _enableAuthAudio = value;
    notifyListeners();
    saveSettings(); // Auto-save
  }

  // Set AI server URL
  void setAiServerUrl(String url) {
    _aiServerUrl = url;
    notifyListeners();
    saveSettings(); // Auto-save
  }

  // Load settings from storage
  Future<void> loadSettings() async {
    // First, try to load from Firestore if user is logged in
    if (_currentUserId != null && _firestoreService != null) {
      try {
        // Load user settings from Firestore
        final userSettings =
            await _firestoreService!.getUserSettings(_currentUserId!);

        if (userSettings != null) {
          _themeMode = _parseThemeMode(userSettings['themeMode'] as String?);
          _connectionMode =
              _parseConnectionMode(userSettings['connectionMode'] as String?);
          _language = userSettings['language'] as String? ?? 'en';
          _enableNotifications =
              userSettings['enableNotifications'] as bool? ?? true;
          _deviceStatusNotifications =
              userSettings['deviceStatusNotifications'] as bool? ?? true;
          _automationNotifications =
              userSettings['automationNotifications'] as bool? ?? true;
          _securityAlerts = userSettings['securityAlerts'] as bool? ?? true;
          _soundEnabled = userSettings['soundEnabled'] as bool? ?? true;
          _vibrationEnabled = userSettings['vibrationEnabled'] as bool? ?? true;
          _autoConnect = userSettings['autoConnect'] as bool? ?? true;
          _offlineMode = userSettings['offlineMode'] as bool? ?? false;
          _dataRefreshInterval =
              userSettings['dataRefreshInterval'] as int? ?? 5;

          // MQTT settings
          _mqttBrokerAddress =
              userSettings['mqttBrokerAddress'] as String? ?? '192.168.1.100';
          _mqttBrokerPort = userSettings['mqttBrokerPort'] as int? ?? 1883;
          _mqttUsername = userSettings['mqttUsername'] as String? ?? '';
          _mqttPassword = userSettings['mqttPassword'] as String? ?? '';

          // Authentication settings
          _enableEmailPasswordAuth =
              userSettings['enableEmailPasswordAuth'] as bool? ?? false;
          _userEmail = userSettings['userEmail'] as String? ?? '';
          _userPassword = userSettings['userPassword'] as String? ?? '';
          _enableAuthAudio = userSettings['enableAuthAudio'] as bool? ?? true;

          // AI Chat settings
          _aiServerUrl = userSettings['aiServerUrl'] as String? ??
              'http://192.168.1.100:8000';

          notifyListeners();
          // Also save to local storage for offline access
          await _saveToLocalStorage();
        }
      } catch (e) {
        debugPrint('Error loading settings from Firestore: $e');
        // Fall back to local storage
        await _loadFromLocalStorage();
      }
    } else {
      // Load from local storage if not logged in
      await _loadFromLocalStorage();
    }
  }

  ThemeMode _parseThemeMode(String? mode) {
    switch (mode) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      case 'system':
        return ThemeMode.system;
      default:
        return ThemeMode.dark;
    }
  }

  ConnectionMode _parseConnectionMode(String? mode) {
    switch (mode) {
      case 'cloud':
        return ConnectionMode.cloud;
      case 'local':
        return ConnectionMode.local;
      default:
        return ConnectionMode.cloud;
    }
  }

  // Save settings to storage
  Future<void> saveSettings() async {
    // Always save to local storage
    await _saveToLocalStorage();

    // Also save to Firestore if user is logged in
    if (_currentUserId != null && _firestoreService != null) {
      try {
        await _firestoreService!.saveUserSettings(_currentUserId!, {
          'themeMode': _themeMode.name,
          'connectionMode': _connectionMode.name,
          'language': _language,
          'enableNotifications': _enableNotifications,
          'deviceStatusNotifications': _deviceStatusNotifications,
          'automationNotifications': _automationNotifications,
          'securityAlerts': _securityAlerts,
          'soundEnabled': _soundEnabled,
          'vibrationEnabled': _vibrationEnabled,
          'autoConnect': _autoConnect,
          'offlineMode': _offlineMode,
          'dataRefreshInterval': _dataRefreshInterval,
          'mqttBrokerAddress': _mqttBrokerAddress,
          'mqttBrokerPort': _mqttBrokerPort,
          'mqttUsername': _mqttUsername,
          'mqttPassword': _mqttPassword,
          'enableEmailPasswordAuth': _enableEmailPasswordAuth,
          'userEmail': _userEmail,
          'userPassword': _userPassword,
          'enableAuthAudio': _enableAuthAudio,
          'aiServerUrl': _aiServerUrl,
          'updatedAt': DateTime.now().toIso8601String(),
        });
      } catch (e) {
        debugPrint('Error saving settings to Firestore: $e');
      }
    }
  }

  // Load settings from SharedPreferences
  Future<void> _loadFromLocalStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      final themeModeStr = prefs.getString('themeMode');
      if (themeModeStr != null) {
        _themeMode = _parseThemeMode(themeModeStr);
      }

      final connectionModeStr = prefs.getString('connectionMode');
      if (connectionModeStr != null) {
        _connectionMode = _parseConnectionMode(connectionModeStr);
      }

      _language = prefs.getString('language') ?? 'en';
      _enableNotifications = prefs.getBool('enableNotifications') ?? true;
      _deviceStatusNotifications =
          prefs.getBool('deviceStatusNotifications') ?? true;
      _automationNotifications =
          prefs.getBool('automationNotifications') ?? true;
      _securityAlerts = prefs.getBool('securityAlerts') ?? true;
      _soundEnabled = prefs.getBool('soundEnabled') ?? true;
      _vibrationEnabled = prefs.getBool('vibrationEnabled') ?? true;
      _autoConnect = prefs.getBool('autoConnect') ?? true;
      _offlineMode = prefs.getBool('offlineMode') ?? false;
      _dataRefreshInterval = prefs.getInt('dataRefreshInterval') ?? 5;

      _mqttBrokerAddress =
          prefs.getString('mqttBrokerAddress') ?? '192.168.1.100';
      _mqttBrokerPort = prefs.getInt('mqttBrokerPort') ?? 1883;
      _mqttUsername = prefs.getString('mqttUsername') ?? '';
      _mqttPassword = prefs.getString('mqttPassword') ?? '';

      _enableEmailPasswordAuth =
          prefs.getBool('enableEmailPasswordAuth') ?? false;
      _userEmail = prefs.getString('userEmail') ?? '';
      _userPassword = prefs.getString('userPassword') ?? '';
      _enableAuthAudio = prefs.getBool('enableAuthAudio') ?? true;

      _aiServerUrl =
          prefs.getString('aiServerUrl') ?? 'http://192.168.1.100:8000';

      notifyListeners();
    } catch (e) {
      debugPrint('Error loading settings from local storage: $e');
    }
  }

  // Save settings to SharedPreferences
  Future<void> _saveToLocalStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      await prefs.setString('themeMode', _themeMode.name);
      await prefs.setString('connectionMode', _connectionMode.name);
      await prefs.setString('language', _language);
      await prefs.setBool('enableNotifications', _enableNotifications);
      await prefs.setBool(
          'deviceStatusNotifications', _deviceStatusNotifications);
      await prefs.setBool('automationNotifications', _automationNotifications);
      await prefs.setBool('securityAlerts', _securityAlerts);
      await prefs.setBool('soundEnabled', _soundEnabled);
      await prefs.setBool('vibrationEnabled', _vibrationEnabled);
      await prefs.setBool('autoConnect', _autoConnect);
      await prefs.setBool('offlineMode', _offlineMode);
      await prefs.setInt('dataRefreshInterval', _dataRefreshInterval);

      await prefs.setString('mqttBrokerAddress', _mqttBrokerAddress);
      await prefs.setInt('mqttBrokerPort', _mqttBrokerPort);
      await prefs.setString('mqttUsername', _mqttUsername);
      await prefs.setString('mqttPassword', _mqttPassword);

      await prefs.setBool('enableEmailPasswordAuth', _enableEmailPasswordAuth);
      await prefs.setString('userEmail', _userEmail);
      await prefs.setString('userPassword', _userPassword);
      await prefs.setBool('enableAuthAudio', _enableAuthAudio);
      await prefs.setString('aiServerUrl', _aiServerUrl);
    } catch (e) {
      debugPrint('Error saving settings to local storage: $e');
    }
  }
}
