import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:provider/provider.dart';
import 'package:iconsax/iconsax.dart';
import 'package:animate_do/animate_do.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/providers/ai_chat_provider.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/services/voice_service.dart';

/// Dedicated screen for Voice-to-Voice (V2V) conversation
/// Records voice -> sends MP3 -> receives MP3 -> plays automatically
class VoiceToVoiceScreen extends StatefulWidget {
  const VoiceToVoiceScreen({super.key});

  @override
  State<VoiceToVoiceScreen> createState() => _VoiceToVoiceScreenState();
}

class _VoiceToVoiceScreenState extends State<VoiceToVoiceScreen>
    with TickerProviderStateMixin {
  bool _isRecording = false;
  bool _isWaitingForResponse = false;
  String _statusMessage = '';
  Timer? _silenceTimer;
  Timer? _recordingTimer;
  int _recordingDuration = 0;
  StreamSubscription? _recorderSubscription;
  static const double _silenceThreshold = 45.0; // dB
  static const int _silenceDurationMs = 2000; // 2 seconds

  late AnimationController _pulseController;
  late AnimationController _waveController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    _waveController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat();

    _initializeVoiceMode();
  }

  @override
  void dispose() {
    _silenceTimer?.cancel();
    _recordingTimer?.cancel();
    _recorderSubscription?.cancel();
    _pulseController.dispose();
    _waveController.dispose();
    super.dispose();
  }

  Future<void> _initializeVoiceMode() async {
    final chatProvider = context.read<AIChatProvider>();
    // Don't change voice mode, keep it independent
    setState(() {
      _statusMessage = AppLocalizations.of(context).t('ready_to_talk');
    });
  }

  Future<void> _startRecording() async {
    final chatProvider = context.read<AIChatProvider>();
    final voiceService = chatProvider.voiceService;
    final loc = AppLocalizations.of(context);

    try {
      // Start recording
      final started = await voiceService.startRecording(
        locale: chatProvider.currentLocale,
      );

      if (started) {
        setState(() {
          _isRecording = true;
          _recordingDuration = 0;
          _statusMessage = loc.t('listening');
        });

        // Start recording duration timer
        _recordingTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
          if (mounted) {
            setState(() {
              _recordingDuration++;
            });
          }
        });

        // Set subscription duration for frequent updates
        await voiceService
            .setSubscriptionDuration(const Duration(milliseconds: 100));

        // Listen to recording progress for silence detection
        _recorderSubscription?.cancel();
        _recorderSubscription = voiceService.onProgress?.listen((e) {
          if (e.decibels != null) {
            _handleSilenceDetection(e.decibels!);
          }
        });

        // Initial silence timer
        _resetSilenceTimer();
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(loc.t('voice_permission_denied')),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } on PermissionException catch (_) {
      // Permission denied - guide user to settings
      if (mounted) {
        _showPermissionDialog();
      }
    } catch (e) {
      // Other errors
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${loc.t('error_starting_recording')}: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _showPermissionDialog() async {
    final loc = AppLocalizations.of(context);
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            const Icon(Iconsax.microphone_slash, color: Colors.red),
            const SizedBox(width: 8),
            Expanded(child: Text(loc.t('microphone_permission_required'))),
          ],
        ),
        content: Text(loc.t('microphone_permission_message')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(loc.t('cancel')),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryColor,
            ),
            child: Text(loc.t('open_settings')),
          ),
        ],
      ),
    );

    if (result == true) {
      await openAppSettings();
    }
  }

  void _handleSilenceDetection(double decibels) {
    // If sound is detected (above threshold), reset the timer
    if (decibels > _silenceThreshold) {
      _resetSilenceTimer();
    }
  }

  void _resetSilenceTimer() {
    _silenceTimer?.cancel();
    _silenceTimer = Timer(const Duration(milliseconds: _silenceDurationMs), () {
      if (_isRecording && mounted) {
        // Only stop if we have recorded something meaningful (e.g. > 1 second)
        // or if it's just initial silence timeout
        _stopRecordingAndSend();
      }
    });
  }

  Future<void> _stopRecordingAndSend() async {
    _silenceTimer?.cancel();
    _recordingTimer?.cancel();
    _recorderSubscription?.cancel();

    final chatProvider = context.read<AIChatProvider>();
    final voiceService = chatProvider.voiceService;
    final authProvider = context.read<AuthProvider>();
    final loc = AppLocalizations.of(context);

    setState(() {
      _isRecording = false;
      _isWaitingForResponse = true;
      _statusMessage = loc.t('processing');
    });

    // Stop recording
    final result = await voiceService.stopRecording();

    if (result != null) {
      final userId = authProvider.currentUser?.uid ?? 'debug-user';

      setState(() {
        _statusMessage = loc.t('waiting_for_response');
      });

      // Send voice message and wait for voice response
      await chatProvider.sendVoiceChatMessage(
        result.filePath,
        result.durationMs,
        userId,
      );

      // Response is auto-played by the provider
      setState(() {
        _isWaitingForResponse = false;
        _statusMessage = loc.t('ready_to_talk');
      });
    } else {
      setState(() {
        _isWaitingForResponse = false;
        _statusMessage = loc.t('recording_failed');
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(loc.t('recording_failed')),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _cancelRecording() async {
    _silenceTimer?.cancel();
    _recordingTimer?.cancel();
    _recorderSubscription?.cancel();

    final chatProvider = context.read<AIChatProvider>();
    final voiceService = chatProvider.voiceService;

    await voiceService.cancelRecording();

    setState(() {
      _isRecording = false;
      _statusMessage = AppLocalizations.of(context).t('ready_to_talk');
    });
  }

  String _formatDuration(int seconds) {
    final mins = seconds ~/ 60;
    final secs = seconds % 60;
    return '${mins.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Iconsax.arrow_left, color: theme.colorScheme.onBackground),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                gradient: AppTheme.primaryGradient,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Iconsax.microphone_2,
                size: 20,
                color: Colors.white,
              ),
            ),
            const SizedBox(width: 12),
            Text(
              loc.t('voice_to_voice'),
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.onBackground,
              ),
            ),
          ],
        ),
        actions: [
          Consumer<AIChatProvider>(
            builder: (context, chatProvider, _) {
              final isAvailable = chatProvider.isVoiceChatAvailable;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Chip(
                  label: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isAvailable
                            ? Iconsax.tick_circle
                            : Iconsax.close_circle,
                        size: 14,
                        color: isAvailable ? Colors.green : Colors.red,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        isAvailable ? loc.t('online') : loc.t('offline'),
                        style: const TextStyle(fontSize: 11),
                      ),
                    ],
                  ),
                  backgroundColor: (isAvailable ? Colors.green : Colors.red)
                      .withOpacity(0.1),
                ),
              );
            },
          ),
        ],
      ),
      body: Consumer<AIChatProvider>(
        builder: (context, chatProvider, _) {
          final isLoading = chatProvider.isLoading;
          final error = chatProvider.error;

          return SafeArea(
            child: Column(
              children: [
                // Main voice interaction area
                Expanded(
                  child: Center(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // Visual indicator
                          _buildVisualIndicator(isDark),
                          const SizedBox(height: 32),

                          // Status message
                          FadeIn(
                            child: Text(
                              _statusMessage,
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                                color: theme.colorScheme.onBackground,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),

                          // Recording duration
                          if (_isRecording) ...[
                            const SizedBox(height: 16),
                            FadeIn(
                              child: Text(
                                _formatDuration(_recordingDuration),
                                style: TextStyle(
                                  fontSize: 32,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.primaryColor,
                                ),
                              ),
                            ),
                          ],

                          // Error message
                          if (error != null && error.isNotEmpty) ...[
                            const SizedBox(height: 16),
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.red.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: Colors.red.withOpacity(0.3),
                                ),
                              ),
                              child: Row(
                                children: [
                                  const Icon(
                                    Iconsax.warning_2,
                                    color: Colors.red,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      error,
                                      style: const TextStyle(
                                        color: Colors.red,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],

                          const SizedBox(height: 32),

                          // Instructions
                          if (!_isRecording &&
                              !_isWaitingForResponse &&
                              !isLoading) ...[
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: (isDark
                                        ? Colors.white
                                        : AppTheme.primaryColor)
                                    .withOpacity(0.05),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: AppTheme.primaryColor.withOpacity(0.1),
                                ),
                              ),
                              child: Column(
                                children: [
                                  Icon(
                                    Iconsax.info_circle,
                                    size: 32,
                                    color: AppTheme.primaryColor,
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    loc.t('v2v_instructions'),
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: theme.colorScheme.onBackground
                                          .withOpacity(0.7),
                                      height: 1.5,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),

                // Control buttons
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: _buildControls(chatProvider, isDark),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildVisualIndicator(bool isDark) {
    if (_isWaitingForResponse) {
      // Waiting animation
      return FadeIn(
        child: AnimatedBuilder(
          animation: _waveController,
          builder: (context, child) {
            return Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    AppTheme.primaryColor.withOpacity(0.3),
                    AppTheme.primaryColor.withOpacity(0.1),
                    Colors.transparent,
                  ],
                  stops: [
                    0.0,
                    _waveController.value * 0.7,
                    _waveController.value,
                  ],
                ),
              ),
              child: Center(
                child: Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: AppTheme.primaryGradient,
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.primaryColor.withOpacity(0.5),
                        blurRadius: 30,
                        spreadRadius: 10,
                      ),
                    ],
                  ),
                  child: const Icon(
                    Iconsax.volume_high,
                    size: 48,
                    color: Colors.white,
                  ),
                ),
              ),
            );
          },
        ),
      );
    } else if (_isRecording) {
      // Recording animation
      return FadeIn(
        child: AnimatedBuilder(
          animation: _pulseController,
          builder: (context, child) {
            final scale = 1.0 + (_pulseController.value * 0.3);
            return Transform.scale(
              scale: scale,
              child: Container(
                width: 200,
                height: 200,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      Colors.red.withOpacity(0.3),
                      Colors.red.withOpacity(0.1),
                      Colors.transparent,
                    ],
                  ),
                ),
                child: Center(
                  child: Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.red,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.red.withOpacity(0.5),
                          blurRadius: 30,
                          spreadRadius: 10,
                        ),
                      ],
                    ),
                    child: const Icon(
                      Iconsax.microphone,
                      size: 48,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      );
    } else {
      // Idle state
      return FadeIn(
        child: Container(
          width: 200,
          height: 200,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: AppTheme.primaryGradient.scale(0.3),
          ),
          child: Center(
            child: Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: AppTheme.primaryGradient,
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.primaryColor.withOpacity(0.3),
                    blurRadius: 20,
                    spreadRadius: 5,
                  ),
                ],
              ),
              child: const Icon(
                Iconsax.microphone_2,
                size: 48,
                color: Colors.white,
              ),
            ),
          ),
        ),
      );
    }
  }

  Widget _buildControls(AIChatProvider chatProvider, bool isDark) {
    final loc = AppLocalizations.of(context);
    final isLoading = chatProvider.isLoading;

    if (_isRecording) {
      // Recording controls
      return Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          // Cancel button
          Expanded(
            child: ElevatedButton.icon(
              onPressed: _cancelRecording,
              icon: const Icon(Iconsax.close_circle),
              label: Text(loc.t('cancel')),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.withOpacity(0.2),
                foregroundColor: Colors.red,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          // Send button
          Expanded(
            child: ElevatedButton.icon(
              onPressed: _stopRecordingAndSend,
              icon: const Icon(Iconsax.send_1),
              label: Text(loc.t('send')),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
          ),
        ],
      );
    } else if (_isWaitingForResponse || isLoading) {
      // Waiting state
      return SizedBox(
        height: 56,
        child: Center(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor:
                      AlwaysStoppedAnimation<Color>(AppTheme.primaryColor),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                loc.t('processing'),
                style: TextStyle(
                  fontSize: 16,
                  color: AppTheme.primaryColor,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      );
    } else {
      // Start recording button
      return SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          onPressed: chatProvider.isVoiceChatAvailable ? _startRecording : null,
          icon: const Icon(Iconsax.microphone, size: 28),
          label: Text(
            loc.t('tap_to_speak'),
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: chatProvider.isVoiceChatAvailable
                ? AppTheme.primaryColor
                : Colors.grey,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 20),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            elevation: 8,
            shadowColor: AppTheme.primaryColor.withOpacity(0.5),
          ),
        ),
      );
    }
  }
}
