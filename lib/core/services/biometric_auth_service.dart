import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Service for handling biometric authentication (fingerprint, face ID)
class BiometricAuthService {
  final LocalAuthentication _localAuth = LocalAuthentication();

  static const String _biometricEnabledKey = 'biometric_enabled';
  static const String _lastBiometricUserKey = 'last_biometric_user';
  static const String _biometricUserEmailKey = 'biometric_user_email';

  /// Check if biometric authentication is available on the device
  Future<bool> canCheckBiometrics() async {
    try {
      return await _localAuth.canCheckBiometrics;
    } on PlatformException catch (e) {
      debugPrint('❌ Error checking biometrics availability: $e');
      return false;
    }
  }

  /// Check if device supports biometrics
  Future<bool> isDeviceSupported() async {
    try {
      return await _localAuth.isDeviceSupported();
    } on PlatformException catch (e) {
      debugPrint('❌ Error checking device support: $e');
      return false;
    }
  }

  /// Get list of available biometric types
  Future<List<BiometricType>> getAvailableBiometrics() async {
    try {
      return await _localAuth.getAvailableBiometrics();
    } on PlatformException catch (e) {
      debugPrint('❌ Error getting available biometrics: $e');
      return [];
    }
  }

  /// Authenticate using biometrics
  Future<bool> authenticate({
    String localizedReason = 'Please authenticate to access your account',
    bool useErrorDialogs = true,
    bool stickyAuth = true,
  }) async {
    try {
      final isAvailable = await canCheckBiometrics();
      final isSupported = await isDeviceSupported();

      if (!isAvailable || !isSupported) {
        debugPrint('⚠️ Biometric authentication not available');
        return false;
      }

      final authenticated = await _localAuth.authenticate(
        localizedReason: localizedReason,
        options: AuthenticationOptions(
          useErrorDialogs: useErrorDialogs,
          stickyAuth: stickyAuth,
          biometricOnly: false, // Allow PIN/Pattern as fallback
        ),
      );

      if (authenticated) {
        debugPrint('✅ Biometric authentication successful');
      } else {
        debugPrint('❌ Biometric authentication failed');
      }

      return authenticated;
    } on PlatformException catch (e) {
      debugPrint('❌ Biometric authentication error: $e');

      // Handle specific errors
      switch (e.code) {
        case 'NotAvailable':
          debugPrint(
              '⚠️ Biometric authentication not available on this device');
          break;
        case 'NotEnrolled':
          debugPrint('⚠️ No biometrics enrolled on this device');
          break;
        case 'LockedOut':
          debugPrint('⚠️ Too many failed attempts. Biometrics locked out.');
          break;
        case 'PermanentlyLockedOut':
          debugPrint('⚠️ Biometrics permanently locked out');
          break;
        default:
          debugPrint('⚠️ Unknown biometric error: ${e.code}');
      }

      return false;
    }
  }

  /// Check if biometric authentication is enabled for the user
  Future<bool> isBiometricEnabled() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(_biometricEnabledKey) ?? false;
    } catch (e) {
      debugPrint('❌ Error checking biometric enabled status: $e');
      return false;
    }
  }

  /// Enable biometric authentication for the user
  Future<void> enableBiometric(String userId, {String? userEmail}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_biometricEnabledKey, true);
      await prefs.setString(_lastBiometricUserKey, userId);
      if (userEmail != null) {
        await prefs.setString(_biometricUserEmailKey, userEmail);
      }
      debugPrint(
          '✅ Biometric authentication enabled for user: $userId (email: $userEmail)');
    } catch (e) {
      debugPrint('❌ Error enabling biometric: $e');
      rethrow;
    }
  }

  /// Disable biometric authentication
  Future<void> disableBiometric() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_biometricEnabledKey, false);
      await prefs.remove(_lastBiometricUserKey);
      await prefs.remove(_biometricUserEmailKey);
      debugPrint('✅ Biometric authentication disabled');
    } catch (e) {
      debugPrint('❌ Error disabling biometric: $e');
      rethrow;
    }
  }

  /// Get the last user who enabled biometric authentication
  Future<String?> getLastBiometricUser() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_lastBiometricUserKey);
    } catch (e) {
      debugPrint('❌ Error getting last biometric user: $e');
      return null;
    }
  }

  /// Get the email of the user who enabled biometric authentication
  Future<String?> getBiometricUserEmail() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_biometricUserEmailKey);
    } catch (e) {
      debugPrint('❌ Error getting biometric user email: $e');
      return null;
    }
  }

  /// Check if biometric credentials are stored for auto-login
  Future<bool> hasBiometricCredentials() async {
    try {
      final isEnabled = await isBiometricEnabled();
      final email = await getBiometricUserEmail();
      return isEnabled && email != null && email.isNotEmpty;
    } catch (e) {
      debugPrint('❌ Error checking biometric credentials: $e');
      return false;
    }
  }

  /// Stop biometric authentication (cancel dialog)
  Future<void> stopAuthentication() async {
    try {
      await _localAuth.stopAuthentication();
      debugPrint('✅ Biometric authentication cancelled');
    } catch (e) {
      debugPrint('❌ Error stopping authentication: $e');
    }
  }

  /// Get human-readable description of available biometrics
  Future<String> getBiometricsDescription() async {
    final biometrics = await getAvailableBiometrics();

    if (biometrics.isEmpty) {
      return 'No biometric authentication available';
    }

    final descriptions = biometrics.map((type) {
      switch (type) {
        case BiometricType.face:
          return 'Face ID';
        case BiometricType.fingerprint:
          return 'Fingerprint';
        case BiometricType.iris:
          return 'Iris scan';
        case BiometricType.strong:
          return 'Strong biometric';
        case BiometricType.weak:
          return 'Weak biometric';
      }
    }).toList();

    return descriptions.join(', ');
  }
}
