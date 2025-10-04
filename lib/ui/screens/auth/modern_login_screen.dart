import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:animate_do/animate_do.dart';
import 'package:glassmorphism/glassmorphism.dart';
import 'package:iconsax/iconsax.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/theme/app_theme.dart';
import 'modern_register_screen.dart';
import 'email_verification_screen.dart';

class ModernLoginScreen extends StatefulWidget {
  const ModernLoginScreen({super.key});

  @override
  State<ModernLoginScreen> createState() => _ModernLoginScreenState();
}

class _ModernLoginScreenState extends State<ModernLoginScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _rememberMe = false;
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..forward();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (_formKey.currentState!.validate()) {
      final authProvider = context.read<AuthProvider>();
      
      final success = await authProvider.signIn(
        _emailController.text.trim(),
        _passwordController.text,
      );

      if (success && mounted) {
        // Check if email is verified
        if (authProvider.currentUser?.emailVerified == false) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (context) => const EmailVerificationScreen(),
            ),
          );
        } else {
          Navigator.of(context).pushReplacementNamed('/home');
        }
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
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                const SizedBox(height: 40),
                
                // Animated Logo/Icon
                FadeInDown(
                  duration: const Duration(milliseconds: 800),
                  child: Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: AppTheme.primaryGradient,
                      boxShadow: AppTheme.glowShadow,
                    ),
                    child: const Icon(
                      Iconsax.home_15,
                      size: 60,
                      color: Colors.white,
                    ),
                  ),
                ),

                const SizedBox(height: 32),

                // Welcome Text
                FadeInDown(
                  delay: const Duration(milliseconds: 200),
                  child: Column(
                    children: [
                      Text(
                        'Welcome Back',
                        style: Theme.of(context).textTheme.displayMedium?.copyWith(
                          color: AppTheme.lightText,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Sign in to control your smart home',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppTheme.mutedText,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 48),

                // Login Form Card
                FadeInUp(
                  delay: const Duration(milliseconds: 400),
                  child: GlassmorphicContainer(
                    width: double.infinity,
                    height: 420,
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

                            const SizedBox(height: 20),

                            // Password Field
                            _buildTextField(
                              controller: _passwordController,
                              label: 'Password',
                              hint: 'Enter your password',
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
                                  return 'Please enter your password';
                                }
                                if (value.length < 6) {
                                  return 'Password must be at least 6 characters';
                                }
                                return null;
                              },
                            ),

                            const SizedBox(height: 16),

                            // Remember Me & Forgot Password
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    SizedBox(
                                      width: 24,
                                      height: 24,
                                      child: Checkbox(
                                        value: _rememberMe,
                                        onChanged: (value) {
                                          setState(() {
                                            _rememberMe = value ?? false;
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
                                    Text(
                                      'Remember me',
                                      style: Theme.of(context).textTheme.bodySmall,
                                    ),
                                  ],
                                ),
                                TextButton(
                                  onPressed: () {
                                    // TODO: Implement forgot password
                                  },
                                  child: Text(
                                    'Forgot Password?',
                                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: AppTheme.primaryColor,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),

                            const SizedBox(height: 32),

                            // Login Button
                            Consumer<AuthProvider>(
                              builder: (context, authProvider, child) {
                                return authProvider.isLoading
                                    ? const CircularProgressIndicator()
                                    : _buildGradientButton(
                                        text: 'Sign In',
                                        onPressed: _handleLogin,
                                      );
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 32),

                // Divider
                FadeInUp(
                  delay: const Duration(milliseconds: 600),
                  child: Row(
                    children: [
                      Expanded(
                        child: Divider(
                          color: AppTheme.mutedText.withOpacity(0.3),
                          thickness: 1,
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Text(
                          'OR',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ),
                      Expanded(
                        child: Divider(
                          color: AppTheme.mutedText.withOpacity(0.3),
                          thickness: 1,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 32),

                // Social Login Buttons
                FadeInUp(
                  delay: const Duration(milliseconds: 800),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _buildSocialButton(
                        icon: Iconsax.security_user,
                        onPressed: () {
                          // TODO: Implement Google Sign In
                        },
                      ),
                      const SizedBox(width: 16),
                      _buildSocialButton(
                        icon: Iconsax.play,
                        onPressed: () {
                          // TODO: Implement Apple Sign In
                        },
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 32),

                // Sign Up Link
                FadeInUp(
                  delay: const Duration(milliseconds: 1000),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        "Don't have an account? ",
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppTheme.mutedText,
                        ),
                      ),
                      TextButton(
                        onPressed: () {
                          Navigator.of(context).push(
                            PageRouteBuilder(
                              pageBuilder: (context, animation, secondaryAnimation) =>
                                  const ModernRegisterScreen(),
                              transitionsBuilder:
                                  (context, animation, secondaryAnimation, child) {
                                return FadeTransition(
                                  opacity: animation,
                                  child: SlideTransition(
                                    position: Tween<Offset>(
                                      begin: const Offset(1, 0),
                                      end: Offset.zero,
                                    ).animate(animation),
                                    child: child,
                                  ),
                                );
                              },
                            ),
                          );
                        },
                        child: Text(
                          'Sign Up',
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
        gradient: AppTheme.primaryGradient,
        borderRadius: AppTheme.mediumRadius,
        boxShadow: AppTheme.glowShadow,
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

  Widget _buildSocialButton({
    required IconData icon,
    required VoidCallback onPressed,
  }) {
    return GlassmorphicContainer(
      width: 60,
      height: 60,
      borderRadius: 16,
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
        onPressed: onPressed,
        icon: Icon(icon, color: AppTheme.lightText, size: 28),
      ),
    );
  }
}
