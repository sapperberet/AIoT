import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';

class SessionService {
  static const String _lastLoginKey = 'last_login_timestamp';
  static const String _sessionDurationKey = 'session_duration_days';
  static const int _defaultSessionDurationDays = 2;
  static const int _minSessionDurationDays = 1;
  static const int _maxSessionDurationDays = 30;

  /// Get session duration in days (user configurable)
  static Future<int> getSessionDuration() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getInt(_sessionDurationKey) ?? _defaultSessionDurationDays;
    } catch (e) {
      debugPrint('❌ Error getting session duration: $e');
      return _defaultSessionDurationDays;
    }
  }

  /// Set session duration in days (1-30 days)
  static Future<void> setSessionDuration(int days) async {
    try {
      if (days < _minSessionDurationDays || days > _maxSessionDurationDays) {
        debugPrint('⚠️ Invalid session duration: $days days. Must be between $_minSessionDurationDays and $_maxSessionDurationDays');
        return;
      }
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_sessionDurationKey, days);
      debugPrint('✅ Session duration set to: $days days');
    } catch (e) {
      debugPrint('❌ Error setting session duration: $e');
    }
  }

  /// Save login timestamp
  static Future<void> saveLoginTimestamp() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      await prefs.setInt(_lastLoginKey, timestamp);
      debugPrint('✅ Login timestamp saved: ${DateTime.now()}');
    } catch (e) {
      debugPrint('❌ Error saving login timestamp: $e');
    }
  }

  /// Check if session is still valid (within configured duration)
  static Future<bool> isSessionValid() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lastLogin = prefs.getInt(_lastLoginKey);

      if (lastLogin == null) {
        debugPrint('⚠️ No login timestamp found');
        return false;
      }

      final sessionDuration = await getSessionDuration();
      final lastLoginDate = DateTime.fromMillisecondsSinceEpoch(lastLogin);
      final now = DateTime.now();
      final difference = now.difference(lastLoginDate);

      final isValid = difference.inDays < sessionDuration;
      
      debugPrint('📅 Last login: $lastLoginDate');
      debugPrint('📅 Current time: $now');
      debugPrint('📅 Days since login: ${difference.inDays}');
      debugPrint('📅 Session duration: $sessionDuration days');
      debugPrint('✅ Session valid: $isValid');

      return isValid;
    } catch (e) {
      debugPrint('❌ Error checking session validity: $e');
      return false;
    }
  }

  /// Clear session data
  static Future<void> clearSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_lastLoginKey);
      debugPrint('✅ Session cleared');
    } catch (e) {
      debugPrint('❌ Error clearing session: $e');
    }
  }

  /// Get remaining session time
  static Future<Duration?> getRemainingSessionTime() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lastLogin = prefs.getInt(_lastLoginKey);

      if (lastLogin == null) return null;

      final sessionDuration = await getSessionDuration();
      final lastLoginDate = DateTime.fromMillisecondsSinceEpoch(lastLogin);
      final expiryDate = lastLoginDate.add(Duration(days: sessionDuration));
      final now = DateTime.now();

      if (now.isAfter(expiryDate)) {
        return Duration.zero;
      }

      return expiryDate.difference(now);
    } catch (e) {
      debugPrint('❌ Error getting remaining session time: $e');
      return null;
    }
  }

  /// Get session expiry date
  static Future<DateTime?> getSessionExpiryDate() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lastLogin = prefs.getInt(_lastLoginKey);

      if (lastLogin == null) return null;

      final sessionDuration = await getSessionDuration();
      final lastLoginDate = DateTime.fromMillisecondsSinceEpoch(lastLogin);
      return lastLoginDate.add(Duration(days: sessionDuration));
    } catch (e) {
      debugPrint('❌ Error getting session expiry date: $e');
      return null;
    }
  }
}
