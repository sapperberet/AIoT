import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:iconsax/iconsax.dart';
import 'package:animate_do/animate_do.dart';
import 'package:intl/intl.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/providers/ai_chat_provider.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/models/chat_session_model.dart';
import '../../../core/theme/app_theme.dart';
import 'ai_chat_screen.dart';

class ChatSessionsScreen extends StatefulWidget {
  const ChatSessionsScreen({super.key});

  @override
  State<ChatSessionsScreen> createState() => _ChatSessionsScreenState();
}

class _ChatSessionsScreenState extends State<ChatSessionsScreen> {
  bool _isSelectionMode = false;
  final Set<String> _selectedSessions = {};

  @override
  void initState() {
    super.initState();
    _loadSessions();
  }

  Future<void> _loadSessions() async {
    final authProvider = context.read<AuthProvider>();
    final chatProvider = context.read<AIChatProvider>();
    if (authProvider.currentUser != null) {
      await chatProvider.loadChatHistory(authProvider.currentUser!.uid);
    }
  }

  void _toggleSelectionMode() {
    setState(() {
      _isSelectionMode = !_isSelectionMode;
      if (!_isSelectionMode) {
        _selectedSessions.clear();
      }
    });
  }

  void _toggleSessionSelection(String sessionId) {
    setState(() {
      if (_selectedSessions.contains(sessionId)) {
        _selectedSessions.remove(sessionId);
      } else {
        _selectedSessions.add(sessionId);
      }
    });
  }

  Future<void> _deleteSelectedSessions() async {
    final authProvider = context.read<AuthProvider>();
    final chatProvider = context.read<AIChatProvider>();
    final userId = authProvider.currentUser?.uid;

    if (userId == null) return;

    for (final sessionId in _selectedSessions) {
      await chatProvider.deleteSession(userId, sessionId);
    }

    setState(() {
      _isSelectionMode = false;
      _selectedSessions.clear();
    });
  }

