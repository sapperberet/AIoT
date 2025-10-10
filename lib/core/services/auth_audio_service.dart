import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

/// Service for managing authentication audio notifications
class AuthAudioService {
  static final AuthAudioService _instance = AuthAudioService._internal();
  factory AuthAudioService() => _instance;
  AuthAudioService._internal();

  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _isEnabled = true;

  /// Enable or disable audio notifications
  void setEnabled(bool enabled) {
    _isEnabled = enabled;
    debugPrint('🔊 Auth audio ${enabled ? 'enabled' : 'disabled'}');
  }

  /// Check if audio is enabled
  bool get isEnabled => _isEnabled;

  /// Play "look at camera" notification
  Future<void> playLookAtCamera() async {
    if (!_isEnabled) return;

    try {
      await _audioPlayer.stop();
      await _audioPlayer.play(
        AssetSource('Audio/notification-look_at_camera.mp3'),
      );
      debugPrint('🔊 Playing: Look at camera notification');
    } catch (e) {
      debugPrint('❌ Error playing look at camera audio: $e');
    }
  }

  /// Play authentication success sound
  Future<void> playSuccess() async {
    if (!_isEnabled) return;

    try {
      await _audioPlayer.stop();
      await _audioPlayer.play(
        AssetSource('Audio/success.mp3'),
      );
      debugPrint('🔊 Playing: Authentication success');
    } catch (e) {
      debugPrint('❌ Error playing success audio: $e');
    }
  }

  /// Stop any currently playing audio
  Future<void> stop() async {
    try {
      await _audioPlayer.stop();
      debugPrint('🔊 Audio stopped');
    } catch (e) {
      debugPrint('❌ Error stopping audio: $e');
    }
  }

  /// Dispose of the audio player
  Future<void> dispose() async {
    try {
      await _audioPlayer.dispose();
      debugPrint('🔊 Audio service disposed');
    } catch (e) {
      debugPrint('❌ Error disposing audio service: $e');
    }
  }
}
