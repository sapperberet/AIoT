import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import 'package:logger/logger.dart';
import 'package:audioplayers/audioplayers.dart';
import '../models/chat_message_model.dart';
import '../services/ai_chat_service.dart';

/// Provider for managing AI chat state
class AIChatProvider with ChangeNotifier {
  final AIChatService _chatService;
  final Logger _logger = Logger();
  final AudioPlayer _audioPlayer = AudioPlayer();
  final Uuid _uuid = const Uuid();

  final List<ChatMessage> _messages = [];
  bool _isLoading = false;
  bool _isServerAvailable = false;
  String? _error;
  bool _showThinkMode = false; // Toggle for showing AI reasoning
  int _unreadCount = 0; // Track unread AI messages

  AIChatProvider({required AIChatService chatService})
      : _chatService = chatService {
    _checkServerHealth();
  }

  List<ChatMessage> get messages => List.unmodifiable(_messages);
  bool get isLoading => _isLoading;
  bool get isServerAvailable => _isServerAvailable;
  String? get error => _error;
  bool get hasMessages => _messages.isNotEmpty;
  bool get showThinkMode => _showThinkMode;
  int get unreadMessageCount => _unreadCount;

  /// Toggle think mode visibility
  void toggleThinkMode(bool value) {
    _showThinkMode = value;
    notifyListeners();
  }

  /// Mark all messages as read
  void markAllAsRead() {
    _unreadCount = 0;
    notifyListeners();
  }

  /// Increment unread count (called when AI sends a message)
  void _incrementUnreadCount() {
    _unreadCount++;
    notifyListeners();
  }

  /// Check if AI agent server is available
  Future<void> _checkServerHealth() async {
    _isServerAvailable = await _chatService.checkServerHealth();
    notifyListeners();
  }

  /// Set the AI agent server URL
  void setServerUrl(String url) {
    _chatService.setServerUrl(url);
    _checkServerHealth();
  }

  /// Send a message to the AI agent with streaming support
  Future<void> sendMessage(String content, String userId) async {
    if (content.trim().isEmpty) return;

    // Play send sound
    _playSendSound();

    // Create user message
    final userMessage = ChatMessage(
      id: _uuid.v4(),
      content: content.trim(),
      isUser: true,
      timestamp: DateTime.now(),
      status: MessageStatus.sending,
    );

    _messages.add(userMessage);
    notifyListeners();

    // Update message status to sent
    final index = _messages.indexWhere((m) => m.id == userMessage.id);
    if (index != -1) {
      _messages[index] = userMessage.copyWith(status: MessageStatus.sent);
      notifyListeners();
    }

    // Show loading indicator
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      // Generate session ID for this conversation
      final sessionId = _uuid.v4();

      // Create AI message placeholder
      final aiMessageId = _uuid.v4();
      final aiMessage = ChatMessage(
        id: aiMessageId,
        content: '',
        isUser: false,
        timestamp: DateTime.now(),
        status: MessageStatus.sending,
      );
      _messages.add(aiMessage);
      notifyListeners();

      // Receive streamed response
      final buffer = StringBuffer();

      await for (var chunk in _chatService.sendMessageStream(
        content,
        userId,
        sessionId,
        filterThinkBlocks: !_showThinkMode, // Filter if NOT showing think mode
      )) {
        buffer.write(chunk);

        // Update AI message with accumulated content
        final aiIndex = _messages.indexWhere((m) => m.id == aiMessageId);
        if (aiIndex != -1) {
          _messages[aiIndex] = aiMessage.copyWith(
            content: buffer.toString(),
            status: MessageStatus.delivered,
          );
          notifyListeners();
        }
      }

      // Play receive sound when complete
      if (buffer.toString().trim().isNotEmpty) {
        _playReceiveSound();
        // Increment unread count when AI responds
        _incrementUnreadCount();
      }

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _logger.e('Error sending message: $e');
      _error = e.toString();

      // Mark user message as error
      if (index != -1) {
        _messages[index] = userMessage.copyWith(
          status: MessageStatus.error,
          error: 'Failed to send message',
        );
      }

      _isLoading = false;
      notifyListeners();
    }
  }

  /// Load chat history from server
  Future<void> loadChatHistory(String userId) async {
    try {
      _isLoading = true;
      notifyListeners();

      final history = await _chatService.getChatHistory(userId);
      _messages.clear();
      _messages.addAll(history);

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _logger.e('Error loading chat history: $e');
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Clear all messages
  Future<void> clearMessages(String userId) async {
    try {
      await _chatService.clearChatHistory(userId);
      _messages.clear();
      _error = null;
      notifyListeners();
    } catch (e) {
      _logger.e('Error clearing messages: $e');
    }
  }

  /// Retry sending a failed message
  Future<void> retryMessage(String messageId, String userId) async {
    final index = _messages.indexWhere((m) => m.id == messageId);
    if (index == -1) return;

    final message = _messages[index];
    if (!message.isUser) return;

    // Remove the failed message
    _messages.removeAt(index);
    notifyListeners();

    // Resend
    await sendMessage(message.content, userId);
  }

  /// Play sound when sending a message
  void _playSendSound() {
    try {
      _audioPlayer.play(AssetSource('Audio/chat notify.mp3'));
    } catch (e) {
      _logger.w('Failed to play send sound: $e');
    }
  }

  /// Play sound when receiving a message
  void _playReceiveSound() {
    try {
      _audioPlayer.play(AssetSource('Audio/message-incoming.mp3'));
    } catch (e) {
      _logger.w('Failed to play receive sound: $e');
    }
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }
}
