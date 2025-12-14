import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:animate_do/animate_do.dart';
import '../../core/providers/auth_provider.dart';
import '../../core/providers/settings_provider.dart';
import '../../core/theme/app_theme.dart';
import '../../core/localization/app_localizations.dart';
import '../../core/services/biometric_service.dart';
import '../../main.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  final BiometricService _biometricService = BiometricService();

  @override
  void initState() {
    super.initState();
    _checkAuthStatus();
  }

  Future<void> _checkAuthStatus() async {
    // If DEBUG_MODE is enabled, skip the splash screen and go directly to home
    if (DEBUG_MODE) {
      debugPrint('🚀 DEBUG MODE: Skipping authentication, going to home...');
      await Future.delayed(
          const Duration(seconds: 1)); // Brief splash animation
      if (!mounted) return;
      Navigator.of(context).pushReplacementNamed('/home');
      return;
    }

    // Normal authentication flow
    await Future.delayed(const Duration(seconds: 2));

    if (!mounted) return;

    final authProvider = context.read<AuthProvider>();
    final settingsProvider = context.read<SettingsProvider>();

    // If user is already authenticated (has active Firebase session), go to home
    // SECURITY: Also verify the Firebase user is still valid
    if (authProvider.isAuthenticated) {
      debugPrint('✅ User already authenticated, verifying session...');
      
      // Verify user still exists in Firebase Auth before allowing access
      final isValid = await _verifyFirebaseUser(authProvider);
      if (!isValid) {
        debugPrint('🚫 User no longer valid in Firebase, redirecting to login');
        if (!mounted) return;
        Navigator.of(context).pushReplacementNamed('/modern-login');
        return;
      }
      
      Navigator.of(context).pushReplacementNamed('/home');
      return;
    }

    // Check if user has previously enabled biometric AND has a stored session
    // Only attempt biometric if they've logged in before
    if (settingsProvider.enableBiometricLogin &&
        authProvider.currentUser != null) {
      final isBiometricAvailable =
          await _biometricService.isBiometricAvailable();

      if (isBiometricAvailable) {
        debugPrint(
            '🔐 Attempting biometric authentication for returning user...');

        // SECURITY: Use authProvider.authenticateWithBiometric() which validates
        // that the Firebase user still exists before allowing biometric access
        final success = await authProvider.authenticateWithBiometric();

        if (success && mounted) {
          debugPrint('✅ Biometric successful (Firebase user verified), going to home');
          Navigator.of(context).pushReplacementNamed('/home');
          return;
        } else {
          debugPrint('❌ Biometric failed or user no longer valid');
          // Show error if there's one
          if (authProvider.errorMessage != null) {
            debugPrint('🚫 Auth error: ${authProvider.errorMessage}');
          }
        }
      }
    }

    // First-time user or biometric not enabled - show proper login page
    debugPrint('👤 New user or biometric not enabled, showing login screen');
    if (!mounted) return;
    Navigator.of(context).pushReplacementNamed('/modern-login');
  }
  
  /// Verify that the Firebase user still exists and is valid
  Future<bool> _verifyFirebaseUser(AuthProvider authProvider) async {
    try {
      final user = authProvider.currentUser;
      if (user == null) return false;
      
      // Try to reload the user - this will fail if user was deleted
      await user.reload();
      return true;
    } catch (e) {
      final errorStr = e.toString().toLowerCase();
      if (errorStr.contains('user-not-found') ||
          errorStr.contains('user-disabled') ||
          errorStr.contains('user-token-expired') ||
          errorStr.contains('invalid-user-token')) {
        debugPrint('🚫 Firebase user verification failed: $e');
        // Sign out the invalid user
        await authProvider.signOut();
        return false;
      }
      // For network errors, allow cached session
      debugPrint('⚠️ Could not verify user (network issue?), allowing cached session: $e');
      return true;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: AppTheme.backgroundGradient,
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Animated Logo
              FadeInDown(
                duration: const Duration(milliseconds: 800),
                child: ClipOval(
                  child: Container(
                    width: 150,
                    height: 150,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: AppTheme.primaryGradient,
                      boxShadow: AppTheme.glowShadow,
                    ),
                    child: Image.asset(
                      'assets/icons/playstore.png',
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 40),

              // App Name
              FadeInUp(
                duration: const Duration(milliseconds: 800),
                delay: const Duration(milliseconds: 200),
                child: ShaderMask(
                  shaderCallback: (bounds) =>
                      AppTheme.primaryGradient.createShader(bounds),
                  child: const Text(
                    'Smart Home',
                    style: TextStyle(
                      fontSize: 42,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Tagline
              FadeInUp(
                duration: const Duration(milliseconds: 800),
                delay: const Duration(milliseconds: 400),
                child: Builder(
                  builder: (context) {
                    final loc = AppLocalizations.of(context);
                    return Text(
                      loc.t('control_world'),
                      style: const TextStyle(
                        fontSize: 16,
                        color: AppTheme.mutedText,
                        fontWeight: FontWeight.w500,
                      ),
                    );
                  },
                ),
              ),

              const SizedBox(height: 60),

              // Loading Indicator
              FadeInUp(
                duration: const Duration(milliseconds: 800),
                delay: const Duration(milliseconds: 600),
                child: SizedBox(
                  width: 50,
                  height: 50,
                  child: CircularProgressIndicator(
                    strokeWidth: 3,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      theme.brightness == Brightness.dark
                          ? AppTheme.primaryColor
                          : AppTheme.primaryColor,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
