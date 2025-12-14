import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:logger/logger.dart';

/// Event types for smart home logging
enum EventType {
  // Device events
  deviceStateChanged,
  deviceOnline,
  deviceOffline,

  // Security events
  doorOpened,
  doorClosed,
  windowOpened,
  windowClosed,
  garageOpened,
  garageClosed,

  // Alarm events
  alarmTriggered,
  alarmAcknowledged,
  alarmCleared,
  buzzerActivated,
  buzzerDeactivated,

  // Light events
  lightTurnedOn,
  lightTurnedOff,
  lightBrightnessChanged,

  // Fan events
  fanSpeedChanged,
  fanTurnedOn,
  fanTurnedOff,

  // Access events
  personRecognized,
  personUnrecognized,
  accessGranted,
  accessDenied,

  // System events
  systemStarted,
  systemStopped,
  connectionLost,
  connectionRestored,
  automationTriggered,
}

/// Severity levels for events
enum EventSeverity {
  info,
  warning,
  critical,
}

/// Model class for a logged event
class EventLog {
  final String id;
  final EventType type;
  final EventSeverity severity;
  final String title;
  final String description;
  final String? deviceId;
  final String? deviceName;
  final String? location;
  final Map<String, dynamic>? metadata;
  final DateTime timestamp;
  final bool isRead;

  EventLog({
    required this.id,
    required this.type,
    required this.severity,
    required this.title,
    required this.description,
    this.deviceId,
    this.deviceName,
    this.location,
    this.metadata,
    DateTime? timestamp,
    this.isRead = false,
  }) : timestamp = timestamp ?? DateTime.now();

