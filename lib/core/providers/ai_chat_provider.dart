import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:uuid/uuid.dart';
import 'package:logger/logger.dart';
import 'package:audioplayers/audioplayers.dart';
import 'dart:async';
import '../models/chat_message_model.dart';
import '../models/chat_session_model.dart';
import '../services/ai_chat_service.dart';
import '../services/voice_service.dart';
import '../services/backend_voice_service.dart';
import '../services/chat_storage_service.dart';
import '../services/ai_chat_actions_service.dart';

/// Voice mode for AI chat
enum VoiceMode {
  /// Text only chat
  textOnly,

  /// Voice input, text output
  voiceToText,

  /// Voice input, voice output (full voice chat)
  voiceToVoice,
}

/// Provider for managing AI chat state
class AIChatProvider with ChangeNotifier {
  final AIChatService _chatService;
  final VoiceService _voiceService = VoiceService();
  final BackendVoiceService _backendVoiceService = BackendVoiceService();
  final ChatStorageService _storageService = ChatStorageService();
  final Logger _logger = Logger();
  final AudioPlayer _audioPlayer = AudioPlayer();
  final Uuid _uuid = const Uuid();

  // Actions service (will be initialized later)
  AIChatActionsService? _actionsService;

  final List<ChatMessage> _messages = [];
  List<ChatSession> _sessions = [];
  ChatSession? _currentSession;
  String? _currentUserId;
  bool _isLoading = false;
  bool _isServerAvailable = false;
  String? _error;
  bool _showThinkMode = false; // Toggle for showing AI reasoning
  int _unreadCount = 0; // Track unread AI messages
  String? _currentLocale; // Current locale for speech recognition

  // Voice mode settings
  VoiceMode _voiceMode = VoiceMode.textOnly;
  bool _isVoiceChatAvailable = false;
  bool _isTtsAvailable = false;
  bool _isAsrAvailable = false;
  bool _isPlayingVoiceReply = false;

  // LLM provider settings
  bool _isExternalLlmAvailable = false;

  // Stream cancellation support
  StreamSubscription<String>? _activeStreamSubscription;
  bool _isCancelled = false;

  // Callback for when AI response is received (for notifications)
  void Function(String message)? onAIResponseReceived;

  AIChatProvider({required AIChatService chatService})
      : _chatService = chatService {
    _checkServerHealth();
    _initializeVoiceService();
    _checkBackendServices();
  }

  List<ChatMessage> get messages => List.unmodifiable(_messages);
  bool get isLoading => _isLoading;
  bool get isServerAvailable => _isServerAvailable;
  String? get error => _error;
  bool get hasMessages => _messages.isNotEmpty;
  bool get showThinkMode => _showThinkMode;
  int get unreadMessageCount => _unreadCount;
  VoiceService get voiceService => _voiceService;
  BackendVoiceService get backendVoiceService => _backendVoiceService;
  String? get currentLocale => _currentLocale;

  // Session getters
  List<ChatSession> get sessions => List.unmodifiable(_sessions);
  ChatSession? get currentSession => _currentSession;
  bool get hasSessions => _sessions.isNotEmpty;

  // Voice mode getters
  VoiceMode get voiceMode => _voiceMode;
  bool get isVoiceChatAvailable => _isVoiceChatAvailable;
  bool get isTtsAvailable => _isTtsAvailable;
  bool get isAsrAvailable => _isAsrAvailable;
  bool get isPlayingVoiceReply => _isPlayingVoiceReply;

  // LLM provider getters
  LlmProvider get llmProvider => _chatService.llmProvider;
  bool get isExternalLlmAvailable => _isExternalLlmAvailable;

  /// Initialize voice service
  Future<void> _initializeVoiceService() async {
    try {
      await _voiceService.initialize();
    } catch (e) {
      _logger.e('Failed to initialize voice service: $e');
    }
  }

