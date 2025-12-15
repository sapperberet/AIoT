import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../models/access_level.dart';
import '../models/user_model.dart';
import 'email_service.dart';

/// Model for pending user approval request
class PendingUserRequest {
  final String uid;
  final String email;
  final String displayName;
  final DateTime requestedAt;
  final String? otp;
  final DateTime? otpGeneratedAt;
  final bool otpVerified;

  PendingUserRequest({
    required this.uid,
    required this.email,
    required this.displayName,
    required this.requestedAt,
    this.otp,
    this.otpGeneratedAt,
    this.otpVerified = false,
  });

  factory PendingUserRequest.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return PendingUserRequest(
      uid: doc.id,
      email: data['email'] ?? '',
      displayName: data['displayName'] ?? 'Unknown',
      requestedAt:
          (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      otp: data['pendingApprovalOtp'],
      otpGeneratedAt: (data['otpGeneratedAt'] as Timestamp?)?.toDate(),
      otpVerified: data['otpVerified'] ?? false,
    );
  }

  bool get isOtpExpired {
    if (otpGeneratedAt == null) return true;
    return DateTime.now().difference(otpGeneratedAt!).inMinutes > 30;
  }
}

/// Service for managing user approval workflow
class UserApprovalService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Generate a 6-digit OTP
  String _generateOtp() {
    final random = Random.secure();
    return (100000 + random.nextInt(900000)).toString();
  }

  /// Get all admin users (high access level)
  Future<List<UserModel>> getAdminUsers() async {
    try {
      final snapshot = await _firestore
          .collection('users')
          .where('accessLevel', isEqualTo: 'high')
          .where('isApproved', isEqualTo: true)
          .get();

      return snapshot.docs
          .map((doc) => UserModel.fromJson({...doc.data(), 'uid': doc.id}))
          .toList();
    } catch (e) {
      debugPrint('❌ Error getting admin users: $e');
      return [];
    }
  }

  /// Get all pending user requests
  Future<List<PendingUserRequest>> getPendingUsers() async {
    try {
      final snapshot = await _firestore
          .collection('users')
          .where('accessLevel', isEqualTo: 'pending')
          .where('isApproved', isEqualTo: false)
          .orderBy('createdAt', descending: true)
          .get();

      return snapshot.docs
          .map((doc) => PendingUserRequest.fromFirestore(doc))
          .toList();
    } catch (e) {
      debugPrint('❌ Error getting pending users: $e');
      return [];
    }
  }

  /// Stream pending users for real-time updates
  Stream<List<PendingUserRequest>> watchPendingUsers() {
    return _firestore
        .collection('users')
        .where('accessLevel', isEqualTo: 'pending')
        .where('isApproved', isEqualTo: false)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => PendingUserRequest.fromFirestore(doc))
            .toList());
  }

  /// Generate and store OTP for a pending user
  /// Sends OTP to the USER's own email for 2FA self-verification
  /// Also notifies the admin notification email
  Future<String?> generateApprovalOtp(String pendingUserId) async {
    try {
      final otp = _generateOtp();
      final now = DateTime.now();

      // Store OTP in the pending user's document
      await _firestore.collection('users').doc(pendingUserId).update({
        'pendingApprovalOtp': otp,
        'otpGeneratedAt': Timestamp.fromDate(now),
        'otpVerified': false,
      });

      // Get pending user details
      final userDoc =
          await _firestore.collection('users').doc(pendingUserId).get();
      final userData = userDoc.data();
      final pendingUserEmail = userData?['email'] ?? 'Unknown';
      final pendingUserName = userData?['displayName'] ?? 'New User';

      // === 2FA: Send OTP to the USER's own email ===
      if (pendingUserEmail != 'Unknown') {
        final emailSent = await EmailService.sendOtpEmail(
          recipientEmail: pendingUserEmail,
          recipientName: pendingUserName,
          otp: otp,
        );
        if (emailSent) {
          debugPrint('📧 OTP email sent to user: $pendingUserEmail');
        } else {
          debugPrint('⚠️ SMTP not configured - user won\'t receive OTP email');
        }
      }

      // === Send notification to admin email (no account required) ===
      final adminEmailSent = await EmailService.sendAdminNotificationEmail(
        adminEmail: adminNotificationEmail,
        adminName: 'Administrator',
        pendingUserEmail: pendingUserEmail,
        pendingUserName: pendingUserName,
        otp: otp,
      );
      if (adminEmailSent) {
        debugPrint('📧 Admin notification sent to: $adminNotificationEmail');
      }

      // Also notify any registered admin users via in-app notification
      final admins = await getAdminUsers();
      for (final admin in admins) {
        await _firestore.collection('approval_requests').add({
          'pendingUserId': pendingUserId,
          'pendingUserEmail': pendingUserEmail,
          'pendingUserName': pendingUserName,
          'otp': otp,
          'adminId': admin.uid,
          'adminEmail': admin.email,
          'createdAt': Timestamp.fromDate(now),
          'expiresAt': Timestamp.fromDate(now.add(const Duration(minutes: 30))),
          'status': 'pending',
        });

        // Create in-app notification for admin
        await _firestore.collection('notifications').add({
          'userId': admin.uid,
          'title': 'New User Approval Required',
          'message':
              '$pendingUserName ($pendingUserEmail) is requesting access. OTP: $otp',
          'type': 'user_approval',
          'data': {
            'pendingUserId': pendingUserId,
            'otp': otp,
          },
          'createdAt': Timestamp.fromDate(now),
          'isRead': false,
        });
      }

      debugPrint('✅ OTP generated and notifications sent');
      return otp;
    } catch (e) {
      debugPrint('❌ Error generating approval OTP: $e');
      return null;
    }
  }

  /// Verify OTP and approve user (called by admin)
  Future<bool> verifyOtpAndApproveUser({
    required String pendingUserId,
    required String otp,
    required String approvedByUserId,
    AccessLevel assignedLevel = AccessLevel.low,
  }) async {
    try {
      // Get pending user document
      final userDoc =
          await _firestore.collection('users').doc(pendingUserId).get();
      if (!userDoc.exists) {
        debugPrint('❌ Pending user not found');
        return false;
      }

      final userData = userDoc.data()!;
      final storedOtp = userData['pendingApprovalOtp'];
      final otpGeneratedAt =
          (userData['otpGeneratedAt'] as Timestamp?)?.toDate();

      // Verify OTP
      if (storedOtp != otp) {
        debugPrint('❌ Invalid OTP');
        return false;
      }

      // Check if OTP is expired (30 minutes)
      if (otpGeneratedAt == null ||
          DateTime.now().difference(otpGeneratedAt).inMinutes > 30) {
        debugPrint('❌ OTP expired');
        return false;
      }

      // Approve the user
      await _firestore.collection('users').doc(pendingUserId).update({
        'accessLevel': assignedLevel.toStorageString(),
        'isApproved': true,
        'approvedAt': FieldValue.serverTimestamp(),
        'approvedBy': approvedByUserId,
        'pendingApprovalOtp': FieldValue.delete(),
        'otpGeneratedAt': FieldValue.delete(),
        'otpVerified': true,
      });

      // Update approval request status
      final approvalRequests = await _firestore
          .collection('approval_requests')
          .where('pendingUserId', isEqualTo: pendingUserId)
          .where('status', isEqualTo: 'pending')
          .get();

      for (final doc in approvalRequests.docs) {
        await doc.reference.update({
          'status': 'approved',
          'approvedBy': approvedByUserId,
          'approvedAt': FieldValue.serverTimestamp(),
        });
      }

      // Log the approval action
      await _firestore.collection('admin_actions').add({
        'action': 'approve_user',
        'targetUserId': pendingUserId,
        'performedBy': approvedByUserId,
        'assignedLevel': assignedLevel.toStorageString(),
        'timestamp': FieldValue.serverTimestamp(),
      });

      // Notify the approved user
      await _firestore.collection('notifications').add({
        'userId': pendingUserId,
        'title': 'Account Approved!',
        'message':
            'Your account has been approved. You can now access the app.',
        'type': 'account_approved',
        'createdAt': FieldValue.serverTimestamp(),
        'isRead': false,
      });

      debugPrint(
          '✅ User approved: $pendingUserId with level: ${assignedLevel.displayName}');
      return true;
    } catch (e) {
      debugPrint('❌ Error approving user: $e');
      return false;
    }
  }

  /// Self-verify OTP by pending user (when admin shares OTP with them)
  /// Returns: 'success', 'invalid_otp', 'expired', 'error'
  Future<String> selfVerifyOtp(String otp) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return 'error';

      // Get pending user document
      final userDoc = await _firestore.collection('users').doc(user.uid).get();
      if (!userDoc.exists) {
        debugPrint('❌ User document not found');
        return 'error';
      }

      final userData = userDoc.data()!;
      final storedOtp = userData['pendingApprovalOtp'];
      final otpGeneratedAt =
          (userData['otpGeneratedAt'] as Timestamp?)?.toDate();

      // Verify OTP
      if (storedOtp != otp) {
        debugPrint('❌ Invalid OTP entered');
        return 'invalid_otp';
      }

      // Check if OTP is expired (30 minutes)
      if (otpGeneratedAt == null ||
          DateTime.now().difference(otpGeneratedAt).inMinutes > 30) {
        debugPrint('❌ OTP expired');
        return 'expired';
      }

      // Approve the user with default low access level
      await _firestore.collection('users').doc(user.uid).update({
        'accessLevel': 'low',
        'isApproved': true,
        'approvedAt': FieldValue.serverTimestamp(),
        'approvedBy': 'self_verified',
        'pendingApprovalOtp': FieldValue.delete(),
        'otpGeneratedAt': FieldValue.delete(),
        'otpVerified': true,
      });

      // Update approval request status
      final approvalRequests = await _firestore
          .collection('approval_requests')
          .where('pendingUserId', isEqualTo: user.uid)
          .where('status', isEqualTo: 'pending')
          .get();

      for (final doc in approvalRequests.docs) {
        await doc.reference.update({
          'status': 'self_approved',
          'approvedAt': FieldValue.serverTimestamp(),
        });
      }

      debugPrint('✅ User self-verified with OTP: ${user.uid}');
      return 'success';
    } catch (e) {
      debugPrint('❌ Error self-verifying OTP: $e');
      return 'error';
    }
  }

  /// Reject a pending user request
  Future<bool> rejectUser({
    required String pendingUserId,
    required String rejectedByUserId,
    String? reason,
  }) async {
    try {
      // Update user document
      await _firestore.collection('users').doc(pendingUserId).update({
        'accessLevel': 'rejected',
        'isApproved': false,
        'rejectedAt': FieldValue.serverTimestamp(),
        'rejectedBy': rejectedByUserId,
        'rejectionReason': reason,
      });

      // Update approval request status
      final approvalRequests = await _firestore
          .collection('approval_requests')
          .where('pendingUserId', isEqualTo: pendingUserId)
          .where('status', isEqualTo: 'pending')
          .get();

      for (final doc in approvalRequests.docs) {
        await doc.reference.update({
          'status': 'rejected',
          'rejectedBy': rejectedByUserId,
          'rejectedAt': FieldValue.serverTimestamp(),
          'rejectionReason': reason,
        });
      }

      // Log the rejection action
      await _firestore.collection('admin_actions').add({
        'action': 'reject_user',
        'targetUserId': pendingUserId,
        'performedBy': rejectedByUserId,
        'reason': reason,
        'timestamp': FieldValue.serverTimestamp(),
      });

      debugPrint('✅ User rejected: $pendingUserId');
      return true;
    } catch (e) {
      debugPrint('❌ Error rejecting user: $e');
      return false;
    }
  }

  /// Change user access level (admin only)
  Future<bool> changeUserAccessLevel({
    required String userId,
    required AccessLevel newLevel,
    required String changedByUserId,
  }) async {
    try {
      await _firestore.collection('users').doc(userId).update({
        'accessLevel': newLevel.toStorageString(),
        'accessLevelChangedAt': FieldValue.serverTimestamp(),
        'accessLevelChangedBy': changedByUserId,
      });

      // Log the action
      await _firestore.collection('admin_actions').add({
        'action': 'change_access_level',
        'targetUserId': userId,
        'performedBy': changedByUserId,
        'newLevel': newLevel.toStorageString(),
        'timestamp': FieldValue.serverTimestamp(),
      });

      debugPrint(
          '✅ User access level changed: $userId -> ${newLevel.displayName}');
      return true;
    } catch (e) {
      debugPrint('❌ Error changing access level: $e');
      return false;
    }
  }

  /// Auto-verify user via MQTT/broker network connection
  /// If user can connect to the MQTT broker, they're on the trusted network
  /// Returns: 'success', 'not_connected', 'error'
  Future<String> verifyViaMqttConnection() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return 'error';

      // Approve the user with default low access level
      await _firestore.collection('users').doc(user.uid).update({
        'accessLevel': 'low',
        'isApproved': true,
        'approvedAt': FieldValue.serverTimestamp(),
        'approvedBy': 'mqtt_network_verified',
        'pendingApprovalOtp': FieldValue.delete(),
        'otpGeneratedAt': FieldValue.delete(),
        'otpVerified': true,
        'verificationMethod': 'mqtt_network',
      });

      // Update approval request status
      final approvalRequests = await _firestore
          .collection('approval_requests')
          .where('pendingUserId', isEqualTo: user.uid)
          .where('status', isEqualTo: 'pending')
          .get();

      for (final doc in approvalRequests.docs) {
        await doc.reference.update({
          'status': 'mqtt_verified',
          'approvedAt': FieldValue.serverTimestamp(),
        });
      }

      debugPrint('✅ User verified via MQTT network: ${user.uid}');
      return 'success';
    } catch (e) {
      debugPrint('❌ Error verifying via MQTT: $e');
      return 'error';
    }
  }

  /// Check if current user is approved
  Future<bool> isCurrentUserApproved() async {
    final user = _auth.currentUser;
    if (user == null) return false;

    try {
      final doc = await _firestore.collection('users').doc(user.uid).get();
      if (!doc.exists) return false;

      final data = doc.data()!;
      return data['isApproved'] == true &&
          data['accessLevel'] != 'pending' &&
          data['accessLevel'] != 'rejected';
    } catch (e) {
      debugPrint('❌ Error checking user approval status: $e');
      return false;
    }
  }

  /// Get current user's access level
  Future<AccessLevel> getCurrentUserAccessLevel() async {
    final user = _auth.currentUser;
    if (user == null) return AccessLevel.pending;

    try {
      final doc = await _firestore.collection('users').doc(user.uid).get();
      if (!doc.exists) return AccessLevel.pending;

      final data = doc.data()!;
      return AccessLevelExtension.fromString(data['accessLevel'] as String?);
    } catch (e) {
      debugPrint('❌ Error getting user access level: $e');
      return AccessLevel.pending;
    }
  }

  /// Stream current user's approval status
  Stream<bool> watchCurrentUserApprovalStatus() {
    final user = _auth.currentUser;
    if (user == null) return Stream.value(false);

    return _firestore.collection('users').doc(user.uid).snapshots().map((doc) {
      if (!doc.exists) return false;
      final data = doc.data()!;
      return data['isApproved'] == true &&
          data['accessLevel'] != 'pending' &&
          data['accessLevel'] != 'rejected';
    });
  }

  /// Create the first admin user (for initial setup)
  Future<bool> createFirstAdmin(String userId) async {
    try {
      // Check if any admin exists
      final existingAdmins = await getAdminUsers();
      if (existingAdmins.isNotEmpty) {
        debugPrint('❌ Admin already exists, cannot create first admin');
        return false;
      }

      // Make this user an admin
      await _firestore.collection('users').doc(userId).update({
        'accessLevel': 'high',
        'isApproved': true,
        'approvedAt': FieldValue.serverTimestamp(),
        'approvedBy': 'system', // Self-approved as first admin
        'isFirstAdmin': true,
      });

      debugPrint('✅ First admin created: $userId');
      return true;
    } catch (e) {
      debugPrint('❌ Error creating first admin: $e');
      return false;
    }
  }

  /// Check if system needs first admin setup
  Future<bool> needsFirstAdminSetup() async {
    try {
      final admins = await getAdminUsers();
      return admins.isEmpty;
    } catch (e) {
      debugPrint('❌ Error checking first admin setup: $e');
      return true; // Assume needs setup on error
    }
  }

  /// Admin notification email - receives OTP codes when users register
  /// This is NOT a user account, just an email recipient for notifications
  static const String adminNotificationEmail = 'ahmedamromran2003@gmail.com';

  /// List of designated admin emails (for backwards compatibility)
  /// These emails, if registered as users, become admins automatically
  /// NOTE: Add emails here to auto-approve them as admins
  static const List<String> designatedAdminEmails = [
    // Add user emails here if you want them to become admins when they register
    'ahmedamromran2003@gmail.com', // Primary admin
    'tegaraenglish69@gmail.com', // Test user
  ];

  /// Check if the email is a designated admin
  static bool isDesignatedAdmin(String email) {
    return designatedAdminEmails.contains(email.toLowerCase().trim());
  }

  /// Bootstrap admin for a designated admin email
  /// This auto-approves users with designated admin emails as high-level admins
  Future<bool> bootstrapDesignatedAdmin(String userId, String email) async {
    try {
      // Check if this email is designated as admin
      if (!isDesignatedAdmin(email)) {
        debugPrint('📋 $email is not a designated admin');
        return false;
      }

      debugPrint('🔐 Bootstrapping designated admin: $email');

      // Use set with merge to handle both new and existing documents
      await _firestore.collection('users').doc(userId).set({
        'uid': userId,
        'email': email,
        'displayName': 'System Administrator',
        'accessLevel': 'high',
        'isApproved': true,
        'approvedAt': FieldValue.serverTimestamp(),
        'approvedBy': 'system_bootstrap',
        'isDesignatedAdmin': true,
        'otpVerified': true,
        'createdAt': FieldValue.serverTimestamp(),
        'preferences': {'theme': 'system', 'notifications': true},
      }, SetOptions(merge: true));

      debugPrint('✅ Designated admin bootstrapped: $email');
      return true;
    } catch (e) {
      debugPrint('❌ Error bootstrapping designated admin: $e');
      return false;
    }
  }
}
