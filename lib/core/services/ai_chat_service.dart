import 'dart:convert';
import 'dart:async';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:logger/logger.dart';
import 'package:path_provider/path_provider.dart';
import '../models/chat_message_model.dart';
import '../config/mqtt_config.dart';
import 'package:uuid/uuid.dart';

/// LLM Provider types
enum LlmProvider {
  /// Local n8n workflow (default)
  n8nLocal,

  /// Local Ollama instance
  ollamaLocal,

  /// External LLM via ngrok (Colab deployment)
  externalNgrok,
}

/// Service for communicating with the AI agent backend
class AIChatService {
  final Logger _logger = Logger();
  final Uuid _uuid = const Uuid();

  // Default: Use the same IP as MQTT broker (where n8n is running)
  // Production API endpoint (always active when workflow is active)
  String _baseUrl = '';

  // LLM Provider configuration
  LlmProvider _llmProvider = LlmProvider.n8nLocal;
  String _externalLlmUrl = '';
  String _externalLlmApiKey = '';
  String _externalLlmModel = '';

  // Voice chat endpoint
  String _voiceChatUrl = '';

  AIChatService() {
    _baseUrl =
        'http://${MqttConfig.localBrokerAddress}:${MqttConfig.n8nPort}/api/agent';
    _voiceChatUrl =
        'http://${MqttConfig.localBrokerAddress}:${MqttConfig.n8nPort}/api/voice';

    // Initialize external LLM settings from config
    _externalLlmUrl = 'https://${MqttConfig.externalLlmDomain}';
    _externalLlmApiKey = MqttConfig.externalLlmApiKey;
    _externalLlmModel = MqttConfig.externalLlmModel;
  }

  /// Get current LLM provider
  LlmProvider get llmProvider => _llmProvider;

  /// Set LLM provider
  void setLlmProvider(LlmProvider provider) {
    _llmProvider = provider;
    _logger.i('LLM provider changed to: $provider');
  }

  /// Set the AI agent server URL (for n8n)
  void setServerUrl(String url) {
    _baseUrl = url.endsWith('/') ? url.substring(0, url.length - 1) : url;
    _logger.i('AI Chat server URL updated: $_baseUrl');
  }

  /// Set external LLM configuration (for ngrok/Colab deployment)
  void setExternalLlmConfig({
    required String url,
    required String apiKey,
    String? model,
  }) {
    _externalLlmUrl =
        url.endsWith('/') ? url.substring(0, url.length - 1) : url;
    _externalLlmApiKey = apiKey;
    if (model != null) _externalLlmModel = model;
    _logger.i('External LLM configured: $_externalLlmUrl');
  }

