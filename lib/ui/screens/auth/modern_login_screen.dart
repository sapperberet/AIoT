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
  int _secretTapCount = 0;
  DateTime? _lastTapTime;

  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;

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

  Future<void> _handleLogin() async {
    if (_formKey.currentState!.validate()) {
      final authProvider = context.read<AuthProvider>();
      final loc = AppLocalizations.of(context);

      final success = await authProvider.signIn(
        _emailController.text.trim(),
        _passwordController.text,
      );

      if (mounted) {
        // Check if user is pending approval
        if (authProvider.isPendingApproval) {
          Navigator.of(context).pushReplacementNamed('/pending-approval');
          return;
        }

        if (success) {
          Navigator.of(context).pushReplacementNamed('/home');
        } else if (authProvider.errorMessage != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(authProvider.errorMessage!),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _emailController.dispose();
    _passwordController.dispose();
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

                // Logo (Secret: Tap 7 times quickly to access Face Recognition)
                FadeInDown(
                  duration: const Duration(milliseconds: 400),
                  child: GestureDetector(
                    onTap: () {
                      final now = DateTime.now();
                      if (_lastTapTime != null &&
                          now.difference(_lastTapTime!).inSeconds > 2) {
                        _secretTapCount = 0;
                      }
                      _lastTapTime = now;
                      _secretTapCount++;

                      if (_secretTapCount >= 7) {
                        _secretTapCount = 0;
                        // Show secret feature unlocked message
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Row(
                              children: [
                                const Icon(Icons.lock_open,
                                    color: Colors.white),
                                const SizedBox(width: 12),
                                const Expanded(
                                  child: Text('🔓 Secret Feature Unlocked!'),
                                ),
                              ],
                            ),
                            backgroundColor: AppTheme.accentColor,
                            duration: const Duration(seconds: 2),
                          ),
                        );
                        // Navigate to Face Auth after short delay
                        Future.delayed(const Duration(milliseconds: 500), () {
                          if (mounted) {
                            Navigator.of(context).pushNamed('/face-auth');
                          }
                        });
                      }
                    },
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
                        'Choose your authentication method',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: isDark
                                  ? AppTheme.mutedText
                                  : textColor.withOpacity(0.6),
                            ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 40),

                // Face Authentication removed - now hidden feature (tap logo 7 times)

                // Email & Password Login Form
                FadeInUp(
                  delay: const Duration(milliseconds: 200),
                  duration: const Duration(milliseconds: 400),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      children: [
                        // Email Field
                        TextFormField(
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                          style: TextStyle(color: textColor),
                          decoration: InputDecoration(
                            labelText: loc.translate('email'),
                            labelStyle:
                                TextStyle(color: textColor.withOpacity(0.7)),
                            prefixIcon:
                                Icon(Iconsax.sms, color: AppTheme.primaryColor),
                            filled: true,
                            fillColor: isDark
                                ? Colors.white.withOpacity(0.05)
                                : Colors.white.withOpacity(0.8),
                            border: OutlineInputBorder(
                              borderRadius: AppTheme.smallRadius,
                              borderSide: BorderSide(
                                color: AppTheme.primaryColor.withOpacity(0.3),
                              ),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: AppTheme.smallRadius,
                              borderSide: BorderSide(
                                color: AppTheme.primaryColor.withOpacity(0.2),
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: AppTheme.smallRadius,
                              borderSide: BorderSide(
                                color: AppTheme.primaryColor,
                                width: 2,
                              ),
                            ),
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return loc.translate('enter_email');
                            }
                            if (!value.contains('@')) {
                              return loc.translate('valid_email');
                            }
                            return null;
                          },
                        ),

                        const SizedBox(height: 16),

                        // Password Field
                        TextFormField(
                          controller: _passwordController,
                          obscureText: _obscurePassword,
                          style: TextStyle(color: textColor),
                          decoration: InputDecoration(
                            labelText: loc.translate('password'),
                            labelStyle:
                                TextStyle(color: textColor.withOpacity(0.7)),
                            prefixIcon: Icon(Iconsax.lock,
                                color: AppTheme.primaryColor),
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscurePassword
                                    ? Iconsax.eye_slash
                                    : Iconsax.eye,
                                color: textColor.withOpacity(0.7),
                              ),
                              onPressed: () {
                                setState(() {
                                  _obscurePassword = !_obscurePassword;
                                });
                              },
                            ),
                            filled: true,
                            fillColor: isDark
                                ? Colors.white.withOpacity(0.05)
                                : Colors.white.withOpacity(0.8),
                            border: OutlineInputBorder(
                              borderRadius: AppTheme.smallRadius,
                              borderSide: BorderSide(
                                color: AppTheme.primaryColor.withOpacity(0.3),
                              ),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: AppTheme.smallRadius,
                              borderSide: BorderSide(
                                color: AppTheme.primaryColor.withOpacity(0.2),
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: AppTheme.smallRadius,
                              borderSide: BorderSide(
                                color: AppTheme.primaryColor,
                                width: 2,
                              ),
                            ),
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return loc.translate('enter_password');
                            }
                            if (value.length < 6) {
                              return loc.translate('password_length');
                            }
                            return null;
                          },
                        ),

                        const SizedBox(height: 12),

                        // Forgot Password Link
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(
                            onPressed: () {
                              Navigator.of(context)
                                  .pushNamed('/forgot-password');
                            },
                            child: Text(
                              loc.translate('forgot_password'),
                              style: TextStyle(
                                color: AppTheme.accentColor,
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(height: 12),

                        // Login Button
                        SizedBox(
                          width: double.infinity,
                          height: 56,
                          child: Consumer<AuthProvider>(
                            builder: (context, authProvider, _) {
                              return ElevatedButton(
                                onPressed: authProvider.isLoading
                                    ? null
                                    : _handleLogin,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppTheme.primaryColor,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: AppTheme.smallRadius,
                                  ),
                                  elevation: 4,
                                ),
                                child: authProvider.isLoading
                                    ? const SizedBox(
                                        height: 24,
                                        width: 24,
                                        child: CircularProgressIndicator(
                                          color: Colors.white,
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          const Icon(Iconsax.login, size: 20),
                                          const SizedBox(width: 8),
                                          Text(
                                            loc.translate('sign_in'),
                                            style: const TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ],
                                      ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 24),

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

                // Sign Up Section
                FadeInUp(
                  delay: const Duration(milliseconds: 350),
                  duration: const Duration(milliseconds: 400),
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: isDark
                          ? Colors.white.withOpacity(0.05)
                          : Colors.black.withOpacity(0.03),
                      borderRadius: AppTheme.mediumRadius,
                      border: Border.all(
                        color: isDark
                            ? Colors.white.withOpacity(0.1)
                            : Colors.black.withOpacity(0.1),
                        width: 1,
                      ),
                    ),
                    child: Column(
                      children: [
                        Text(
                          loc.translate('no_account'),
                          style:
                              Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: textColor.withOpacity(0.7),
                                  ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: () {
                              Navigator.of(context).pushNamed('/register');
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.accentColor,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: AppTheme.smallRadius,
                              ),
                              elevation: 4,
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Iconsax.user_add, size: 20),
                                const SizedBox(width: 8),
                                Text(
                                  loc.translate('sign_up'),
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // Info Box - Explaining authentication
                FadeInUp(
                  delay: const Duration(milliseconds: 400),
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
                            'Biometric login is available after your first successful login. Enable it in Settings.',
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
