import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Service to handle biometric authentication (fingerprint, face id, etc.)
class BiometricService {
  static final BiometricService _instance = BiometricService._internal();
  factory BiometricService() => _instance;
  BiometricService._internal();

  final LocalAuthentication _auth = LocalAuthentication();

  // Keys for SharedPreferences
  static const String _biometricEnabledKey = 'biometric_enabled';
  static const String _hasCompletedFirstAuthKey = 'has_completed_first_auth';

  /// Check if biometric authentication is available on the device
  Future<bool> isBiometricAvailable() async {
    try {
      // Check if device supports biometrics
      final bool canCheckBiometrics = await _auth.canCheckBiometrics;
      final bool isDeviceSupported = await _auth.isDeviceSupported();

      return canCheckBiometrics && isDeviceSupported;
    } on PlatformException catch (e) {
      debugPrint('Error checking biometric availability: $e');
      return false;
    }
  }

  /// Get available biometric types on the device
  Future<List<BiometricType>> getAvailableBiometrics() async {
    try {
      return await _auth.getAvailableBiometrics();
    } on PlatformException catch (e) {
      debugPrint('Error getting available biometrics: $e');
      return [];
    }
  }

  /// Check if fingerprint is available
  Future<bool> isFingerprintAvailable() async {
    final biometrics = await getAvailableBiometrics();
    return biometrics.contains(BiometricType.fingerprint);
  }

  /// Check if face recognition (Face ID) is available
  Future<bool> isFaceIdAvailable() async {
    final biometrics = await getAvailableBiometrics();
    return biometrics.contains(BiometricType.face);
  }

  /// Authenticate using biometrics
  Future<bool> authenticate({
    String localizedReason = 'Authenticate to access Smart Home',
    bool biometricOnly = true,
  }) async {
    try {
      final isAvailable = await isBiometricAvailable();
      if (!isAvailable) {
        debugPrint('Biometric authentication not available');
        return false;
      }

      return await _auth.authenticate(
        localizedReason: localizedReason,
        options: AuthenticationOptions(
          biometricOnly: biometricOnly,
          stickyAuth: true,
          useErrorDialogs: true,
        ),
      );
    } on PlatformException catch (e) {
      debugPrint('Error during biometric authentication: $e');
      return false;
    }
  }

  /// Check if biometric login is enabled by the user
  Future<bool> isBiometricLoginEnabled() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(_biometricEnabledKey) ?? false;
    } catch (e) {
      debugPrint('Error checking biometric login enabled: $e');
      return false;
    }
  }

  /// Enable or disable biometric login
  Future<bool> setBiometricLoginEnabled(bool enabled) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_biometricEnabledKey, enabled);
      return true;
    } catch (e) {
      debugPrint('Error setting biometric login enabled: $e');
      return false;
    }
  }

  /// Check if user has completed first authentication
  Future<bool> hasCompletedFirstAuth() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(_hasCompletedFirstAuthKey) ?? false;
    } catch (e) {
      debugPrint('Error checking first auth completed: $e');
      return false;
    }
  }

  /// Mark first authentication as completed
  Future<bool> setFirstAuthCompleted() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_hasCompletedFirstAuthKey, true);
      return true;
    } catch (e) {
      debugPrint('Error setting first auth completed: $e');
      return false;
    }
  }

  /// Get a user-friendly name for the available biometric type
  Future<String> getBiometricTypeName() async {
    final biometrics = await getAvailableBiometrics();

    if (biometrics.contains(BiometricType.face)) {
      return 'Face ID';
    } else if (biometrics.contains(BiometricType.fingerprint)) {
      return 'Fingerprint';
    } else if (biometrics.contains(BiometricType.iris)) {
      return 'Iris';
    } else if (biometrics.contains(BiometricType.strong)) {
      return 'Biometric';
    } else if (biometrics.contains(BiometricType.weak)) {
      return 'Biometric';
    }

    return 'Biometric';
  }

  /// Clear all biometric settings (for logout)
  Future<void> clearBiometricSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_biometricEnabledKey);
      // Note: We don't clear _hasCompletedFirstAuthKey as it's user-specific via Firebase
    } catch (e) {
      debugPrint('Error clearing biometric settings: $e');
    }
  }
}