  factory EventLog.fromJson(Map<String, dynamic> json) {
    return EventLog(
      id: json['id'] as String? ?? '',
      type: EventType.values.firstWhere(
        (e) => e.name == json['type'],
        orElse: () => EventType.deviceStateChanged,
      ),
      severity: EventSeverity.values.firstWhere(
        (e) => e.name == json['severity'],
        orElse: () => EventSeverity.info,
      ),
      title: json['title'] as String? ?? '',
      description: json['description'] as String? ?? '',
      deviceId: json['deviceId'] as String?,
      deviceName: json['deviceName'] as String?,
      location: json['location'] as String?,
      metadata: json['metadata'] as Map<String, dynamic>?,
      timestamp: (json['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
      isRead: json['isRead'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type.name,
      'severity': severity.name,
      'title': title,
      'description': description,
      'deviceId': deviceId,
      'deviceName': deviceName,
      'location': location,
      'metadata': metadata,
      'timestamp': Timestamp.fromDate(timestamp),
      'isRead': isRead,
    };
  }

  EventLog copyWith({
    String? id,
    EventType? type,
    EventSeverity? severity,
    String? title,
    String? description,
    String? deviceId,
    String? deviceName,
    String? location,
    Map<String, dynamic>? metadata,
    DateTime? timestamp,
    bool? isRead,
  }) {
    return EventLog(
      id: id ?? this.id,
      type: type ?? this.type,
      severity: severity ?? this.severity,
      title: title ?? this.title,
      description: description ?? this.description,
      deviceId: deviceId ?? this.deviceId,
      deviceName: deviceName ?? this.deviceName,
      location: location ?? this.location,
      metadata: metadata ?? this.metadata,
      timestamp: timestamp ?? this.timestamp,
      isRead: isRead ?? this.isRead,
    );
  }

  /// Check if this is a security-related event
  bool get isSecurityEvent {
    return type == EventType.doorOpened ||
        type == EventType.doorClosed ||
        type == EventType.windowOpened ||
        type == EventType.windowClosed ||
        type == EventType.garageOpened ||
        type == EventType.garageClosed ||
        type == EventType.personRecognized ||
        type == EventType.personUnrecognized ||
        type == EventType.accessGranted ||
        type == EventType.accessDenied ||
        type == EventType.alarmTriggered ||
        type == EventType.buzzerActivated;
  }

  /// Get icon name for this event type
  String get iconName {
    switch (type) {
      case EventType.doorOpened:
      case EventType.doorClosed:
        return 'door';
      case EventType.windowOpened:
      case EventType.windowClosed:
        return 'window';
      case EventType.garageOpened:
      case EventType.garageClosed:
        return 'garage';
      case EventType.lightTurnedOn:
      case EventType.lightTurnedOff:
      case EventType.lightBrightnessChanged:
        return 'light';
      case EventType.buzzerActivated:
      case EventType.buzzerDeactivated:
        return 'buzzer';
      case EventType.alarmTriggered:
      case EventType.alarmAcknowledged:
      case EventType.alarmCleared:
        return 'alarm';
      case EventType.personRecognized:
      case EventType.personUnrecognized:
      case EventType.accessGranted:
      case EventType.accessDenied:
        return 'person';
      default:
        return 'device';
    }
  }
}

/// Service for logging and retrieving events from Firebase
class EventLogService with ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final Logger _logger = Logger();

  static const String _eventsCollection = 'events';
  static const int _maxEventsToKeep = 1000;

  /// Log a new event to Firebase
  Future<void> logEvent({
    required String userId,
    required EventType type,
    required String title,
    required String description,
    EventSeverity severity = EventSeverity.info,
    String? deviceId,
    String? deviceName,
    String? location,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      final eventId = DateTime.now().millisecondsSinceEpoch.toString();
      final event = EventLog(
        id: eventId,
        type: type,
        severity: severity,
        title: title,
        description: description,
        deviceId: deviceId,
        deviceName: deviceName,
        location: location,
        metadata: metadata,
      );

      await _firestore
          .collection('users')
          .doc(userId)
          .collection(_eventsCollection)
          .doc(eventId)
          .set(event.toJson());

      _logger.i('Event logged: ${type.name} - $title');

      // Cleanup old events if needed
      _cleanupOldEvents(userId);
    } catch (e) {
      _logger.e('Error logging event: $e');
    }
  }

  /// Log door state change
  Future<void> logDoorEvent({
    required String userId,
    required bool isOpen,
    required String location,
    String? triggeredBy,
  }) async {
    await logEvent(
      userId: userId,
      type: isOpen ? EventType.doorOpened : EventType.doorClosed,
      title: isOpen ? '🚪 Door Opened' : '🚪 Door Closed',
      description:
          '${location.toUpperCase()} door ${isOpen ? 'opened' : 'closed'}${triggeredBy != null ? ' by $triggeredBy' : ''}',
      severity: isOpen ? EventSeverity.warning : EventSeverity.info,
      location: location,
      metadata: {
        'state': isOpen ? 'open' : 'closed',
        'triggeredBy': triggeredBy,
      },
    );
  }

  /// Log window state change
  Future<void> logWindowEvent({
    required String userId,
    required bool isOpen,
    required String location,
  }) async {
    await logEvent(
      userId: userId,
      type: isOpen ? EventType.windowOpened : EventType.windowClosed,
      title: isOpen ? '🪟 Window Opened' : '🪟 Window Closed',
      description:
          '${location.toUpperCase()} window ${isOpen ? 'opened' : 'closed'}',
      severity: isOpen ? EventSeverity.warning : EventSeverity.info,
      location: location,
      metadata: {'state': isOpen ? 'open' : 'closed'},
    );
  }

  /// Log garage state change
  Future<void> logGarageEvent({
    required String userId,
    required bool isOpen,
  }) async {
    await logEvent(
      userId: userId,
      type: isOpen ? EventType.garageOpened : EventType.garageClosed,
      title: isOpen ? '🚗 Garage Opened' : '🚗 Garage Closed',
      description: 'Garage door ${isOpen ? 'opened' : 'closed'}',
      severity: isOpen ? EventSeverity.warning : EventSeverity.info,
      location: 'garage',
      metadata: {'state': isOpen ? 'open' : 'closed'},
    );
  }

  /// Log light state change
  Future<void> logLightEvent({
    required String userId,
    required bool isOn,
    required String location,
    int? brightness,
  }) async {
    await logEvent(
      userId: userId,
      type: isOn ? EventType.lightTurnedOn : EventType.lightTurnedOff,
      title: isOn ? '💡 Light On' : '💡 Light Off',
      description:
          '${location.toUpperCase()} light turned ${isOn ? 'on' : 'off'}${brightness != null ? ' at $brightness%' : ''}',
      severity: EventSeverity.info,
      location: location,
      metadata: {
        'state': isOn ? 'on' : 'off',
        if (brightness != null) 'brightness': brightness,
      },
    );
  }

  /// Log fan state change
  Future<void> logFanEvent({
    required String userId,
    required int speed,
    required String location,
  }) async {
    final speedLabels = ['Off', 'Low', 'Medium', 'High'];
    final isOn = speed > 0;
    await logEvent(
      userId: userId,
      type: isOn ? EventType.fanTurnedOn : EventType.fanTurnedOff,
      title: 'Fan ${speedLabels[speed]}',
      description:
          '${location.toUpperCase()} fan set to ${speedLabels[speed].toLowerCase()}',
      severity: EventSeverity.info,
      location: location,
      deviceId: 'fan_$location',
      metadata: {
        'speed': speed,
        'speedLabel': speedLabels[speed].toLowerCase(),
      },
    );
  }

  /// Log buzzer state change
  Future<void> logBuzzerEvent({
    required String userId,
    required bool isActive,
    String? reason,
  }) async {
    await logEvent(
      userId: userId,
      type: isActive ? EventType.buzzerActivated : EventType.buzzerDeactivated,
      title: isActive ? '🔔 Buzzer Activated' : '🔔 Buzzer Deactivated',
      description:
          'Buzzer ${isActive ? 'activated' : 'deactivated'}${reason != null ? ': $reason' : ''}',
      severity: isActive ? EventSeverity.critical : EventSeverity.info,
      metadata: {
        'state': isActive ? 'active' : 'inactive',
        if (reason != null) 'reason': reason,
      },
    );
  }

  /// Log alarm event
  Future<void> logAlarmEvent({
    required String userId,
    required String alarmType,
    required String location,
    required String message,
    EventSeverity severity = EventSeverity.critical,
  }) async {
    await logEvent(
      userId: userId,
      type: EventType.alarmTriggered,
      title: '🚨 Alarm: $alarmType',
      description: message,
      severity: severity,
      location: location,
      metadata: {'alarmType': alarmType},
    );
  }

  /// Log person detection event
  Future<void> logPersonEvent({
    required String userId,
    required bool recognized,
    String? personName,
    required String location,
  }) async {
    await logEvent(
      userId: userId,
      type: recognized
          ? EventType.personRecognized
          : EventType.personUnrecognized,
      title: recognized ? '✅ Person Recognized' : '⚠️ Unknown Person',
      description: recognized
          ? '$personName detected at $location'
          : 'Unrecognized person detected at $location',
      severity: recognized ? EventSeverity.info : EventSeverity.critical,
      location: location,
      metadata: {
        'recognized': recognized,
        if (personName != null) 'personName': personName,
      },
    );
  }

  /// Get events stream with optional filters
  Stream<List<EventLog>> getEventsStream(
    String userId, {
    EventType? typeFilter,
    EventSeverity? severityFilter,
    String? locationFilter,
    DateTime? startDate,
    DateTime? endDate,
    int limit = 100,
  }) {
    Query query = _firestore
        .collection('users')
        .doc(userId)
        .collection(_eventsCollection)
        .orderBy('timestamp', descending: true);

    if (typeFilter != null) {
      query = query.where('type', isEqualTo: typeFilter.name);
    }

    if (severityFilter != null) {
      query = query.where('severity', isEqualTo: severityFilter.name);
    }

    if (locationFilter != null) {
      query = query.where('location', isEqualTo: locationFilter);
    }

    if (startDate != null) {
      query = query.where('timestamp',
          isGreaterThanOrEqualTo: Timestamp.fromDate(startDate));
    }

    if (endDate != null) {
      query = query.where('timestamp',
          isLessThanOrEqualTo: Timestamp.fromDate(endDate));
    }

    query = query.limit(limit);

    return query.snapshots().map((snapshot) => snapshot.docs
        .map((doc) => EventLog.fromJson(
            {...doc.data() as Map<String, dynamic>, 'id': doc.id}))
        .toList());
  }

  /// Get security events only
  /// Uses client-side filtering to avoid Firestore composite index requirements
  Stream<List<EventLog>> getSecurityEventsStream(String userId,
      {int limit = 50}) {
    // Fetch more events and filter client-side to avoid composite index issues
    final securityTypes = {
      EventType.doorOpened.name,
      EventType.doorClosed.name,
      EventType.windowOpened.name,
      EventType.windowClosed.name,
      EventType.garageOpened.name,
      EventType.garageClosed.name,
      EventType.personRecognized.name,
      EventType.personUnrecognized.name,
      EventType.alarmTriggered.name,
      EventType.accessGranted.name,
      EventType.accessDenied.name,
    };

    return _firestore
        .collection('users')
        .doc(userId)
        .collection(_eventsCollection)
        .orderBy('timestamp', descending: true)
        .limit(limit * 3) // Fetch more to ensure we get enough security events
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => EventLog.fromJson({...doc.data(), 'id': doc.id}))
            .where((event) => securityTypes.contains(event.type.name))
            .take(limit)
            .toList());
  }