  /// Check backend services availability (TTS, ASR, voice chat)
  Future<void> _checkBackendServices() async {
    try {
      // Check TTS availability
      _isTtsAvailable = await _backendVoiceService.checkTtsHealth();
      _logger.i('TTS available: $_isTtsAvailable');

      // Check ASR availability
      _isAsrAvailable = await _backendVoiceService.checkAsrHealth();
      _logger.i('ASR available: $_isAsrAvailable');

      // Check voice chat availability
      _isVoiceChatAvailable = await _chatService.checkVoiceChatHealth();
      _logger.i('Voice chat available: $_isVoiceChatAvailable');

      // Check external LLM availability
      _isExternalLlmAvailable = await _chatService.checkExternalLlmHealth();
      _logger.i('External LLM available: $_isExternalLlmAvailable');

      notifyListeners();
    } catch (e) {
      _logger.e('Error checking backend services: $e');
    }
  }

  /// Refresh backend service status
  Future<void> refreshBackendStatus() async {
    await _checkServerHealth();
    await _checkBackendServices();
  }

  /// Set voice mode
  void setVoiceMode(VoiceMode mode) {
    _voiceMode = mode;
    _logger.i('Voice mode changed to: $mode');
    notifyListeners();
  }

  /// Set LLM provider
  void setLlmProvider(LlmProvider provider) {
    _chatService.setLlmProvider(provider);
    notifyListeners();
  }

  /// Initialize actions service (must be called after MQTT and other services are ready)
  void initializeActionsService(AIChatActionsService actionsService) {
    _actionsService = actionsService;
    _logger.i('AI Chat actions service initialized');
  }

  /// Process AI response for automation actions
  Future<Map<String, dynamic>?> processActions(
    String aiResponse, {
    String? userId,
  }) async {
    if (_actionsService == null) {
      _logger.w('Actions service not initialized');
      return null;
    }

    final results = await _actionsService!.parseAndExecuteActions(
      aiResponse,
      userId: userId,
    );

    if (results['success'] == true) {
      _logger.i('✅ Executed actions: ${results['executedActions']}');
    }

    return results;
  }

  /// Update broker endpoint from settings
  void updateBrokerEndpoint(String address, {int? port}) {
    _chatService.updateBrokerEndpoint(address, port: port);
    _backendVoiceService.updateBrokerAddress(address);
    _checkServerHealth();
    _checkBackendServices();
    notifyListeners();
  }

  /// Get current broker address
  String get currentBrokerAddress => _chatService.currentBrokerAddress;

  /// Get current broker port
  int get currentBrokerPort => _chatService.currentBrokerPort;

  /// Configure external LLM
  void configureExternalLlm({
    required String url,
    required String apiKey,
    String? model,
  }) {
    _chatService.setExternalLlmConfig(url: url, apiKey: apiKey, model: model);
    _checkBackendServices(); // Re-check availability
  }

  /// Set locale for speech recognition
  void setLocale(String locale) {
    _currentLocale = locale;
    notifyListeners();
  }

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
    // Defer notifyListeners to avoid calling it during build
    SchedulerBinding.instance.addPostFrameCallback((_) {
      notifyListeners();
    });
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

  /// Cancel ongoing AI response stream
  void cancelCurrentResponse() {
    if (_activeStreamSubscription != null) {
      _isCancelled = true;
      _activeStreamSubscription?.cancel();
      _activeStreamSubscription = null;
      _isLoading = false;
      _logger.i('AI response stream cancelled by user');
      notifyListeners();
    }
  }

  /// Check if a response is currently being received
  bool get isReceivingResponse => _activeStreamSubscription != null;

