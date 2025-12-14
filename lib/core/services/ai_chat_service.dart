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

      // Use regular http.post instead of streaming request
      // because n8n returns complete responses, not chunked streams
      // Add longer timeout since AI processing can take time
      final response = await http
          .post(
            Uri.parse(_baseUrl),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'chatInput': content, // n8n AI Agent expects 'chatInput'
              'message': content, // Also send as 'message' for compatibility
              'sessionId': sessionId,
            }),
          )
          .timeout(const Duration(
              seconds: 300)); // 5 minute timeout for AI processing

      print('[AI Chat Service] Response status: ${response.statusCode}');
      print('[AI Chat Service] Response body length: ${response.body.length}');
      print('[AI Chat Service] Response body: ${response.body}');

      if (response.statusCode == 200) {
        _logger.i('Received response from AI agent');

        bool insideThinkBlock = false;
        bool hasYieldedAnyContent = false;
        final responseBody = response.body;

        // Process the complete response body
        if (responseBody.isNotEmpty) {
          print(
              '[AI Chat Service] Processing response body (${responseBody.length} bytes)');

          // FIRST: Try to parse the entire response as a single JSON object
          // This is the most common case for n8n webhook responses
          try {
            final data = jsonDecode(responseBody);
            print('[AI Chat Service] Parsed as single JSON object: $data');

            // Check for n8n streaming error format: {"type":"error","metadata":{...}}
            if (data['type'] == 'error') {
              final metadata = data['metadata'] as Map<String, dynamic>?;
              final nodeName = metadata?['nodeName'] as String? ?? 'AI Agent';
              print(
                  '[AI Chat Service] ⚠️ n8n error event from node: $nodeName');

              yield '⚠️ Error in $nodeName. The AI workflow encountered an issue.\n\n💡 Try:\n• Check n8n logs: docker logs n8n\n• Restart Ollama: docker restart ollama\n• Verify Ollama model is loaded';
              hasYieldedAnyContent = true;
            }
            // Check for n8n error response format with errorMessage
            else if (data['errorMessage'] != null) {
              final errorMsg = data['errorMessage'] as String;
              print('[AI Chat Service] ⚠️ n8n error response: $errorMsg');

              String details = '';
              if (data['n8nDetails'] != null) {
                final n8nDetails = data['n8nDetails'] as Map<String, dynamic>;
                final nodeName = n8nDetails['nodeName'] as String? ?? '';
                if (nodeName.isNotEmpty) {
                  details = ' (in $nodeName)';
                }
              }

              String helpHint = '';
              if (errorMsg.contains('timed out') ||
                  errorMsg.contains('timeout')) {
                helpHint =
                    '\n\n💡 The AI model is taking too long. Try:\n• Restarting Ollama: docker restart ollama\n• Using a smaller model\n• Checking if Ollama has enough memory';
              } else if (errorMsg.contains('connect') ||
                  errorMsg.contains('ECONNREFUSED')) {
                helpHint =
                    '\n\n💡 Cannot connect to Ollama. Try:\n• docker compose up -d ollama\n• Check if Ollama is running';
              } else if (errorMsg.contains('model') ||
                  errorMsg.contains('not found')) {
                helpHint =
                    '\n\n💡 Model not found. Try:\n• docker exec ollama ollama pull qwen2.5:7b-instruct';
              }

              yield '⚠️ $errorMsg$details$helpHint';
              hasYieldedAnyContent = true;
            }
            // Check for direct n8n output format: {"output": "response text"}
            else if (data['output'] != null && data['output'] is String) {
              final output = (data['output'] as String).trim();
              print('[AI Chat Service] ✅ Found direct output field: $output');
              if (output.isNotEmpty) {
                yield output;
                hasYieldedAnyContent = true;
              }
            }
            // Check for other common response fields
            else {
              String content = data['content'] as String? ??
                  data['text'] as String? ??
                  data['response'] as String? ??
                  data['answer'] as String? ??
                  data['result'] as String? ??
                  data['message'] as String? ??
                  '';

              if (content.isNotEmpty) {
                print('[AI Chat Service] ✅ Found content in field: $content');
                yield content;
                hasYieldedAnyContent = true;
              } else {
                print(
                    '[AI Chat Service] ⚠️ No recognizable content in JSON: $data');
              }
            }
          } catch (jsonError) {
            // Not a single JSON object, try line-by-line parsing (streaming format)
            print(
                '[AI Chat Service] Not single JSON, trying line-by-line: $jsonError');

            final lines = responseBody.split('\n');
            print('[AI Chat Service] Split into ${lines.length} lines');

            for (var line in lines) {
              if (line.trim().isEmpty) continue;

              print(
                  '[AI Chat Service] Processing line: ${line.substring(0, line.length > 100 ? 100 : line.length)}...');

              try {
                final data = jsonDecode(line);
                print('[AI Chat Service] Decoded JSON: $data');

                // Check for output field
                if (data['output'] != null && data['output'] is String) {
                  final output = data['output'] as String;
                  if (output.trim().isNotEmpty) {
                    yield output.trim();
                    hasYieldedAnyContent = true;
                    continue;
                  }
                }

                // Handle streaming event types
                final type = data['type'] as String?;
                if (type == 'begin' || type == 'end') continue;

                if (type == 'error') {
                  String errorMsg = data['error'] as String? ??
                      data['message'] as String? ??
                      'AI workflow error';
                  yield '⚠️ $errorMsg';
                  hasYieldedAnyContent = true;
                  continue;
                }

                // Extract content
                String content = data['content'] as String? ??
                    data['data'] as String? ??
                    data['text'] as String? ??
                    '';

                if (content.isNotEmpty) {
                  yield content;
                  hasYieldedAnyContent = true;
                }
              } catch (e) {
                // Plain text line
                if (!line.trim().startsWith('<') && line.trim().isNotEmpty) {
                  yield line.trim();
                  hasYieldedAnyContent = true;
                }
              }
            }
          }

          // FALLBACK: If still no content, yield raw response
          if (!hasYieldedAnyContent) {
            print(
                '[AI Chat Service] ⚠️ No content extracted, yielding raw response');
            if (!responseBody.trim().startsWith('<')) {
              yield responseBody.trim();
              hasYieldedAnyContent = true;
            }
          }
        } else {
          // Empty response body - n8n webhook might be misconfigured
          print('[AI Chat Service] ⚠️ Empty response body received');
          yield '⚠️ The AI service returned an empty response.\n\n💡 This usually means:\n• The n8n workflow "Respond to Webhook" node is not properly connected\n• The AI is still processing (timeout)\n\nPlease check the n8n workflow configuration.';
          hasYieldedAnyContent = true;
        }

        print(
            '[AI Chat Service] Processing completed. hasYieldedAnyContent: $hasYieldedAnyContent');
      } else if (response.statusCode == 404) {
        _logger.e('Webhook not found (404) - n8n workflow may not be active');
        throw Exception(
          'AI agent not available. Make sure the n8n workflow is activated in the n8n UI.',
        );
      } else {
        _logger.e('AI agent error: ${response.statusCode}');
        _logger.e('Response body: ${response.body}');
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
      // Use n8n's built-in health endpoint instead of sending to webhook
      // This is more reliable as it doesn't depend on workflow processing
      final n8nBaseUrl =
          'http://${MqttConfig.localBrokerAddress}:${MqttConfig.n8nPort}';
      final healthUrl = '$n8nBaseUrl/healthz';

      _logger.d('Checking n8n health at: $healthUrl');

      final response = await http
          .get(Uri.parse(healthUrl))
          .timeout(const Duration(seconds: 10));

      _logger.d('n8n health response: ${response.statusCode}');

      // n8n's /healthz returns 200 when server is running
      if (response.statusCode == 200) {
        return true;
      }

      // Fallback: try HEAD request to webhook endpoint
      // Some n8n setups may not have /healthz enabled
      try {
        final webhookResponse = await http
            .head(Uri.parse(_baseUrl))
            .timeout(const Duration(seconds: 5));
        // n8n returns 404 for HEAD on webhook, but that means server is up
        // 200, 404, 405 all indicate server is running
        return webhookResponse.statusCode < 500;
      } catch (e) {
        return false;
      }
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
          final ext = _getExtensionFromMimeType(contentType);
          final filePath = '${directory.path}/ai_voice_reply_$timestamp.$ext';

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
            // Default to mp3 if not specified
            final filePath = '${directory.path}/ai_voice_reply_$timestamp.mp3';

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

  String _getExtensionFromMimeType(String mimeType) {
    if (mimeType.contains('wav')) return 'wav';
    if (mimeType.contains('mpeg') || mimeType.contains('mp3')) return 'mp3';
    if (mimeType.contains('aac')) return 'aac';
    if (mimeType.contains('ogg')) return 'ogg';
    if (mimeType.contains('mp4') || mimeType.contains('m4a')) return 'm4a';
    return 'mp3'; // Default to mp3 as requested
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

  /// Update broker endpoint (for MQTT and n8n services)
  void updateBrokerEndpoint(String newAddress, {int? port}) {
    _baseUrl = 'http://$newAddress:${port ?? MqttConfig.n8nPort}/api/agent';
    _voiceChatUrl = 'http://$newAddress:${port ?? MqttConfig.n8nPort}/api/voice';
    _logger.i('Broker endpoint updated: $newAddress');
  }

  /// Get current broker address
  String get currentBrokerAddress {
    final uri = Uri.parse(_baseUrl);
    return uri.host;
  }

  /// Get current broker port
  int get currentBrokerPort {
    final uri = Uri.parse(_baseUrl);
    return uri.port;
  }

  /// Send a message with action intent
  /// The AI can respond with action commands that will be parsed and executed
  Future<Map<String, dynamic>> sendMessageWithActions(
    String content,
    String userId,
    String sessionId, {
    bool includeActions = true,
  }) async {
    try {
      final response = await http
          .post(
            Uri.parse(_baseUrl),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'chatInput': content,
              'message': content,
              'sessionId': sessionId,
              'userId': userId,
              'enableActions': includeActions,
              'systemPrompt': includeActions
                  ? 'You can control smart home devices. When you want to perform an action, use this format: [ACTION:type:param1:param2]. Available actions: open_door, close_door, open_window, close_window, turn_light, set_fan, trigger_alarm. Example: "I\'ll open the door for you [ACTION:open_door:main_door]"'
                  : null,
            }),
          )
          .timeout(const Duration(seconds: 60));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        
        String responseText = '';
        if (data['output'] != null) {
          responseText = data['output'] as String;
        } else if (data['response'] != null) {
          responseText = data['response'] as String;
        }

        return {
          'success': true,
          'response': responseText,
          'hasActions': responseText.contains('[ACTION:'),
          'rawData': data,
        };
      }

      return {
        'success': false,
        'error': 'Failed to get response: ${response.statusCode}',
      };
    } catch (e) {
      _logger.e('Error sending message with actions: $e');
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }
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
