import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:logger/logger.dart';
import 'package:path_provider/path_provider.dart';
import '../config/mqtt_config.dart';

/// Service for backend voice processing (TTS via Piper, ASR via Faster-Whisper)
class BackendVoiceService {
  final Logger _logger = Logger();

  String? _customBaseUrl;

  /// Get the base URL for backend services
  String get baseUrl =>
      _customBaseUrl ?? 'http://${MqttConfig.localBrokerAddress}';

  /// TTS endpoint (Piper)
  String get ttsUrl => '$baseUrl:${MqttConfig.piperTtsPort}/synthesize';

  /// ASR endpoint (Faster-Whisper)
  String get asrUrl => '$baseUrl:${MqttConfig.asrWhisperPort}/transcribe';

  /// Voice chat endpoint (n8n - sends audio, receives audio)
  String get voiceChatUrl => '$baseUrl:${MqttConfig.n8nPort}/api/voice';

  /// Set custom base URL for all services
  void setBaseUrl(String url) {
    _customBaseUrl = url.endsWith('/') ? url.substring(0, url.length - 1) : url;
    _logger.i('Backend voice service base URL updated: $_customBaseUrl');
  }

  /// Update broker address (convenience method)
  void updateBrokerAddress(String address) {
    // Update MqttConfig for other services to use
    MqttConfig.localBrokerAddress = address;
    setBaseUrl('http://$address');
    _logger.i('🔄 Backend voice service updated to use: $address');
  }

  /// Check if TTS service is available
  Future<bool> checkTtsHealth() async {
    try {
      // Try to synthesize a short text
      final response = await http
          .post(
            Uri.parse(ttsUrl),
            headers: {'Content-Type': 'application/json'},
            body: '{"text": "test"}',
          )
          .timeout(const Duration(seconds: 5));
      return response.statusCode == 200;
    } catch (e) {
      _logger.w('TTS service health check failed: $e');
      return false;
    }
  }

  /// Check if ASR service is available
  Future<bool> checkAsrHealth() async {
    try {
      final healthUrl = '$baseUrl:${MqttConfig.asrWhisperPort}/healthz';
      final response = await http
          .get(Uri.parse(healthUrl))
          .timeout(const Duration(seconds: 5));
      return response.statusCode == 200;
    } catch (e) {
      _logger.w('ASR service health check failed: $e');
      return false;
    }
  }