  /// Send a message to the AI agent with streaming support
  Future<void> sendMessage(String content, String userId,
      {MessageType type = MessageType.text,
      String? voiceFilePath,
      int? voiceDurationMs}) async {
    print('[AI Chat] sendMessage called with content: "$content"');

    if (content.trim().isEmpty) {
      print('[AI Chat] Content is empty, returning');
      return;
    }

    // Don't allow new messages while still receiving a response
    if (_isLoading) {
      print('[AI Chat] Still loading previous response, ignoring');
      return;
    }

    print('[AI Chat] Creating user message...');

    // Reset cancellation flag
    _isCancelled = false;

    // Play send sound
    _playSendSound();

    // Create user message
    final userMessage = ChatMessage(
      id: _uuid.v4(),
      content: content.trim(),
      isUser: true,
      timestamp: DateTime.now(),
      status: MessageStatus.sending,
      type: type,
      voiceFilePath: voiceFilePath,
      voiceDurationMs: voiceDurationMs,
      transcription: type == MessageType.voice ? content : null,
    );

    _messages.add(userMessage);
    print(
        '[AI Chat] User message added to list. Total messages: ${_messages.length}');
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
    print('[AI Chat] Starting AI request...');
    notifyListeners();

    try {
      // Generate session ID for this conversation
      final sessionId = _uuid.v4();
      print('[AI Chat] Session ID: $sessionId');

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
      print('[AI Chat] Starting to receive stream...');

      // Use stream subscription for cancellation support
      final completer = Completer<void>();

      _activeStreamSubscription = _chatService
          .sendMessageStream(
        content,
        userId,
        sessionId,
        filterThinkBlocks: !_showThinkMode, // Filter if NOT showing think mode
      )
          .listen(
        (chunk) {
          if (_isCancelled) return;

          buffer.write(chunk);
          print(
              '[AI Chat] Received chunk (${chunk.length} chars): ${chunk.substring(0, chunk.length > 50 ? 50 : chunk.length)}...');

          // Update AI message with accumulated content
          final aiIndex = _messages.indexWhere((m) => m.id == aiMessageId);
          if (aiIndex != -1) {
            _messages[aiIndex] = aiMessage.copyWith(
              content: buffer.toString(),
              status: MessageStatus.delivered,
            );
            // Defer notifyListeners to avoid calling it during build
            SchedulerBinding.instance.addPostFrameCallback((_) {
              notifyListeners();
            });
          }
        },
        onDone: () async {
          _activeStreamSubscription = null;

          if (!_isCancelled) {
            // Play receive sound when complete
            final responseText = buffer.toString().trim();
            if (responseText.isNotEmpty) {
              _playReceiveSound();
              // Increment unread count when AI responds
              _incrementUnreadCount();

              // Process actions in the response
              if (responseText.contains('[ACTION:')) {
                _logger.i('Detected action commands in AI response');
                await processActions(responseText, userId: userId);
              }

              // Trigger callback for notification
              if (onAIResponseReceived != null) {
                onAIResponseReceived!(responseText);
              }
            }
          }

          // Save session after message exchange
          _saveCurrentSession();

          _isLoading = false;
          // Defer notifyListeners to avoid calling it during build
          SchedulerBinding.instance.addPostFrameCallback((_) {
            notifyListeners();
          });

          if (!completer.isCompleted) {
            completer.complete();
          }
        },
        onError: (error) {
          _activeStreamSubscription = null;
          _logger.e('Error in stream: $error');
          _error = error.toString();

          // Mark user message as error
          if (index != -1) {
            _messages[index] = userMessage.copyWith(
              status: MessageStatus.error,
              error: 'Failed to send message',
            );
          }

          // Still save the session to persist the user message
          _saveCurrentSession();

          _isLoading = false;
          // Defer notifyListeners to avoid calling it during build
          SchedulerBinding.instance.addPostFrameCallback((_) {
            notifyListeners();
          });

          if (!completer.isCompleted) {
            completer.completeError(error);
          }
        },
        cancelOnError: true,
      );

      await completer.future;
    } catch (e) {
      _activeStreamSubscription = null;
      _logger.e('Error sending message: $e');
      _error = e.toString();

      // Mark user message as error
      if (index != -1) {
        _messages[index] = userMessage.copyWith(
          status: MessageStatus.error,
          error: 'Failed to send message',
        );
      }

      // Still save the session to persist the user message
      await _saveCurrentSession();

      _isLoading = false;
      // Defer notifyListeners to avoid calling it during build
      SchedulerBinding.instance.addPostFrameCallback((_) {
        notifyListeners();
      });
    }
  }

  /// Send a voice message with transcription
  Future<void> sendVoiceMessage(
    String voiceFilePath,
    int durationMs,
    String transcription,
    String userId,
  ) async {
    await sendMessage(
      transcription,
      userId,
      type: MessageType.voice,
      voiceFilePath: voiceFilePath,
      voiceDurationMs: durationMs,
    );
  }

