import 'package:cloud_firestore/cloud_firestore.dart';

enum DeviceType {
  light,
  alarm,
  sensor,
  camera,
  thermostat,
  lock,
  door,
  window,
  garage,
  buzzer,
}

enum DeviceStatus {
  online,
  offline,
  error,
}

/// State for doors, windows, garage
enum OpenCloseState {
  open,
  closed,
  opening,
  closing,
  unknown,
}

/// Converts string to OpenCloseState
OpenCloseState parseOpenCloseState(String? state) {
  if (state == null) return OpenCloseState.unknown;
  switch (state.toLowerCase()) {
    case 'open':
      return OpenCloseState.open;
    case 'closed':
      return OpenCloseState.closed;
    case 'opening':
      return OpenCloseState.opening;
    case 'closing':
      return OpenCloseState.closing;
    default:
      return OpenCloseState.unknown;
  }
}

class Device {
  final String id;
  final String name;
  final DeviceType type;
  final String room;
  final DeviceStatus status;
  final Map<String, dynamic> state;
  final DateTime lastUpdated;

  Device({
    required this.id,
    required this.name,
    required this.type,
    required this.room,
    required this.status,
    required this.state,
    required this.lastUpdated,
  });

  factory Device.fromJson(Map<String, dynamic> json) {
    return Device(
      id: json['id'] as String,
      name: json['name'] as String,
      type: DeviceType.values.firstWhere(
        (e) => e.toString() == 'DeviceType.${json['type']}',
        orElse: () => DeviceType.sensor,
      ),
      room: json['room'] as String,
      status: DeviceStatus.values.firstWhere(
        (e) => e.toString() == 'DeviceStatus.${json['status']}',
        orElse: () => DeviceStatus.offline,
      ),
      state: json['state'] as Map<String, dynamic>? ?? {},
      lastUpdated:
          (json['lastUpdated'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'type': type.toString().split('.').last,
      'room': room,
      'status': status.toString().split('.').last,
      'state': state,
      'lastUpdated': Timestamp.fromDate(lastUpdated),
    };
  }

  Device copyWith({
    String? id,
    String? name,
    DeviceType? type,
    String? room,
    DeviceStatus? status,
    Map<String, dynamic>? state,
    DateTime? lastUpdated,
  }) {
    return Device(
      id: id ?? this.id,
      name: name ?? this.name,
      type: type ?? this.type,
      room: room ?? this.room,
      status: status ?? this.status,
      state: state ?? this.state,
      lastUpdated: lastUpdated ?? this.lastUpdated,
    );
  }

  /// Helper getters for specific device types
  bool get isLight => type == DeviceType.light;
  bool get isDoor => type == DeviceType.door;
  bool get isWindow => type == DeviceType.window;
  bool get isGarage => type == DeviceType.garage;
  bool get isBuzzer => type == DeviceType.buzzer;
  bool get isLock => type == DeviceType.lock;

  /// Get the open/close state for doors, windows, garage
  OpenCloseState get openCloseState {
    if (type != DeviceType.door &&
        type != DeviceType.window &&
        type != DeviceType.garage) {
      return OpenCloseState.unknown;
    }
    return parseOpenCloseState(state['state'] as String?);
  }

  /// Check if door/window/garage is open
  bool get isOpen => openCloseState == OpenCloseState.open;

  /// Check if door/window/garage is closed
  bool get isClosed => openCloseState == OpenCloseState.closed;

  /// Check if light is on
  bool get isLightOn => type == DeviceType.light && state['state'] == 'on';

  /// Check if buzzer is active
  bool get isBuzzerActive =>
      type == DeviceType.buzzer && state['active'] == true;

  /// Get light brightness (0-100)
  int get brightness => (state['brightness'] as num?)?.toInt() ?? 100;
}

class AlarmEvent {
  final String id;
  final String location;
  final String type; // fire, motion, door, etc.
  final String severity; // critical, warning, info
  final String message;
  final DateTime timestamp;
  final bool acknowledged;

  AlarmEvent({
    required this.id,
    required this.location,
    required this.type,
    required this.severity,
    required this.message,
    required this.timestamp,
    this.acknowledged = false,
  });

  factory AlarmEvent.fromJson(Map<String, dynamic> json) {
    return AlarmEvent(
      id: json['id'] as String,
      location: json['location'] as String,
      type: json['type'] as String,
      severity: json['severity'] as String,
      message: json['message'] as String,
      timestamp: (json['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
      acknowledged: json['acknowledged'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'location': location,
      'type': type,
      'severity': severity,
      'message': message,
      'timestamp': Timestamp.fromDate(timestamp),
      'acknowledged': acknowledged,
    };
  }
}
