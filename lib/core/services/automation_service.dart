import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/automation_model.dart';

/// Service for managing automation rules in Firestore
class AutomationService with ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  List<Automation> _automations = [];
  List<Automation> get automations => _automations;

  List<AutomationExecutionLog> _executionLogs = [];
  List<AutomationExecutionLog> get executionLogs => _executionLogs;

  StreamSubscription<QuerySnapshot>? _automationsSubscription;
  StreamSubscription<QuerySnapshot>? _logsSubscription;

  bool _isInitialized = false;
  bool get isInitialized => _isInitialized;

  /// Initialize the service and start listening to Firestore
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      debugPrint('🤖 Initializing AutomationService...');

      // Listen to automations collection
      _automationsSubscription = _firestore
          .collection('automations')
          .orderBy('createdAt', descending: true)
          .snapshots()
          .listen((snapshot) {
        _automations = snapshot.docs
            .map((doc) => Automation.fromJson({
                  ...doc.data(),
                  'id': doc.id,
                }))
            .toList();

        debugPrint('🤖 Loaded ${_automations.length} automations');
        notifyListeners();
      });

      // Listen to execution logs (last 100)
      _logsSubscription = _firestore
          .collection('automation_logs')
          .orderBy('executedAt', descending: true)
          .limit(100)
          .snapshots()
          .listen((snapshot) {
        _executionLogs = snapshot.docs
            .map((doc) => AutomationExecutionLog.fromJson({
                  ...doc.data(),
                  'id': doc.id,
                }))
            .toList();

        notifyListeners();
      });

      _isInitialized = true;
      debugPrint('✅ AutomationService initialized successfully');
    } catch (e) {
      debugPrint('❌ Failed to initialize AutomationService: $e');
    }
  }

  /// Create a new automation
  Future<String?> createAutomation(Automation automation) async {
    try {
      final docRef = await _firestore.collection('automations').add(
            automation.copyWith(id: '').toJson(),
          );

      debugPrint('✅ Created automation: ${automation.name} (${docRef.id})');
      return docRef.id;
    } catch (e) {
      debugPrint('❌ Failed to create automation: $e');
      return null;
    }
  }

  /// Update an existing automation
  Future<bool> updateAutomation(Automation automation) async {
    try {
      await _firestore
          .collection('automations')
          .doc(automation.id)
          .update(automation.toJson());

      debugPrint('✅ Updated automation: ${automation.name}');
      return true;
    } catch (e) {
      debugPrint('❌ Failed to update automation: $e');
      return false;
    }
  }

  /// Delete an automation
  Future<bool> deleteAutomation(String automationId) async {
    try {
      await _firestore.collection('automations').doc(automationId).delete();

      debugPrint('✅ Deleted automation: $automationId');
      return true;
    } catch (e) {
      debugPrint('❌ Failed to delete automation: $e');
      return false;
    }
  }

  /// Toggle automation enabled state
  Future<bool> toggleAutomation(String automationId, bool enabled) async {
    try {
      await _firestore
          .collection('automations')
          .doc(automationId)
          .update({'isEnabled': enabled});

      debugPrint('✅ Toggled automation $automationId: $enabled');
      return true;
    } catch (e) {
      debugPrint('❌ Failed to toggle automation: $e');
      return false;
    }
  }

  /// Record automation execution
  Future<void> logExecution(AutomationExecutionLog log) async {
    try {
      await _firestore
          .collection('automation_logs')
          .doc(log.id)
          .set(log.toJson());

      // Update automation last triggered time and execution count
      final automation = _automations.firstWhere(
          (a) => a.id == log.automationId,
          orElse: () => _automations.first);

      await _firestore.collection('automations').doc(log.automationId).update({
        'lastTriggered': Timestamp.fromDate(log.executedAt),
        'executionCount': automation.executionCount + 1,
      });

      debugPrint('✅ Logged automation execution: ${log.automationName}');
    } catch (e) {
      debugPrint('❌ Failed to log automation execution: $e');
    }
  }

  /// Get automation by ID
  Automation? getAutomation(String automationId) {
    try {
      return _automations.firstWhere((a) => a.id == automationId);
    } catch (e) {
      return null;
    }
  }

  /// Get enabled automations
  List<Automation> getEnabledAutomations() {
    return _automations.where((a) => a.isEnabled).toList();
  }

  /// Get automations by trigger type
  List<Automation> getAutomationsByTrigger(TriggerType triggerType) {
    return _automations
        .where(
            (a) => a.isEnabled && a.triggers.any((t) => t.type == triggerType))
        .toList();
  }

  /// Get execution logs for specific automation
  List<AutomationExecutionLog> getLogsForAutomation(String automationId) {
    return _executionLogs
        .where((log) => log.automationId == automationId)
        .toList();
  }

  /// Get recent execution logs
  List<AutomationExecutionLog> getRecentLogs({int limit = 20}) {
    return _executionLogs.take(limit).toList();
  }

  /// Clean up old logs (keep last 1000)
  Future<void> cleanupOldLogs() async {
    try {
      final snapshot = await _firestore
          .collection('automation_logs')
          .orderBy('executedAt', descending: true)
          .get();

      if (snapshot.docs.length > 1000) {
        final batch = _firestore.batch();
        for (int i = 1000; i < snapshot.docs.length; i++) {
          batch.delete(snapshot.docs[i].reference);
        }
        await batch.commit();
        debugPrint('✅ Cleaned up ${snapshot.docs.length - 1000} old logs');
      }
    } catch (e) {
      debugPrint('❌ Failed to cleanup old logs: $e');
    }
  }

  @override
  void dispose() {
    _automationsSubscription?.cancel();
    _logsSubscription?.cancel();
    super.dispose();
  }
}
