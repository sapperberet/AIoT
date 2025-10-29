import 'package:flutter/foundation.dart';
import 'dart:async';

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
  final List<AppNotification> _notifications = [];
  final StreamController<AppNotification> _notificationStreamController =
      StreamController<AppNotification>.broadcast();

  NotificationService() {
    _initializeSampleNotifications();
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

    notifyListeners();
  }

  // Mark notification as read
  void markAsRead(String notificationId) {
    final index = _notifications.indexWhere((n) => n.id == notificationId);
    if (index != -1) {
      _notifications[index] = _notifications[index].copyWith(isRead: true);
      notifyListeners();
    }
  }

  // Mark all as read
  void markAllAsRead() {
    for (int i = 0; i < _notifications.length; i++) {
      _notifications[i] = _notifications[i].copyWith(isRead: true);
    }
    notifyListeners();
  }

  // Delete notification
  void deleteNotification(String notificationId) {
    _notifications.removeWhere((n) => n.id == notificationId);
    notifyListeners();
  }

  // Clear all notifications
  void clearAll() {
    _notifications.clear();
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

  // Show local notification (placeholder - will use flutter_local_notifications)
  Future<void> _showLocalNotification(AppNotification notification) async {
    // TODO: Implement with flutter_local_notifications package
    debugPrint('Notification: ${notification.title} - ${notification.message}');
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
      title: '⚠️ Unrecognized Person Detected',
      message: 'An unrecognized person was detected at ${location ?? 'entrance'}. Tap to view camera feed.',
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
      title: '✅ Person Recognized',
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

  @override
  void dispose() {
    _notificationStreamController.close();
    super.dispose();
  }
}
