import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import 'package:audioplayers/audioplayers.dart';

/// Widget to display and play voice messages
class VoiceMessageBubble extends StatefulWidget {
  final String voiceFilePath;
  final int durationMs;
  final bool isUser;
  final String? transcription;
  final VoidCallback? onTranscriptionToggle;

  const VoiceMessageBubble({
    super.key,
    required this.voiceFilePath,
    required this.durationMs,
    required this.isUser,
    this.transcription,
    this.onTranscriptionToggle,
  });

  @override
  State<VoiceMessageBubble> createState() => _VoiceMessageBubbleState();
}

class _VoiceMessageBubbleState extends State<VoiceMessageBubble> {
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _isPlaying = false;
  bool _showTranscription = false;
  Duration _currentPosition = Duration.zero;
  Duration _totalDuration = Duration.zero;

  @override
  void initState() {
    super.initState();
    _totalDuration = Duration(milliseconds: widget.durationMs);
    _setupAudioPlayer();
  }

  void _setupAudioPlayer() {
    _audioPlayer.onPlayerStateChanged.listen((state) {
      if (mounted) {
        setState(() {
          _isPlaying = state == PlayerState.playing;
        });
      }
    });

    _audioPlayer.onPositionChanged.listen((position) {
      if (mounted) {
        setState(() {
          _currentPosition = position;
        });
      }
    });

    _audioPlayer.onPlayerComplete.listen((_) {
      if (mounted) {
        setState(() {
          _isPlaying = false;
          _currentPosition = Duration.zero;
        });
      }
    });
  }

  Future<void> _togglePlayPause() async {
    try {
      if (_isPlaying) {
        await _audioPlayer.pause();
      } else {
        await _audioPlayer.play(DeviceFileSource(widget.voiceFilePath));
      }
    } catch (e) {
      debugPrint('Error playing audio: $e');
    }
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textColor =
        widget.isUser ? Colors.white : theme.colorScheme.onSurface;

    return Column(
      crossAxisAlignment:
          widget.isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        // Voice player
        Container(
          width: 250,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Play/Pause button
              IconButton(
                onPressed: _togglePlayPause,
                icon: Icon(
                  _isPlaying ? Iconsax.pause : Iconsax.play,
                  color: textColor,
                ),
                iconSize: 24,
              ),

              // Waveform slider
              Expanded(
                child: Column(
                  children: [
                    SliderTheme(
                      data: SliderThemeData(
                        trackHeight: 2,
                        thumbShape: const RoundSliderThumbShape(
                          enabledThumbRadius: 6,
                        ),
                        overlayShape: const RoundSliderOverlayShape(
                          overlayRadius: 12,
                        ),
                        activeTrackColor: textColor,
                        inactiveTrackColor: textColor.withOpacity(0.3),
                        thumbColor: textColor,
                      ),
                      child: Slider(
                        value: _totalDuration.inMilliseconds > 0
                            ? _currentPosition.inMilliseconds /
                                _totalDuration.inMilliseconds
                            : 0,
                        onChanged: (value) async {
                          final position = Duration(
                            milliseconds:
                                (value * _totalDuration.inMilliseconds).toInt(),
                          );
                          await _audioPlayer.seek(position);
                        },
                      ),
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          _formatDuration(_currentPosition),
                          style: TextStyle(
                            fontSize: 11,
                            color: textColor.withOpacity(0.7),
                            fontFeatures: [const FontFeature.tabularFigures()],
                          ),
                        ),
                        Text(
                          _formatDuration(_totalDuration),
                          style: TextStyle(
                            fontSize: 11,
                            color: textColor.withOpacity(0.7),
                            fontFeatures: [const FontFeature.tabularFigures()],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        // Transcription toggle
        if (widget.transcription != null) ...[
          const SizedBox(height: 4),
          InkWell(
            onTap: () {
              setState(() {
                _showTranscription = !_showTranscription;
              });
              widget.onTranscriptionToggle?.call();
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    _showTranscription
                        ? Iconsax.arrow_up_2
                        : Iconsax.arrow_down_1,
                    size: 14,
                    color: textColor.withOpacity(0.7),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    _showTranscription ? 'Hide text' : 'Show text',
                    style: TextStyle(
                      fontSize: 12,
                      color: textColor.withOpacity(0.7),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],

        // Transcription text
        if (_showTranscription && widget.transcription != null) ...[
          const SizedBox(height: 8),
          Container(
            constraints: const BoxConstraints(maxWidth: 250),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: widget.isUser
                  ? Colors.white.withOpacity(0.2)
                  : theme.colorScheme.surface.withOpacity(0.5),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: textColor.withOpacity(0.2),
              ),
            ),
            child: Text(
              widget.transcription!,
              style: TextStyle(
                fontSize: 13,
                color: textColor,
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
        ],
      ],
    );
  }
}
