import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import 'dart:async';
import '../../core/theme/app_theme.dart';

/// Widget for recording voice messages
class VoiceRecorderWidget extends StatefulWidget {
  final VoidCallback onCancel;
  final Function(int durationMs) onSend;
  final Function(int durationMs) onDurationUpdate;

  const VoiceRecorderWidget({
    super.key,
    required this.onCancel,
    required this.onSend,
    required this.onDurationUpdate,
  });

  @override
  State<VoiceRecorderWidget> createState() => _VoiceRecorderWidgetState();
}

class _VoiceRecorderWidgetState extends State<VoiceRecorderWidget>
    with SingleTickerProviderStateMixin {
  Timer? _timer;
  int _durationMs = 0;
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);

    _startTimer();
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(milliseconds: 100), (timer) {
      setState(() {
        _durationMs += 100;
        widget.onDurationUpdate(_durationMs);
      });
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pulseController.dispose();
    super.dispose();
  }

  String _formatDuration(int ms) {
    final seconds = ms ~/ 1000;
    final minutes = seconds ~/ 60;
    final remainingSeconds = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${remainingSeconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkSurface : AppTheme.lightSurface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          children: [
            // Cancel button
            IconButton(
              onPressed: widget.onCancel,
              icon: const Icon(Iconsax.close_circle, color: Colors.red),
              iconSize: 32,
            ),
            const SizedBox(width: 12),

            // Recording indicator
            Expanded(
              child: Row(
                children: [
                  // Pulsing record icon
                  AnimatedBuilder(
                    animation: _pulseController,
                    builder: (context, child) {
                      return Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          color: Colors.red.withOpacity(
                            0.5 + (_pulseController.value * 0.5),
                          ),
                          shape: BoxShape.circle,
                        ),
                      );
                    },
                  ),
                  const SizedBox(width: 12),

                  // Duration
                  Text(
                    _formatDuration(_durationMs),
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      fontFeatures: [const FontFeature.tabularFigures()],
                    ),
                  ),
                  const SizedBox(width: 12),

                  // Waveform animation (simplified)
                  Expanded(
                    child: AnimatedBuilder(
                      animation: _pulseController,
                      builder: (context, child) {
                        return Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: List.generate(20, (index) {
                            final delay = (index * 0.05) % 1.0;
                            final value =
                                (((_pulseController.value + delay) % 1.0) * 2 -
                                        1)
                                    .abs();
                            return Container(
                              width: 3,
                              height: 4 + (value * 20),
                              margin: const EdgeInsets.symmetric(horizontal: 1),
                              decoration: BoxDecoration(
                                color: AppTheme.primaryColor.withOpacity(0.6),
                                borderRadius: BorderRadius.circular(2),
                              ),
                            );
                          }),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(width: 12),

            // Send button
            Container(
              decoration: BoxDecoration(
                gradient: AppTheme.primaryGradient,
                shape: BoxShape.circle,
                boxShadow: AppTheme.glowShadow,
              ),
              child: IconButton(
                onPressed: () => widget.onSend(_durationMs),
                icon: const Icon(Iconsax.send_1, color: Colors.white),
                iconSize: 24,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