  /// Initialize sessions for a user
  Future<void> initializeSessions(String userId) async {
    _currentUserId = userId;
    _sessions = await _storageService.loadSessions(userId);

    // Load the last active session or create a new one
    final activeSessionId = await _storageService.getActiveSessionId(userId);
    if (activeSessionId != null) {
      _currentSession = _sessions.firstWhere(
        (s) => s.id == activeSessionId,
        orElse: () => _sessions.isNotEmpty
            ? _sessions.first
            : ChatSession.create(userId: userId),
      );
    } else if (_sessions.isNotEmpty) {
      _currentSession = _sessions.first;
    } else {
      // Create a new session if none exists
      _currentSession = ChatSession.create(userId: userId);
      _sessions.add(_currentSession!);
      await _storageService.saveSession(userId, _currentSession!);
    }

    // Load messages from current session
    _messages.clear();
    if (_currentSession != null) {
      _messages.addAll(_currentSession!.messages);
    }

    notifyListeners();
  }

  /// Create a new chat session
  Future<void> createNewSession(String userId) async {
    final newSession = ChatSession.create(userId: userId);
    _sessions.insert(0, newSession);
    _currentSession = newSession;
    _messages.clear();

    await _storageService.saveSession(userId, newSession);
    await _storageService.setActiveSessionId(userId, newSession.id);

    notifyListeners();
  }

  /// Switch to a different session
  Future<void> switchToSession(String userId, String sessionId) async {
    final session = _sessions.firstWhere(
      (s) => s.id == sessionId,
      orElse: () => throw Exception('Session not found'),
    );

    _currentSession = session;
    _messages.clear();
    _messages.addAll(session.messages);

    await _storageService.setActiveSessionId(userId, sessionId);

    notifyListeners();
  }

  /// Delete a chat session
  Future<void> deleteSession(String userId, String sessionId) async {
    await _storageService.deleteSession(userId, sessionId);
    _sessions.removeWhere((s) => s.id == sessionId);

    // If deleted the current session, switch to another or create new
    if (_currentSession?.id == sessionId) {
      if (_sessions.isNotEmpty) {
        _currentSession = _sessions.first;
        _messages.clear();
        _messages.addAll(_currentSession!.messages);
        await _storageService.setActiveSessionId(userId, _currentSession!.id);
      } else {
        // Create a new session
        await createNewSession(userId);
      }
    }

    notifyListeners();
  }

  /// Delete all sessions
  Future<void> deleteAllSessions(String userId) async {
    await _storageService.clearAllSessions(userId);
    _sessions.clear();
    _messages.clear();

    // Create a fresh session
    await createNewSession(userId);
  }

  /// Save current session state (called after sending messages)
  Future<void> _saveCurrentSession() async {
    if (_currentSession == null || _currentUserId == null) return;

    // Update session title from first user message if it's "New Chat"
    String newTitle = _currentSession!.title;
    if (_currentSession!.title == 'New Chat' && _messages.isNotEmpty) {
      final firstUserMessage = _messages.firstWhere(
        (m) => m.isUser,
        orElse: () => _messages.first,
      );
      newTitle = firstUserMessage.content.length > 50
          ? '${firstUserMessage.content.substring(0, 47)}...'
          : firstUserMessage.content;
    }

    _currentSession = _currentSession!.copyWith(
      messages: List.from(_messages),
      lastMessageAt: DateTime.now(),
      title: newTitle,
    );

    // Update in sessions list
    final index = _sessions.indexWhere((s) => s.id == _currentSession!.id);
    if (index != -1) {
      _sessions[index] = _currentSession!;
    }

    await _storageService.saveSession(_currentUserId!, _currentSession!);
  }

