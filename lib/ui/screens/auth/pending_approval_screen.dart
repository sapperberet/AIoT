import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:animate_do/animate_do.dart';
import 'package:iconsax/iconsax.dart';

import '../../../core/providers/auth_provider.dart';
import '../../../core/services/user_approval_service.dart';
import '../../../core/services/mqtt_service.dart';
import '../../../core/localization/app_localizations.dart';

/// Screen shown to users who have registered but are pending admin approval
class PendingApprovalScreen extends StatefulWidget {
  const PendingApprovalScreen({super.key});

  @override
  State<PendingApprovalScreen> createState() => _PendingApprovalScreenState();
}

class _PendingApprovalScreenState extends State<PendingApprovalScreen> {
  final UserApprovalService _approvalService = UserApprovalService();
  final TextEditingController _otpController = TextEditingController();
  bool _isCheckingStatus = false;
  bool _isVerifyingOtp = false;
  bool _isVerifyingMqtt = false;
  String? _otpError;

  @override
  void initState() {
    super.initState();
    _startApprovalListener();
    _checkMqttAutoVerification();
  }

  @override
  void dispose() {
    _otpController.dispose();
    super.dispose();
  }

  void _startApprovalListener() {
    // Listen for approval status changes
    _approvalService.watchCurrentUserApprovalStatus().listen((isApproved) {
      if (isApproved && mounted) {
        // User has been approved - navigate to main app
        Navigator.of(context).pushReplacementNamed('/home');
      }
    });
  }

  /// Check if user is connected to MQTT broker for auto-verification
  Future<void> _checkMqttAutoVerification() async {
    try {
      final mqttService = context.read<MqttService>();
      if (mqttService.currentStatus == ConnectionStatus.connected) {
        // Auto-verify via MQTT network
        await _verifyViaMqtt();
      }
    } catch (e) {
      debugPrint('MQTT check skipped: $e');
    }
  }

  /// Verify user via MQTT network connection
  Future<void> _verifyViaMqtt() async {
    setState(() => _isVerifyingMqtt = true);

    try {
      final mqttService = context.read<MqttService>();

      // Try to connect if not already connected
      if (mqttService.currentStatus != ConnectionStatus.connected) {
        await mqttService.connect();
      }

      if (mqttService.currentStatus == ConnectionStatus.connected) {
        final result = await _approvalService.verifyViaMqttConnection();

        if (!mounted) return;

        if (result == 'success') {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Verified via network connection!'),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.of(context).pushReplacementNamed('/home');
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Could not connect to broker network'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('MQTT verification error: $e');
    } finally {
      if (mounted) {
        setState(() => _isVerifyingMqtt = false);
      }
    }
  }

  Future<void> _checkApprovalStatus() async {
    setState(() => _isCheckingStatus = true);

    final isApproved = await _approvalService.isCurrentUserApproved();

    setState(() => _isCheckingStatus = false);

    if (isApproved && mounted) {
      Navigator.of(context).pushReplacementNamed('/home');
    } else if (mounted) {
      final loc = AppLocalizations.of(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            loc.translate('approval_still_pending'),
          ),
          backgroundColor: Colors.orange,
        ),
      );
    }
  }

  Future<void> _signOut() async {
    await context.read<AuthProvider>().signOut();
    if (mounted) {
      Navigator.of(context).pushReplacementNamed('/modern-login');
    }
  }

