import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'notification_service.dart';

/// Background message handler - must be top-level function
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  debugPrint('🔔 Background message received: ${message.messageId}');
  // The message will be handled when the app is opened
}

/// Service for managing Firebase Cloud Messaging push notifications
class PushNotificationService {
  static final PushNotificationService _instance =
      PushNotificationService._internal();
  factory PushNotificationService() => _instance;
  PushNotificationService._internal();

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  NotificationService? _notificationService;
  String? _fcmToken;
  bool _isInitialized = false;

  String? get fcmToken => _fcmToken;
  bool get isInitialized => _isInitialized;

  /// Initialize push notifications
  Future<void> initialize(
      {required NotificationService notificationService}) async {
    if (_isInitialized) return;

    try {
      _notificationService = notificationService;

      // Set up background message handler
      FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

      // Request permission
      NotificationSettings settings = await _messaging.requestPermission(
        alert: true,
        announcement: false,
        badge: true,
        carPlay: false,
        criticalAlert: false,
        provisional: false,
        sound: true,
      );

      debugPrint(
          '🔔 Push notification permission: ${settings.authorizationStatus}');

      if (settings.authorizationStatus == AuthorizationStatus.authorized ||
          settings.authorizationStatus == AuthorizationStatus.provisional) {
        // Get FCM token
        _fcmToken = await _messaging.getToken();
        debugPrint('🔔 FCM Token: $_fcmToken');

        // Save token to Firestore for the current user
        await _saveTokenToFirestore();

        // Listen for token refresh
        _messaging.onTokenRefresh.listen(_handleTokenRefresh);

        // Handle foreground messages
        FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

        // Handle when app is opened from notification
        FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationOpened);

        // Check if app was opened from a notification
        RemoteMessage? initialMessage = await _messaging.getInitialMessage();
        if (initialMessage != null) {
          _handleNotificationOpened(initialMessage);
        }

        _isInitialized = true;
        debugPrint('✅ Push notification service initialized');
      } else {
        debugPrint('⚠️ Push notifications not authorized');
      }
    } catch (e) {
      debugPrint('❌ Error initializing push notifications: $e');
    }
  }

  /// Save FCM token to Firestore
  Future<void> _saveTokenToFirestore() async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null || _fcmToken == null) return;

      await _firestore.collection('users').doc(userId).update({
        'fcmToken': _fcmToken,
        'fcmTokenUpdatedAt': FieldValue.serverTimestamp(),
        'platform': defaultTargetPlatform.name,
      });

      debugPrint('✅ FCM token saved to Firestore');
    } catch (e) {
      debugPrint('❌ Error saving FCM token: $e');
    }
  }

  /// Handle token refresh
  void _handleTokenRefresh(String newToken) async {
    debugPrint('🔔 FCM token refreshed: $newToken');
    _fcmToken = newToken;
    await _saveTokenToFirestore();
  }

  /// Handle foreground messages
  void _handleForegroundMessage(RemoteMessage message) {
    debugPrint(
        '🔔 Foreground message received: ${message.notification?.title}');

    // Convert to AppNotification and show
    if (_notificationService != null) {
      final notification = _convertRemoteMessageToNotification(message);
      if (notification != null) {
        _notificationService!.addNotification(
          title: notification.title,
          message: notification.message,
          type: notification.type,
          priority: notification.priority,
          data: notification.data,
        );

        // Also show as system notification
        _notificationService!.showSystemNotification(
          title: notification.title,
          message: notification.message,
          payload: jsonEncode(message.data),
        );
      }
    }
  }

  /// Handle when app is opened from a notification
  void _handleNotificationOpened(RemoteMessage message) {
    debugPrint(
        '🔔 App opened from notification: ${message.notification?.title}');

    // Convert to AppNotification
    if (_notificationService != null) {
      final notification = _convertRemoteMessageToNotification(message);
      if (notification != null) {
        _notificationService!.addNotification(
          title: notification.title,
          message: notification.message,
          type: notification.type,
          priority: notification.priority,
          data: notification.data,
        );
      }
    }

    // Handle navigation based on notification data
    final data = message.data;
    if (data.containsKey('route')) {
      // Navigate to specific route - this would be handled by a navigation service
      debugPrint('Navigate to: ${data['route']}');
    }
  }

  /// Convert RemoteMessage to AppNotification
  AppNotification? _convertRemoteMessageToNotification(RemoteMessage message) {
    final notification = message.notification;
    if (notification == null) return null;

    // Determine notification type from data
    NotificationType type = NotificationType.info;
    if (message.data.containsKey('type')) {
      switch (message.data['type']) {
        case 'device':
          type = NotificationType.deviceStatus;
          break;
        case 'automation':
          type = NotificationType.automation;
          break;
        case 'security':
          type = NotificationType.security;
          break;
        default:
          type = NotificationType.info;
      }
    }

    // Determine priority
    NotificationPriority priority = NotificationPriority.medium;
    if (message.data.containsKey('priority')) {
      switch (message.data['priority']) {
        case 'high':
        case 'urgent':
          priority = NotificationPriority.high;
          break;
        case 'low':
          priority = NotificationPriority.low;
          break;
      }
    }

    return AppNotification(
      id: message.messageId ?? DateTime.now().millisecondsSinceEpoch.toString(),
      title: notification.title ?? 'Smart Home',
      message: notification.body ?? '',
      type: type,
      priority: priority,
      data: message.data,
    );
  }

  /// Subscribe to a topic for push notifications
  Future<void> subscribeToTopic(String topic) async {
    try {
      await _messaging.subscribeToTopic(topic);
      debugPrint('✅ Subscribed to topic: $topic');
    } catch (e) {
      debugPrint('❌ Error subscribing to topic: $e');
    }
  }

  /// Unsubscribe from a topic
  Future<void> unsubscribeFromTopic(String topic) async {
    try {
      await _messaging.unsubscribeFromTopic(topic);
      debugPrint('✅ Unsubscribed from topic: $topic');
    } catch (e) {
      debugPrint('❌ Error unsubscribing from topic: $e');
    }
  }

  /// Subscribe to default topics for the user
  Future<void> subscribeToDefaultTopics() async {
    await subscribeToTopic('all_users');
    await subscribeToTopic('smart_home_updates');

    // Subscribe to security alerts
    await subscribeToTopic('security_alerts');

    // Subscribe to automation alerts
    await subscribeToTopic('automation_alerts');
  }

  /// Clear FCM token when user logs out
  Future<void> clearToken() async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId != null) {
        await _firestore.collection('users').doc(userId).update({
          'fcmToken': FieldValue.delete(),
        });
      }

      await _messaging.deleteToken();
      _fcmToken = null;
      debugPrint('✅ FCM token cleared');
    } catch (e) {
      debugPrint('❌ Error clearing FCM token: $e');
    }
  }
}