  /// Load chat history from local storage (session-aware)
  Future<void> loadChatHistory(String userId) async {
    try {
      _isLoading = true;
      notifyListeners();

      await initializeSessions(userId);

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _logger.e('Error loading chat history: $e');
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Clear current session messages
  Future<void> clearMessages(String userId) async {
    try {
      if (_currentSession != null) {
        await _storageService.clearSessionMessages(userId, _currentSession!.id);
        _currentSession = _currentSession!.copyWith(
          messages: [],
          title: 'New Chat',
        );

        // Update in sessions list
        final index = _sessions.indexWhere((s) => s.id == _currentSession!.id);
        if (index != -1) {
          _sessions[index] = _currentSession!;
        }
      }
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

  /// Send voice-to-voice chat (full voice mode)
  /// Records user voice, sends to backend, receives and plays AI voice response
  Future<void> sendVoiceChatMessage(
    String audioFilePath,
    int durationMs,
    String userId,
  ) async {
    _logger.i('Starting voice-to-voice chat');

    // Create user voice message
    final userMessage = ChatMessage(
      id: _uuid.v4(),
      content: '🎤 Voice message',
      isUser: true,
      timestamp: DateTime.now(),
      status: MessageStatus.sending,
      type: MessageType.voice,
      voiceFilePath: audioFilePath,
      voiceDurationMs: durationMs,
    );

    _messages.add(userMessage);
    notifyListeners();

    // Update to sent
    final userIndex = _messages.indexWhere((m) => m.id == userMessage.id);
    if (userIndex != -1) {
      _messages[userIndex] = userMessage.copyWith(status: MessageStatus.sent);
      notifyListeners();
    }

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final sessionId = _uuid.v4();

      // Send to voice chat endpoint
      final response = await _chatService.sendVoiceMessage(
        audioFilePath,
        sessionId,
      );

      if (response != null) {
        // Update user message with transcription if available
        if (response.userTranscription != null && userIndex != -1) {
          _messages[userIndex] = _messages[userIndex].copyWith(
            content: response.userTranscription,
            transcription: response.userTranscription,
          );
          notifyListeners();
        }

        // Create AI voice response message
        final aiMessage = ChatMessage(
          id: _uuid.v4(),
          content: response.aiResponse ?? '🔊 Voice response',
          isUser: false,
          timestamp: DateTime.now(),
          status: MessageStatus.delivered,
          type: MessageType.voice,
          voiceFilePath: response.audioFilePath,
          transcription: response.aiResponse,
        );

        _messages.add(aiMessage);
        _incrementUnreadCount();

        // Auto-play the voice response
        await _playVoiceResponse(response.audioFilePath);
      } else {
        throw Exception('Failed to get voice response from AI');
      }

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _logger.e('Error in voice chat: $e');
      _error = e.toString();

      if (userIndex != -1) {
        _messages[userIndex] = _messages[userIndex].copyWith(
          status: MessageStatus.error,
          error: 'Voice chat failed',
        );
      }

      _isLoading = false;
      notifyListeners();
    }
  }

  /// Play voice response audio
  Future<void> _playVoiceResponse(String audioFilePath) async {
    try {
      _isPlayingVoiceReply = true;
      notifyListeners();

      await _audioPlayer.play(DeviceFileSource(audioFilePath));

      // Wait for playback to complete
      await _audioPlayer.onPlayerComplete.first;

      _isPlayingVoiceReply = false;
      notifyListeners();
    } catch (e) {
      _logger.e('Error playing voice response: $e');
      _isPlayingVoiceReply = false;
      notifyListeners();
    }
  }

  /// Stop playing voice response
  Future<void> stopVoiceResponse() async {
    try {
      await _audioPlayer.stop();
      _isPlayingVoiceReply = false;
      notifyListeners();
    } catch (e) {
      _logger.e('Error stopping voice response: $e');
    }
  }

  /// Transcribe audio using backend ASR (Faster-Whisper)
  Future<String?> transcribeWithBackend(String audioFilePath) async {
    try {
      final result = await _backendVoiceService.transcribeAudio(
        audioFilePath,
        language: _currentLocale?.split('_').first ?? 'ar',
      );
      return result?.text;
    } catch (e) {
      _logger.e('Backend transcription failed: $e');
      return null;
    }
  }

  /// Synthesize text to speech using backend TTS (Piper)
  Future<String?> synthesizeWithBackend(String text) async {
    try {
      return await _backendVoiceService.synthesizeSpeech(text);
    } catch (e) {
      _logger.e('Backend TTS failed: $e');
      return null;
    }
  }

  @override
  void dispose() {
    // Cancel any active stream subscription
    _activeStreamSubscription?.cancel();
    _activeStreamSubscription = null;
    _audioPlayer.dispose();
    _voiceService.dispose();
    super.dispose();
  }
}
