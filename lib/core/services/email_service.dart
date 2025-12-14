import 'package:flutter/foundation.dart';
import 'package:mailer/mailer.dart';
import 'package:mailer/smtp_server.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Service for sending emails (OTP, notifications, etc.)
/// Uses Gmail SMTP by default - user needs to configure their Gmail with App Password
class EmailService {
  static const String _smtpEmailKey = 'smtp_email';
  static const String _smtpPasswordKey = 'smtp_app_password';
  static const String _smtpConfiguredKey = 'smtp_configured';

  // Hardcoded SMTP credentials for initial setup (replace with your own)
  // These are used when no configuration exists yet
  // TODO: Replace with your Gmail and App Password for OTP emails
  static const String _fallbackEmail = 'ahmedamromran2003@gmail.com'; // e.g., 'your.app@gmail.com'
  static const String _fallbackPassword = 'zcsx icqp chtk ouig'; // 16-char app password

  /// Get SMTP credentials - from SharedPreferences or fallback
  static Future<Map<String, String?>> _getSmtpCredentials() async {
    final prefs = await SharedPreferences.getInstance();
    final isConfigured = prefs.getBool(_smtpConfiguredKey) ?? false;

    if (isConfigured) {
      return {
        'email': prefs.getString(_smtpEmailKey),
        'password': prefs.getString(_smtpPasswordKey),
      };
    }

    // Use fallback if configured
    if (_fallbackEmail.isNotEmpty && _fallbackPassword.isNotEmpty) {
      return {
        'email': _fallbackEmail,
        'password': _fallbackPassword,
      };
    }

    return {'email': null, 'password': null};
  }

  /// Check if SMTP is configured (either via settings or fallback)
  static Future<bool> isConfigured() async {
    final creds = await _getSmtpCredentials();
    return creds['email'] != null && creds['password'] != null;
  }

