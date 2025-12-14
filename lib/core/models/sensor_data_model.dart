import 'package:cloud_firestore/cloud_firestore.dart';

/// Sensor types supported by the system
enum SensorType {
  temperature,
  humidity,
  gas,
  ldr, // Light Dependent Resistor (solar/light sensor)
  energy,
  motion,
  smoke,
  water,
  sound,
  pressure,
  airQuality,
}

/// Extension to convert sensor type to/from string
extension SensorTypeExtension on SensorType {
  String get name {
    switch (this) {
      case SensorType.temperature:
        return 'temperature';
      case SensorType.humidity:
        return 'humidity';
      case SensorType.gas:
        return 'gas';
      case SensorType.ldr:
        return 'ldr';
      case SensorType.energy:
        return 'energy';
      case SensorType.motion:
        return 'motion';
      case SensorType.smoke:
        return 'smoke';
      case SensorType.water:
        return 'water';
      case SensorType.sound:
        return 'sound';
      case SensorType.pressure:
        return 'pressure';
      case SensorType.airQuality:
        return 'air_quality';
    }
  }

  static SensorType fromString(String value) {
    switch (value.toLowerCase()) {
      case 'temperature':
      case 'temp':
        return SensorType.temperature;
      case 'humidity':
        return SensorType.humidity;
      case 'gas':
        return SensorType.gas;
      case 'ldr':
      case 'light':
      case 'solar':
        return SensorType.ldr;
      case 'energy':
      case 'power':
      case 'consumption':
        return SensorType.energy;
      case 'motion':
      case 'pir':
        return SensorType.motion;
      case 'smoke':
        return SensorType.smoke;
      case 'water':
        return SensorType.water;
      case 'sound':
        return SensorType.sound;
      case 'pressure':
        return SensorType.pressure;
      case 'air_quality':
      case 'airquality':
        return SensorType.airQuality;
      default:
        return SensorType.temperature; // Default fallback
    }
  }
}

/// Model for sensor data readings
class SensorData {
  final String id;
  final String sensorId;
  final SensorType type;
  final double value;
  final String unit;
  final DateTime timestamp;
  final Map<String, dynamic>? metadata;

  SensorData({
    required this.id,
    required this.sensorId,
    required this.type,
    required this.value,
    required this.unit,
    required this.timestamp,
    this.metadata,
  });

  /// Create from JSON
  factory SensorData.fromJson(Map<String, dynamic> json) {
    return SensorData(
      id: json['id'] as String? ?? '',
      sensorId:
          json['sensorId'] as String? ?? json['sensor_id'] as String? ?? '',
      type: SensorTypeExtension.fromString(
          json['type'] as String? ?? 'temperature'),
      value: (json['value'] as num?)?.toDouble() ?? 0.0,
      unit: json['unit'] as String? ?? '',
      timestamp: (json['timestamp'] as Timestamp?)?.toDate() ??
          (json['timestamp'] != null
              ? DateTime.parse(json['timestamp'] as String)
              : DateTime.now()),
      metadata: json['metadata'] as Map<String, dynamic>?,
    );
  }

  /// Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'sensorId': sensorId,
      'type': type.name,
      'value': value,
      'unit': unit,
      'timestamp': Timestamp.fromDate(timestamp),
      if (metadata != null) 'metadata': metadata,
    };
  }

  /// Create a copy with updated values
  SensorData copyWith({
    String? id,
    String? sensorId,
    SensorType? type,
    double? value,
    String? unit,
    DateTime? timestamp,
    Map<String, dynamic>? metadata,
  }) {
    return SensorData(
      id: id ?? this.id,
      sensorId: sensorId ?? this.sensorId,
      type: type ?? this.type,
      value: value ?? this.value,
      unit: unit ?? this.unit,
      timestamp: timestamp ?? this.timestamp,
      metadata: metadata ?? this.metadata,
    );
  }

  @override
  String toString() {
    return 'SensorData(id: $id, type: ${type.name}, value: $value$unit, time: $timestamp)';
  }
}

/// Aggregated sensor statistics for charts and displays
class SensorStats {
  final SensorType type;
  final double currentValue;
  final double minValue;
  final double maxValue;
  final double avgValue;
  final String unit;
  final DateTime periodStart;
  final DateTime periodEnd;
  final List<SensorData> readings;

  SensorStats({
    required this.type,
    required this.currentValue,
    required this.minValue,
    required this.maxValue,
    required this.avgValue,
    required this.unit,
    required this.periodStart,
    required this.periodEnd,
    required this.readings,
  });

  /// Calculate stats from a list of sensor data
  factory SensorStats.fromReadings({
    required SensorType type,
    required List<SensorData> readings,
    required String unit,
  }) {
    if (readings.isEmpty) {
      final now = DateTime.now();
      return SensorStats(
        type: type,
        currentValue: 0,
        minValue: 0,
        maxValue: 0,
        avgValue: 0,
        unit: unit,
        periodStart: now,
        periodEnd: now,
        readings: [],
      );
    }

    final values = readings.map((r) => r.value).toList();
    final current = readings.last.value;
    final min = values.reduce((a, b) => a < b ? a : b);
    final max = values.reduce((a, b) => a > b ? a : b);
    final avg = values.reduce((a, b) => a + b) / values.length;

    return SensorStats(
      type: type,
      currentValue: current,
      minValue: min,
      maxValue: max,
      avgValue: avg,
      unit: unit,
      periodStart: readings.first.timestamp,
      periodEnd: readings.last.timestamp,
      readings: readings,
    );
  }

  @override
  String toString() {
    return 'SensorStats(type: ${type.name}, current: $currentValue$unit, avg: ${avgValue.toStringAsFixed(1)}$unit)';
  }
}
