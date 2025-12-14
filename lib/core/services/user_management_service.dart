import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/access_level.dart';

/// Model for user account information
class UserAccount {
  final String uid;
  final String email;
  final String displayName;
  final DateTime createdAt;
  final DateTime? lastSignIn;
  final String? lastSignInDevice;
  final AccessLevel accessLevel;
  final bool isApproved;
  final bool isBanned;
  final String? banReason;
  final DateTime? bannedAt;
  final String? bannedBy;
  final int signInCount;

  UserAccount({
    required this.uid,
    required this.email,
    required this.displayName,
    required this.createdAt,
    this.lastSignIn,
    this.lastSignInDevice,
    this.accessLevel = AccessLevel.pending,
    this.isApproved = false,
    this.isBanned = false,
    this.banReason,
    this.bannedAt,
    this.bannedBy,
    this.signInCount = 0,
  });

  // Legacy compatibility
  bool get isAdmin => accessLevel == AccessLevel.high;

  factory UserAccount.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    return UserAccount(
      uid: doc.id,
      email: data['email'] ?? '',
      displayName: data['displayName'] ?? 'Unknown User',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      lastSignIn: (data['lastSignIn'] as Timestamp?)?.toDate(),
      lastSignInDevice: data['lastSignInDevice'],
      accessLevel: AccessLevelExtension.fromString(data['accessLevel'] as String?),
      isApproved: data['isApproved'] ?? false,
      isBanned: data['isBanned'] ?? false,
      banReason: data['banReason'],
      bannedAt: (data['bannedAt'] as Timestamp?)?.toDate(),
      bannedBy: data['bannedBy'],
      signInCount: data['signInCount'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'uid': uid,
      'email': email,
      'displayName': displayName,
      'createdAt': Timestamp.fromDate(createdAt),
      'lastSignIn': lastSignIn != null ? Timestamp.fromDate(lastSignIn!) : null,
      'lastSignInDevice': lastSignInDevice,
      'accessLevel': accessLevel.toStorageString(),
      'isApproved': isApproved,
      'isBanned': isBanned,
      'banReason': banReason,
      'bannedAt': bannedAt != null ? Timestamp.fromDate(bannedAt!) : null,
      'bannedBy': bannedBy,
      'signInCount': signInCount,
    };
  }

  bool get isNewUser {
    final now = DateTime.now();
    final difference = now.difference(createdAt);
    return difference.inHours < 24;
  }

  bool get isSuspicious {
    // Flag as suspicious if:
    // 1. Created very recently (< 1 hour) with multiple sign-ins
    // 2. No recent activity but many sign-ins
    final now = DateTime.now();
    final accountAge = now.difference(createdAt);

    if (accountAge.inHours < 1 && signInCount > 5) {
      return true;
    }

    if (lastSignIn != null) {
      final lastActivityAge = now.difference(lastSignIn!);
      if (lastActivityAge.inDays > 7 && signInCount > 10) {
        return true;
      }
    }

    return false;
  }
}