  /// Check if user has explicitly configured SMTP
  static Future<bool> isExplicitlyConfigured() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_smtpConfiguredKey) ?? false;
  }

  /// Configure SMTP settings
  /// For Gmail: Use an App Password (not your regular password)
  /// Generate at: https://myaccount.google.com/apppasswords
  static Future<bool> configure({
    required String email,
    required String appPassword,
  }) async {
    try {
      // Test the connection first
      final smtpServer = gmail(email, appPassword);
      final testMessage = Message()
        ..from = Address(email, 'Smart Home App')
        ..recipients.add(email)
        ..subject = 'SMTP Configuration Test'
        ..text = 'Your email is now configured for sending OTPs.';

      await send(testMessage, smtpServer);

      // Save configuration
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_smtpEmailKey, email);
      await prefs.setString(_smtpPasswordKey, appPassword);
      await prefs.setBool(_smtpConfiguredKey, true);

      debugPrint('✅ SMTP configured successfully');
      return true;
    } catch (e) {
      debugPrint('❌ SMTP configuration failed: $e');
      return false;
    }
  }

  /// Clear SMTP configuration
  static Future<void> clearConfiguration() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_smtpEmailKey);
    await prefs.remove(_smtpPasswordKey);
    await prefs.setBool(_smtpConfiguredKey, false);
  }

  /// Get configured email address
  static Future<String?> getConfiguredEmail() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_smtpEmailKey);
  }

  /// Send OTP email to user for self-verification
  static Future<bool> sendOtpEmail({
    required String recipientEmail,
    required String recipientName,
    required String otp,
  }) async {
    try {
      final creds = await _getSmtpCredentials();
      final senderEmail = creds['email'];
      final appPassword = creds['password'];

      if (senderEmail == null || appPassword == null) {
        debugPrint('⚠️ SMTP not configured - OTP will only be shown in app');
        debugPrint(
            '💡 Configure SMTP in Settings or set _fallbackEmail/_fallbackPassword in email_service.dart');
        return false;
      }

      final smtpServer = gmail(senderEmail, appPassword);

      final message = Message()
        ..from = Address(senderEmail, 'Smart Home App')
        ..recipients.add(recipientEmail)
        ..subject = 'Your Smart Home App Verification Code'
        ..html = '''
<!DOCTYPE html>
<html>
<head>
  <style>
    body { font-family: Arial, sans-serif; background-color: #f5f5f5; padding: 20px; }
    .container { max-width: 500px; margin: 0 auto; background: white; border-radius: 10px; padding: 30px; box-shadow: 0 2px 10px rgba(0,0,0,0.1); }
    .header { text-align: center; color: #2196F3; }
    .otp-box { background: #E3F2FD; border: 2px solid #2196F3; border-radius: 10px; padding: 20px; text-align: center; margin: 20px 0; }
    .otp-code { font-size: 36px; font-weight: bold; color: #1565C0; letter-spacing: 8px; }
    .footer { color: #666; font-size: 12px; text-align: center; margin-top: 20px; }
    .warning { color: #ff5722; font-size: 14px; margin-top: 15px; }
  </style>
</head>
<body>
  <div class="container">
    <h1 class="header">🏠 Smart Home App</h1>
    <p>Hello <strong>$recipientName</strong>,</p>
    <p>Your verification code is:</p>
    <div class="otp-box">
      <span class="otp-code">$otp</span>
    </div>
    <p>Enter this code in the app to verify your account.</p>
    <p class="warning">⏱️ This code expires in 30 minutes.</p>
    <div class="footer">
      <p>If you didn't request this code, please ignore this email.</p>
      <p>© 2025 Smart Home App</p>
    </div>
  </div>
</body>
</html>
''';

      final sendReport = await send(message, smtpServer);
      debugPrint('✅ OTP email sent to $recipientEmail: $sendReport');
      return true;
    } catch (e) {
      debugPrint('❌ Failed to send OTP email: $e');
      return false;
    }
  }

  /// Send approval notification to admin
  static Future<bool> sendAdminNotificationEmail({
    required String adminEmail,
    required String adminName,
    required String pendingUserEmail,
    required String pendingUserName,
    required String otp,
  }) async {
    try {
      final creds = await _getSmtpCredentials();
      final senderEmail = creds['email'];
      final appPassword = creds['password'];

      if (senderEmail == null || appPassword == null) {
        debugPrint('⚠️ SMTP not configured - admin notification skipped');
        return false;
      }

      final smtpServer = gmail(senderEmail, appPassword);

      final message = Message()
        ..from = Address(senderEmail, 'Smart Home App')
        ..recipients.add(adminEmail)
        ..subject = 'New User Approval Request - $pendingUserName'
        ..html = '''
<!DOCTYPE html>
<html>
<head>
  <style>
    body { font-family: Arial, sans-serif; background-color: #f5f5f5; padding: 20px; }
    .container { max-width: 500px; margin: 0 auto; background: white; border-radius: 10px; padding: 30px; box-shadow: 0 2px 10px rgba(0,0,0,0.1); }
    .header { text-align: center; color: #4CAF50; }
    .info-box { background: #E8F5E9; border-left: 4px solid #4CAF50; padding: 15px; margin: 20px 0; }
    .otp-box { background: #FFF3E0; border: 2px solid #FF9800; border-radius: 10px; padding: 20px; text-align: center; margin: 20px 0; }
    .otp-code { font-size: 36px; font-weight: bold; color: #E65100; letter-spacing: 8px; }
    .footer { color: #666; font-size: 12px; text-align: center; margin-top: 20px; }
  </style>
</head>
<body>
  <div class="container">
    <h1 class="header">👤 New User Request</h1>
    <p>Hello <strong>$adminName</strong>,</p>
    <p>A new user is requesting access to the Smart Home App:</p>
    <div class="info-box">
      <p><strong>Name:</strong> $pendingUserName</p>
      <p><strong>Email:</strong> $pendingUserEmail</p>
    </div>
    <p>Verification Code:</p>
    <div class="otp-box">
      <span class="otp-code">$otp</span>
    </div>
    <p>You can share this code with the user, or approve them directly from the admin panel in the app.</p>
    <div class="footer">
      <p>This code expires in 30 minutes.</p>
      <p>© 2025 Smart Home App</p>
    </div>
  </div>
</body>
</html>
''';

      final sendReport = await send(message, smtpServer);
      debugPrint('✅ Admin notification email sent to $adminEmail: $sendReport');
      return true;
    } catch (e) {
      debugPrint('❌ Failed to send admin notification email: $e');
      return false;
    }
  }
}
