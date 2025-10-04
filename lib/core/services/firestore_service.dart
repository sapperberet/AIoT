import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:logger/logger.dart';
import '../models/device_model.dart';

class FirestoreService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final Logger _logger = Logger();

  // Collections
  String get devicesCollection => 'devices';
  String get alarmsCollection => 'alarms';
  String get logsCollection => 'logs';

  // Get all devices for a user
  Stream<List<Device>> getDevicesStream(String userId) {
    return _firestore
        .collection('users')
        .doc(userId)
        .collection(devicesCollection)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => Device.fromJson({...doc.data(), 'id': doc.id}))
            .toList());
  }

  // Get device by ID
  Future<Device?> getDevice(String userId, String deviceId) async {
    try {
      final doc = await _firestore
          .collection('users')
          .doc(userId)
          .collection(devicesCollection)
          .doc(deviceId)
          .get();

      if (doc.exists) {
        return Device.fromJson({...doc.data()!, 'id': doc.id});
      }
      return null;
    } catch (e) {
      _logger.e('Error getting device: $e');
      return null;
    }
  }

  // Update device state
  Future<void> updateDeviceState(
    String userId,
    String deviceId,
    Map<String, dynamic> state,
  ) async {
    try {
      await _firestore
          .collection('users')
          .doc(userId)
          .collection(devicesCollection)
          .doc(deviceId)
          .update({
        'state': state,
        'lastUpdated': FieldValue.serverTimestamp(),
      });
      _logger.i('Device state updated: $deviceId');
    } catch (e) {
      _logger.e('Error updating device state: $e');
      rethrow;
    }
  }

  // Send command to device (for cloud control)
  Future<void> sendDeviceCommand(
    String userId,
    String deviceId,
    Map<String, dynamic> command,
  ) async {
    try {
      await _firestore
          .collection('users')
          .doc(userId)
          .collection(devicesCollection)
          .doc(deviceId)
          .collection('commands')
          .add({
        ...command,
        'timestamp': FieldValue.serverTimestamp(),
        'executed': false,
      });
      _logger.i('Command sent to device: $deviceId');
    } catch (e) {
      _logger.e('Error sending command: $e');
      rethrow;
    }
  }

  // Listen for device commands (ESP32 will use this)
  Stream<QuerySnapshot> listenForCommands(String userId, String deviceId) {
    return _firestore
        .collection('users')
        .doc(userId)
        .collection(devicesCollection)
        .doc(deviceId)
        .collection('commands')
        .where('executed', isEqualTo: false)
        .orderBy('timestamp')
        .snapshots();
  }

  // Mark command as executed
  Future<void> markCommandExecuted(
    String userId,
    String deviceId,
    String commandId,
  ) async {
    try {
      await _firestore
          .collection('users')
          .doc(userId)
          .collection(devicesCollection)
          .doc(deviceId)
          .collection('commands')
          .doc(commandId)
          .update({'executed': true});
    } catch (e) {
      _logger.e('Error marking command as executed: $e');
    }
  }

  // Get alarms stream
  Stream<List<AlarmEvent>> getAlarmsStream(String userId) {
    return _firestore
        .collection('users')
        .doc(userId)
        .collection(alarmsCollection)
        .orderBy('timestamp', descending: true)
        .limit(100)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => AlarmEvent.fromJson({...doc.data(), 'id': doc.id}))
            .toList());
  }

  // Add alarm event
  Future<void> addAlarmEvent(String userId, AlarmEvent alarm) async {
    try {
      await _firestore
          .collection('users')
          .doc(userId)
          .collection(alarmsCollection)
          .add(alarm.toJson());
      _logger.i('Alarm event added: ${alarm.type} at ${alarm.location}');
    } catch (e) {
      _logger.e('Error adding alarm: $e');
    }
  }

  // Acknowledge alarm
  Future<void> acknowledgeAlarm(String userId, String alarmId) async {
    try {
      await _firestore
          .collection('users')
          .doc(userId)
          .collection(alarmsCollection)
          .doc(alarmId)
          .update({'acknowledged': true});
    } catch (e) {
      _logger.e('Error acknowledging alarm: $e');
    }
  }

  // Log an event
  Future<void> logEvent(
      String userId, String event, Map<String, dynamic> data) async {
    try {
      await _firestore
          .collection('users')
          .doc(userId)
          .collection(logsCollection)
          .add({
        'event': event,
        'data': data,
        'timestamp': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      _logger.e('Error logging event: $e');
    }
  }

  // Get logs stream
  Stream<QuerySnapshot> getLogsStream(String userId, {int limit = 50}) {
    return _firestore
        .collection('users')
        .doc(userId)
        .collection(logsCollection)
        .orderBy('timestamp', descending: true)
        .limit(limit)
        .snapshots();
  }
}
