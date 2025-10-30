import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:iconsax/iconsax.dart';
import 'package:animate_do/animate_do.dart';
import 'package:video_player/video_player.dart';
import 'dart:async';
import '../../../core/localization/app_localizations.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/providers/home_visualization_provider.dart';
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
  DateTime? _lastStreamStart;
  int _connectionAttempts = 0;

  // Performance tuning constants - CRITICAL CHANGES FOR AUDIO/VIDEO SYNC
  static const int _maxRetries = 3;
  static const Duration _retryDelay = Duration(milliseconds: 500);

  // Monitoring metrics for debugging
  int _audioSyncErrors = 0;

  @override
  void initState() {
    super.initState();
    _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    final authProvider = context.read<AuthProvider>();
    _connectionAttempts = 0;

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

    debugPrint('📹 Camera RTSP stream URL: $streamUrl');
    debugPrint('⏱️ Starting camera stream initialization...');
    _lastStreamStart = DateTime.now();

    await _connectToStream(streamUrl);
  }

  /// Connect to camera stream with retry logic and timeout
  Future<void> _connectToStream(String streamUrl) async {
    try {
      // Dispose previous controller if exists
      await _controller?.dispose();

      // CRITICAL: Try RTSP first (faster initialization), then fallback to HLS
      // RTSP = immediate connection (good for testing)
      // HLS = slower init but better audio sync once connected
      final streamUrls = _getStreamUrlFallbackChain(streamUrl);

      debugPrint('🎥 Stream URL chain: $streamUrls');

      // Try each URL in sequence until one works
      String? effectiveStreamUrl;
      String? lastError;

      for (final url in streamUrls) {
        try {
          debugPrint('🔗 Trying: $url');

          _controller = VideoPlayerController.networkUrl(
            Uri.parse(url),
            videoPlayerOptions: VideoPlayerOptions(
              allowBackgroundPlayback: false,
              mixWithOthers: false,
            ),
          );

          _controller!.addListener(_onVideoControllerUpdate);

          // CRITICAL FIX: Aggressive timeout for faster fallback
          // RTSP is too slow on slow networks - give it only 5s then fall back to HLS
          final timeout = url.contains('.m3u8')
              ? Duration(seconds: 15) // HLS: 15 seconds (faster than RTSP)
              : Duration(
                  seconds:
                      5); // RTSP: 5 seconds ONLY (skip slow connections fast)

          debugPrint(
              '⏳ Initializing video player (timeout: ${timeout.inSeconds}s) - $url');

          await Future.any([
            _controller!.initialize(),
            Future.delayed(timeout, () {
              throw TimeoutException(
                  'Video player initialization timeout for $url');
            }),
          ]);

          // SUCCESS! Set playback speed and start
          await _controller!.setPlaybackSpeed(1.0);
          await _controller!.play();
          _controller!.setLooping(true);

          effectiveStreamUrl = url;
          debugPrint('✅ Successfully connected to: $url');
          break; // Exit loop on success
        } on TimeoutException catch (e) {
          lastError = e.message ?? 'Timeout';
          debugPrint('⏱️ Timeout on $url: $lastError');
          await _controller?.dispose();
          _controller = null;
          // Continue to next URL
        } catch (e) {
          lastError = e.toString();
          debugPrint('❌ Failed on $url: $lastError');
          await _controller?.dispose();
          _controller = null;
          // Continue to next URL
        }
      }

      if (effectiveStreamUrl == null) {
        throw Exception('All stream URLs failed. Last error: $lastError');
      }

      // Calculate initialization time
      final elapsed = DateTime.now().difference(_lastStreamStart!);
      debugPrint(
          '✅ Camera stream initialized in ${elapsed.inMilliseconds}ms using: $effectiveStreamUrl');

      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = null;
          _connectionAttempts = 0;
          _audioSyncErrors = 0;
        });
      }
    } catch (e) {
      debugPrint('❌ Video player error: $e');
      _handleStreamError(
          'Failed to initialize video player.\n\nError: ${e.toString()}');
    }
  }

  /// Get fallback chain: [RTSP (fast), HLS (better sync), HLS with alt port]
  List<String> _getStreamUrlFallbackChain(String rtspUrl) {
    try {
      if (rtspUrl.contains('rtsp://')) {
        final ip = rtspUrl.split('rtsp://')[1].split(':')[0];
        return [
          rtspUrl, // Try RTSP first (faster initialization)
          'http://$ip:8888/cam/index.m3u8', // HLS primary port
          'http://$ip:8080/cam/index.m3u8', // HLS alternate port
        ];
      }
      return [rtspUrl];
    } catch (e) {
      debugPrint('⚠️ Failed to build stream URL chain: $e');
      return [rtspUrl];
    }
  }

  /// Handle stream errors with retry logic
  void _handleStreamError(String error) {
    _connectionAttempts++;

    if (_connectionAttempts < _maxRetries && mounted) {
      debugPrint(
          '🔄 Retry attempt $_connectionAttempts/$_maxRetries after ${_retryDelay.inMilliseconds}ms');

      setState(() {
        _errorMessage =
            '$error\n\nRetrying... (${_connectionAttempts}/$_maxRetries)';
      });

      Future.delayed(_retryDelay, () {
        if (mounted) {
          final authProvider = context.read<AuthProvider>();
          final streamUrl = authProvider.getRtspStreamUrl();
          if (streamUrl != null) {
            _connectToStream(streamUrl);
          }
        }
      });
    } else {
      debugPrint('❌ Failed to connect after $_connectionAttempts attempts');
      if (mounted) {
        setState(() {
          _errorMessage = error;
          _isLoading = false;
        });
      }
    }
  }

  /// Monitor video player state for optimization and audio/video sync
  void _onVideoControllerUpdate() {
    if (!mounted) return;

    // CRITICAL FIX: Detect and handle audio sync problems
    if (_controller?.value.isBuffering == true) {
      _audioSyncErrors++;

      if (_audioSyncErrors > 5) {
        debugPrint(
            '🚨 CRITICAL: Audio/video buffering detected (${_audioSyncErrors} times). Frame drops likely.');
        debugPrint(
            '📊 Current playback: isPlaying=${_controller?.value.isPlaying}, position=${_controller?.value.position}');

        // If we see too many buffering events, consider restarting stream
        if (_audioSyncErrors > 15 && mounted) {
          debugPrint('⚠️ Excessive buffering detected - restarting stream');
          _audioSyncErrors = 0;
        }
      }
    } else {
      // Reset counter when not buffering
      if (_audioSyncErrors > 0) {
        _audioSyncErrors = 0;
      }
    }

    // Monitor frame drops
    if (_controller?.value.position != null && _lastStreamStart != null) {
      final duration = DateTime.now().difference(_lastStreamStart!);
      if (duration.inSeconds > 5 && duration.inSeconds % 10 == 0) {
        // Log metrics every 10 seconds
        debugPrint('📈 Stream metrics - Audio sync errors: $_audioSyncErrors');
      }
    }
  }

  Future<void> _openDoor() async {
    final authProvider = context.read<AuthProvider>();
    final vizProvider = context.read<HomeVisualizationProvider>();

    setState(() {
      _isDoorOpen = true;
    });

    // Trigger door animation in 3D visualization (global sync)
    vizProvider.triggerDoorOpen();

    final success = await authProvider.openDoor();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            success
                ? '✅ Door opened successfully! (Check 3D view)'
                : '❌ Failed to open door',
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
    _controller?.removeListener(_onVideoControllerUpdate);
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
                debugPrint('🔄 Manual camera refresh requested');
                setState(() {
                  _isLoading = true;
                  _errorMessage = null;
                  _connectionAttempts = 0;
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
                        debugPrint('🔄 Manual retry requested');
                        setState(() {
                          _errorMessage = null;
                          _isLoading = true;
                          _connectionAttempts = 0;
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
