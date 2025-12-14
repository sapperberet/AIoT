import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

/// Service for tracking user activity and sign-ins
class UserActivityService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Record a new user sign-in activity
  Future<void> recordSignIn({
    required String userId,
    required String email,
    required String displayName,
    String? deviceInfo,
    String? ipAddress,
  }) async {
    try {
      // Create activity record
      await _firestore.collection('user_activities').add({
        'userId': userId,
        'email': email,
        'displayName': displayName,
        'activityType': 'sign_in',
        'deviceInfo': deviceInfo ?? 'Unknown device',
        'ipAddress': ipAddress ?? 'Unknown',
        'timestamp': FieldValue.serverTimestamp(),
      });

      // Update user's last sign-in
      await _firestore.collection('users').doc(userId).update({
        'lastSignIn': FieldValue.serverTimestamp(),
        'lastSignInDevice': deviceInfo ?? 'Unknown device',
      });

      debugPrint('✅ Sign-in activity recorded for: $email');
    } catch (e) {
      debugPrint('❌ Error recording sign-in activity: $e');
    }
  }

  /// Record a new user registration
  Future<void> recordNewUserRegistration({
    required String userId,
    required String email,
    required String displayName,
    String? deviceInfo,
  }) async {
    try {
      // Create activity record for new registration
      await _firestore.collection('user_activities').add({
        'userId': userId,
        'email': email,
        'displayName': displayName,
        'activityType': 'new_registration',
        'deviceInfo': deviceInfo ?? 'Unknown device',
        'timestamp': FieldValue.serverTimestamp(),
        'isNew': true, // Flag for new user detection
      });

      debugPrint('✅ New user registration recorded: $email');
    } catch (e) {
      debugPrint('❌ Error recording new user registration: $e');
    }
  }

  /// Stream of new user sign-ins (for real-time notifications)
  Stream<QuerySnapshot> watchNewUserSignIns() {
    return _firestore
        .collection('user_activities')
        .where('activityType', isEqualTo: 'new_registration')
        .orderBy('timestamp', descending: true)
        .limit(50)
        .snapshots();
  }

  /// Stream of all user activities
  Stream<QuerySnapshot> watchAllUserActivities() {
    return _firestore
        .collection('user_activities')
        .orderBy('timestamp', descending: true)
        .limit(100)
        .snapshots();
  }

  /// Get recent sign-in activities
  Future<List<Map<String, dynamic>>> getRecentSignIns({int limit = 20}) async {
    try {
      final snapshot = await _firestore
          .collection('user_activities')
          .where('activityType', isEqualTo: 'sign_in')
          .orderBy('timestamp', descending: true)
          .limit(limit)
          .get();

      return snapshot.docs
          .map((doc) => {
                'id': doc.id,
                ...doc.data(),
              })
          .toList();
    } catch (e) {
      debugPrint('❌ Error getting recent sign-ins: $e');
      return [];
    }
  }

  /// Get new user registrations (last 24 hours)
  Future<List<Map<String, dynamic>>> getNewUserRegistrations() async {
    try {
      final yesterday = DateTime.now().subtract(const Duration(hours: 24));

      final snapshot = await _firestore
          .collection('user_activities')
          .where('activityType', isEqualTo: 'new_registration')
          .where('timestamp', isGreaterThan: Timestamp.fromDate(yesterday))
          .orderBy('timestamp', descending: true)
          .get();

      return snapshot.docs
          .map((doc) => {
                'id': doc.id,
                ...doc.data(),
              })
          .toList();
    } catch (e) {
      debugPrint('❌ Error getting new user registrations: $e');
      return [];
    }
  }

  /// Check if there are unnotified new user registrations
  Future<bool> hasUnnotifiedNewUsers(String adminUserId) async {
    try {
      final lastCheck = await _getLastNotificationCheck(adminUserId);

      final snapshot = await _firestore
          .collection('user_activities')
          .where('activityType', isEqualTo: 'new_registration')
          .where('timestamp', isGreaterThan: lastCheck)
          .limit(1)
          .get();

      return snapshot.docs.isNotEmpty;
    } catch (e) {
      debugPrint('❌ Error checking unnotified new users: $e');
      return false;
    }
  }

  /// Mark new user notifications as read
  Future<void> markNewUsersNotified(String adminUserId) async {
    try {
      await _firestore.collection('admin_notifications').doc(adminUserId).set({
        'lastNewUserCheck': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('❌ Error marking new users notified: $e');
    }
  }

  /// Get last notification check timestamp
  Future<Timestamp> _getLastNotificationCheck(String adminUserId) async {
    try {
      final doc = await _firestore
          .collection('admin_notifications')
          .doc(adminUserId)
          .get();

      if (doc.exists && doc.data()?['lastNewUserCheck'] != null) {
        return doc.data()!['lastNewUserCheck'] as Timestamp;
      }
    } catch (e) {
      debugPrint('❌ Error getting last notification check: $e');
    }

    // Return timestamp from 24 hours ago as default
    return Timestamp.fromDate(
        DateTime.now().subtract(const Duration(hours: 24)));
  }
}
