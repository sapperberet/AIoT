import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:animate_do/animate_do.dart';
import 'package:iconsax/iconsax.dart';

import '../../../core/providers/auth_provider.dart';
import '../../../core/services/user_approval_service.dart';
import '../../../core/localization/app_localizations.dart';

/// Screen shown to users who have registered but are pending admin approval
class PendingApprovalScreen extends StatefulWidget {
  const PendingApprovalScreen({super.key});

  @override
  State<PendingApprovalScreen> createState() => _PendingApprovalScreenState();
}

class _PendingApprovalScreenState extends State<PendingApprovalScreen> {
  final UserApprovalService _approvalService = UserApprovalService();
  bool _isCheckingStatus = false;

  @override
  void initState() {
    super.initState();
    _startApprovalListener();
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
      Navigator.of(context).pushReplacementNamed('/login');
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
                      MediaQuery.of(context).padding.bottom - 48,
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
                              child: CircularProgressIndicator(strokeWidth: 2),
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
