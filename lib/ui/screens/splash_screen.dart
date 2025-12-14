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
    if (authProvider.isAuthenticated) {
      debugPrint('✅ User already authenticated, going to home');
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

        final success = await _biometricService.authenticate(
          localizedReason: 'Authenticate to access Smart Home',
        );

        if (success && mounted) {
          debugPrint('✅ Biometric successful, going to home');
          Navigator.of(context).pushReplacementNamed('/home');
          return;
        } else {
          debugPrint('❌ Biometric failed or cancelled');
        }
      }
    }

    // First-time user or biometric not enabled - show proper login page
    debugPrint('👤 New user or biometric not enabled, showing login screen');
    if (!mounted) return;
    Navigator.of(context).pushReplacementNamed('/modern-login');
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
