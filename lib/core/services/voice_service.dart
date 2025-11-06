import 'dart:io';
import 'package:logger/logger.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:path_provider/path_provider.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:permission_handler/permission_handler.dart';

/// Service for handling voice recording and speech-to-text transcription
class VoiceService {
  final Logger _logger = Logger();
  final FlutterSoundRecorder _recorder = FlutterSoundRecorder();
  final stt.SpeechToText _speechToText = stt.SpeechToText();

  bool _isRecording = false;
  bool _isInitialized = false;
  String? _currentRecordingPath;
  DateTime? _recordingStartTime;

  bool get isRecording => _isRecording;
  bool get isInitialized => _isInitialized;

  /// Initialize speech-to-text service
  Future<bool> initialize() async {
    try {
      _logger.i('Initializing voice service...');

      // Request microphone permission
      final micStatus = await Permission.microphone.request();
      if (!micStatus.isGranted) {
        _logger.e('Microphone permission denied');
        return false;
      }

      // Initialize flutter_sound recorder
      await _recorder.openRecorder();
      
      // Initialize speech-to-text
      _isInitialized = await _speechToText.initialize(
        onError: (error) {
          _logger.e('Speech-to-text error: $error');
        },
        onStatus: (status) {
          _logger.d('Speech-to-text status: $status');
        },
      );

      if (_isInitialized) {
        _logger.i('Voice service initialized successfully');
      } else {
        _logger.e('Failed to initialize speech-to-text');
      }

      return _isInitialized;
    } catch (e) {
      _logger.e('Error initializing voice service: $e');
      return false;
    }
  }

  /// Get available locales for speech recognition
  Future<List<stt.LocaleName>> getAvailableLocales() async {
    if (!_isInitialized) {
      await initialize();
    }
    return _speechToText.locales();
  }

  /// Start recording voice
  /// [locale] - Language locale for transcription (e.g., 'en_US', 'nl_NL', 'de_DE')
  Future<bool> startRecording({String? locale}) async {
    try {
      if (!_isInitialized) {
        final initialized = await initialize();
        if (!initialized) return false;
      }

      if (_isRecording) {
        _logger.w('Already recording');
        return false;
      }

      // Create recording file path
      final directory = await getApplicationDocumentsDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      _currentRecordingPath = '${directory.path}/voice_$timestamp.aac';

      // Start recording
      await _recorder.startRecorder(
        toFile: _currentRecordingPath!,
        codec: Codec.aacADTS,
        bitRate: 128000,
        sampleRate: 44100,
      );

      _isRecording = true;
      _recordingStartTime = DateTime.now();
      _logger.i('Started recording to: $_currentRecordingPath');

      return true;
    } catch (e) {
      _logger.e('Error starting recording: $e');
      return false;
    }
  }

  /// Stop recording and return the file path and duration
  Future<VoiceRecordingResult?> stopRecording() async {
    try {
      if (!_isRecording) {
        _logger.w('Not currently recording');
        return null;
      }

      final path = await _recorder.stopRecorder();
      _isRecording = false;

      if (path == null || _recordingStartTime == null) {
        _logger.e('Failed to stop recording');
        return null;
      }

      final duration = DateTime.now().difference(_recordingStartTime!);
      _logger.i('Recording stopped. Duration: ${duration.inSeconds}s');

      final result = VoiceRecordingResult(
        filePath: path,
        durationMs: duration.inMilliseconds,
      );

      _recordingStartTime = null;
      _currentRecordingPath = null;

      return result;
    } catch (e) {
      _logger.e('Error stopping recording: $e');
      _isRecording = false;
      return null;
    }
  }

  /// Cancel current recording
  Future<void> cancelRecording() async {
    try {
      if (_isRecording) {
        await _recorder.stopRecorder();
        _isRecording = false;
        _recordingStartTime = null;

        // Delete the recording file
        if (_currentRecordingPath != null) {
          final file = File(_currentRecordingPath!);
          if (await file.exists()) {
            await file.delete();
            _logger.i('Deleted cancelled recording');
          }
        }
        _currentRecordingPath = null;
      }
    } catch (e) {
      _logger.e('Error cancelling recording: $e');
    }
  }

  /// Get recording duration while recording
  int? getRecordingDuration() {
    if (_recordingStartTime == null) return null;
    return DateTime.now().difference(_recordingStartTime!).inMilliseconds;
  }

  /// Transcribe audio file to text
  /// [filePath] - Path to the audio file
  /// [locale] - Language locale for transcription (e.g., 'en_US', 'nl_NL', 'de_DE')
  Future<String?> transcribeAudio(String filePath, {String? locale}) async {
    try {
      if (!_isInitialized) {
        final initialized = await initialize();
        if (!initialized) return null;
      }

      _logger.i('Transcribing audio file: $filePath');

      // For real-time transcription during recording
      // Note: speech_to_text works with live microphone input
      // For file-based transcription, we'd need a different service
      // This is a placeholder that shows how to use live transcription

      final transcription = StringBuffer();
      bool isComplete = false;

      await _speechToText.listen(
        onResult: (result) {
          transcription.clear();
          transcription.write(result.recognizedWords);
          _logger.d('Transcription: ${result.recognizedWords}');
          
          if (result.finalResult) {
            isComplete = true;
          }
        },
        localeId: locale,
        listenMode: stt.ListenMode.dictation,
      );

      // Wait for transcription to complete or timeout
      final timeout = DateTime.now().add(const Duration(seconds: 30));
      while (!isComplete && DateTime.now().isBefore(timeout)) {
        await Future.delayed(const Duration(milliseconds: 100));
      }

      await _speechToText.stop();

      final result = transcription.toString().trim();
      _logger.i('Transcription result: $result');

      return result.isNotEmpty ? result : null;
    } catch (e) {
      _logger.e('Error transcribing audio: $e');
      return null;
    }
  }

  /// Live transcription during recording
  /// [locale] - Language locale for transcription
  /// [onResult] - Callback with transcribed text
  Future<bool> startLiveTranscription({
    String? locale,
    required Function(String text) onResult,
  }) async {
    try {
      if (!_isInitialized) {
        final initialized = await initialize();
        if (!initialized) return false;
      }

      await _speechToText.listen(
        onResult: (result) {
          onResult(result.recognizedWords);
        },
        localeId: locale,
        listenMode: stt.ListenMode.dictation,
        cancelOnError: false,
        partialResults: true,
      );

      return true;
    } catch (e) {
      _logger.e('Error starting live transcription: $e');
      return false;
    }
  }

  /// Stop live transcription
  Future<void> stopLiveTranscription() async {
    try {
      await _speechToText.stop();
    } catch (e) {
      _logger.e('Error stopping live transcription: $e');
    }
  }

  /// Check if speech recognition is available
  Future<bool> isSpeechAvailable() async {
    return await _speechToText.initialize();
  }

  /// Dispose resources
  void dispose() {
    _recorder.closeRecorder();
  }
}

/// Result of a voice recording
class VoiceRecordingResult {
  final String filePath;
  final int durationMs;

  VoiceRecordingResult({
    required this.filePath,
    required this.durationMs,
  });
}
