import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/sensor_data_model.dart';

/// Service for managing sensor data collection, storage, and retrieval
class SensorService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // In-memory cache for latest sensor readings
  final Map<String, SensorData> _latestReadings = {};

  // Stream controllers for real-time sensor updates
  final Map<SensorType, StreamController<SensorData>> _sensorStreamControllers =
      {};

  // Batch write buffer for performance
  final List<SensorData> _writeBuffer = [];
  Timer? _batchWriteTimer;
  static const int _batchWriteInterval = 30; // seconds
  static const int _maxBufferSize = 100;

  SensorService() {
    // Initialize stream controllers for each sensor type
    for (var type in SensorType.values) {
      _sensorStreamControllers[type] = StreamController<SensorData>.broadcast();
    }

    // Start batch write timer
    _startBatchWriteTimer();
  }

  /// Get stream for a specific sensor type
  Stream<SensorData> getSensorStream(SensorType type) {
    return _sensorStreamControllers[type]?.stream ?? const Stream.empty();
  }

  /// Get the latest reading for a sensor
  SensorData? getLatestReading(String sensorId) {
    return _latestReadings[sensorId];
  }

  /// Get the latest reading by sensor type
  SensorData? getLatestReadingByType(SensorType type) {
    return _latestReadings.values.firstWhere(
      (data) => data.type == type,
      orElse: () => SensorData(
        id: '',
        sensorId: '',
        type: type,
        value: 0,
        unit: _getDefaultUnit(type),
        timestamp: DateTime.now(),
      ),
    );
  }

  /// Process incoming sensor reading from MQTT or other sources
  Future<void> processSensorReading({
    required String sensorId,
    required SensorType type,
    required double value,
    String? unit,
    Map<String, dynamic>? metadata,
  }) async {
    final reading = SensorData(
      id: '${sensorId}_${DateTime.now().millisecondsSinceEpoch}',
      sensorId: sensorId,
      type: type,
      value: value,
      unit: unit ?? _getDefaultUnit(type),
      timestamp: DateTime.now(),
      metadata: metadata,
    );

    // Update cache
    _latestReadings[sensorId] = reading;

    // Emit to stream
    _sensorStreamControllers[type]?.add(reading);

    // Add to write buffer
    _writeBuffer.add(reading);

    // Check if buffer needs immediate flush
    if (_writeBuffer.length >= _maxBufferSize) {
      await _flushWriteBuffer();
    }

    debugPrint('📊 Sensor reading: ${type.name} = $value${reading.unit}');
  }

  /// Store sensor data to Firestore
  Future<void> storeSensorData(SensorData data) async {
    try {
      await _firestore
          .collection('sensor_data')
          .doc(data.id)
          .set(data.toJson());
      debugPrint('✅ Stored sensor data: ${data.id}');
    } catch (e) {
      debugPrint('❌ Failed to store sensor data: $e');
    }
  }

  /// Get sensor data for a time period
  Future<List<SensorData>> getSensorHistory({
    required SensorType type,
    DateTime? startTime,
    DateTime? endTime,
    int? limit,
  }) async {
    try {
      Query query = _firestore
          .collection('sensor_data')
          .where('type', isEqualTo: type.name)
          .orderBy('timestamp', descending: true);

      if (startTime != null) {
        query = query.where('timestamp',
            isGreaterThanOrEqualTo: Timestamp.fromDate(startTime));
      }

      if (endTime != null) {
        query = query.where('timestamp',
            isLessThanOrEqualTo: Timestamp.fromDate(endTime));
      }

      if (limit != null) {
        query = query.limit(limit);
      }

      final snapshot = await query.get();
      return snapshot.docs
          .map((doc) => SensorData.fromJson(doc.data() as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('❌ Failed to get sensor history: $e');
      return [];
    }
  }

  /// Get sensor statistics for a period
  Future<SensorStats> getSensorStats({
    required SensorType type,
    DateTime? startTime,
    DateTime? endTime,
  }) async {
    final readings = await getSensorHistory(
      type: type,
      startTime: startTime,
      endTime: endTime,
    );

    return SensorStats.fromReadings(
      type: type,
      readings: readings,
      unit: _getDefaultUnit(type),
    );
  }

  /// Get energy consumption data for charts
  Future<List<SensorData>> getEnergyConsumption({
    required DateTime startTime,
    required DateTime endTime,
  }) async {
    return getSensorHistory(
      type: SensorType.energy,
      startTime: startTime,
      endTime: endTime,
    );
  }

  /// Calculate total energy consumption for a period
  Future<double> getTotalEnergyConsumption({
    required DateTime startTime,
    required DateTime endTime,
  }) async {
    final readings = await getEnergyConsumption(
      startTime: startTime,
      endTime: endTime,
    );

    if (readings.isEmpty) return 0.0;

    // Sum all energy readings (assuming cumulative or integrate over time)
    return readings.fold<double>(0.0, (sum, reading) => sum + reading.value);
  }

  /// Get temperature trends
  Future<List<SensorData>> getTemperatureHistory({
    required DateTime startTime,
    required DateTime endTime,
  }) async {
    return getSensorHistory(
      type: SensorType.temperature,
      startTime: startTime,
      endTime: endTime,
    );
  }

  /// Check if gas sensor was triggered in a time period
  Future<bool> wasGasTriggered({
    required DateTime startTime,
    required DateTime endTime,
    double threshold = 300.0, // ppm threshold
  }) async {
    final readings = await getSensorHistory(
      type: SensorType.gas,
      startTime: startTime,
      endTime: endTime,
    );

    return readings.any((reading) => reading.value > threshold);
  }

  /// Get solar/LDR readings for solar panel monitoring
  Future<List<SensorData>> getSolarLightHistory({
    required DateTime startTime,
    required DateTime endTime,
  }) async {
    return getSensorHistory(
      type: SensorType.ldr,
      startTime: startTime,
      endTime: endTime,
    );
  }

  /// Start batch write timer
  void _startBatchWriteTimer() {
    _batchWriteTimer?.cancel();
    _batchWriteTimer = Timer.periodic(
      Duration(seconds: _batchWriteInterval),
      (_) => _flushWriteBuffer(),
    );
  }

  /// Flush write buffer to Firestore
  Future<void> _flushWriteBuffer() async {
    if (_writeBuffer.isEmpty) return;

    debugPrint(
        '💾 Flushing ${_writeBuffer.length} sensor readings to Firestore...');

    try {
      final batch = _firestore.batch();
      final buffer = List<SensorData>.from(_writeBuffer);
      _writeBuffer.clear();

      for (var data in buffer) {
        final docRef = _firestore.collection('sensor_data').doc(data.id);
        batch.set(docRef, data.toJson());
      }

      await batch.commit();
      debugPrint('✅ Successfully stored ${buffer.length} sensor readings');
    } catch (e) {
      debugPrint('❌ Failed to flush sensor data: $e');
      // Re-add failed writes to buffer
      _writeBuffer.addAll(_writeBuffer);
    }
  }

  /// Get default unit for sensor type
  String _getDefaultUnit(SensorType type) {
    switch (type) {
      case SensorType.temperature:
        return '°C';
      case SensorType.humidity:
        return '%';
      case SensorType.gas:
        return 'ppm';
      case SensorType.ldr:
        return 'lux';
      case SensorType.energy:
        return 'kWh';
      case SensorType.motion:
        return 'bool';
      case SensorType.smoke:
        return 'ppm';
      case SensorType.water:
        return 'bool';
      case SensorType.sound:
        return 'dB';
      case SensorType.pressure:
        return 'hPa';
      case SensorType.airQuality:
        return 'AQI';
    }
  }

  /// Clear old sensor data (cleanup job)
  Future<void> clearOldData({int daysToKeep = 30}) async {
    try {
      final cutoffDate = DateTime.now().subtract(Duration(days: daysToKeep));
      final snapshot = await _firestore
          .collection('sensor_data')
          .where('timestamp', isLessThan: Timestamp.fromDate(cutoffDate))
          .get();

      final batch = _firestore.batch();
      for (var doc in snapshot.docs) {
        batch.delete(doc.reference);
      }

      await batch.commit();
      debugPrint('🧹 Cleared ${snapshot.docs.length} old sensor readings');
    } catch (e) {
      debugPrint('❌ Failed to clear old data: $e');
    }
  }

  /// Dispose resources
  void dispose() {
    _batchWriteTimer?.cancel();
    _flushWriteBuffer();
    for (var controller in _sensorStreamControllers.values) {
      controller.close();
    }
    _sensorStreamControllers.clear();
  }
}