  void _showDeleteConfirmation(BuildContext context) {
    final loc = AppLocalizations.of(context);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(loc.t('delete_sessions')),
        content: Text(
          loc.t('delete_sessions_confirm').replaceAll(
                '{count}',
                _selectedSessions.length.toString(),
              ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(loc.t('cancel')),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _deleteSelectedSessions();
            },
            style: TextButton.styleFrom(foregroundColor: AppTheme.errorColor),
            child: Text(loc.t('delete')),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final textColor = theme.colorScheme.onBackground;
    final loc = AppLocalizations.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: FadeInLeft(
          child: IconButton(
            icon: Icon(
              _isSelectionMode ? Icons.close : Iconsax.arrow_left,
              color: textColor,
            ),
            onPressed: _isSelectionMode
                ? _toggleSelectionMode
                : () => Navigator.pop(context),
          ),
        ),
        title: FadeInDown(
          child: _isSelectionMode
              ? Text(
                  '${_selectedSessions.length} ${loc.t('selected')}',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: textColor,
                  ),
                )
              : ShaderMask(
                  shaderCallback: (bounds) =>
                      AppTheme.primaryGradient.createShader(bounds),
                  child: Text(
                    loc.t('chat_history'),
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
        ),
        actions: [
          if (_isSelectionMode && _selectedSessions.isNotEmpty)
            FadeInRight(
              child: IconButton(
                icon: const Icon(Iconsax.trash, color: AppTheme.errorColor),
                onPressed: () => _showDeleteConfirmation(context),
              ),
            ),
          if (!_isSelectionMode)
            FadeInRight(
              child: PopupMenuButton<String>(
                icon: Icon(Iconsax.more, color: textColor),
                color: isDark ? AppTheme.darkCard : AppTheme.lightSurface,
                itemBuilder: (context) => [
                  PopupMenuItem(
                    value: 'select',
                    child: Row(
                      children: [
                        Icon(Iconsax.tick_square,
                            color: AppTheme.primaryColor, size: 20),
                        const SizedBox(width: 12),
                        Text(loc.t('select'),
                            style: TextStyle(color: textColor)),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'delete_all',
                    child: Row(
                      children: [
                        const Icon(Iconsax.trash,
                            color: AppTheme.errorColor, size: 20),
                        const SizedBox(width: 12),
                        Text(loc.t('delete_all'),
                            style: TextStyle(color: textColor)),
                      ],
                    ),
                  ),
                ],
                onSelected: (value) {
                  if (value == 'select') {
                    _toggleSelectionMode();
                  } else if (value == 'delete_all') {
                    _showDeleteAllConfirmation(context);
                  }
                },
              ),
            ),
        ],
      ),
      body: Consumer<AIChatProvider>(
        builder: (context, chatProvider, child) {
          if (chatProvider.isLoading) {
            return const Center(
              child: CircularProgressIndicator(color: AppTheme.primaryColor),
            );
          }

          if (!chatProvider.hasSessions) {
            return _buildEmptyState(loc, textColor);
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: chatProvider.sessions.length,
            itemBuilder: (context, index) {
              final session = chatProvider.sessions[index];
              return FadeInUp(
                delay: Duration(milliseconds: 50 * index),
                child: _buildSessionCard(
                  context,
                  session,
                  chatProvider.currentSession?.id == session.id,
                  isDark,
                  textColor,
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FadeInUp(
        child: FloatingActionButton.extended(
          onPressed: () => _createNewSession(context),
          backgroundColor: AppTheme.primaryColor,
          icon: const Icon(Iconsax.add, color: Colors.white),
          label: Text(
            loc.t('new_chat'),
            style: const TextStyle(color: Colors.white),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(AppLocalizations loc, Color textColor) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Iconsax.message_text,
            size: 80,
            color: textColor.withOpacity(0.3),
          ),
          const SizedBox(height: 16),
          Text(
            loc.t('no_chat_history'),
            style: TextStyle(
              fontSize: 18,
              color: textColor.withOpacity(0.5),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            loc.t('start_new_chat_hint'),
            style: TextStyle(
              fontSize: 14,
              color: textColor.withOpacity(0.4),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSessionCard(
    BuildContext context,
    ChatSession session,
    bool isActive,
    bool isDark,
    Color textColor,
  ) {
    final isSelected = _selectedSessions.contains(session.id);
    final dateFormat = DateFormat('MMM d, HH:mm');

    return GestureDetector(
      onTap: () {
        if (_isSelectionMode) {
          _toggleSessionSelection(session.id);
        } else {
          _openSession(context, session);
        }
      },
      onLongPress: () {
        if (!_isSelectionMode) {
          _toggleSelectionMode();
          _toggleSessionSelection(session.id);
        }
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? AppTheme.darkCard : AppTheme.lightCard,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isActive
                ? AppTheme.primaryColor
                : isSelected
                    ? AppTheme.primaryColor.withOpacity(0.5)
                    : Colors.transparent,
            width: isActive || isSelected ? 2 : 0,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            if (_isSelectionMode)
              Checkbox(
                value: isSelected,
                onChanged: (_) => _toggleSessionSelection(session.id),
                activeColor: AppTheme.primaryColor,
              ),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                gradient: AppTheme.primaryGradient,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Iconsax.message_text_1,
                color: Colors.white,
                size: 24,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    session.displayTitle,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: textColor,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    session.lastMessagePreview,
                    style: TextStyle(
                      fontSize: 13,
                      color: textColor.withOpacity(0.6),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(
                        Iconsax.clock,
                        size: 12,
                        color: textColor.withOpacity(0.4),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        dateFormat.format(session.lastMessageAt),
                        style: TextStyle(
                          fontSize: 11,
                          color: textColor.withOpacity(0.4),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Icon(
                        Iconsax.message,
                        size: 12,
                        color: textColor.withOpacity(0.4),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${session.messages.length}',
                        style: TextStyle(
                          fontSize: 11,
                          color: textColor.withOpacity(0.4),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            if (isActive)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  AppLocalizations.of(context).t('active'),
                  style: const TextStyle(
                    fontSize: 10,
                    color: AppTheme.primaryColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _createNewSession(BuildContext context) async {
    final authProvider = context.read<AuthProvider>();
    final chatProvider = context.read<AIChatProvider>();
    final userId = authProvider.currentUser?.uid;

    if (userId == null) return;

    await chatProvider.createNewSession(userId);

    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const AIChatScreen()),
      );
    }
  }

  void _openSession(BuildContext context, ChatSession session) async {
    final authProvider = context.read<AuthProvider>();
    final chatProvider = context.read<AIChatProvider>();
    final userId = authProvider.currentUser?.uid;

    if (userId == null) return;

    await chatProvider.switchToSession(userId, session.id);

    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const AIChatScreen()),
      );
    }
  }

  void _showDeleteAllConfirmation(BuildContext context) {
    final loc = AppLocalizations.of(context);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(loc.t('delete_all_sessions')),
        content: Text(loc.t('delete_all_sessions_confirm')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(loc.t('cancel')),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              final authProvider = context.read<AuthProvider>();
              final chatProvider = context.read<AIChatProvider>();
              final userId = authProvider.currentUser?.uid;
              if (userId != null) {
                await chatProvider.deleteAllSessions(userId);
              }
            },
            style: TextButton.styleFrom(foregroundColor: AppTheme.errorColor),
            child: Text(loc.t('delete')),
          ),
        ],
      ),
    );
  }
}
