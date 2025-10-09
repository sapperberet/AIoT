import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:animate_do/animate_do.dart';
import 'package:iconsax/iconsax.dart';

import '../../../core/providers/auth_provider.dart';
import '../../../core/models/face_auth_model.dart';

class FaceAuthScreen extends StatefulWidget {
  const FaceAuthScreen({super.key});

  @override
  State<FaceAuthScreen> createState() => _FaceAuthScreenState();
}

class _FaceAuthScreenState extends State<FaceAuthScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;

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
    super.dispose();
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
      // Connection successful, user can now authenticate
    }
  }

  Future<void> _authenticateWithFace() async {
    final authProvider = context.read<AuthProvider>();
    final success = await authProvider.authenticateWithFace();

    if (mounted) {
      if (success) {
        // Authentication successful - navigate to home
        Navigator.of(context).pushReplacementNamed('/home');
      } else {
        // Show error
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
                      'Face Authentication',
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

          // Alternative Login Option
          FadeInUp(
            delay: const Duration(milliseconds: 800),
            child: TextButton.icon(
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(Icons.email),
              label: const Text('Use Email & Password Instead'),
            ),
          ),
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

    // Add pulse animation when scanning
    if (status == FaceAuthStatus.scanning ||
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

    String title;
    String? subtitle;

    switch (status) {
      case FaceAuthStatus.idle:
        title = 'Ready to Authenticate';
        subtitle = 'Tap the button below to start';
        break;
      case FaceAuthStatus.discovering:
        title = 'Discovering...';
        subtitle = 'Searching for face recognition system';
        break;
      case FaceAuthStatus.connecting:
        title = 'Connecting...';
        subtitle = 'Establishing connection';
        break;
      case FaceAuthStatus.requestingScan:
        title = 'Requesting Scan...';
        subtitle = null;
        break;
      case FaceAuthStatus.scanning:
        title = 'Look at the Camera';
        subtitle = 'Position your face in front of the camera';
        break;
      case FaceAuthStatus.processing:
        title = 'Processing...';
        subtitle = 'Verifying your identity';
        break;
      case FaceAuthStatus.success:
        title = 'Success!';
        subtitle = message ?? 'Authentication successful';
        break;
      case FaceAuthStatus.failed:
        title = 'Failed';
        subtitle = message ?? 'Face not recognized';
        break;
      case FaceAuthStatus.timeout:
        title = 'Timeout';
        subtitle = 'Request timed out. Please try again.';
        break;
      case FaceAuthStatus.error:
        title = 'Error';
        subtitle = message ?? 'An error occurred';
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
        if (subtitle != null) ...[
          const SizedBox(height: 12),
          Text(
            subtitle,
            style: theme.textTheme.bodyLarge?.copyWith(
              color: theme.textTheme.bodySmall?.color,
            ),
            textAlign: TextAlign.center,
          ),
        ],
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

    String buttonText;
    VoidCallback? onPressed;

    if (!hasBeacon) {
      buttonText = 'Scan for System';
      onPressed = isLoading ? null : _startDiscovery;
    } else if (status == FaceAuthStatus.idle ||
        status == FaceAuthStatus.failed) {
      buttonText = 'Authenticate with Face';
      onPressed = isLoading ? null : _authenticateWithFace;
    } else if (status == FaceAuthStatus.success) {
      buttonText = 'Continue';
      onPressed = () => Navigator.of(context).pushReplacementNamed('/home');
    } else {
      buttonText = 'Cancel';
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
                'System Connected',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildInfoRow(theme, 'Name', beacon.name),
          _buildInfoRow(theme, 'IP Address', beacon.ip),
          _buildInfoRow(theme, 'Port', beacon.port.toString()),
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