  /// Get available models from external LLM
  Future<List<String>> getExternalModels() async {
    try {
      final response = await http
          .get(Uri.parse('$_externalLlmUrl/v1/models'))
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final models =
            (data['data'] as List?)?.map((m) => m['id'] as String).toList() ??
                [];
        return models;
      }
      return [];
    } catch (e) {
      _logger.w('Failed to get external models: $e');
      return [];
    }
  }

  /// Send a message to the AI agent with streaming response
  /// Returns a stream of message chunks
  /// [filterThinkBlocks] - if true, removes think block content
  Stream<String> sendMessageStream(
    String content,
    String userId,
    String sessionId, {
    bool filterThinkBlocks = true,
  }) async* {
    try {
      _logger.d('Sending message to AI agent: $content');
      print('[AI Chat Service] URL: $_baseUrl');
      print(
          '[AI Chat Service] Payload: {chatInput: $content, sessionId: $sessionId}');

      final request = http.Request('POST', Uri.parse(_baseUrl));
      request.headers['Content-Type'] = 'application/json';
      // Match n8n AI Agent payload format
      request.body = jsonEncode({
        'message': content,
        'sessionId': sessionId,
      });

      final response = await request.send();
      print('[AI Chat Service] Response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        _logger.i('Receiving streamed response from AI agent');

        bool insideThinkBlock = false;

        await for (var chunk in response.stream.transform(utf8.decoder)) {
          print('[AI Chat Service] Raw chunk received: $chunk');

          // Parse each line of the streamed response
          final lines = chunk.split('\n');
          print('[AI Chat Service] Split into ${lines.length} lines');

          for (var line in lines) {
            if (line.trim().isEmpty) continue;

            print(
                '[AI Chat Service] Processing line: ${line.substring(0, line.length > 100 ? 100 : line.length)}...');

            try {
              final data = jsonDecode(line);
              print('[AI Chat Service] Decoded JSON: $data');
              print('[AI Chat Service] Type: ${data['type']}');

              // Handle different n8n streaming event types
              final type = data['type'] as String?;

              if (type == 'begin') {
                print('[AI Chat Service] ✅ Stream begin event');
                continue;
              } else if (type == 'end') {
                print('[AI Chat Service] ✅ Stream end event');
                continue;
              } else if (type == 'error') {
                // Error from n8n workflow
                print('[AI Chat Service] ⚠️ ERROR EVENT RECEIVED');
                print('[AI Chat Service] Full error data: $data');
                print('[AI Chat Service] Error field: ${data['error']}');
                print('[AI Chat Service] Message field: ${data['message']}');
                print('[AI Chat Service] Metadata: ${data['metadata']}');

                // Try multiple ways to extract error info
                String errorMsg = 'AI workflow error';

                if (data['error'] != null) {
                  if (data['error'] is String) {
                    errorMsg = data['error'] as String;
                  } else if (data['error'] is Map) {
                    errorMsg =
                        data['error']['message'] ?? data['error'].toString();
                  }
                } else if (data['message'] != null) {
                  errorMsg = data['message'] as String;
                } else if (data['description'] != null) {
                  errorMsg = data['description'] as String;
                }

                // Provide helpful hints for common errors
                String helpHint = '';
                if (errorMsg.contains('empty response') ||
                    errorMsg.contains('chat model')) {
                  helpHint =
                      '\n\n💡 Tip: The LLM model may not be loaded. Run:\ndocker exec ollama ollama pull qwen2.5:7b-instruct';
                } else if (errorMsg.contains('connect') ||
                    errorMsg.contains('ECONNREFUSED')) {
                  helpHint =
                      '\n\n💡 Tip: Check if Ollama container is running:\ndocker compose up -d ollama';
                }

                print('[AI Chat Service] Yielding error message: $errorMsg');
                yield '⚠️ $errorMsg$helpHint';
                continue;
              }

              // Extract content from data/message/chunk events
              if (type == 'item' ||
                  type == 'message' ||
                  type == 'chunk' ||
                  type == 'data' ||
                  type == 'token') {
                String content = data['content'] as String? ??
                    data['data'] as String? ??
                    data['text'] as String? ??
                    data['output'] as String? ??
                    data['message'] as String? ??
                    '';
                print('[AI Chat Service] Extracted content: $content');

                // Handle <think> blocks if filtering is enabled
                if (filterThinkBlocks) {
                  if (content.contains('<think>')) {
                    insideThinkBlock = true;
                    continue;
                  }
                  if (content.contains('</think>')) {
                    insideThinkBlock = false;
                    continue;
                  }

                  // Skip content inside think blocks
                  if (insideThinkBlock) {
                    continue;
                  }

                  // Skip markdown code blocks
                  if (content.trim().startsWith('```')) {
                    continue;
                  }
                }

                // Yield the content chunk
                if (content.isNotEmpty) {
                  print('[AI Chat Service] ✅ Yielding content: $content');
                  yield content;
                } else {
                  print('[AI Chat Service] Content is empty, not yielding');
                }
              } else {
                print(
                    '[AI Chat Service] ⚠️ Unknown event type: $type, full data: $data');
              }
            } catch (e) {
              print('[AI Chat Service] Error parsing line: $e');
              print('[AI Chat Service] Problematic line: $line');
              _logger.w('Error parsing chunk: $e');
              continue;
            }
          }
        }
      } else if (response.statusCode == 404) {
        _logger.e('Webhook not found (404) - n8n workflow may not be active');
        throw Exception(
          'AI agent not available. Make sure the n8n workflow is activated in the n8n UI.',
        );
      } else {
        _logger.e('AI agent error: ${response.statusCode}');
        final body = await response.stream.bytesToString();
        _logger.e('Response body: $body');
        throw Exception('Failed to get response: ${response.statusCode}');
      }
    } catch (e) {
      _logger.e('Error sending message to AI agent: $e');
      rethrow;
    }
  }

  /// Send a message to the AI agent (non-streaming fallback)
  Future<ChatMessage> sendMessage(String content, String userId) async {
    try {
      final sessionId = _uuid.v4();
      final buffer = StringBuffer();

      await for (var chunk in sendMessageStream(content, userId, sessionId)) {
        buffer.write(chunk);
      }

      return ChatMessage(
        id: _uuid.v4(),
        content: buffer.toString().trim(),
        isUser: false,
        timestamp: DateTime.now(),
        status: MessageStatus.delivered,
      );
    } catch (e) {
      _logger.e('Error in sendMessage: $e');
      rethrow;
    }
  }

  /// Check if the AI agent server is available
  Future<bool> checkServerHealth() async {
    try {
      // Simple check - try to connect to the endpoint
      final response = await http
          .post(
            Uri.parse(_baseUrl),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'message': 'ping',
              'sessionId': 'health_check',
            }),
          )
          .timeout(const Duration(seconds: 15));

      return response.statusCode == 200;
    } catch (e) {
      _logger.w('AI agent server health check failed: $e');
      return false;
    }
  }

  /// Get chat history from the server (if supported)
  Future<List<ChatMessage>> getChatHistory(String userId) async {
    try {
      final response = await http
          .get(
            Uri.parse('$_baseUrl/api/chat/history?user_id=$userId'),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final List<dynamic> messages = data['messages'] ?? [];

        return messages.map((msg) {
          return ChatMessage(
            id: msg['id'] ?? _uuid.v4(),
            content: msg['content'] ?? '',
            isUser: msg['is_user'] ?? false,
            timestamp: DateTime.parse(msg['timestamp']),
            status: MessageStatus.delivered,
          );
        }).toList();
      }
      return [];
    } catch (e) {
      _logger.w('Failed to get chat history: $e');
      return [];
    }
  }

  /// Clear chat history on the server
  Future<void> clearChatHistory(String userId) async {
    try {
      await http
          .delete(
            Uri.parse('$_baseUrl/api/chat/history?user_id=$userId'),
          )
          .timeout(const Duration(seconds: 10));
    } catch (e) {
      _logger.w('Failed to clear chat history: $e');
    }
  }

  /// Send message to external LLM (OpenAI-compatible API)
  /// Used when _llmProvider is externalNgrok
  Stream<String> sendMessageToExternalLlm(
    String content,
    String sessionId, {
    bool filterThinkBlocks = true,
  }) async* {
    try {
      _logger.d('Sending message to external LLM: $content');

      final request = http.Request(
        'POST',
        Uri.parse('$_externalLlmUrl/v1/chat/completions'),
      );
      request.headers['Content-Type'] = 'application/json';
      request.headers['Authorization'] = 'Bearer $_externalLlmApiKey';

      request.body = jsonEncode({
        'model': _externalLlmModel,
        'messages': [
          {'role': 'user', 'content': content}
        ],
        'stream': false,
      });

      final response = await request.send();

      if (response.statusCode == 200) {
        final body = await response.stream.bytesToString();
        final data = jsonDecode(body);

        final reply = data['choices']?[0]?['message']?['content'] ?? '';

        // Filter think blocks if needed
        String filteredReply = reply;
        if (filterThinkBlocks) {
          filteredReply = reply
              .replaceAll(RegExp(r'<think>.*?</think>', dotAll: true), '')
              .trim();
        }

        yield filteredReply;
      } else if (response.statusCode == 401) {
        throw Exception('Invalid API key for external LLM');
      } else {
        final body = await response.stream.bytesToString();
        throw Exception('External LLM error: ${response.statusCode} - $body');
      }
    } catch (e) {
      _logger.e('Error sending to external LLM: $e');
      rethrow;
    }
  }

  /// Send voice message and receive voice reply via n8n /api/voice
  /// Returns VoiceChatResponse with audio file path and transcriptions
  Future<VoiceChatResponse?> sendVoiceMessage(
    String audioFilePath,
    String sessionId,
  ) async {
    try {
      _logger.i('Sending voice message: $audioFilePath');

      final file = File(audioFilePath);
      if (!await file.exists()) {
        _logger.e('Audio file not found: $audioFilePath');
        return null;
      }

      final request = http.MultipartRequest('POST', Uri.parse(_voiceChatUrl));

      // Add audio file
      request.files.add(await http.MultipartFile.fromPath(
        'audio',
        audioFilePath,
        contentType: MediaType('audio', _getAudioMimeType(audioFilePath)),
      ));

      // Add session ID
      request.fields['sessionId'] = sessionId;

      final streamedResponse =
          await request.send().timeout(const Duration(seconds: 120));
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        final contentType = response.headers['content-type'] ?? '';

        if (contentType.contains('audio')) {
          // Save audio response
          final directory = await getApplicationDocumentsDirectory();
          final timestamp = DateTime.now().millisecondsSinceEpoch;
          final filePath = '${directory.path}/ai_voice_reply_$timestamp.wav';

          final audioFile = File(filePath);
          await audioFile.writeAsBytes(response.bodyBytes);

          return VoiceChatResponse(
            audioFilePath: filePath,
            userTranscription: response.headers['x-user-transcription'],
            aiResponse: response.headers['x-ai-response'],
          );
        } else {
          // JSON response
          final data = jsonDecode(response.body);

          if (data['audio'] != null) {
            // Base64 encoded audio
            final audioBytes = base64Decode(data['audio']);
            final directory = await getApplicationDocumentsDirectory();
            final timestamp = DateTime.now().millisecondsSinceEpoch;
            final filePath = '${directory.path}/ai_voice_reply_$timestamp.wav';

            final audioFile = File(filePath);
            await audioFile.writeAsBytes(audioBytes);

            return VoiceChatResponse(
              audioFilePath: filePath,
              userTranscription: data['transcription'],
              aiResponse: data['response'],
            );
          } else if (data['error'] != null) {
            _logger.e('Voice chat error: ${data['error']}');
            return null;
          }
        }
      } else {
        _logger.e('Voice chat error: ${response.statusCode}');
        return null;
      }

      return null;
    } catch (e) {
      _logger.e('Error in voice chat: $e');
      return null;
    }
  }

  String _getAudioMimeType(String filePath) {
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
      default:
        return 'octet-stream';
    }
  }

  /// Check external LLM health
  Future<bool> checkExternalLlmHealth() async {
    try {
      final response = await http
          .get(Uri.parse('$_externalLlmUrl/v1/models'))
          .timeout(const Duration(seconds: 10));
      return response.statusCode == 200;
    } catch (e) {
      _logger.w('External LLM health check failed: $e');
      return false;
    }
  }

  /// Check voice chat endpoint health
  Future<bool> checkVoiceChatHealth() async {
    try {
      // Just check if endpoint is reachable
      final uri = Uri.parse(_voiceChatUrl);
      final response = await http.head(uri).timeout(const Duration(seconds: 5));
      // n8n returns various codes, as long as it's not a network error, it's "available"
      return response.statusCode < 500;
    } catch (e) {
      _logger.w('Voice chat health check failed: $e');
      return false;
    }
  }

  /// Get voice chat URL
  String get voiceChatUrl => _voiceChatUrl;

  /// Get external LLM URL
  String get externalLlmUrl => _externalLlmUrl;

  /// Get external LLM model
  String get externalLlmModel => _externalLlmModel;
}

/// Response from voice chat endpoint
class VoiceChatResponse {
  final String audioFilePath;
  final String? userTranscription;
  final String? aiResponse;

  VoiceChatResponse({
    required this.audioFilePath,
    this.userTranscription,
    this.aiResponse,
  });
}
