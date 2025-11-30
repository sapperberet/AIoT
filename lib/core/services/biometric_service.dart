import 'package:flutter/foundation.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

class BiometricService {
  static const String _biometricEnabledKeyPrefix = 'biometric_enabled_';
  static const String _hasCompletedInitialAuthKeyPrefix = 'has_completed_initial_auth_';
  static const String _currentUserIdKey = 'current_biometric_user_id';
  
  final LocalAuthentication _localAuth = LocalAuthentication();

  /// Check if device supports biometric authentication
  Future<bool> isBiometricAvailable() async {
    try {
      final canAuthenticateWithBiometrics = await _localAuth.canCheckBiometrics;
      final canAuthenticate = await _localAuth.isDeviceSupported();
      return canAuthenticateWithBiometrics && canAuthenticate;
    } catch (e) {
      debugPrint('❌ Error checking biometric availability: $e');
      return false;
    }
  }

  /// Get available biometric types (fingerprint, face ID, etc.)
  Future<List<BiometricType>> getAvailableBiometrics() async {
    try {
      return await _localAuth.getAvailableBiometrics();
    } catch (e) {
      debugPrint('❌ Error getting available biometrics: $e');
      return [];
    }
  }

  /// Authenticate user with biometrics
  Future<bool> authenticate({
    String localizedReason = 'Please authenticate to access Smart Home',
  }) async {
    try {
      final didAuthenticate = await _localAuth.authenticate(
        localizedReason: localizedReason,
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: true,
        ),
      );
      
      if (didAuthenticate) {
        debugPrint('✅ Biometric authentication successful');
      } else {
        debugPrint('⚠️ Biometric authentication failed');
      }
      
      return didAuthenticate;
    } catch (e) {
      debugPrint('❌ Error during biometric authentication: $e');
      return false;
    }
  }

  /// Set current user ID for user-specific biometric settings
  Future<void> setCurrentUserId(String? userId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (userId != null) {
        await prefs.setString(_currentUserIdKey, userId);
      } else {
        await prefs.remove(_currentUserIdKey);
      }
    } catch (e) {
      debugPrint('❌ Error setting current user ID: $e');
    }
  }

  /// Get current user ID
  Future<String?> _getCurrentUserId() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_currentUserIdKey);
    } catch (e) {
      debugPrint('❌ Error getting current user ID: $e');
      return null;
    }
  }

  /// Check if user has enabled biometric login (user-specific)
  Future<bool> isBiometricEnabled() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = await _getCurrentUserId();
      if (userId == null) return false;
      return prefs.getBool('$_biometricEnabledKeyPrefix$userId') ?? false;
    } catch (e) {
      debugPrint('❌ Error checking biometric enabled status: $e');
      return false;
    }
  }

  /// Enable or disable biometric login (user-specific)
  Future<void> setBiometricEnabled(bool enabled) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = await _getCurrentUserId();
      if (userId == null) {
        debugPrint('⚠️ No user ID set, cannot save biometric setting');
        return;
      }
      await prefs.setBool('$_biometricEnabledKeyPrefix$userId', enabled);
      debugPrint('✅ Biometric login ${enabled ? 'enabled' : 'disabled'} for user $userId');
    } catch (e) {
      debugPrint('❌ Error setting biometric enabled status: $e');
    }
  }

  /// Check if user has completed initial authentication (user-specific)
  Future<bool> hasCompletedInitialAuth() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = await _getCurrentUserId();
      if (userId == null) return false;
      return prefs.getBool('$_hasCompletedInitialAuthKeyPrefix$userId') ?? false;
    } catch (e) {
      debugPrint('❌ Error checking initial auth status: $e');
      return false;
    }
  }

  /// Mark initial authentication as completed (user-specific)
  Future<void> setInitialAuthCompleted(bool completed) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = await _getCurrentUserId();
      if (userId == null) {
        debugPrint('⚠️ No user ID set, cannot save initial auth status');
        return;
      }
      await prefs.setBool('$_hasCompletedInitialAuthKeyPrefix$userId', completed);
      debugPrint('✅ Initial auth completion status set to: $completed for user $userId');
    } catch (e) {
      debugPrint('❌ Error setting initial auth status: $e');
    }
  }

  /// Clear biometric settings for current user (on logout)
  Future<void> clearBiometricSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = await _getCurrentUserId();
      if (userId != null) {
        await prefs.remove('$_biometricEnabledKeyPrefix$userId');
        // Keep initial auth status for this user (they can re-enable biometric on next login)
      }
      await prefs.remove(_currentUserIdKey);
      debugPrint('✅ Biometric settings cleared');
    } catch (e) {
      debugPrint('❌ Error clearing biometric settings: $e');
    }
  }

  /// Get a human-readable description of available biometric types
  Future<String> getBiometricTypeDescription() async {
    final types = await getAvailableBiometrics();
    if (types.isEmpty) return 'No biometrics available';
    
    final descriptions = <String>[];
    for (final type in types) {
      switch (type) {
        case BiometricType.fingerprint:
          descriptions.add('Fingerprint');
          break;
        case BiometricType.face:
          descriptions.add('Face ID');
          break;
        case BiometricType.iris:
          descriptions.add('Iris');
          break;
        case BiometricType.strong:
          descriptions.add('Strong biometric');
          break;
        case BiometricType.weak:
          descriptions.add('Weak biometric');
          break;
      }
    }
    
    return descriptions.join(', ');
  }
}
