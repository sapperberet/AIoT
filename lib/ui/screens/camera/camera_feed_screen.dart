import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:iconsax/iconsax.dart';
import 'package:animate_do/animate_do.dart';
import 'package:video_player/video_player.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/theme/app_theme.dart';

class CameraFeedScreen extends StatefulWidget {
  const CameraFeedScreen({super.key});

  @override
  State<CameraFeedScreen> createState() => _CameraFeedScreenState();
}

class _CameraFeedScreenState extends State<CameraFeedScreen> {
  VideoPlayerController? _controller;
  bool _isLoading = true;
  String? _errorMessage;
  bool _isDoorOpen = false;

  @override
  void initState() {
    super.initState();
    _initializeCamera();
  }

  void _initializeCamera() async {
    final authProvider = context.read<AuthProvider>();

    // Check if beacon is discovered
    if (authProvider.discoveredBeacon == null) {
      setState(() {
        _errorMessage =
            'Please connect to face recognition system first.\n\nGo back and tap "Login with Face Recognition" to discover the system.';
        _isLoading = false;
      });
      return;
    }

    final streamUrl = authProvider.getRtspStreamUrl(); // Use RTSP

    if (streamUrl == null) {
      setState(() {
        _errorMessage =
            'Camera stream not available. Please connect to face recognition system.';
        _isLoading = false;
      });
      return;
    }

    // Debug log
    debugPrint('📹 Camera RTSP stream URL: $streamUrl');

    try {
      // Dispose previous controller if exists
      await _controller?.dispose();

      // Initialize video player with RTSP stream
      // video_player on Android uses ExoPlayer which supports RTSP
      _controller = VideoPlayerController.networkUrl(
        Uri.parse(streamUrl),
        videoPlayerOptions: VideoPlayerOptions(
          allowBackgroundPlayback: false,
          mixWithOthers: false,
        ),
      );

      await _controller!.initialize();
      await _controller!.play();

      // Set to loop
      _controller!.setLooping(true);

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('❌ Video player error: $e');
      setState(() {
        _errorMessage =
            'Failed to initialize video player.\n\nError: ${e.toString()}';
        _isLoading = false;
      });
    }
  }

  Future<void> _openDoor() async {
    final authProvider = context.read<AuthProvider>();

    setState(() {
      _isDoorOpen = true;
    });

    final success = await authProvider.openDoor();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            success ? 'Door opened successfully' : 'Failed to open door',
          ),
          backgroundColor:
              success ? AppTheme.successColor : AppTheme.errorColor,
          behavior: SnackBarBehavior.floating,
        ),
      );

      // Reset button after 3 seconds
      Future.delayed(const Duration(seconds: 3), () {
        if (mounted) {
          setState(() {
            _isDoorOpen = false;
          });
        }
      });
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textColor = theme.colorScheme.onBackground;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black.withOpacity(0.8),
        elevation: 0,
        leading: FadeInLeft(
          child: IconButton(
            icon: Icon(Iconsax.arrow_left, color: textColor),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        title: FadeInDown(
          child: Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: _isLoading
                      ? AppTheme.warningColor
                      : (_errorMessage != null
                          ? AppTheme.errorColor
                          : AppTheme.successColor),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: (_isLoading
                              ? AppTheme.warningColor
                              : (_errorMessage != null
                                  ? AppTheme.errorColor
                                  : AppTheme.successColor))
                          .withOpacity(0.5),
                      blurRadius: 8,
                      spreadRadius: 2,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Text(
                AppLocalizations.of(context).t('camera_feed'),
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: textColor,
                ),
              ),
            ],
          ),
        ),
        actions: [
          FadeInRight(
            child: IconButton(
              icon: Icon(Iconsax.refresh, color: textColor),
              onPressed: () {
                setState(() {
                  _isLoading = true;
                  _errorMessage = null;
                });
                _initializeCamera();
              },
            ),
          ),
        ],
      ),
      body: Stack(
        children: [
          // Camera Feed
          if (_errorMessage != null)
            Center(
              child: FadeIn(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Iconsax.video_slash,
                      size: 80,
                      color: AppTheme.errorColor.withOpacity(0.5),
                    ),
                    const SizedBox(height: 24),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 32),
                      child: Text(
                        _errorMessage!,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: textColor.withOpacity(0.7),
                          fontSize: 16,
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),
                    ElevatedButton.icon(
                      onPressed: () {
                        setState(() {
                          _errorMessage = null;
                          _isLoading = true;
                        });
                        _initializeCamera();
                      },
                      icon: const Icon(Iconsax.refresh),
                      label: const Text('Retry'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            )
          else if (_controller != null && _controller!.value.isInitialized)
            Center(
              child: AspectRatio(
                aspectRatio: _controller!.value.aspectRatio,
                child: VideoPlayer(_controller!),
              ),
            )
          else
            Center(
              child: Icon(
                Iconsax.video,
                size: 80,
                color: textColor.withOpacity(0.3),
              ),
            ),

          // Loading Indicator
          if (_isLoading && _errorMessage == null)
            Center(
              child: FadeIn(
                child: Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.7),
                    borderRadius: AppTheme.largeRadius,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(
                          AppTheme.primaryColor,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Connecting to camera...',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
      floatingActionButton: _errorMessage == null
          ? FadeInUp(
              child: FloatingActionButton.extended(
                onPressed: _isDoorOpen ? null : _openDoor,
                backgroundColor:
                    _isDoorOpen ? AppTheme.successColor : AppTheme.primaryColor,
                icon: Icon(
                  _isDoorOpen ? Iconsax.tick_circle : Iconsax.lock_slash,
                  color: Colors.white,
                ),
                label: Text(
                  _isDoorOpen ? 'Door Opened' : 'Open Door',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            )
          : null,
    );
  }
}