  Future<void> _verifyOtp() async {
    final otp = _otpController.text.trim();
    if (otp.length != 6) {
      setState(() => _otpError = 'OTP must be 6 digits');
      return;
    }

    setState(() {
      _isVerifyingOtp = true;
      _otpError = null;
    });

    final result = await _approvalService.selfVerifyOtp(otp);

    setState(() => _isVerifyingOtp = false);

    if (!mounted) return;

    switch (result) {
      case 'success':
        Navigator.of(context).pushReplacementNamed('/home');
        break;
      case 'invalid_otp':
        setState(() => _otpError = 'Invalid OTP. Please check and try again.');
        break;
      case 'expired':
        setState(() => _otpError =
            'OTP has expired. Please request a new one from an admin.');
        break;
      default:
        setState(() => _otpError = 'An error occurred. Please try again.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final loc = AppLocalizations.of(context);
    final authProvider = context.watch<AuthProvider>();
    final user = authProvider.currentUser;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              theme.colorScheme.primary.withOpacity(0.1),
              theme.colorScheme.secondary.withOpacity(0.1),
            ],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: MediaQuery.of(context).size.height -
                      MediaQuery.of(context).padding.top -
                      MediaQuery.of(context).padding.bottom -
                      48,
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Animated waiting icon
                    FadeInDown(
                      child: Container(
                        padding: const EdgeInsets.all(32),
                        decoration: BoxDecoration(
                          color: Colors.orange.withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Iconsax.clock,
                          size: 80,
                          color: Colors.orange,
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),

                    // Title
                    FadeInDown(
                      delay: const Duration(milliseconds: 200),
                      child: Text(
                        loc.translate('pending_approval_title'),
                        style: theme.textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Description
                    FadeInDown(
                      delay: const Duration(milliseconds: 400),
                      child: Text(
                        loc.translate('pending_approval_description'),
                        style: theme.textTheme.bodyLarge?.copyWith(
                          color: Colors.grey[600],
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    const SizedBox(height: 32),

                    // User info card
                    if (user != null)
                      FadeInUp(
                        delay: const Duration(milliseconds: 600),
                        child: Card(
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              children: [
                                CircleAvatar(
                                  radius: 30,
                                  backgroundColor: theme.colorScheme.primary,
                                  child: Text(
                                    (user.displayName ?? user.email ?? 'U')[0]
                                        .toUpperCase(),
                                    style: const TextStyle(
                                      fontSize: 24,
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  user.displayName ?? 'User',
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Text(
                                  user.email ?? '',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: Colors.grey[600],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    const SizedBox(height: 32),

                    // Info box
                    FadeInUp(
                      delay: const Duration(milliseconds: 800),
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.blue.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Colors.blue.withOpacity(0.3),
                          ),
                        ),
                        child: Row(
                          children: [
                            const Icon(Iconsax.info_circle, color: Colors.blue),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                loc.translate('pending_approval_info'),
                                style: theme.textTheme.bodySmall,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),

                    // OTP Entry Section
                    FadeInUp(
                      delay: const Duration(milliseconds: 900),
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surface,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: theme.colorScheme.outline.withOpacity(0.3),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Email indicator
                            if (user?.email != null)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 8,
                                ),
                                margin: const EdgeInsets.only(bottom: 12),
                                decoration: BoxDecoration(
                                  color: Colors.green.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: Colors.green.withOpacity(0.3),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(
                                      Iconsax.sms,
                                      color: Colors.green,
                                      size: 16,
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        'Code sent to: ${user!.email}',
                                        style:
                                            theme.textTheme.bodySmall?.copyWith(
                                          color: Colors.green[700],
                                          fontWeight: FontWeight.w500,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            Row(
                              children: [
                                Icon(
                                  Iconsax.key,
                                  color: theme.colorScheme.primary,
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Verify Your Email',
                                  style: theme.textTheme.titleSmall?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Check your email for a 6-digit verification code. Enter it below to activate your account.',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: Colors.grey[600],
                              ),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: TextField(
                                    controller: _otpController,
                                    keyboardType: TextInputType.number,
                                    maxLength: 6,
                                    decoration: InputDecoration(
                                      hintText: '6-digit OTP',
                                      counterText: '',
                                      errorText: _otpError,
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 12,
                                      ),
                                    ),
                                    onChanged: (_) {
                                      if (_otpError != null) {
                                        setState(() => _otpError = null);
                                      }
                                    },
                                  ),
                                ),
                                const SizedBox(width: 12),
                                ElevatedButton(
                                  onPressed:
                                      _isVerifyingOtp ? null : _verifyOtp,
                                  style: ElevatedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 20,
                                      vertical: 14,
                                    ),
                                  ),
                                  child: _isVerifyingOtp
                                      ? const SizedBox(
                                          width: 20,
                                          height: 20,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                          ),
                                        )
                                      : const Text('Verify'),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // OR Divider
                    FadeInUp(
                      delay: const Duration(milliseconds: 950),
                      child: Row(
                        children: [
                          Expanded(child: Divider(color: Colors.grey[400])),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: Text(
                              'OR',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: Colors.grey[600],
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          Expanded(child: Divider(color: Colors.grey[400])),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // MQTT Network Verification Button
                    FadeInUp(
                      delay: const Duration(milliseconds: 975),
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.teal.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Colors.teal.withOpacity(0.3),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Iconsax.wifi,
                                  color: Colors.teal,
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Network Verification',
                                  style: theme.textTheme.titleSmall?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'If you\'re connected to the home network (MQTT broker), you can verify automatically.',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: Colors.grey[600],
                              ),
                            ),
                            const SizedBox(height: 12),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                onPressed:
                                    _isVerifyingMqtt ? null : _verifyViaMqtt,
                                icon: _isVerifyingMqtt
                                    ? const SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white,
                                        ),
                                      )
                                    : const Icon(Iconsax.wifi),
                                label: Text(_isVerifyingMqtt
                                    ? 'Connecting...'
                                    : 'Verify via Network'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.teal,
                                  foregroundColor: Colors.white,
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 14),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Check status button
                    FadeInUp(
                      delay: const Duration(milliseconds: 1000),
                      child: SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed:
                              _isCheckingStatus ? null : _checkApprovalStatus,
                          icon: _isCheckingStatus
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child:
                                      CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Icon(Iconsax.refresh),
                          label: Text(
                            loc.translate('check_approval_status'),
                          ),
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Sign out button
                    FadeInUp(
                      delay: const Duration(milliseconds: 1200),
                      child: TextButton.icon(
                        onPressed: _signOut,
                        icon: const Icon(Iconsax.logout),
                        label: Text(
                          loc.translate('sign_out'),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
