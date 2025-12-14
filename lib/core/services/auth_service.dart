import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/user_model.dart';
import '../models/access_level.dart';
import 'session_service.dart';
import 'mqtt_service.dart';
import 'user_activity_service.dart';
import 'user_management_service.dart';
import 'user_approval_service.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final MqttService? _mqttService;
  final UserActivityService _activityService = UserActivityService();
  final UserManagementService _managementService = UserManagementService();
  final UserApprovalService _approvalService = UserApprovalService();

  AuthService({MqttService? mqttService}) : _mqttService = mqttService;

  // Firebase automatically persists user sessions on mobile platforms

  // Get current user
  User? get currentUser => _auth.currentUser;

  // Auth state changes stream
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // Get approval service
  UserApprovalService get approvalService => _approvalService;

  // Check if user is approved to access the app
  Future<bool> isUserApproved(String userId) async {
    try {
      final doc = await _firestore.collection('users').doc(userId).get();
      if (!doc.exists) return false;
      
      final data = doc.data()!;
      final accessLevel = AccessLevelExtension.fromString(data['accessLevel'] as String?);
      return data['isApproved'] == true && accessLevel.isApproved;
    } catch (e) {
      debugPrint('❌ Error checking user approval: $e');
      return false;
    }
  }

  // Get user's access level
  Future<AccessLevel> getUserAccessLevel(String userId) async {
    try {
      final doc = await _firestore.collection('users').doc(userId).get();
      if (!doc.exists) return AccessLevel.pending;
      
      final data = doc.data()!;
      return AccessLevelExtension.fromString(data['accessLevel'] as String?);
    } catch (e) {
      debugPrint('❌ Error getting user access level: $e');
      return AccessLevel.pending;
    }
  }

  // Sign in with email and password (checks approval status)
  Future<UserCredential> signInWithEmailAndPassword({
    required String email,
    required String password,
    bool checkApproval = true,
  }) async {
    try {
      // Save login timestamp BEFORE sign-in to prevent session validation race condition
      await SessionService.saveLoginTimestamp();

      final credential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (credential.user != null) {
        // Check if user is banned
        final userDoc = await _firestore
            .collection('users')
            .doc(credential.user!.uid)
            .get();
        
        if (userDoc.exists) {
          final userData = userDoc.data()!;
          
          // Check if banned
          if (userData['isBanned'] == true) {
            await _auth.signOut();
            throw FirebaseAuthException(
              code: 'user-banned',
              message:
                  'Your account has been banned. Reason: ${userData['banReason'] ?? 'Violation of terms'}',
            );
          }

          // Check approval status (only if checkApproval is true)
          if (checkApproval) {
            final accessLevel = AccessLevelExtension.fromString(userData['accessLevel'] as String?);
            final isApproved = userData['isApproved'] == true && accessLevel.isApproved;
            
            if (!isApproved) {
              // Don't sign out - keep them signed in but return a specific error
              // so UI can show the pending approval screen
              debugPrint('⚠️ User not yet approved: ${credential.user!.uid}');
              throw 'USER_PENDING_APPROVAL';
            }
          }
        }

        // Record sign-in activity
        await _activityService.recordSignIn(
          userId: credential.user!.uid,
          email: credential.user!.email ?? email,
          displayName: credential.user!.displayName ?? 'User',
        );

        // Increment sign-in count
        await _firestore.collection('users').doc(credential.user!.uid).update({
          'signInCount': FieldValue.increment(1),
        });
      }

      debugPrint('✅ User signed in: ${credential.user?.email}');
      return credential;
    } on FirebaseAuthException catch (e) {
      // Check for wrong-password before handling the exception
      if (e.code == 'wrong-password' || e.code == 'invalid-credential') {
        debugPrint('⚠️ Wrong password detected: ${e.code}');
        throw 'WRONG_PASSWORD';
      }
      throw _handleAuthException(e);
    } catch (e) {
      // Handle Pigeon API errors (Firebase Platform Channel type cast issues)
      if (e.toString().contains('Pigeon') ||
          e.toString().contains('List<Object?>') ||
          e.toString().contains('type cast') ||
          e.toString().contains('not a subtype') ||
          e.runtimeType.toString().contains('TypeError')) {
        debugPrint(
            '⚠️ Pigeon error during signIn (ignored), checking current user: $e');

        // Despite the error, check if user is actually signed in
        final user = _auth.currentUser;
        if (user != null) {
          debugPrint(
              '✅ Retrieved current user after Pigeon error: ${user.uid}');

          // Create a pseudo-credential since we can't get the real one
          // The user is authenticated, which is what matters
          throw 'PIGEON_ERROR_USER_AUTHENTICATED';
        } else {
          debugPrint('❌ No current user after Pigeon error');
          throw Exception('Failed to sign in: ${e.toString()}');
        }
      }
      rethrow;
    }
  }

  // Register with email and password
  Future<UserCredential> registerWithEmailAndPassword({
    required String email,
    required String password,
    String? displayName,
  }) async {
    try {
      // Save login timestamp FIRST to prevent race condition with auth state listener
      await SessionService.saveLoginTimestamp();
      debugPrint('✅ Login timestamp saved BEFORE account creation');

      UserCredential? credential;
      User? user;

      try {
        credential = await _auth.createUserWithEmailAndPassword(
          email: email,
          password: password,
        );
        user = credential.user;
        debugPrint('🔧 Account created, user: ${user?.uid}');
      } catch (e) {
        // Catch Pigeon errors during account creation
        final errorStr = e.toString();
        if (errorStr.contains('Pigeon') ||
            errorStr.contains('List<Object?>') ||
            errorStr.contains('type cast') ||
            errorStr.contains('not a subtype') ||
            e.runtimeType.toString().contains('TypeError')) {
          debugPrint(
              '⚠️ Pigeon error during createUser (ignored), getting current user: $e');
          // Account was created successfully despite the error, get the current user
          user = _auth.currentUser;
          if (user != null) {
            debugPrint(
                '✅ Retrieved current user after Pigeon error: ${user.uid}');
          } else {
            debugPrint('❌ No current user found after Pigeon error');
            rethrow;
          }
        } else {
          rethrow;
        }
      }

      if (user == null) {
        throw 'Failed to create user account';
      }

      debugPrint('🔧 displayName to set: $displayName');

      // Update display name if provided (catch Pigeon API errors)
      if (displayName != null) {
        try {
          debugPrint('🔄 Updating displayName to: $displayName');
          await user.updateDisplayName(displayName);
          debugPrint('✅ updateDisplayName succeeded');
          await user.reload(); // Reload to get updated displayName
          debugPrint('✅ reload succeeded');
        } catch (e) {
          // Ignore Pigeon API type cast errors (known Firebase bug)
          // These errors include "PigeonUserDetails", "PigeonUser", or "List<Object?>"
          final errorStr = e.toString();
          debugPrint('⚠️ Caught error during displayName update: $errorStr');
          if (errorStr.contains('Pigeon') ||
              errorStr.contains('List<Object?>') ||
              errorStr.contains('type cast') ||
              errorStr.contains('not a subtype')) {
            debugPrint('⚠️ Pigeon API error (ignored): $e');
          } else {
            debugPrint('❌ Unknown error (rethrowing): $e');
            rethrow;
          }
        }
      }

      // Create user document in Firestore
      debugPrint('🔧 Creating Firestore user document...');
      await _createUserDocument(user, displayName);
      debugPrint('✅ Firestore user document created');

      // Record new user registration activity
      await _activityService.recordNewUserRegistration(
        userId: user.uid,
        email: user.email ?? email,
        displayName: displayName ?? 'User',
      );

      // Login timestamp already saved at the beginning
      debugPrint('✅ Registration complete');

      // Return credential if we have it, otherwise try to sign in to get one
      if (credential != null) {
        return credential;
      } else {
        // If we only have user (due to Pigeon error), try to sign in to get credential
        // But if that also fails with Pigeon error, just return a mock credential
        debugPrint('🔧 Re-signing in to get credential...');
        try {
          // Skip approval check for re-sign-in after registration
          // (user just registered and is pending approval)
          return await signInWithEmailAndPassword(
              email: email, password: password, checkApproval: false);
        } catch (e) {
          final errorStr = e.toString();
          if (errorStr.contains('Pigeon') ||
              errorStr.contains('List<Object?>') ||
              errorStr.contains('type cast') ||
              errorStr.contains('not a subtype') ||
              e.runtimeType.toString().contains('TypeError')) {
            debugPrint(
                '⚠️ Pigeon error during re-sign-in (ignored), user already authenticated');
            // User is already authenticated, just throw a specific error that we'll catch upstream
            throw 'PIGEON_ERROR_USER_AUTHENTICATED';
          } else {
            rethrow;
          }
        }
      }
    } on FirebaseAuthException catch (e) {
      debugPrint('❌ FirebaseAuthException in registerWithEmailAndPassword: $e');
      throw _handleAuthException(e);
    } catch (e) {
      debugPrint('❌ Generic exception in registerWithEmailAndPassword: $e');
      debugPrint('❌ Exception type: ${e.runtimeType}');
      rethrow;
    }
  }

  // Create user document in Firestore with pending approval status
  Future<void> _createUserDocument(User user, String? displayName) async {
    // Check if this should be the first admin
    final needsFirstAdmin = await _approvalService.needsFirstAdminSetup();
    
    final userModel = UserModel(
      uid: user.uid,
      email: user.email!,
      displayName: displayName,
      createdAt: DateTime.now(),
      preferences: {
        'theme': 'system',
        'notifications': true,
      },
      // First user becomes admin automatically, others start as pending
      accessLevel: needsFirstAdmin ? AccessLevel.high : AccessLevel.pending,
      isApproved: needsFirstAdmin, // First admin is auto-approved
    );

    await _firestore.collection('users').doc(user.uid).set(userModel.toJson());

    // If not the first admin, generate OTP and notify admins
    if (!needsFirstAdmin) {
      debugPrint('🔧 Generating approval OTP for new user...');
      await _approvalService.generateApprovalOtp(user.uid);
      debugPrint('✅ Approval OTP generated and admins notified');
    } else {
      debugPrint('✅ First admin user created - auto-approved');
    }
  }

  // Get user data from Firestore
  Future<UserModel?> getUserData(String uid) async {
    try {
      final doc = await _firestore.collection('users').doc(uid).get();
      if (doc.exists) {
        return UserModel.fromJson(doc.data()!);
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  // Check if current session is valid
  Future<bool> isSessionValid() async {
    // Check if user is logged in
    if (_auth.currentUser == null) {
      return false;
    }

    // Check if session hasn't expired (2 days)
    return await SessionService.isSessionValid();
  }

  // Sign out if session expired
  Future<void> signOutIfSessionExpired() async {
    if (_auth.currentUser != null) {
      final isValid = await SessionService.isSessionValid();
      if (!isValid) {
        debugPrint('⚠️ Session expired, signing out...');
        await signOut();
      }
    }
  }

  // Sign out
  Future<void> signOut() async {
    await _auth.signOut();
    // Clear session data
    await SessionService.clearSession();
  }

  // Reset password
  Future<void> resetPassword(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    }
  }

  // Sign in or create user with face recognition
  Future<UserCredential?> signInWithFaceRecognition({
    required String recognizedName,
  }) async {
    try {
      // Normalize the name to handle variants (ahmed_1, ahmed_2 → ahmed)
      final baseName = _normalizeRecognizedName(recognizedName);

      debugPrint('🔍 Face recognized: $recognizedName');
      debugPrint('🔍 Normalized to: $baseName');

      // Try to find existing mapping using the BASE name
      final mapping = await _getFaceNameMapping(baseName);

      if (mapping != null && mapping['email'] != null) {
        try {
          // User exists, sign in with existing credentials
          final email = mapping['email'] as String;
          final password = mapping['password'] as String? ??
              _generateDefaultPassword(baseName);

          debugPrint('✅ Found existing account for: $baseName');
          debugPrint('📧 Email: $email');
          debugPrint(
              '🔑 Password retrieved from mapping: ${mapping['password'] != null ? "YES (length: ${(mapping['password'] as String).length})" : "NO (using generated)"}');
          debugPrint(
              '🔑 Password being used: ${password.substring(0, 10)}... (length: ${password.length})');
          debugPrint('🔍 Full mapping data: ${mapping.keys.join(', ')}');

          // DEBUG: Show full password for troubleshooting
          if (mapping['password'] != null) {
            debugPrint('🔐 Stored password: ${mapping['password']}');
          }
          final generatedPassword = _generateDefaultPassword(baseName);
          debugPrint('🔐 Generated password would be: $generatedPassword');
          debugPrint('🔐 Passwords match: ${password == generatedPassword}');

          UserCredential? credential;
          User? user;

          try {
            credential = await signInWithEmailAndPassword(
              email: email,
              password: password,
            );
            user = credential.user;
          } catch (e) {
            // Handle Pigeon error where user is authenticated but credential couldn't be returned
            if (e.toString() == 'PIGEON_ERROR_USER_AUTHENTICATED') {
              debugPrint(
                  '⚠️ Pigeon error during sign-in (ignored), user is authenticated');
              user = _auth.currentUser;

              if (user == null) {
                throw 'Failed to sign in: User authenticated but currentUser is null';
              }

              debugPrint(
                  '✅ Retrieved current user after Pigeon error: ${user.uid}');
              // Continue with user updates even though we don't have credential
            } else if (e.toString() == 'WRONG_PASSWORD' ||
                e.toString().contains('wrong-password') ||
                e.toString().contains('incorrect') ||
                e.toString().contains('malformed')) {
              // Password mismatch - Firebase account exists with different password
              // This can happen if the account was created in a previous session with a different password
              debugPrint(
                  '⚠️ Password mismatch detected. Attempting to delete and recreate account...');

              // Delete the face_mappings document to force recreation
              try {
                await _firestore
                    .collection('face_mappings')
                    .doc(baseName.toLowerCase())
                    .delete();
                debugPrint('✅ Deleted old face_mappings document');
              } catch (deleteError) {
                debugPrint('⚠️ Error deleting face_mappings: $deleteError');
              }

              // Throw error to trigger new user flow
              throw 'PASSWORD_MISMATCH_RECREATE_NEEDED';
            } else {
              // If sign-in fails with a different error, propagate it
              throw 'Failed to sign in existing user: $e';
            }
          }

          // Update displayName - ALWAYS update to ensure correct name
          if (user != null) {
            final displayName = _formatDisplayName(baseName);

            // Update Firebase Auth displayName (catch Pigeon API type cast error)
            try {
              await user.updateDisplayName(displayName);
              await user.reload(); // Reload to get updated displayName
              debugPrint(
                  '✅ Updated Firebase Auth displayName to: $displayName');
            } catch (e) {
              // Ignore Pigeon API type cast errors (known Firebase bug)
              final errorStr = e.toString();
              if (errorStr.contains('Pigeon') ||
                  errorStr.contains('List<Object?>') ||
                  errorStr.contains('type cast') ||
                  errorStr.contains('not a subtype')) {
                debugPrint('⚠️ Pigeon API error (ignored): $e');
              } else {
                rethrow;
              }
            }

            // Update Firestore displayName - ALWAYS update to ensure consistency
            final userDoc =
                await _firestore.collection('users').doc(user.uid).get();
            if (userDoc.exists) {
              await _firestore.collection('users').doc(user.uid).update({
                'displayName': displayName,
                'faceRecognitionName': baseName,
                'authMethod': 'face_recognition',
              });
              debugPrint('✅ Updated Firestore displayName to: $displayName');
            } else {
              // If user doc doesn't exist for some reason, create it
              await _createUserDocument(user, displayName);
              debugPrint(
                  '✅ Created user document with displayName: $displayName');
            }
          }

          return credential;
        } catch (e) {
          // If PASSWORD_MISMATCH error, fall through to create new user
          if (e.toString() == 'PASSWORD_MISMATCH_RECREATE_NEEDED') {
            debugPrint(
                '🔄 Falling through to create new user due to password mismatch');
            // Continue to new user creation below
          } else {
            rethrow;
          }
        }
      }

      // New user detected OR password mismatch retry - create Firebase account
      {
        debugPrint('🆕 New user detected: $baseName (from $recognizedName)');

        final email = _generateEmailFromName(baseName);
        final displayName = _formatDisplayName(baseName);

        // Try to find existing password by querying all face_mappings with this email
        String? existingPassword;
        try {
          debugPrint('🔍 Querying face_mappings for email: $email');
          final mappingsQuery = await _firestore
              .collection('face_mappings')
              .where('email', isEqualTo: email)
              .limit(1)
              .get();

          debugPrint(
              '🔍 Found ${mappingsQuery.docs.length} face_mappings for $email');

          if (mappingsQuery.docs.isNotEmpty) {
            final data = mappingsQuery.docs.first.data();
            existingPassword = data['password'] as String?;
            debugPrint(
                '✅ Found existing password for: $email (length: ${existingPassword?.length})');
            debugPrint('🔍 Face mapping data: ${data.keys.join(', ')}');
          } else {
            debugPrint('⚠️ No face_mappings found for: $email');
          }
        } catch (e) {
          debugPrint('❌ Error querying existing password: $e');
        }

        // Use existing password if found, otherwise generate new one
        final password = existingPassword ?? _generateDefaultPassword(baseName);

        debugPrint('📧 Creating account: $email');

        UserCredential? credential;

        try {
          // Try to create new Firebase account
          credential = await registerWithEmailAndPassword(
            email: email,
            password: password,
            displayName: displayName,
          );
        } catch (e) {
          // Handle Pigeon error where user is authenticated but credential couldn't be returned
          if (e.toString() == 'PIGEON_ERROR_USER_AUTHENTICATED') {
            debugPrint(
                '✅ User authenticated despite Pigeon error, getting current user');
            final currentUser = _auth.currentUser;
            if (currentUser != null) {
              // User is authenticated, we'll create the face mapping with this user
              // We don't have a credential but we have the user, which is enough
              await _createFaceNameMapping(
                recognizedName: baseName,
                userId: currentUser.uid,
                email: email,
                password: password,
              );

              await _firestore.collection('users').doc(currentUser.uid).update({
                'faceRecognitionName': baseName,
                'authMethod': 'face_recognition',
                'recognizedVariants': [recognizedName],
              });

              debugPrint(
                  '✅ Account created for: $baseName (Pigeon workaround)');
              // Return null to indicate success without credential (caller will check currentUser)
              return null;
            } else {
              throw 'User authentication succeeded but currentUser is null';
            }
          }

          // If account already exists, try to sign in instead
          if (e.toString().contains('email-already-in-use') ||
              e.toString().contains('already exists')) {
            debugPrint('📧 Account already exists, signing in instead...');

            try {
              credential = await signInWithEmailAndPassword(
                email: email,
                password: password,
              );

              // Update displayName after sign-in
              if (credential.user != null) {
                try {
                  await credential.user!.updateDisplayName(displayName);
                  await credential.user!.reload();
                  debugPrint(
                      '✅ Updated Firebase Auth displayName to: $displayName');
                } catch (updateError) {
                  final errorStr = updateError.toString();
                  if (errorStr.contains('Pigeon') ||
                      errorStr.contains('List<Object?>') ||
                      errorStr.contains('type cast') ||
                      errorStr.contains('not a subtype')) {
                    debugPrint('⚠️ Pigeon API error (ignored): $updateError');
                  } else {
                    rethrow;
                  }
                }

                // Update Firestore displayName
                await _firestore
                    .collection('users')
                    .doc(credential.user!.uid)
                    .set({
                  'displayName': displayName,
                  'faceRecognitionName': baseName,
                  'authMethod': 'face_recognition',
                }, SetOptions(merge: true));
                debugPrint('✅ Updated Firestore displayName to: $displayName');
              }
            } catch (signInError) {
              // If sign-in fails, it means the account exists but password doesn't match
              // This happens when face_mappings was deleted but Firebase Auth account remains
              debugPrint('❌ Sign-in failed: $signInError');
              throw 'Account exists with different password. Please delete user "$email" from Firebase Console → Authentication → Users, then try again.';
            }
          } else {
            rethrow;
          }
        }

        // Store face-to-user mapping using BASE name
        if (credential.user != null) {
          await _createFaceNameMapping(
            recognizedName: baseName, // Store base name, not variant
            userId: credential.user!.uid,
            email: email,
            password: password,
          );

          // Add face recognition info to user profile
          await _firestore
              .collection('users')
              .doc(credential.user!.uid)
              .update({
            'faceRecognitionName': baseName, // Store base name
            'authMethod': 'face_recognition',
            'recognizedVariants': [recognizedName], // Track all variants
          });

          debugPrint('✅ Account created for: $baseName');
        }

        return credential;
      }
    } catch (e) {
      throw 'Face recognition authentication failed: $e';
    }
  }

  // Get face name to user mapping from Firestore
  Future<Map<String, dynamic>?> _getFaceNameMapping(
      String recognizedName) async {
    try {
      final doc = await _firestore
          .collection('face_mappings')
          .doc(recognizedName.toLowerCase())
          .get();

      if (doc.exists) {
        return doc.data();
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  // Create face name to user mapping in Firestore
  Future<void> _createFaceNameMapping({
    required String recognizedName,
    required String userId,
    required String email,
    required String password,
  }) async {
    await _firestore
        .collection('face_mappings')
        .doc(recognizedName.toLowerCase())
        .set({
      'recognizedName': recognizedName,
      'userId': userId,
      'email': email,
      'password': password, // Encrypted in production!
      'createdAt': FieldValue.serverTimestamp(),
      'lastUsed': FieldValue.serverTimestamp(),
    });
  }

  // Update last used timestamp for face mapping
  Future<void> updateFaceMappingLastUsed(String recognizedName) async {
    try {
      await _firestore
          .collection('face_mappings')
          .doc(recognizedName.toLowerCase())
          .update({
        'lastUsed': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      // Ignore errors
    }
  }

  // Normalize face name to base identity
  // ahmed, ahmed_1, ahmed_2 → "ahmed" (same person)
  // ahmed_samy, ahmed_samy_1, ahmed_samy_2 → "ahmed_samy" (same person)
  String _normalizeRecognizedName(String name) {
    // Remove trailing _1, _2, _3, etc. (these are image variations of same person)

    final lowerName = name.toLowerCase();

    // Pattern: anything ending with _digit (e.g., ahmed_1, ahmed_samy_2)
    // This indicates same person, different image
    final nameWithNumber = RegExp(r'^(.+)_(\d+)$');
    final match = nameWithNumber.firstMatch(lowerName);

    if (match != null) {
      // It's a name with number suffix → return base name
      return match
          .group(1)!; // "ahmed_1" → "ahmed", "ahmed_samy_2" → "ahmed_samy"
    }

    // Otherwise return as-is (handles "ahmed", "ahmed_samy", etc.)
    return lowerName;
  }

  // Generate email from recognized name
  String _generateEmailFromName(String name) {
    // Use normalized name for consistent email
    final baseName = _normalizeRecognizedName(name);
    final cleanName = baseName.replaceAll(RegExp(r'[^a-z0-9_]'), '_');
    return '$cleanName@smarthome.local';
  }

  // Generate a default password (should be secure in production)
  String _generateDefaultPassword(String name) {
    // In production, use a secure password generation method
    // Use a FIXED password based on name (no timestamp) so it's consistent
    final baseName = _normalizeRecognizedName(name);
    return 'FaceAuth_${baseName}_SmartHome2024!';
  }

  // Format display name from recognized name
  String _formatDisplayName(String name) {
    // Use normalized name for consistent display
    final baseName = _normalizeRecognizedName(name);
    // Convert snake_case or similar to Title Case
    return baseName
        .split(RegExp(r'[_\-\s]+'))
        .map((word) => word.isEmpty
            ? ''
            : word[0].toUpperCase() + word.substring(1).toLowerCase())
        .join(' ');
  }

  // Handle authentication exceptions
  String _handleAuthException(FirebaseAuthException e) {
    switch (e.code) {
      case 'weak-password':
        return 'The password provided is too weak.';
      case 'email-already-in-use':
        return 'An account already exists for that email.';
      case 'user-not-found':
        return 'No user found for that email.';
      case 'wrong-password':
        return 'Wrong password provided.';
      case 'invalid-email':
        return 'The email address is invalid.';
      case 'user-disabled':
        return 'This user account has been disabled.';
      case 'too-many-requests':
        return 'Too many requests. Please try again later.';
      case 'operation-not-allowed':
        return 'This operation is not allowed.';
      default:
        return 'An error occurred. Please try again.';
    }
  }
}
