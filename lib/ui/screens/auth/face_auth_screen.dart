import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:animate_do/animate_do.dart';
import 'package:iconsax/iconsax.dart';

import '../../../core/providers/auth_provider.dart';
import '../../../core/providers/settings_provider.dart';
import '../../../core/models/face_auth_model.dart';
import '../../../core/services/auth_audio_service.dart';
import '../../../core/localization/app_localizations.dart';

class FaceAuthScreen extends StatefulWidget {
  const FaceAuthScreen({super.key});

  @override
  State<FaceAuthScreen> createState() => _FaceAuthScreenState();
}

class _FaceAuthScreenState extends State<FaceAuthScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  final AuthAudioService _audioService = AuthAudioService();
  FaceAuthStatus? _previousStatus;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();

    // Auto-start discovery
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startDiscovery();
    });
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _audioService.stop(); // Stop any playing audio
    super.dispose();
  }

  // Play audio based on status changes
  void _handleStatusChange(FaceAuthStatus newStatus) {
    if (_previousStatus != newStatus) {
      // Check if audio is enabled in settings
      final settingsProvider = context.read<SettingsProvider>();
      if (settingsProvider.enableAuthAudio) {
        if (newStatus == FaceAuthStatus.scanning) {
          // User should look at camera
          _audioService.playLookAtCamera();
        } else if (newStatus == FaceAuthStatus.success) {
          // Face recognized successfully
          _audioService.playSuccess();
        }
      }
      _previousStatus = newStatus;

      // Check if we need to navigate after status change
      _checkAuthStatusAndNavigate(newStatus);
    }
  }

  Future<void> _startDiscovery() async {
    final authProvider = context.read<AuthProvider>();
    final success = await authProvider.discoverFaceAuthBeacon();

    if (success && mounted) {
      // Automatically connect if beacon found
      _connectToBroker();
    }
  }

  Future<void> _connectToBroker() async {
    final authProvider = context.read<AuthProvider>();
    final connected = await authProvider.connectToFaceBroker();

    if (connected && mounted) {
      // Connection successful, automatically start face authentication
      debugPrint('🔵 Auto-starting face authentication...');
      await Future.delayed(const Duration(milliseconds: 500));
      _authenticateWithFace();
    }
  }

  Future<void> _authenticateWithFace() async {
    final authProvider = context.read<AuthProvider>();

    // Start the authentication process
    authProvider.authenticateWithFace();

    // Wait for status to change to either success or failed
    // The status is updated through the stream listener in auth_provider
    await Future.delayed(const Duration(milliseconds: 500));

    // The navigation will be handled by the status change listener in initState
    // which monitors faceAuthStatus and calls the navigation logic
  }

  void _checkAuthStatusAndNavigate(FaceAuthStatus status) async {
    if (status == FaceAuthStatus.success) {
      // Wait a moment for the success sound to play
      await Future.delayed(const Duration(milliseconds: 1500));

      if (mounted) {
        // Check if Layer 2 (Email/Password) is enabled in settings
        final settingsProvider = context.read<SettingsProvider>();

        if (settingsProvider.enableEmailPasswordAuth) {
          // Layer 2 is ENABLED - Navigate to email/password screen
          debugPrint(
              '🔐 Layer 1 complete. Proceeding to Layer 2 (Email/Password)...');
          Navigator.of(context).pushReplacementNamed('/auth/email-password');
        } else {
          // Layer 2 is DISABLED - Navigate directly to home
          debugPrint(
              '✅ Layer 1 complete. Layer 2 disabled. Navigating to home...');
          Navigator.of(context).pushReplacementNamed('/home');
        }
      }
    } else if (status == FaceAuthStatus.failed ||
        status == FaceAuthStatus.error) {
      // Show error dialog on failure
      if (mounted) {
        final authProvider = context.read<AuthProvider>();
        _showErrorDialog(
            authProvider.faceAuthMessage ?? 'Authentication failed');
      }
    }
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Authentication Failed'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _authenticateWithFace();
            },
            child: const Text('Try Again'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final loc = AppLocalizations.of(context);

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
          child: Column(
            children: [
              // App Bar
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      loc.translate('face_auth_title'),
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),

              Expanded(
                child: Consumer<AuthProvider>(
                  builder: (context, authProvider, _) {
                    return _buildContent(
                      context,
                      theme,
                      authProvider,
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildContent(
    BuildContext context,
    ThemeData theme,
    AuthProvider authProvider,
  ) {
    final status = authProvider.faceAuthStatus;

    // Handle audio notifications based on status changes
    _handleStatusChange(status);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(height: 40),

          // Face Icon with Animation
          FadeInDown(
            child: _buildFaceIcon(status),
          ),

          const SizedBox(height: 40),

          // Status Message
          FadeInUp(
            delay: const Duration(milliseconds: 200),
            child: _buildStatusMessage(theme, authProvider),
          ),

          const SizedBox(height: 60),

          // Action Button
          FadeInUp(
            delay: const Duration(milliseconds: 400),
            child: _buildActionButton(theme, authProvider, status),
          ),

          const SizedBox(height: 24),

          // Beacon Info (if discovered)
          if (authProvider.discoveredBeacon != null)
            FadeInUp(
              delay: const Duration(milliseconds: 600),
              child: _buildBeaconInfo(theme, authProvider.discoveredBeacon!),
            ),

          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildFaceIcon(FaceAuthStatus status) {
    IconData icon;
    Color color;

    switch (status) {
      case FaceAuthStatus.success:
        icon = Iconsax.tick_circle;
        color = Colors.green;
        break;
      case FaceAuthStatus.failed:
      case FaceAuthStatus.error:
        icon = Iconsax.close_circle;
        color = Colors.red;
        break;
      case FaceAuthStatus.timeout:
        icon = Iconsax.timer_1;
        color = Colors.orange;
        break;
      case FaceAuthStatus.initializing:
      case FaceAuthStatus.scanning:
      case FaceAuthStatus.processing:
        icon = Iconsax.scan;
        color = Theme.of(context).colorScheme.primary;
        break;
      default:
        icon = Iconsax.security_user;
        color = Theme.of(context).colorScheme.primary;
    }

    Widget iconWidget = Container(
      width: 200,
      height: 200,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            color.withOpacity(0.2),
            color.withOpacity(0.1),
          ],
        ),
      ),
      child: Icon(
        icon,
        size: 100,
        color: color,
      ),
    );

    // Add pulse animation when initializing, scanning or processing
    if (status == FaceAuthStatus.initializing ||
        status == FaceAuthStatus.scanning ||
        status == FaceAuthStatus.processing) {
      return AnimatedBuilder(
        animation: _pulseController,
        builder: (context, child) {
          return Transform.scale(
            scale: 1.0 + (_pulseController.value * 0.1),
            child: child,
          );
        },
        child: iconWidget,
      );
    }

    return iconWidget;
  }

  Widget _buildStatusMessage(ThemeData theme, AuthProvider authProvider) {
    final status = authProvider.faceAuthStatus;
    final message = authProvider.faceAuthMessage;
    final loc = AppLocalizations.of(context);

    String title;
    String? subtitle;

    switch (status) {
      case FaceAuthStatus.idle:
        title = loc.translate('face_auth_title');
        subtitle = loc.translate('face_auth_subtitle');
        break;
      case FaceAuthStatus.discovering:
        title = loc.translate('discovering');
        subtitle = loc.translate('face_auth_subtitle');
        break;
      case FaceAuthStatus.connecting:
        title = loc.translate('connecting');
        subtitle = loc.translate('connecting');
        break;
      case FaceAuthStatus.requestingScan:
        title = loc.translate('requesting_scan');
        subtitle = message ?? loc.translate('initializing');
        break;
      case FaceAuthStatus.initializing:
        title = loc.translate('initializing');
        subtitle = message ?? loc.translate('initializing');
        break;
      case FaceAuthStatus.scanning:
        title = loc.translate('scanning');
        subtitle = loc.translate('scanning_subtitle');
        break;
      case FaceAuthStatus.processing:
        title = loc.translate('processing');
        subtitle = loc.translate('processing_subtitle');
        break;
      case FaceAuthStatus.success:
        title = loc.translate('auth_success');
        subtitle = message ?? loc.translate('auth_success_subtitle');
        break;
      case FaceAuthStatus.failed:
        title = loc.translate('auth_failed');
        subtitle = message ?? loc.translate('auth_failed_subtitle');
        break;
      case FaceAuthStatus.timeout:
        title = loc.translate('auth_timeout');
        subtitle = loc.translate('auth_timeout_subtitle');
        break;
      case FaceAuthStatus.error:
        title = loc.translate('auth_error');
        subtitle = message ?? loc.translate('auth_error_subtitle');
        break;
    }

    return Column(
      children: [
        Text(
          title,
          style: theme.textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 12),
        Text(
          subtitle,
          style: theme.textTheme.bodyLarge?.copyWith(
            color: theme.textTheme.bodySmall?.color,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildActionButton(
    ThemeData theme,
    AuthProvider authProvider,
    FaceAuthStatus status,
  ) {
    final isLoading = authProvider.isLoading;
    final hasBeacon = authProvider.discoveredBeacon != null;
    final loc = AppLocalizations.of(context);

    String buttonText;
    VoidCallback? onPressed;

    if (!hasBeacon) {
      buttonText = loc.translate('discovering');
      onPressed = isLoading ? null : _startDiscovery;
    } else if (status == FaceAuthStatus.idle ||
        status == FaceAuthStatus.failed) {
      buttonText = loc.translate('sign_in_with_face');
      onPressed = isLoading ? null : _authenticateWithFace;
    } else if (status == FaceAuthStatus.success) {
      // SUCCESS - No button needed, auto-navigating
      return const SizedBox.shrink();
    } else {
      buttonText = loc.translate('cancel');
      onPressed = () {
        authProvider.cancelFaceAuth();
      };
    }

    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        child: isLoading
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : Text(
                buttonText,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
      ),
    );
  }

  Widget _buildBeaconInfo(ThemeData theme, FaceAuthBeacon beacon) {
    final loc = AppLocalizations.of(context);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceVariant.withOpacity(0.3),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.colorScheme.primary.withOpacity(0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Iconsax.monitor,
                size: 20,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Text(
                loc.translate('beacon_info'),
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildInfoRow(theme, loc.translate('service_name'), beacon.name),
          _buildInfoRow(theme, loc.translate('ip_address'), beacon.ip),
          _buildInfoRow(theme, loc.translate('port'), beacon.port.toString()),
        ],
      ),
    );
  }

  Widget _buildInfoRow(ThemeData theme, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.textTheme.bodySmall?.color,
            ),
          ),
          Text(
            value,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