  /// Search events by text
  Future<List<EventLog>> searchEvents(
    String userId,
    String searchQuery, {
    int limit = 50,
  }) async {
    try {
      // Firestore doesn't support full-text search natively
      // We'll fetch recent events and filter client-side
      final snapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection(_eventsCollection)
          .orderBy('timestamp', descending: true)
          .limit(500) // Fetch more to filter
          .get();

      final query = searchQuery.toLowerCase();
      return snapshot.docs
          .map((doc) => EventLog.fromJson({...doc.data(), 'id': doc.id}))
          .where((event) =>
              event.title.toLowerCase().contains(query) ||
              event.description.toLowerCase().contains(query) ||
              (event.location?.toLowerCase().contains(query) ?? false) ||
              (event.deviceName?.toLowerCase().contains(query) ?? false))
          .take(limit)
          .toList();
    } catch (e) {
      _logger.e('Error searching events: $e');
      return [];
    }
  }

  /// Mark event as read
  Future<void> markEventAsRead(String userId, String eventId) async {
    try {
      await _firestore
          .collection('users')
          .doc(userId)
          .collection(_eventsCollection)
          .doc(eventId)
          .update({'isRead': true});
    } catch (e) {
      _logger.e('Error marking event as read: $e');
    }
  }

  /// Mark all events as read
  Future<void> markAllEventsAsRead(String userId) async {
    try {
      final batch = _firestore.batch();
      final snapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection(_eventsCollection)
          .where('isRead', isEqualTo: false)
          .get();

      for (var doc in snapshot.docs) {
        batch.update(doc.reference, {'isRead': true});
      }

      await batch.commit();
    } catch (e) {
      _logger.e('Error marking all events as read: $e');
    }
  }

