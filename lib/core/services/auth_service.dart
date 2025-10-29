import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/user_model.dart';
import 'session_service.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Firebase automatically persists user sessions on mobile platforms

  // Get current user
  User? get currentUser => _auth.currentUser;

  // Auth state changes stream
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // Sign in with email and password
  Future<UserCredential> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    try {
      final credential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      // Save login timestamp for session management
      await SessionService.saveLoginTimestamp();

      return credential;
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    }
  }

  // Register with email and password
  Future<UserCredential> registerWithEmailAndPassword({
    required String email,
    required String password,
    String? displayName,
  }) async {
    try {
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      // Update display name if provided
      if (displayName != null && credential.user != null) {
        await credential.user!.updateDisplayName(displayName);
      }

      // Create user document in Firestore
      if (credential.user != null) {
        await _createUserDocument(credential.user!, displayName);
      }

      // Save login timestamp for session management
      await SessionService.saveLoginTimestamp();

      return credential;
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    }
  }

  // Create user document in Firestore
  Future<void> _createUserDocument(User user, String? displayName) async {
    final userModel = UserModel(
      uid: user.uid,
      email: user.email!,
      displayName: displayName,
      createdAt: DateTime.now(),
      preferences: {
        'theme': 'system',
        'notifications': true,
      },
    );

    await _firestore.collection('users').doc(user.uid).set(userModel.toJson());
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
        // User exists, sign in with existing credentials
        final email = mapping['email'] as String;
        final password = mapping['password'] as String? ??
            _generateDefaultPassword(baseName);

        debugPrint('✅ Found existing account for: $baseName');

        try {
          final credential = await signInWithEmailAndPassword(
            email: email,
            password: password,
          );

          // Update displayName if not set
          if (credential.user != null) {
            final displayName = _formatDisplayName(baseName);

            // Update Firebase Auth displayName if missing
            if (credential.user!.displayName == null ||
                credential.user!.displayName!.isEmpty) {
              await credential.user!.updateDisplayName(displayName);
              await credential.user!
                  .reload(); // Reload to get updated displayName
              debugPrint(
                  '✅ Updated Firebase Auth displayName to: $displayName');
            }

            // Update Firestore displayName if missing
            final userDoc = await _firestore
                .collection('users')
                .doc(credential.user!.uid)
                .get();
            if (userDoc.exists) {
              final userData = userDoc.data();
              if (userData?['displayName'] == null ||
                  userData?['displayName'] == '') {
                await _firestore
                    .collection('users')
                    .doc(credential.user!.uid)
                    .update({
                  'displayName': displayName,
                  'faceRecognitionName': baseName,
                  'authMethod': 'face_recognition',
                });
                debugPrint('✅ Updated Firestore displayName to: $displayName');
              }
            }
          }

          return credential;
        } catch (e) {
          // If sign-in fails, might need to recreate account
          throw 'Failed to sign in existing user: $e';
        }
      } else {
        // New user detected - create Firebase account
        debugPrint('🆕 New user detected: $baseName (from $recognizedName)');

        final email = _generateEmailFromName(baseName);
        final password = _generateDefaultPassword(baseName);
        final displayName = _formatDisplayName(baseName);

        debugPrint('📧 Creating account: $email');

        // Create new Firebase account
        final credential = await registerWithEmailAndPassword(
          email: email,
          password: password,
          displayName: displayName,
        );

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
    // For now, use a combination of base name and timestamp
    final baseName = _normalizeRecognizedName(name);
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    return 'FaceAuth_${baseName}_$timestamp';
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