  /// Synthesize text to speech using Piper TTS
  /// Returns the path to the generated audio file
  Future<String?> synthesizeSpeech(
    String text, {
    int? speaker,
    double? noiseScale,
    double? lengthScale,
    double? noiseW,
  }) async {
    try {
      _logger.i(
          'Synthesizing speech: "${text.substring(0, text.length > 50 ? 50 : text.length)}..."');

      final body = <String, dynamic>{'text': text};
      if (speaker != null) body['speaker'] = speaker;
      if (noiseScale != null) body['noise_scale'] = noiseScale;
      if (lengthScale != null) body['length_scale'] = lengthScale;
      if (noiseW != null) body['noise_w'] = noiseW;

      final response = await http
          .post(
            Uri.parse(ttsUrl),
            headers: {'Content-Type': 'application/json'},
            body: _jsonEncode(body),
          )
          .timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        // Save the audio file
        final directory = await getApplicationDocumentsDirectory();
        final timestamp = DateTime.now().millisecondsSinceEpoch;
        final filePath = '${directory.path}/tts_$timestamp.wav';

        final file = File(filePath);
        await file.writeAsBytes(response.bodyBytes);

        _logger.i('TTS audio saved to: $filePath');
        return filePath;
      } else {
        _logger.e('TTS error: ${response.statusCode} - ${response.body}');
        return null;
      }
    } catch (e) {
      _logger.e('Error synthesizing speech: $e');
      return null;
    }
  }

  /// Transcribe audio file to text using Faster-Whisper
  Future<TranscriptionResult?> transcribeAudio(
    String audioFilePath, {
    String language = 'ar',
    int beamSize = 5,
    String temperature = '0.0,0.2,0.4',
  }) async {
    try {
      _logger.i('Transcribing audio: $audioFilePath');

      final file = File(audioFilePath);
      if (!await file.exists()) {
        _logger.e('Audio file not found: $audioFilePath');
        return null;
      }

      final request = http.MultipartRequest('POST', Uri.parse(asrUrl));

      // Add audio file
      request.files.add(await http.MultipartFile.fromPath(
        'file',
        audioFilePath,
        contentType: MediaType('audio', _getAudioType(audioFilePath)),
      ));

      // Add form fields
      request.fields['language'] = language;
      request.fields['beam_size'] = beamSize.toString();
      request.fields['temperature'] = temperature;

      final streamedResponse =
          await request.send().timeout(const Duration(seconds: 60));
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        final data = _jsonDecode(response.body);
        _logger.i('Transcription result: ${data['text']}');

        return TranscriptionResult(
          text: data['text'] ?? '',
          language: data['language'] ?? language,
          duration: data['duration']?.toDouble(),
        );
      } else {
        _logger.e('ASR error: ${response.statusCode} - ${response.body}');
        return null;
      }
    } catch (e) {
      _logger.e('Error transcribing audio: $e');
      return null;
    }
  }

  /// Send voice message and receive voice reply (via n8n /api/voice)
  /// Returns the path to the response audio file and the transcription
  Future<VoiceChatResult?> sendVoiceChat(
    String audioFilePath,
    String sessionId,
  ) async {
    try {
      _logger.i('Sending voice chat: $audioFilePath');

      final file = File(audioFilePath);
      if (!await file.exists()) {
        _logger.e('Audio file not found: $audioFilePath');
        return null;
      }

      final request = http.MultipartRequest('POST', Uri.parse(voiceChatUrl));

      // Add audio file
      request.files.add(await http.MultipartFile.fromPath(
        'audio',
        audioFilePath,
        contentType: MediaType('audio', _getAudioType(audioFilePath)),
      ));

      // Add session ID
      request.fields['sessionId'] = sessionId;

      final streamedResponse =
          await request.send().timeout(const Duration(seconds: 120));
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        // Check if response is audio or JSON
        final contentType = response.headers['content-type'] ?? '';

        if (contentType.contains('audio')) {
          // Save the audio response
          final directory = await getApplicationDocumentsDirectory();
          final timestamp = DateTime.now().millisecondsSinceEpoch;
          final filePath = '${directory.path}/voice_reply_$timestamp.wav';

          final audioFile = File(filePath);
          await audioFile.writeAsBytes(response.bodyBytes);

          _logger.i('Voice reply saved to: $filePath');

          return VoiceChatResult(
            audioFilePath: filePath,
            transcription: response.headers['x-transcription'],
            aiResponse: response.headers['x-ai-response'],
          );
        } else {
          // JSON response with base64 audio or error
          final data = _jsonDecode(response.body);

          if (data['audio'] != null) {
            // Decode base64 audio
            final audioBytes = _base64Decode(data['audio']);
            final directory = await getApplicationDocumentsDirectory();
            final timestamp = DateTime.now().millisecondsSinceEpoch;
            final filePath = '${directory.path}/voice_reply_$timestamp.wav';

            final audioFile = File(filePath);
            await audioFile.writeAsBytes(audioBytes);

            return VoiceChatResult(
              audioFilePath: filePath,
              transcription: data['transcription'],
              aiResponse: data['response'],
            );
          } else if (data['error'] != null) {
            _logger.e('Voice chat error: ${data['error']}');
            return null;
          }
        }
      } else {
        _logger
            .e('Voice chat error: ${response.statusCode} - ${response.body}');
        return null;
      }

      return null;
    } catch (e) {
      _logger.e('Error in voice chat: $e');
      return null;
    }
  }

  String _getAudioType(String filePath) {
    final ext = filePath.split('.').last.toLowerCase();
    switch (ext) {
      case 'wav':
        return 'wav';
      case 'mp3':
        return 'mpeg';
      case 'aac':
        return 'aac';
      case 'm4a':
        return 'mp4';
      case 'ogg':
        return 'ogg';
      case 'webm':
        return 'webm';
      default:
        return 'octet-stream';
    }
  }

  // Simple JSON helpers to avoid dart:convert import conflicts
  String _jsonEncode(Map<String, dynamic> data) {
    return jsonEncode(data);
  }

  Map<String, dynamic> _jsonDecode(String json) {
    try {
      final cleaned = json.trim();
      if (cleaned.isEmpty || !cleaned.startsWith('{')) {
        return {};
      }
      return jsonDecode(cleaned) as Map<String, dynamic>;
    } catch (e) {
      return {};
    }
  }

  Uint8List _base64Decode(String encoded) {
    return base64Decode(encoded);
  }
}

/// Result of transcription
class TranscriptionResult {
  final String text;
  final String language;
  final double? duration;

  TranscriptionResult({
    required this.text,
    required this.language,
    this.duration,
  });
}

/// Result of voice chat
class VoiceChatResult {
  final String audioFilePath;
  final String? transcription;
  final String? aiResponse;

  VoiceChatResult({
    required this.audioFilePath,
    this.transcription,
    this.aiResponse,
  });
}