  /// Delete an event
  Future<void> deleteEvent(String userId, String eventId) async {
    try {
      await _firestore
          .collection('users')
          .doc(userId)
          .collection(_eventsCollection)
          .doc(eventId)
          .delete();
    } catch (e) {
      _logger.e('Error deleting event: $e');
    }
  }

  /// Cleanup old events to prevent storage bloat
  Future<void> _cleanupOldEvents(String userId) async {
    try {
      final snapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection(_eventsCollection)
          .orderBy('timestamp', descending: true)
          .get();

      if (snapshot.docs.length > _maxEventsToKeep) {
        final docsToDelete = snapshot.docs.skip(_maxEventsToKeep);
        final batch = _firestore.batch();

        for (var doc in docsToDelete) {
          batch.delete(doc.reference);
        }

        await batch.commit();
        _logger.i('Cleaned up ${docsToDelete.length} old events');
      }
    } catch (e) {
      _logger.e('Error cleaning up old events: $e');
    }
  }

  /// Get unread event count
  Future<int> getUnreadEventCount(String userId) async {
    try {
      final snapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection(_eventsCollection)
          .where('isRead', isEqualTo: false)
          .count()
          .get();

      return snapshot.count ?? 0;
    } catch (e) {
      _logger.e('Error getting unread count: $e');
      return 0;
    }
  }

  /// Export events for a date range (for backup/analysis)
  Future<List<EventLog>> exportEvents(
    String userId, {
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    try {
      final snapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection(_eventsCollection)
          .where('timestamp',
              isGreaterThanOrEqualTo: Timestamp.fromDate(startDate))
          .where('timestamp', isLessThanOrEqualTo: Timestamp.fromDate(endDate))
          .orderBy('timestamp', descending: true)
          .get();

      return snapshot.docs
          .map((doc) => EventLog.fromJson({...doc.data(), 'id': doc.id}))
          .toList();
    } catch (e) {
      _logger.e('Error exporting events: $e');
      return [];
    }
  }

  /// Seed sample events for testing purposes
  Future<void> seedSampleEvents(String userId) async {
    try {
      _logger.i('Seeding sample events for testing...');

      // Seed sample events of different types
      await logDoorEvent(
        userId: userId,
        isOpen: true,
        location: 'Front Door',
        triggeredBy: 'Motion sensor',
      );

      await Future.delayed(const Duration(milliseconds: 100));

      await logWindowEvent(
        userId: userId,
        isOpen: false,
        location: 'Living Room',
      );

      await Future.delayed(const Duration(milliseconds: 100));

      await logLightEvent(
        userId: userId,
        isOn: true,
        location: 'Kitchen',
        brightness: 80,
      );

      await Future.delayed(const Duration(milliseconds: 100));

      await logAlarmEvent(
        userId: userId,
        alarmType: 'Motion',
        location: 'Backyard',
        message: 'Motion detected in backyard',
        severity: EventSeverity.warning,
      );

      await Future.delayed(const Duration(milliseconds: 100));

      await logPersonEvent(
        userId: userId,
        recognized: true,
        personName: 'John',
        location: 'Front Door',
      );

      await Future.delayed(const Duration(milliseconds: 100));

      await logGarageEvent(
        userId: userId,
        isOpen: false,
      );

      _logger.i('Sample events seeded successfully');
    } catch (e) {
      _logger.e('Error seeding sample events: $e');
    }
  }
}
