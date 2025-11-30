import 'package:flutter/foundation.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

class BiometricService {
  static const String _biometricEnabledKey = 'biometric_enabled';
  static const String _hasCompletedInitialAuthKey = 'has_completed_initial_auth';
  
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

  /// Check if user has enabled biometric login
  Future<bool> isBiometricEnabled() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(_biometricEnabledKey) ?? false;
    } catch (e) {
      debugPrint('❌ Error checking biometric enabled status: $e');
      return false;
    }
  }

  /// Enable or disable biometric login
  Future<void> setBiometricEnabled(bool enabled) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_biometricEnabledKey, enabled);
      debugPrint('✅ Biometric login ${enabled ? 'enabled' : 'disabled'}');
    } catch (e) {
      debugPrint('❌ Error setting biometric enabled status: $e');
    }
  }

  /// Check if user has completed initial authentication (required before enabling biometric)
  Future<bool> hasCompletedInitialAuth() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(_hasCompletedInitialAuthKey) ?? false;
    } catch (e) {
      debugPrint('❌ Error checking initial auth status: $e');
      return false;
    }
  }

  /// Mark initial authentication as completed
  Future<void> setInitialAuthCompleted(bool completed) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_hasCompletedInitialAuthKey, completed);
      debugPrint('✅ Initial auth completion status set to: $completed');
    } catch (e) {
      debugPrint('❌ Error setting initial auth status: $e');
    }
  }

  /// Clear biometric settings (on logout)
  Future<void> clearBiometricSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_biometricEnabledKey);
      // Note: We don't clear _hasCompletedInitialAuthKey as that persists per-user
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
