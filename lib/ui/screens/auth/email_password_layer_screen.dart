import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:animate_do/animate_do.dart';
import 'package:iconsax/iconsax.dart';

import '../../../core/providers/settings_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/localization/app_localizations.dart';

/// Email/Password Layer 2 Authentication Screen
/// This screen is shown AFTER successful face authentication
/// when the user has enabled 2FA in settings
class EmailPasswordLayerScreen extends StatefulWidget {
  const EmailPasswordLayerScreen({super.key});

  @override
  State<EmailPasswordLayerScreen> createState() =>
      _EmailPasswordLayerScreenState();
}

class _EmailPasswordLayerScreenState extends State<EmailPasswordLayerScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _isVerifying = false;
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _verifyCredentials() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _isVerifying = true);

    final settingsProvider = context.read<SettingsProvider>();

    // Verify against stored credentials in settings
    final storedEmail = settingsProvider.userEmail;
    final storedPassword = settingsProvider.userPassword;

    await Future.delayed(const Duration(milliseconds: 800)); // Simulate check

    if (mounted) {
      if (_emailController.text.trim() == storedEmail &&
          _passwordController.text == storedPassword) {
        // Layer 2 authentication successful
        debugPrint('✅ Layer 2 (Email/Password) authentication successful!');
        Navigator.of(context).pushReplacementNamed('/home');
      } else {
        // Credentials don't match
        setState(() => _isVerifying = false);
        _showErrorDialog(
          'Invalid Credentials',
          'The email or password you entered does not match your stored credentials.',
        );
      }
    }
  }

  void _showErrorDialog(String title, String message) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final loc = AppLocalizations.of(context);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDark ? AppTheme.darkCard : AppTheme.lightCard,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: Row(
          children: [
            Icon(Iconsax.close_circle, color: Colors.red),
            const SizedBox(width: 12),
            Text(
              title,
              style: TextStyle(
                color: theme.colorScheme.onSurface,
              ),
            ),
          ],
        ),
        content: Text(
          message,
          style: TextStyle(
            color: theme.colorScheme.onSurface.withOpacity(0.8),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(loc.translate('ok')),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _emailController.clear();
              _passwordController.clear();
            },
            child: Text(loc.translate('try_again')),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final textColor = theme.colorScheme.onBackground;
    final loc = AppLocalizations.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isDark
                ? [
                    AppTheme.primaryColor.withOpacity(0.1),
                    AppTheme.accentColor.withOpacity(0.1),
                  ]
                : [
                    AppTheme.primaryColor.withOpacity(0.05),
                    AppTheme.accentColor.withOpacity(0.05),
                  ],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              children: [
                const SizedBox(height: 20),

                // Header
                FadeInDown(
                  child: Column(
                    children: [
                      // Security Shield Icon
                      AnimatedBuilder(
                        animation: _pulseController,
                        builder: (context, child) {
                          return Transform.scale(
                            scale: 1.0 + (_pulseController.value * 0.05),
                            child: child,
                          );
                        },
                        child: Container(
                          width: 120,
                          height: 120,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                AppTheme.accentColor.withOpacity(0.3),
                                AppTheme.primaryColor.withOpacity(0.3),
                              ],
                            ),
                          ),
                          child: Icon(
                            Iconsax.shield_tick,
                            size: 60,
                            color: AppTheme.accentColor,
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Title
                      ShaderMask(
                        shaderCallback: (bounds) =>
                            AppTheme.primaryGradient.createShader(bounds),
                        child: Text(
                          loc.translate('second_layer_auth'),
                          style: const TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Subtitle
                      Text(
                        loc.translate('face_success_verify'),
                        style: TextStyle(
                          fontSize: 15,
                          color: textColor.withOpacity(0.7),
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 50),

                // Form
                FadeInUp(
                  delay: const Duration(milliseconds: 200),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      children: [
                        // Email Field
                        _buildTextField(
                          controller: _emailController,
                          label: loc.translate('email'),
                          hint: loc.translate('email_hint'),
                          icon: Iconsax.sms,
                          keyboardType: TextInputType.emailAddress,
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

                        const SizedBox(height: 20),

                        // Password Field
                        _buildTextField(
                          controller: _passwordController,
                          label: loc.translate('password'),
                          hint: loc.translate('password_hint'),
                          icon: Iconsax.lock,
                          obscureText: _obscurePassword,
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscurePassword
                                  ? Iconsax.eye_slash
                                  : Iconsax.eye,
                              color: textColor.withOpacity(0.5),
                            ),
                            onPressed: () {
                              setState(
                                  () => _obscurePassword = !_obscurePassword);
                            },
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

                        const SizedBox(height: 40),

                        // Verify Button
                        SizedBox(
                          width: double.infinity,
                          height: 56,
                          child: ElevatedButton(
                            onPressed: _isVerifying ? null : _verifyCredentials,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.accentColor,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              elevation: 0,
                            ),
                            child: _isVerifying
                                ? const SizedBox(
                                    width: 24,
                                    height: 24,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                          Colors.white),
                                    ),
                                  )
                                : Text(
                                    loc.translate('verify_credentials'),
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 30),

                // Info Box
                FadeInUp(
                  delay: const Duration(milliseconds: 400),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isDark
                          ? AppTheme.primaryColor.withOpacity(0.1)
                          : AppTheme.primaryColor.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: AppTheme.primaryColor.withOpacity(0.3),
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
                            'These credentials were set up in your Settings for additional security.',
                            style: TextStyle(
                              fontSize: 13,
                              color: textColor.withOpacity(0.7),
                            ),
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
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    bool obscureText = false,
    Widget? suffixIcon,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final textColor = theme.colorScheme.onBackground;

    return Container(
      decoration: BoxDecoration(
        gradient: isDark
            ? AppTheme.cardGradient
            : LinearGradient(
                colors: [AppTheme.lightCard, AppTheme.lightSurface],
              ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppTheme.primaryColor.withOpacity(0.2),
        ),
      ),
      child: TextFormField(
        controller: controller,
        obscureText: obscureText,
        keyboardType: keyboardType,
        validator: validator,
        style: TextStyle(color: textColor),
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          labelStyle: TextStyle(
            color: textColor.withOpacity(0.6),
          ),
          hintStyle: TextStyle(
            color: textColor.withOpacity(0.3),
          ),
          prefixIcon: Icon(icon, color: AppTheme.primaryColor),
          suffixIcon: suffixIcon,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.all(20),
        ),
      ),
    );
  }
}
