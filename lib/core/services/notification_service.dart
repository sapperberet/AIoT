import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'dart:convert';
import 'dart:async';
import 'dart:io' show Platform;

enum NotificationType {
  deviceStatus,
  automation,
  security,
  info,
}

enum NotificationPriority {
  low,
  medium,
  high,
  urgent,
}

class AppNotification {
  final String id;
  final String title;
  final String message;
  final NotificationType type;
  final NotificationPriority priority;
  final DateTime timestamp;
  final bool isRead;
  final Map<String, dynamic>? data;

  AppNotification({
    required this.id,
    required this.title,
    required this.message,
    required this.type,
    this.priority = NotificationPriority.medium,
    DateTime? timestamp,
    this.isRead = false,
    this.data,
  }) : timestamp = timestamp ?? DateTime.now();

  AppNotification copyWith({
    String? id,
    String? title,
    String? message,
    NotificationType? type,
    NotificationPriority? priority,
    DateTime? timestamp,
    bool? isRead,
    Map<String, dynamic>? data,
  }) {
    return AppNotification(
      id: id ?? this.id,
      title: title ?? this.title,
      message: message ?? this.message,
      type: type ?? this.type,
      priority: priority ?? this.priority,
      timestamp: timestamp ?? this.timestamp,
      isRead: isRead ?? this.isRead,
      data: data ?? this.data,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'message': message,
      'type': type.name,
      'priority': priority.name,
      'timestamp': timestamp.toIso8601String(),
      'isRead': isRead,
      'data': data,
    };
  }

  factory AppNotification.fromMap(Map<String, dynamic> map) {
    return AppNotification(
      id: map['id'] ?? '',
      title: map['title'] ?? '',
      message: map['message'] ?? '',
      type: NotificationType.values.firstWhere(
        (e) => e.name == map['type'],
        orElse: () => NotificationType.info,
      ),
      priority: NotificationPriority.values.firstWhere(
        (e) => e.name == map['priority'],
        orElse: () => NotificationPriority.medium,
      ),
      timestamp: DateTime.parse(map['timestamp']),
      isRead: map['isRead'] ?? false,
      data: map['data'],
    );
  }
}

class NotificationService with ChangeNotifier {
  static const String _storageKey = 'app_notifications';
  final List<AppNotification> _notifications = [];
  final StreamController<AppNotification> _notificationStreamController =
      StreamController<AppNotification>.broadcast();

  // For undo functionality
  AppNotification? _lastDeletedNotification;
  int? _lastDeletedIndex;

  // Flutter Local Notifications
  final FlutterLocalNotificationsPlugin _flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();
  bool _isNotificationsInitialized = false;

  NotificationService() {
    _initializeLocalNotifications();
    _loadNotifications();
  }