/// Service for managing user accounts (admin functions)
class UserManagementService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Get all user accounts
  Future<List<UserAccount>> getAllUsers() async {
    try {
      final snapshot = await _firestore
          .collection('users')
          .orderBy('createdAt', descending: true)
          .get();

      return snapshot.docs
          .map((doc) => UserAccount.fromFirestore(doc))
          .toList();
    } catch (e) {
      debugPrint('❌ Error getting all users: $e');
      return [];
    }
  }

  /// Stream all users for real-time updates
  Stream<List<UserAccount>> watchAllUsers() {
    return _firestore
        .collection('users')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => UserAccount.fromFirestore(doc))
            .toList());
  }

  /// Get user by ID
  Future<UserAccount?> getUserById(String userId) async {
    try {
      final doc = await _firestore.collection('users').doc(userId).get();
      if (doc.exists) {
        return UserAccount.fromFirestore(doc);
      }
      return null;
    } catch (e) {
      debugPrint('❌ Error getting user by ID: $e');
      return null;
    }
  }

  /// Check if user is admin (high access level)
  Future<bool> isUserAdmin(String userId) async {
    try {
      final doc = await _firestore.collection('users').doc(userId).get();
      if (doc.exists) {
        final data = doc.data();
        final accessLevel = AccessLevelExtension.fromString(data?['accessLevel'] as String?);
        return accessLevel == AccessLevel.high;
      }
      return false;
    } catch (e) {
      debugPrint('❌ Error checking admin status: $e');
      return false;
    }
  }

  /// Get user's access level
  Future<AccessLevel> getUserAccessLevel(String userId) async {
    try {
      final doc = await _firestore.collection('users').doc(userId).get();
      if (doc.exists) {
        final data = doc.data();
        return AccessLevelExtension.fromString(data?['accessLevel'] as String?);
      }
      return AccessLevel.pending;
    } catch (e) {
      debugPrint('❌ Error getting access level: $e');
      return AccessLevel.pending;
    }
  }

  /// Ban a user
  Future<bool> banUser({
    required String userId,
    required String bannedByUserId,
    required String reason,
  }) async {
    try {
      await _firestore.collection('users').doc(userId).update({
        'isBanned': true,
        'banReason': reason,
        'bannedAt': FieldValue.serverTimestamp(),
        'bannedBy': bannedByUserId,
      });

      // Log the ban action
      await _firestore.collection('admin_actions').add({
        'action': 'ban',
        'targetUserId': userId,
        'performedBy': bannedByUserId,
        'reason': reason,
        'timestamp': FieldValue.serverTimestamp(),
      });

      debugPrint('✅ User banned: $userId');
      return true;
    } catch (e) {
      debugPrint('❌ Error banning user: $e');
      return false;
    }
  }

  /// Unban a user
  Future<bool> unbanUser({
    required String userId,
    required String unbannedByUserId,
  }) async {
    try {
      await _firestore.collection('users').doc(userId).update({
        'isBanned': false,
        'banReason': null,
        'bannedAt': null,
        'bannedBy': null,
      });

      // Log the unban action
      await _firestore.collection('admin_actions').add({
        'action': 'unban',
        'targetUserId': userId,
        'performedBy': unbannedByUserId,
        'timestamp': FieldValue.serverTimestamp(),
      });

      debugPrint('✅ User unbanned: $userId');
      return true;
    } catch (e) {
      debugPrint('❌ Error unbanning user: $e');
      return false;
    }
  }

  /// Kick a user (force logout by invalidating session)
  Future<bool> kickUser({
    required String userId,
    required String kickedByUserId,
    String? reason,
  }) async {
    try {
      // Update user with kick timestamp
      await _firestore.collection('users').doc(userId).update({
        'kickedAt': FieldValue.serverTimestamp(),
        'kickReason': reason ?? 'Kicked by admin',
      });

      // Log the kick action
      await _firestore.collection('admin_actions').add({
        'action': 'kick',
        'targetUserId': userId,
        'performedBy': kickedByUserId,
        'reason': reason,
        'timestamp': FieldValue.serverTimestamp(),
      });

      debugPrint('✅ User kicked: $userId');
      return true;
    } catch (e) {
      debugPrint('❌ Error kicking user: $e');
      return false;
    }
  }

  /// Make user admin (set access level to high)
  Future<bool> makeUserAdmin({
    required String userId,
    required String promotedByUserId,
  }) async {
    try {
      await _firestore.collection('users').doc(userId).update({
        'accessLevel': AccessLevel.high.toStorageString(),
        'isApproved': true,
        'promotedAt': FieldValue.serverTimestamp(),
        'promotedBy': promotedByUserId,
      });

      // Log the promotion
      await _firestore.collection('admin_actions').add({
        'action': 'promote_to_admin',
        'targetUserId': userId,
        'performedBy': promotedByUserId,
        'timestamp': FieldValue.serverTimestamp(),
      });

      debugPrint('✅ User promoted to admin: $userId');
      return true;
    } catch (e) {
      debugPrint('❌ Error promoting user to admin: $e');
      return false;
    }
  }

  /// Set user access level
  Future<bool> setUserAccessLevel({
    required String userId,
    required AccessLevel level,
    required String changedByUserId,
  }) async {
    try {
      await _firestore.collection('users').doc(userId).update({
        'accessLevel': level.toStorageString(),
        'isApproved': level.isApproved,
        'accessLevelChangedAt': FieldValue.serverTimestamp(),
        'accessLevelChangedBy': changedByUserId,
      });

      // Log the change
      await _firestore.collection('admin_actions').add({
        'action': 'change_access_level',
        'targetUserId': userId,
        'performedBy': changedByUserId,
        'newLevel': level.toStorageString(),
        'timestamp': FieldValue.serverTimestamp(),
      });

      debugPrint('✅ User access level changed to ${level.displayName}: $userId');
      return true;
    } catch (e) {
      debugPrint('❌ Error changing access level: $e');
      return false;
    }
  }

  /// Remove admin privileges (demote to regular user)
  Future<bool> removeAdminPrivileges({
    required String userId,
    required String removedByUserId,
  }) async {
    try {
      await _firestore.collection('users').doc(userId).update({
        'accessLevel': AccessLevel.low.toStorageString(),
      });

      // Log the demotion
      await _firestore.collection('admin_actions').add({
        'action': 'remove_admin',
        'targetUserId': userId,
        'performedBy': removedByUserId,
        'timestamp': FieldValue.serverTimestamp(),
      });

      debugPrint('✅ Admin privileges removed: $userId');
      return true;
    } catch (e) {
      debugPrint('❌ Error removing admin privileges: $e');
      return false;
    }
  }

  /// Get admin action logs
  Future<List<Map<String, dynamic>>> getAdminActionLogs(
      {int limit = 50}) async {
    try {
      final snapshot = await _firestore
          .collection('admin_actions')
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
      debugPrint('❌ Error getting admin action logs: $e');
      return [];
    }
  }

  /// Check if user has been kicked (for session validation)
  Future<DateTime?> getUserKickTimestamp(String userId) async {
    try {
      final doc = await _firestore.collection('users').doc(userId).get();
      if (doc.exists) {
        final data = doc.data();
        final kickedAt = data?['kickedAt'] as Timestamp?;
        return kickedAt?.toDate();
      }
      return null;
    } catch (e) {
      debugPrint('❌ Error getting kick timestamp: $e');
      return null;
    }
  }

  /// Delete kick record (after user is logged out)
  Future<void> clearKickRecord(String userId) async {
    try {
      await _firestore.collection('users').doc(userId).update({
        'kickedAt': FieldValue.delete(),
        'kickReason': FieldValue.delete(),
      });
    } catch (e) {
      debugPrint('❌ Error clearing kick record: $e');
    }
  }
}
