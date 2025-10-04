import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:animate_do/animate_do.dart';
import 'package:glassmorphism/glassmorphism.dart';
import 'package:iconsax/iconsax.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/theme/app_theme.dart';
import 'email_verification_screen.dart';

class ModernRegisterScreen extends StatefulWidget {
  const ModernRegisterScreen({super.key});

  @override
  State<ModernRegisterScreen> createState() => _ModernRegisterScreenState();
}

class _ModernRegisterScreenState extends State<ModernRegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _acceptTerms = false;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _handleRegister() async {
    if (!_acceptTerms) {
      _showErrorSnackbar('Please accept the terms and conditions');
      return;
    }

    if (_formKey.currentState!.validate()) {
      final authProvider = context.read<AuthProvider>();
      
      final success = await authProvider.register(
        _emailController.text.trim(),
        _passwordController.text,
        _nameController.text.trim(),
      );

      if (success && mounted) {
        // Navigate to email verification screen
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) => const EmailVerificationScreen(),
          ),
        );
      } else if (mounted && authProvider.errorMessage != null) {
        _showErrorSnackbar(authProvider.errorMessage!);
      }
    }
  }

  void _showErrorSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Iconsax.warning_2, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: AppTheme.errorColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: AppTheme.mediumRadius),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(gradient: AppTheme.backgroundGradient),
        child: SafeArea(
          child: Column(
            children: [
              // Back Button
              Padding(
                padding: const EdgeInsets.all(16),
                child: Align(
                  alignment: Alignment.topLeft,
                  child: FadeInLeft(
                    child: GlassmorphicContainer(
                      width: 48,
                      height: 48,
                      borderRadius: 12,
                      blur: 10,
                      alignment: Alignment.center,
                      border: 2,
                      linearGradient: LinearGradient(
                        colors: [
                          Colors.white.withOpacity(0.1),
                          Colors.white.withOpacity(0.05),
                        ],
                      ),
                      borderGradient: LinearGradient(
                        colors: [
                          Colors.white.withOpacity(0.2),
                          Colors.white.withOpacity(0.1),
                        ],
                      ),
                      child: IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Iconsax.arrow_left, color: AppTheme.lightText),
                      ),
                    ),
                  ),
                ),
              ),

              Expanded(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      // Logo
                      FadeInDown(
                        child: Container(
                          width: 100,
                          height: 100,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: AppTheme.accentGradient,
                            boxShadow: [
                              BoxShadow(
                                color: AppTheme.accentColor.withOpacity(0.3),
                                blurRadius: 30,
                                offset: const Offset(0, 10),
                              ),
                            ],
                          ),
                          child: const Icon(
                            Iconsax.user_add,
                            size: 50,
                            color: Colors.white,
                          ),
                        ),
                      ),

                      const SizedBox(height: 24),

                      // Title
                      FadeInDown(
                        delay: const Duration(milliseconds: 200),
                        child: Column(
                          children: [
                            Text(
                              'Create Account',
                              style: Theme.of(context).textTheme.displayMedium?.copyWith(
                                color: AppTheme.lightText,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Join the smart home revolution',
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: AppTheme.mutedText,
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 40),

                      // Registration Form
                      FadeInUp(
                        delay: const Duration(milliseconds: 400),
                        child: GlassmorphicContainer(
                          width: double.infinity,
                          height: 520,
                          borderRadius: 24,
                          blur: 20,
                          alignment: Alignment.center,
                          border: 2,
                          linearGradient: LinearGradient(
                            colors: [
                              Colors.white.withOpacity(0.1),
                              Colors.white.withOpacity(0.05),
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderGradient: LinearGradient(
                            colors: [
                              Colors.white.withOpacity(0.2),
                              Colors.white.withOpacity(0.1),
                            ],
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Form(
                              key: _formKey,
                              child: Column(
                                children: [
                                  // Name Field
                                  _buildTextField(
                                    controller: _nameController,
                                    label: 'Full Name',
                                    hint: 'Enter your name',
                                    icon: Iconsax.user,
                                    validator: (value) {
                                      if (value == null || value.isEmpty) {
                                        return 'Please enter your name';
                                      }
                                      return null;
                                    },
                                  ),

                                  const SizedBox(height: 16),

                                  // Email Field
                                  _buildTextField(
                                    controller: _emailController,
                                    label: 'Email',
                                    hint: 'Enter your email',
                                    icon: Iconsax.sms,
                                    keyboardType: TextInputType.emailAddress,
                                    validator: (value) {
                                      if (value == null || value.isEmpty) {
                                        return 'Please enter your email';
                                      }
                                      if (!value.contains('@')) {
                                        return 'Please enter a valid email';
                                      }
                                      return null;
                                    },
                                  ),

                                  const SizedBox(height: 16),

                                  // Password Field
                                  _buildTextField(
                                    controller: _passwordController,
                                    label: 'Password',
                                    hint: 'Create a password',
                                    icon: Iconsax.lock,
                                    obscureText: _obscurePassword,
                                    suffixIcon: IconButton(
                                      icon: Icon(
                                        _obscurePassword ? Iconsax.eye_slash : Iconsax.eye,
                                        color: AppTheme.mutedText,
                                      ),
                                      onPressed: () {
                                        setState(() {
                                          _obscurePassword = !_obscurePassword;
                                        });
                                      },
                                    ),
                                    validator: (value) {
                                      if (value == null || value.isEmpty) {
                                        return 'Please enter a password';
                                      }
                                      if (value.length < 6) {
                                        return 'Password must be at least 6 characters';
                                      }
                                      return null;
                                    },
                                  ),

                                  const SizedBox(height: 16),

                                  // Confirm Password Field
                                  _buildTextField(
                                    controller: _confirmPasswordController,
                                    label: 'Confirm Password',
                                    hint: 'Confirm your password',
                                    icon: Iconsax.lock_1,
                                    obscureText: _obscureConfirmPassword,
                                    suffixIcon: IconButton(
                                      icon: Icon(
                                        _obscureConfirmPassword ? Iconsax.eye_slash : Iconsax.eye,
                                        color: AppTheme.mutedText,
                                      ),
                                      onPressed: () {
                                        setState(() {
                                          _obscureConfirmPassword = !_obscureConfirmPassword;
                                        });
                                      },
                                    ),
                                    validator: (value) {
                                      if (value == null || value.isEmpty) {
                                        return 'Please confirm your password';
                                      }
                                      if (value != _passwordController.text) {
                                        return 'Passwords do not match';
                                      }
                                      return null;
                                    },
                                  ),

                                  const SizedBox(height: 20),

                                  // Terms & Conditions
                                  Row(
                                    children: [
                                      SizedBox(
                                        width: 24,
                                        height: 24,
                                        child: Checkbox(
                                          value: _acceptTerms,
                                          onChanged: (value) {
                                            setState(() {
                                              _acceptTerms = value ?? false;
                                            });
                                          },
                                          fillColor: MaterialStateProperty.all(
                                            AppTheme.primaryColor,
                                          ),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text.rich(
                                          TextSpan(
                                            text: 'I agree to the ',
                                            style: Theme.of(context).textTheme.bodySmall,
                                            children: [
                                              TextSpan(
                                                text: 'Terms & Conditions',
                                                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                                  color: AppTheme.primaryColor,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),

                                  const SizedBox(height: 32),

                                  // Register Button
                                  Consumer<AuthProvider>(
                                    builder: (context, authProvider, child) {
                                      return authProvider.isLoading
                                          ? const CircularProgressIndicator()
                                          : _buildGradientButton(
                                              text: 'Create Account',
                                              onPressed: _handleRegister,
                                            );
                                    },
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 24),

                      // Login Link
                      FadeInUp(
                        delay: const Duration(milliseconds: 600),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              'Already have an account? ',
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: AppTheme.mutedText,
                              ),
                            ),
                            TextButton(
                              onPressed: () => Navigator.pop(context),
                              child: Text(
                                'Sign In',
                                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  color: AppTheme.primaryColor,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
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
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    bool obscureText = false,
    TextInputType? keyboardType,
    Widget? suffixIcon,
    String? Function(String?)? validator,
  }) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: AppTheme.mediumRadius,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: TextFormField(
        controller: controller,
        obscureText: obscureText,
        keyboardType: keyboardType,
        style: const TextStyle(color: AppTheme.lightText),
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          prefixIcon: Icon(icon, color: AppTheme.primaryColor),
          suffixIcon: suffixIcon,
          filled: true,
          fillColor: AppTheme.darkSurface.withOpacity(0.5),
          border: OutlineInputBorder(
            borderRadius: AppTheme.mediumRadius,
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: AppTheme.mediumRadius,
            borderSide: BorderSide(
              color: Colors.white.withOpacity(0.1),
              width: 1,
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: AppTheme.mediumRadius,
            borderSide: const BorderSide(
              color: AppTheme.primaryColor,
              width: 2,
            ),
          ),
        ),
        validator: validator,
      ),
    );
  }

  Widget _buildGradientButton({
    required String text,
    required VoidCallback onPressed,
  }) {
    return Container(
      width: double.infinity,
      height: 56,
      decoration: BoxDecoration(
        gradient: AppTheme.accentGradient,
        borderRadius: AppTheme.mediumRadius,
        boxShadow: [
          BoxShadow(
            color: AppTheme.accentColor.withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: AppTheme.mediumRadius,
          ),
        ),
        child: Text(
          text,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}
