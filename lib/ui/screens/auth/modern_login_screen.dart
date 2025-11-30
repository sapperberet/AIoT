import 'package:flutter/material.dart';
import 'package:animate_do/animate_do.dart';
import 'package:glassmorphism/glassmorphism.dart';
import 'package:iconsax/iconsax.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/providers/settings_provider.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/services/biometric_service.dart';

class ModernLoginScreen extends StatefulWidget {
  const ModernLoginScreen({super.key});

  @override
  State<ModernLoginScreen> createState() => _ModernLoginScreenState();
}

class _ModernLoginScreenState extends State<ModernLoginScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  final BiometricService _biometricService = BiometricService();
  bool _isBiometricAvailable = false;
  bool _isBiometricEnabled = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..forward();
    _checkBiometricAvailability();
  }

  Future<void> _checkBiometricAvailability() async {
    final isAvailable = await _biometricService.isBiometricAvailable();
    if (mounted) {
      final settingsProvider = context.read<SettingsProvider>();
      setState(() {
        _isBiometricAvailable = isAvailable;
        _isBiometricEnabled = settingsProvider.enableBiometricLogin;
      });
    }
  }

  Future<void> _handleBiometricLogin() async {
    final loc = AppLocalizations.of(context);

    final success = await _biometricService.authenticate(
      localizedReason: loc.translate('biometric_login_prompt'),
    );

    if (success && mounted) {
      // Check if there's an existing Firebase session
      final authProvider = context.read<AuthProvider>();
      if (authProvider.currentUser != null) {
        Navigator.of(context).pushReplacementNamed('/home');
      } else {
        // No existing session, show message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(loc.translate('biometric_login_failed')),
            backgroundColor: Colors.orange,
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final backgroundColor = theme.scaffoldBackgroundColor;
    final textColor = theme.colorScheme.onBackground;
    final loc = AppLocalizations.of(context);

    return Scaffold(
      backgroundColor: backgroundColor,
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          gradient: isDark
              ? AppTheme.backgroundGradient
              : LinearGradient(
                  colors: [
                    AppTheme.lightBackground,
                    AppTheme.lightSurface,
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                const SizedBox(height: 40),

                // Logo
                FadeInDown(
                  duration: const Duration(milliseconds: 400),
                  child: ClipOval(
                    child: Container(
                      width: 140,
                      height: 140,
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

                const SizedBox(height: 32),

                // Welcome Text
                FadeInDown(
                  delay: const Duration(milliseconds: 100),
                  duration: const Duration(milliseconds: 400),
                  child: Column(
                    children: [
                      Text(
                        loc.translate('welcome_back'),
                        style:
                            Theme.of(context).textTheme.displayMedium?.copyWith(
                                  color: textColor,
                                  fontWeight: FontWeight.bold,
                                ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        loc.translate('authenticate_with_face'),
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: isDark
                                  ? AppTheme.mutedText
                                  : textColor.withOpacity(0.6),
                            ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 48),

                // Primary: Face Authentication Button
                FadeInUp(
                  delay: const Duration(milliseconds: 200),
                  duration: const Duration(milliseconds: 400),
                  child: GestureDetector(
                    onTap: () {
                      debugPrint('🔵 Face Auth button tapped!');
                      Navigator.of(context).pushNamed('/face-auth');
                    },
                    child: GlassmorphicContainer(
                      width: double.infinity,
                      height: 110,
                      borderRadius: 24,
                      blur: 20,
                      alignment: Alignment.center,
                      border: 2,
                      linearGradient: LinearGradient(
                        colors: isDark
                            ? [
                                Colors.white.withOpacity(0.15),
                                Colors.white.withOpacity(0.1),
                              ]
                            : [
                                Colors.white.withOpacity(0.9),
                                Colors.white.withOpacity(0.7),
                              ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderGradient: LinearGradient(
                        colors: [
                          AppTheme.accentColor.withOpacity(0.6),
                          AppTheme.primaryColor.withOpacity(0.6),
                        ],
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: 50,
                            height: 50,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: LinearGradient(
                                colors: [
                                  AppTheme.accentColor.withOpacity(0.9),
                                  AppTheme.primaryColor.withOpacity(0.9),
                                ],
                              ),
                              boxShadow: AppTheme.glowShadow,
                            ),
                            child: const Icon(
                              Iconsax.security_user,
                              color: Colors.white,
                              size: 28,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            loc.translate('face_auth_title'),
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(
                                  color: isDark
                                      ? AppTheme.lightText
                                      : AppTheme.darkText,
                                  fontWeight: FontWeight.bold,
                                ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            loc.translate('tap_to_authenticate'),
                            style:
                                Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: isDark
                                          ? AppTheme.mutedText
                                          : AppTheme.darkText.withOpacity(0.6),
                                      fontSize: 12,
                                    ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 32),

                // Biometric Login Button (show if available, but disable if not enabled in settings)
                if (_isBiometricAvailable)
                  FadeInUp(
                    delay: const Duration(milliseconds: 250),
                    duration: const Duration(milliseconds: 400),
                    child: Opacity(
                      opacity: _isBiometricEnabled ? 1.0 : 0.5,
                      child: GestureDetector(
                        onTap: _isBiometricEnabled
                            ? _handleBiometricLogin
                            : () {
                                // Show message that biometric needs to be enabled in settings
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(loc.translate(
                                        'enable_biometric_in_settings')),
                                    backgroundColor: Colors.orange,
                                    action: SnackBarAction(
                                      label: loc.translate('settings'),
                                      textColor: Colors.white,
                                      onPressed: () {
                                        // Note: User needs to login first to access settings
                                      },
                                    ),
                                  ),
                                );
                              },
                        child: GlassmorphicContainer(
                          width: double.infinity,
                          height: 80,
                          borderRadius: 20,
                          blur: 15,
                          alignment: Alignment.center,
                          border: 2,
                          linearGradient: LinearGradient(
                            colors: isDark
                                ? [
                                    Colors.white.withOpacity(
                                        _isBiometricEnabled ? 0.1 : 0.05),
                                    Colors.white.withOpacity(
                                        _isBiometricEnabled ? 0.05 : 0.02),
                                  ]
                                : [
                                    Colors.white.withOpacity(
                                        _isBiometricEnabled ? 0.8 : 0.5),
                                    Colors.white.withOpacity(
                                        _isBiometricEnabled ? 0.6 : 0.4),
                                  ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderGradient: LinearGradient(
                            colors: [
                              (_isBiometricEnabled
                                      ? AppTheme.primaryColor
                                      : Colors.grey)
                                  .withOpacity(0.5),
                              (_isBiometricEnabled
                                      ? AppTheme.accentColor
                                      : Colors.grey)
                                  .withOpacity(0.5),
                            ],
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  gradient: LinearGradient(
                                    colors: [
                                      AppTheme.primaryColor.withOpacity(0.8),
                                      AppTheme.accentColor.withOpacity(0.8),
                                    ],
                                  ),
                                ),
                                child: const Icon(
                                  Iconsax.finger_scan,
                                  color: Colors.white,
                                  size: 24,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _isBiometricEnabled
                                        ? loc
                                            .translate('enable_biometric_login')
                                        : loc.translate('biometric_disabled'),
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleSmall
                                        ?.copyWith(
                                          color: _isBiometricEnabled
                                              ? (isDark
                                                  ? AppTheme.lightText
                                                  : AppTheme.darkText)
                                              : Colors.grey,
                                          fontWeight: FontWeight.w600,
                                        ),
                                  ),
                                  Text(
                                    _isBiometricEnabled
                                        ? loc.translate('tap_to_authenticate')
                                        : loc.translate('enable_in_settings'),
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodySmall
                                        ?.copyWith(
                                          color: _isBiometricEnabled
                                              ? (isDark
                                                  ? AppTheme.mutedText
                                                  : AppTheme.darkText
                                                      .withOpacity(0.6))
                                              : Colors.grey.withOpacity(0.7),
                                          fontSize: 11,
                                        ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),

                if (_isBiometricAvailable) const SizedBox(height: 24),

                // Info Box - Explaining 2FA
                FadeInUp(
                  delay: const Duration(milliseconds: 300),
                  duration: const Duration(milliseconds: 400),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isDark
                          ? AppTheme.primaryColor.withOpacity(0.1)
                          : AppTheme.primaryColor.withOpacity(0.05),
                      borderRadius: AppTheme.mediumRadius,
                      border: Border.all(
                        color: AppTheme.primaryColor.withOpacity(0.3),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Iconsax.info_circle,
                          color: AppTheme.primaryColor,
                          size: 20,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            loc.translate('two_factor_info'),
                            style:
                                Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: textColor.withOpacity(0.8),
                                      fontSize: 12,
                                    ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
