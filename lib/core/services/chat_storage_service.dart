import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';
import '../models/chat_session_model.dart';
import '../models/chat_message_model.dart';

/// Service for persisting chat sessions and messages locally
class ChatStorageService {
  static const String _sessionsKey = 'chat_sessions';
  static const String _activeSessionKey = 'active_session_id';

  /// Save all sessions for a user
  Future<void> saveSessions(String userId, List<ChatSession> sessions) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final sessionsJson = sessions.map((s) => s.toJson()).toList();
      await prefs.setString(
        '${_sessionsKey}_$userId',
        jsonEncode(sessionsJson),
      );
      debugPrint('Saved ${sessions.length} chat sessions for user $userId');
    } catch (e) {
      debugPrint('Error saving sessions: $e');
    }
  }

  /// Load all sessions for a user
  Future<List<ChatSession>> loadSessions(String userId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final sessionsString = prefs.getString('${_sessionsKey}_$userId');

      if (sessionsString == null || sessionsString.isEmpty) {
        debugPrint('No saved sessions found for user $userId');
        return [];
      }

      final List<dynamic> sessionsJson = jsonDecode(sessionsString);
      final List<ChatSession> sessions = sessionsJson
          .map((json) => ChatSession.fromJson(json as Map<String, dynamic>))
          .toList();

      // Sort by last message date (newest first)
      sessions.sort((a, b) => b.lastMessageAt.compareTo(a.lastMessageAt));

      debugPrint('Loaded ${sessions.length} chat sessions for user $userId');
      return sessions;
    } catch (e) {
      debugPrint('Error loading sessions: $e');
      return [];
    }
  }

  /// Save a single session (updates if exists, creates if new)
  Future<void> saveSession(String userId, ChatSession session) async {
    try {
      final sessions = await loadSessions(userId);
      final index = sessions.indexWhere((s) => s.id == session.id);

      if (index != -1) {
        sessions[index] = session;
      } else {
        sessions.insert(0, session);
      }

      await saveSessions(userId, sessions);
    } catch (e) {
      debugPrint('Error saving session: $e');
    }
  }

  /// Delete a session
  Future<void> deleteSession(String userId, String sessionId) async {
    try {
      final sessions = await loadSessions(userId);
      sessions.removeWhere((s) => s.id == sessionId);
      await saveSessions(userId, sessions);
      debugPrint('Deleted session $sessionId');
    } catch (e) {
      debugPrint('Error deleting session: $e');
    }
  }

  /// Clear all sessions for a user
  Future<void> clearAllSessions(String userId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('${_sessionsKey}_$userId');
      await prefs.remove('${_activeSessionKey}_$userId');
      debugPrint('Cleared all sessions for user $userId');
    } catch (e) {
      debugPrint('Error clearing sessions: $e');
    }
  }

  /// Get active session ID
  Future<String?> getActiveSessionId(String userId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString('${_activeSessionKey}_$userId');
    } catch (e) {
      debugPrint('Error getting active session: $e');
      return null;
    }
  }

  /// Set active session ID
  Future<void> setActiveSessionId(String userId, String? sessionId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (sessionId == null) {
        await prefs.remove('${_activeSessionKey}_$userId');
      } else {
        await prefs.setString('${_activeSessionKey}_$userId', sessionId);
      }
    } catch (e) {
      debugPrint('Error setting active session: $e');
    }
  }

  /// Add a message to a session
  Future<ChatSession?> addMessageToSession(
    String userId,
    String sessionId,
    ChatMessage message,
  ) async {
    try {
      final sessions = await loadSessions(userId);
      final index = sessions.indexWhere((s) => s.id == sessionId);

      if (index == -1) {
        debugPrint('Session not found: $sessionId');
        return null;
      }

      final session = sessions[index];
      final updatedMessages = [...session.messages, message];

      // Update session title from first user message if it's "New Chat"
      String newTitle = session.title;
      if (session.title == 'New Chat' && message.isUser) {
        newTitle = message.content.length > 50
            ? '${message.content.substring(0, 47)}...'
            : message.content;
      }

      final updatedSession = session.copyWith(
        messages: updatedMessages,
        lastMessageAt: message.timestamp,
        title: newTitle,
      );

      sessions[index] = updatedSession;
      await saveSessions(userId, sessions);

      return updatedSession;
    } catch (e) {
      debugPrint('Error adding message to session: $e');
      return null;
    }
  }

  /// Update a message in a session
  Future<void> updateMessageInSession(
    String userId,
    String sessionId,
    ChatMessage updatedMessage,
  ) async {
    try {
      final sessions = await loadSessions(userId);
      final sessionIndex = sessions.indexWhere((s) => s.id == sessionId);

      if (sessionIndex == -1) return;

      final session = sessions[sessionIndex];
      final messageIndex = session.messages.indexWhere(
        (m) => m.id == updatedMessage.id,
      );

      if (messageIndex == -1) return;

      final updatedMessages = List<ChatMessage>.from(session.messages);
      updatedMessages[messageIndex] = updatedMessage;

      sessions[sessionIndex] = session.copyWith(
        messages: updatedMessages,
        lastMessageAt: updatedMessage.timestamp,
      );

      await saveSessions(userId, sessions);
    } catch (e) {
      debugPrint('Error updating message in session: $e');
    }
  }

  /// Get a specific session
  Future<ChatSession?> getSession(String userId, String sessionId) async {
    try {
      final sessions = await loadSessions(userId);
      return sessions.firstWhere(
        (s) => s.id == sessionId,
        orElse: () => throw Exception('Session not found'),
      );
    } catch (e) {
      debugPrint('Error getting session: $e');
      return null;
    }
  }

  /// Clear messages in a session (keep session, remove messages)
  Future<void> clearSessionMessages(String userId, String sessionId) async {
    try {
      final sessions = await loadSessions(userId);
      final index = sessions.indexWhere((s) => s.id == sessionId);

      if (index == -1) return;

      sessions[index] = sessions[index].copyWith(
        messages: [],
        title: 'New Chat',
      );

      await saveSessions(userId, sessions);
      debugPrint('Cleared messages in session $sessionId');
    } catch (e) {
      debugPrint('Error clearing session messages: $e');
    }
  }
}