  /// Initialize local notifications for push notifications
  Future<void> _initializeLocalNotifications() async {
    try {
      // Android initialization settings
      const AndroidInitializationSettings initializationSettingsAndroid =
          AndroidInitializationSettings('@mipmap/ic_launcher');

      // iOS initialization settings
      const DarwinInitializationSettings initializationSettingsIOS =
          DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
      );

      const InitializationSettings initializationSettings =
          InitializationSettings(
        android: initializationSettingsAndroid,
        iOS: initializationSettingsIOS,
      );

      await _flutterLocalNotificationsPlugin.initialize(
        initializationSettings,
        onDidReceiveNotificationResponse: _onNotificationTapped,
      );

      // Request permissions for Android 13+
      if (Platform.isAndroid) {
        await _flutterLocalNotificationsPlugin
            .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin>()
            ?.requestNotificationsPermission();
      }

      _isNotificationsInitialized = true;
      debugPrint('✅ Local notifications initialized');
    } catch (e) {
      debugPrint('❌ Error initializing local notifications: $e');
    }
  }

  void _onNotificationTapped(NotificationResponse response) {
    // Handle notification tap
    debugPrint('Notification tapped: ${response.payload}');
  }

  /// Load notifications from local storage
  Future<void> _loadNotifications() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final notificationsJson = prefs.getString(_storageKey);

      if (notificationsJson != null && notificationsJson.isNotEmpty) {
        final List<dynamic> decoded = jsonDecode(notificationsJson);
        _notifications.clear();
        _notifications.addAll(
          decoded
              .map((json) =>
                  AppNotification.fromMap(json as Map<String, dynamic>))
              .toList(),
        );
        notifyListeners();
      } else {
        // Add sample notifications for first-time users
        _initializeSampleNotifications();
      }
    } catch (e) {
      debugPrint('Error loading notifications: $e');
      _initializeSampleNotifications();
    }
  }

  /// Save notifications to local storage
  Future<void> _saveNotifications() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final notificationsJson = jsonEncode(
        _notifications.map((n) => n.toMap()).toList(),
      );
      await prefs.setString(_storageKey, notificationsJson);
    } catch (e) {
      debugPrint('Error saving notifications: $e');
    }
  }

  void _initializeSampleNotifications() {
    // Add sample notifications for demo
    _notifications.addAll([
      AppNotification(
        id: '1',
        title: 'Welcome to Smart Home',
        message:
            'Your smart home system is ready to use. Start by adding your first device.',
        type: NotificationType.info,
        priority: NotificationPriority.medium,
        timestamp: DateTime.now().subtract(const Duration(hours: 2)),
      ),
      AppNotification(
        id: '2',
        title: 'Security Alert',
        message: 'Motion detected at Front Door at 3:45 PM',
        type: NotificationType.security,
        priority: NotificationPriority.high,
        timestamp: DateTime.now().subtract(const Duration(hours: 1)),
      ),
      AppNotification(
        id: '3',
        title: 'Automation Triggered',
        message: 'Good Morning automation executed successfully',
        type: NotificationType.automation,
        priority: NotificationPriority.medium,
        timestamp: DateTime.now().subtract(const Duration(minutes: 30)),
      ),
    ]);
    _saveNotifications();
  }

  List<AppNotification> get notifications => List.unmodifiable(_notifications);
  Stream<AppNotification> get notificationStream =>
      _notificationStreamController.stream;

  int get unreadCount => _notifications.where((n) => !n.isRead).length;

  // Add a notification
  Future<void> addNotification({
    required String title,
    required String message,
    required NotificationType type,
    NotificationPriority priority = NotificationPriority.medium,
    Map<String, dynamic>? data,
  }) async {
    final notification = AppNotification(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: title,
      message: message,
      type: type,
      priority: priority,
      data: data,
    );

    _notifications.insert(0, notification);
    _notificationStreamController.add(notification);

    // Show local notification based on settings
    await _showLocalNotification(notification);

    await _saveNotifications();
    notifyListeners();
  }

  // Mark notification as read
  void markAsRead(String notificationId) {
    final index = _notifications.indexWhere((n) => n.id == notificationId);
    if (index != -1) {
      _notifications[index] = _notifications[index].copyWith(isRead: true);
      _saveNotifications();
      notifyListeners();
    }
  }

  // Mark all as read
  void markAllAsRead() {
    for (int i = 0; i < _notifications.length; i++) {
      _notifications[i] = _notifications[i].copyWith(isRead: true);
    }
    _saveNotifications();
    notifyListeners();
  }

  // Delete notification (with undo support)
  void deleteNotification(String notificationId) {
    final index = _notifications.indexWhere((n) => n.id == notificationId);
    if (index != -1) {
      // Store for undo
      _lastDeletedNotification = _notifications[index];
      _lastDeletedIndex = index;

      _notifications.removeAt(index);
      _saveNotifications();
      notifyListeners();
    }
  }

  // Undo last delete
  bool undoDelete() {
    if (_lastDeletedNotification != null && _lastDeletedIndex != null) {
      // Restore at original position or at the end if index is out of bounds
      final insertIndex = _lastDeletedIndex! <= _notifications.length
          ? _lastDeletedIndex!
          : _notifications.length;
      _notifications.insert(insertIndex, _lastDeletedNotification!);

      // Clear undo state
      _lastDeletedNotification = null;
      _lastDeletedIndex = null;

      _saveNotifications();
      notifyListeners();
      return true;
    }
    return false;
  }

  // Check if undo is available
  bool get canUndo => _lastDeletedNotification != null;

  // Clear all notifications
  void clearAll() {
    _notifications.clear();
    _saveNotifications();
    notifyListeners();
  }

  // Get notifications by type
  List<AppNotification> getNotificationsByType(NotificationType type) {
    return _notifications.where((n) => n.type == type).toList();
  }

  // Get unread notifications
  List<AppNotification> getUnreadNotifications() {
    return _notifications.where((n) => !n.isRead).toList();
  }

  // Show local notification (push notification when app in background)
  Future<void> _showLocalNotification(AppNotification notification) async {
    if (!_isNotificationsInitialized) {
      debugPrint('Notifications not initialized yet');
      return;
    }

    try {
      // Define notification details for Android
      AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
        'smart_home_channel',
        'Smart Home Notifications',
        channelDescription: 'Notifications from Smart Home App',
        importance: _getAndroidImportance(notification.priority),
        priority: _getAndroidPriority(notification.priority),
        playSound: true,
        sound: const RawResourceAndroidNotificationSound('notification_sound'),
        enableVibration: true,
        icon: '@mipmap/ic_launcher',
        largeIcon: const DrawableResourceAndroidBitmap('@mipmap/ic_launcher'),
        styleInformation: BigTextStyleInformation(
          notification.message,
          htmlFormatBigText: true,
          contentTitle: notification.title,
          htmlFormatContentTitle: true,
        ),
      );

      // Define notification details for iOS
      const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
        sound: 'default',
      );

      NotificationDetails notificationDetails = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );

      await _flutterLocalNotificationsPlugin.show(
        notification.id.hashCode,
        notification.title,
        notification.message,
        notificationDetails,
        payload: jsonEncode(notification.toMap()),
      );

      debugPrint('📱 Push notification sent: ${notification.title}');
    } catch (e) {
      debugPrint('❌ Error showing local notification: $e');
    }
  }

  Importance _getAndroidImportance(NotificationPriority priority) {
    switch (priority) {
      case NotificationPriority.urgent:
        return Importance.max;
      case NotificationPriority.high:
        return Importance.high;
      case NotificationPriority.medium:
        return Importance.defaultImportance;
      case NotificationPriority.low:
        return Importance.low;
    }
  }

  Priority _getAndroidPriority(NotificationPriority priority) {
    switch (priority) {
      case NotificationPriority.urgent:
        return Priority.max;
      case NotificationPriority.high:
        return Priority.high;
      case NotificationPriority.medium:
        return Priority.defaultPriority;
      case NotificationPriority.low:
        return Priority.low;
    }
  }

  // Device status notifications
  void notifyDeviceStatusChange(String deviceName, bool isOnline) {
    addNotification(
      title: 'Device ${isOnline ? 'Connected' : 'Disconnected'}',
      message: '$deviceName is now ${isOnline ? 'online' : 'offline'}',
      type: NotificationType.deviceStatus,
      priority:
          isOnline ? NotificationPriority.low : NotificationPriority.medium,
      data: {'deviceName': deviceName, 'isOnline': isOnline},
    );
  }

  void notifyDeviceStateChange(String deviceName, String state) {
    addNotification(
      title: 'Device State Changed',
      message: '$deviceName is now $state',
      type: NotificationType.deviceStatus,
      priority: NotificationPriority.low,
      data: {'deviceName': deviceName, 'state': state},
    );
  }

  // Automation notifications
  void notifyAutomationTriggered(String automationName) {
    addNotification(
      title: 'Automation Triggered',
      message: 'Automation "$automationName" has been executed',
      type: NotificationType.automation,
      priority: NotificationPriority.medium,
      data: {'automationName': automationName},
    );
  }

  // Security notifications
  void notifySecurityAlert(String message,
      {NotificationPriority priority = NotificationPriority.urgent}) {
    addNotification(
      title: 'Security Alert',
      message: message,
      type: NotificationType.security,
      priority: priority,
    );
  }

  void notifyUnauthorizedAccess(String deviceName) {
    addNotification(
      title: 'Unauthorized Access Detected',
      message: 'Unauthorized access attempt detected on $deviceName',
      type: NotificationType.security,
      priority: NotificationPriority.urgent,
      data: {'deviceName': deviceName},
    );
  }

  // Info notifications
  void notifyInfo(String title, String message) {
    addNotification(
      title: title,
      message: message,
      type: NotificationType.info,
      priority: NotificationPriority.low,
    );
  }

  // Face detection notifications (Version 2)
  void notifyUnrecognizedPerson({String? location}) {
    addNotification(
      title: 'Unrecognized Person Detected',
      message:
          'An unrecognized person was detected at ${location ?? 'entrance'}. Tap to view camera feed.',
      type: NotificationType.security,
      priority: NotificationPriority.urgent,
      data: {
        'type': 'unrecognized_face',
        'location': location ?? 'entrance',
        'action': 'view_camera',
      },
    );
  }

  void notifyPersonRecognized(String name, {String? location}) {
    addNotification(
      title: 'Person Recognized',
      message: '$name detected at ${location ?? 'entrance'}',
      type: NotificationType.info,
      priority: NotificationPriority.low,
      data: {
        'type': 'recognized_face',
        'name': name,
        'location': location ?? 'entrance',
      },
    );
  }

  // Door notifications
  void notifyDoorOpened({String? location}) {
    addNotification(
      title: 'Door Opened',
      message: '${location ?? 'Main'} door has been opened',
      type: NotificationType.security,
      priority: NotificationPriority.high,
      data: {
        'type': 'door_opened',
        'location': location ?? 'main',
      },
    );
  }

  void notifyDoorClosed({String? location}) {
    addNotification(
      title: 'Door Closed',
      message: '${location ?? 'Main'} door has been closed',
      type: NotificationType.security,
      priority: NotificationPriority.low,
      data: {
        'type': 'door_closed',
        'location': location ?? 'main',
      },
    );
  }

  // Garage notifications
  void notifyGarageOpened() {
    addNotification(
      title: 'Garage Door Opened',
      message:
          'Your garage door has been opened. Make sure to close it when done.',
      type: NotificationType.security,
      priority: NotificationPriority.high,
      data: {
        'type': 'garage_opened',
      },
    );
  }

  void notifyGarageClosed() {
    addNotification(
      title: 'Garage Door Closed',
      message: 'Your garage door has been securely closed.',
      type: NotificationType.security,
      priority: NotificationPriority.low,
      data: {
        'type': 'garage_closed',
      },
    );
  }

  void notifyGarageLeftOpen({int minutes = 30}) {
    addNotification(
      title: 'Garage Left Open',
      message:
          'Your garage door has been open for $minutes minutes. Close it for security.',
      type: NotificationType.security,
      priority: NotificationPriority.urgent,
      data: {
        'type': 'garage_warning',
        'minutes_open': minutes,
        'action': 'close_garage',
      },
    );
  }

  // Window notifications
  void notifyWindowOpened({required String location}) {
    addNotification(
      title: 'Window Opened',
      message: 'Window in $location has been opened',
      type: NotificationType.security,
      priority: NotificationPriority.medium,
      data: {
        'type': 'window_opened',
        'location': location,
      },
    );
  }

  void notifyWindowClosed({required String location}) {
    addNotification(
      title: 'Window Closed',
      message: 'Window in $location has been closed',
      type: NotificationType.info,
      priority: NotificationPriority.low,
      data: {
        'type': 'window_closed',
        'location': location,
      },
    );
  }

  void notifyWindowsLeftOpen({int count = 1}) {
    addNotification(
      title: 'Windows Left Open',
      message:
          '$count window${count > 1 ? 's' : ''} ${count > 1 ? 'are' : 'is'} still open. Consider closing for security.',
      type: NotificationType.security,
      priority: NotificationPriority.high,
      data: {
        'type': 'windows_warning',
        'count': count,
      },
    );
  }

  // Buzzer notifications
  void notifyBuzzerActivated({String? reason}) {
    addNotification(
      title: 'Buzzer Activated',
      message: reason ?? 'The buzzer has been activated',
      type: NotificationType.security,
      priority: NotificationPriority.urgent,
      data: {
        'type': 'buzzer_activated',
        if (reason != null) 'reason': reason,
      },
    );
  }

  // Light notifications
  void notifyLightStateChanged({required String location, required bool isOn}) {
    addNotification(
      title: isOn ? 'Light On' : 'Light Off',
      message: '$location light turned ${isOn ? 'on' : 'off'}',
      type: NotificationType.deviceStatus,
      priority: NotificationPriority.low,
      data: {
        'type': 'light_state',
        'location': location,
        'state': isOn ? 'on' : 'off',
      },
    );
  }

  // Night mode warnings
  void notifyOpenEntriesAtNight(
      {int doorCount = 0, int windowCount = 0, bool garageOpen = false}) {
    final List<String> openItems = [];
    if (doorCount > 0)
      openItems.add('$doorCount door${doorCount > 1 ? 's' : ''}');
    if (windowCount > 0)
      openItems.add('$windowCount window${windowCount > 1 ? 's' : ''}');
    if (garageOpen) openItems.add('garage');

    if (openItems.isEmpty) return;

    addNotification(
      title: 'Night Security Check',
      message:
          'You have ${openItems.join(', ')} still open. Secure your home before sleeping.',
      type: NotificationType.security,
      priority: NotificationPriority.urgent,
      data: {
        'type': 'night_security',
        'doors': doorCount,
        'windows': windowCount,
        'garage': garageOpen,
        'action': 'secure_home',
      },
    );
  }

  @override
  void dispose() {
    _notificationStreamController.close();
    super.dispose();
  }
}
