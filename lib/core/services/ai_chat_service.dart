import 'dart:convert';
import 'dart:async';
import 'package:http/http.dart' as http;
import 'package:logger/logger.dart';
import '../models/chat_message_model.dart';
import 'package:uuid/uuid.dart';

/// Service for communicating with the AI agent backend
class AIChatService {
  final Logger _logger = Logger();
  final Uuid _uuid = const Uuid();

  // This should point to your AI agent server
  // Default: localhost for testing
  String _baseUrl = 'http://localhost:5678/webhook-test/agent';

  /// Set the AI agent server URL
  void setServerUrl(String url) {
    _baseUrl = url.endsWith('/') ? url.substring(0, url.length - 1) : url;
    _logger.i('AI Chat server URL updated: $_baseUrl');
  }

  /// Send a message to the AI agent with streaming response
  /// Returns a stream of message chunks
  Stream<String> sendMessageStream(
      String content, String userId, String sessionId) async* {
    try {
      _logger.d('Sending message to AI agent: $content');

      final request = http.Request('POST', Uri.parse(_baseUrl));
      request.headers['Content-Type'] = 'application/json';
      request.body = jsonEncode({
        'message': content,
        'user_id': userId,
        'session_id': sessionId,
      });

      final response = await request.send();

      if (response.statusCode == 200) {
        _logger.i('Receiving streamed response from AI agent');

        bool insideThinkBlock = false;

        await for (var chunk in response.stream.transform(utf8.decoder)) {
          // Parse each line of the streamed response
          final lines = chunk.split('\n');

          for (var line in lines) {
            if (line.trim().isEmpty) continue;

            try {
              final data = jsonDecode(line);

              // Only process "item" type messages
              if (data['type'] == 'item') {
                String content = data['content'] ?? '';

                // Handle <think> blocks
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

                // Yield the content chunk
                if (content.isNotEmpty) {
                  yield content;
                }
              }
            } catch (e) {
              _logger.w('Error parsing chunk: $e');
              continue;
            }
          }
        }
      } else {
        _logger.e('AI agent error: ${response.statusCode}');
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
              'user_id': 'health_check',
              'session_id': 'health_check',
            }),
          )
          .timeout(const Duration(seconds: 5));

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
}
