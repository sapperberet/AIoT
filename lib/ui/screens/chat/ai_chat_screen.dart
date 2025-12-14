import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:iconsax/iconsax.dart';
import 'package:animate_do/animate_do.dart';
import 'package:intl/intl.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/providers/ai_chat_provider.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/providers/settings_provider.dart';
import '../../../core/models/chat_message_model.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/services/ai_chat_service.dart';
import '../../../core/services/notification_service.dart';
import '../../../core/services/voice_service.dart';
import '../../../core/config/mqtt_config.dart';
import '../../widgets/voice_recorder_widget.dart';
import 'chat_theme_settings_dialog.dart';
import '../../../core/providers/chat_theme_provider.dart';
import '../../widgets/formatted_text_widget.dart';
import '../../widgets/voice_message_bubble.dart';
import 'chat_sessions_screen.dart';

class AIChatScreen extends StatefulWidget {
  const AIChatScreen({super.key});

  @override
  State<AIChatScreen> createState() => _AIChatScreenState();
}

class _AIChatScreenState extends State<AIChatScreen>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _focusNode = FocusNode();
  late AnimationController _typingAnimationController;
  bool _showScrollToBottom = false;
  bool _isRecordingVoice = false;
  String _liveTranscription = '';
  int _recordingDuration = 0;
  bool _isScreenActive = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _typingAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();

    _scrollController.addListener(_onScroll);

    // Listen to text changes to toggle send/voice button
    _messageController.addListener(() {
      setState(() {});
    });

    // Load chat history and set up notification callback
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final authProvider = context.read<AuthProvider>();
      final chatProvider = context.read<AIChatProvider>();
      if (authProvider.currentUser != null) {
        chatProvider.loadChatHistory(authProvider.currentUser!.uid);
      }

      // Set up callback for AI response notifications
      chatProvider.onAIResponseReceived = _onAIResponseReceived;
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    // Track when app goes to background
    _isScreenActive = state == AppLifecycleState.resumed;
  }

  void _onAIResponseReceived(String message) {
    // If user is not on this screen or app is in background, show notification
    if (!_isScreenActive || !mounted) {
      final notificationService = context.read<NotificationService>();
      final preview =
          message.length > 100 ? '${message.substring(0, 97)}...' : message;
      notificationService.addNotification(
        title: 'AI Assistant Response',
        message: preview,
        type: NotificationType.info,
        priority: NotificationPriority.medium,
        data: {'type': 'ai_chat_response'},
      );
    }
  }

  void _onScroll() {
    if (_scrollController.hasClients) {
      final showButton = _scrollController.offset > 200;
      if (showButton != _showScrollToBottom) {
        setState(() {
          _showScrollToBottom = showButton;
        });
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    // Cancel any ongoing response when leaving the screen
    final chatProvider = context.read<AIChatProvider>();
    chatProvider.cancelCurrentResponse();
    chatProvider.onAIResponseReceived = null;

    _messageController.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    _typingAnimationController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  Future<void> _createNewChat() async {
    final authProvider = context.read<AuthProvider>();
    final chatProvider = context.read<AIChatProvider>();
    final userId = authProvider.currentUser?.uid ?? 'debug-user';
    await chatProvider.createNewSession(userId);
  }

  void _sendMessage() {
    print('[AI Chat Screen] _sendMessage called');
    final message = _messageController.text.trim();
    print('[AI Chat Screen] Message: "$message"');

    if (message.isEmpty) {
      print('[AI Chat Screen] Message is empty, returning');
      return;
    }

    final authProvider = context.read<AuthProvider>();
    final chatProvider = context.read<AIChatProvider>();

    // Get user ID (use debug fallback if auth is bypassed)
    final userId = authProvider.currentUser?.uid ?? 'debug-user';
    print('[AI Chat Screen] User ID: $userId');

    chatProvider.sendMessage(message, userId);
    _messageController.clear();

    // Scroll to bottom disabled per user request
    // Future.delayed(const Duration(milliseconds: 100), _scrollToBottom);
  }

  Future<void> _startVoiceRecording() async {
    final chatProvider = context.read<AIChatProvider>();
    final voiceService = chatProvider.voiceService;
    final loc = AppLocalizations.of(context);

    try {
      // Start recording
      final started = await voiceService.startRecording(
        locale: chatProvider.currentLocale,
      );

      if (started) {
        setState(() {
          _isRecordingVoice = true;
          _liveTranscription = '';
        });

        // Start live transcription
        await voiceService.startLiveTranscription(
          locale: chatProvider.currentLocale,
          onResult: (text) {
            setState(() {
              _liveTranscription = text;
            });
          },
        );
      } else {
        // Show error
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(loc.t('voice_permission_denied')),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } on PermissionException catch (_) {
      // Permission denied - guide user to settings
      if (mounted) {
        _showPermissionDialog();
      }
    } catch (e) {
      // Other errors
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${loc.t('error_starting_recording')}: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _showPermissionDialog() async {
    final loc = AppLocalizations.of(context);
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            const Icon(Iconsax.microphone_slash, color: Colors.red),
            const SizedBox(width: 8),
            Expanded(child: Text(loc.t('microphone_permission_required'))),
          ],
        ),
        content: Text(loc.t('microphone_permission_message')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(loc.t('cancel')),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryColor,
            ),
            child: Text(loc.t('open_settings')),
          ),
        ],
      ),
    );

    if (result == true) {
      await openAppSettings();
    }
  }

  Future<void> _stopVoiceRecording() async {
    final chatProvider = context.read<AIChatProvider>();
    final voiceService = chatProvider.voiceService;
    final authProvider = context.read<AuthProvider>();

    // Stop live transcription
    await voiceService.stopLiveTranscription();

    // Stop recording
    final result = await voiceService.stopRecording();

    setState(() {
      _isRecordingVoice = false;
    });

    if (result != null) {
      // Get user ID
      final userId = authProvider.currentUser?.uid ?? 'debug-user';

      // Handle based on voice mode
      if (chatProvider.voiceMode == VoiceMode.voiceToVoice &&
          chatProvider.isVoiceChatAvailable) {
        // Full voice-to-voice mode: send audio, receive audio
        await chatProvider.sendVoiceChatMessage(
          result.filePath,
          result.durationMs,
          userId,
        );
      } else {
        // Voice-to-text mode: transcribe locally and send as text
        String transcription = _liveTranscription.trim();

        // If local transcription is empty, try backend ASR
        if (transcription.isEmpty && chatProvider.isAsrAvailable) {
          transcription =
              await chatProvider.transcribeWithBackend(result.filePath) ?? '';
        }

        // Fallback placeholder
        if (transcription.isEmpty) {
          transcription = AppLocalizations.of(context).t('voice_message');
        }

        // Send voice message
        await chatProvider.sendVoiceMessage(
          result.filePath,
          result.durationMs,
          transcription,
          userId,
        );
      }

      // Scroll to bottom disabled per user request
      // Future.delayed(const Duration(milliseconds: 100), _scrollToBottom);
    }
  }

  Future<void> _cancelVoiceRecording() async {
    final chatProvider = context.read<AIChatProvider>();
    final voiceService = chatProvider.voiceService;

    // Stop live transcription
    await voiceService.stopLiveTranscription();

    // Cancel recording
    await voiceService.cancelRecording();

    setState(() {
      _isRecordingVoice = false;
      _liveTranscription = '';
    });
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final textColor = theme.colorScheme.onBackground;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: FadeInLeft(
          child: IconButton(
            icon: Icon(Iconsax.arrow_left, color: textColor),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        title: FadeInDown(
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  gradient: AppTheme.primaryGradient,
                  shape: BoxShape.circle,
                  boxShadow: AppTheme.glowShadow,
                ),
                child: const Icon(
                  Iconsax.message_programming,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      loc.t('ai_assistant'),
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: textColor,
                      ),
                    ),
                    Consumer<AIChatProvider>(
                      builder: (context, chatProvider, child) {
                        return Text(
                          chatProvider.isServerAvailable
                              ? loc.t('online')
                              : loc.t('offline'),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: chatProvider.isServerAvailable
                                ? Colors.green
                                : Colors.red,
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          // New chat button
          FadeInRight(
            child: IconButton(
              icon: Icon(Iconsax.add, color: textColor),
              tooltip: loc.t('new_chat'),
              onPressed: () => _createNewChat(),
            ),
          ),
          // Chat history button
          FadeInRight(
            child: IconButton(
              icon: Icon(Iconsax.message_text, color: textColor),
              tooltip: loc.t('chat_history'),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const ChatSessionsScreen(),
                ),
              ),
            ),
          ),
          FadeInRight(
            child: PopupMenuButton(
              icon: Icon(Iconsax.more, color: textColor),
              color: isDark ? AppTheme.darkSurface : AppTheme.lightSurface,
              shape: RoundedRectangleBorder(
                borderRadius: AppTheme.mediumRadius,
              ),
              itemBuilder: (context) => [
                PopupMenuItem(
                  child: Row(
                    children: [
                      const Icon(Iconsax.paintbucket, size: 20),
                      const SizedBox(width: 12),
                      Text(loc.t('chat_appearance')),
                    ],
                  ),
                  onTap: () => ChatThemeSettingsDialog.show(context),
                ),
                PopupMenuItem(
                  child: Row(
                    children: [
                      const Icon(Iconsax.setting_2, size: 20),
                      const SizedBox(width: 12),
                      Text(loc.t('configure_server')),
                    ],
                  ),
                  onTap: () => _showServerConfigDialog(),
                ),
                PopupMenuItem(
                  child: Row(
                    children: [
                      const Icon(Iconsax.microphone, size: 20),
                      const SizedBox(width: 12),
                      Text(loc.t('voice_settings')),
                    ],
                  ),
                  onTap: () => _showVoiceSettingsDialog(),
                ),
                PopupMenuItem(
                  child: Row(
                    children: [
                      const Icon(Iconsax.cpu, size: 20),
                      const SizedBox(width: 12),
                      Text(loc.t('llm_provider')),
                    ],
                  ),
                  onTap: () => _showLlmProviderDialog(),
                ),
                PopupMenuItem(
                  enabled: false,
                  child: Consumer<AIChatProvider>(
                    builder: (context, chatProvider, _) {
                      return SwitchListTile(
                        value: chatProvider.showThinkMode,
                        onChanged: (value) {
                          chatProvider.toggleThinkMode(value);
                        },
                        title: Text(
                          loc.t('show_think_mode'),
                          style: const TextStyle(fontSize: 14),
                        ),
                        subtitle: Text(
                          loc.t('think_mode_description'),
                          style: TextStyle(
                            fontSize: 11,
                            color: textColor.withOpacity(0.6),
                          ),
                        ),
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        activeColor: AppTheme.primaryColor,
                      );
                    },
                  ),
                ),
                PopupMenuItem(
                  child: Row(
                    children: [
                      const Icon(Iconsax.trash, size: 20, color: Colors.red),
                      const SizedBox(width: 12),
                      Text(
                        loc.t('clear_chat'),
                        style: const TextStyle(color: Colors.red),
                      ),
                    ],
                  ),
                  onTap: () => _showClearChatDialog(),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          // Messages list
          Expanded(
            child: Consumer<AIChatProvider>(
              builder: (context, chatProvider, child) {
                if (chatProvider.isLoading && !chatProvider.hasMessages) {
                  return _buildLoadingState(loc);
                }

                if (!chatProvider.hasMessages) {
                  return _buildEmptyState(loc, isDark, textColor);
                }

                return Stack(
                  children: [
                    ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.all(16),
                      itemCount: chatProvider.messages.length,
                      itemBuilder: (context, index) {
                        final message = chatProvider.messages[index];
                        return FadeInUp(
                          duration: const Duration(milliseconds: 300),
                          delay: Duration(milliseconds: index * 50),
                          child: _buildMessageBubble(
                            message,
                            isDark,
                            textColor,
                          ),
                        );
                      },
                    ),
                    if (chatProvider.isLoading)
                      Positioned(
                        bottom: 16,
                        left: 16,
                        child: _buildTypingIndicator(isDark),
                      ),
                  ],
                );
              },
            ),
          ),

          // Input area
          _buildInputArea(isDark, textColor, loc),

          // Scroll to bottom button - positioned above input area
          if (_showScrollToBottom)
            Positioned(
              bottom: 90, // Above the input area
              right: 16,
              child: FadeInUp(
                child: GestureDetector(
                  onTap: _scrollToBottom,
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor.withOpacity(0.9),
                      borderRadius: BorderRadius.circular(18),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Iconsax.arrow_down_1,
                      color: Colors.white,
                      size: 18,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(AppLocalizations loc, bool isDark, Color textColor) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: FadeIn(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  gradient: AppTheme.primaryGradient.scale(0.3),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Iconsax.message_programming,
                  size: 80,
                  color: AppTheme.primaryColor,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                loc.t('ai_assistant'),
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: textColor,
                ),
              ),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 40),
                child: Text(
                  loc.t('ai_chat_welcome'),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: textColor.withOpacity(0.6),
                  ),
                ),
              ),
              const SizedBox(height: 32),
              _buildSuggestionChips(loc),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSuggestionChips(AppLocalizations loc) {
    final suggestions = [
      loc.t('suggestion_status'),
      loc.t('suggestion_automation'),
      loc.t('suggestion_energy'),
    ];

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      alignment: WrapAlignment.center,
      children: suggestions.map((suggestion) {
        return ActionChip(
          label: Text(suggestion),
          avatar: const Icon(Iconsax.message_question, size: 16),
          onPressed: () {
            _messageController.text = suggestion;
            _sendMessage();
          },
          backgroundColor: AppTheme.primaryColor.withOpacity(0.1),
          labelStyle: const TextStyle(color: AppTheme.primaryColor),
        );
      }).toList(),
    );
  }

  Widget _buildLoadingState(AppLocalizations loc) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 16),
          Text(loc.t('loading')),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(
    ChatMessage message,
    bool isDark,
    Color textColor,
  ) {
    final isUser = message.isUser;

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        mainAxisAlignment:
            isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isUser) ...[
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                gradient: AppTheme.primaryGradient,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Iconsax.cpu,
                color: Colors.white,
                size: 16,
              ),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Consumer<ChatThemeProvider>(
              builder: (context, chatTheme, _) {
                final bubbleRadius = chatTheme.bubbleRadius;
                return Column(
                  crossAxisAlignment: isUser
                      ? CrossAxisAlignment.end
                      : CrossAxisAlignment.start,
                  children: [
                    Container(
                      constraints: BoxConstraints(
                        maxWidth: MediaQuery.of(context).size.width * 0.7,
                      ),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        gradient: isUser
                            ? chatTheme.userBubbleGradient
                            : chatTheme.aiBubbleGradient,
                        borderRadius: BorderRadius.only(
                          topLeft: Radius.circular(bubbleRadius),
                          topRight: Radius.circular(bubbleRadius),
                          bottomLeft:
                              Radius.circular(isUser ? bubbleRadius : 4),
                          bottomRight:
                              Radius.circular(isUser ? 4 : bubbleRadius),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: (isUser
                                    ? (chatTheme.customUserBubbleColor ??
                                        chatTheme.currentTheme.userBubbleColor)
                                    : Colors.black)
                                .withOpacity(0.1),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: message.type == MessageType.voice &&
                              message.voiceFilePath != null
                          ? VoiceMessageBubble(
                              voiceFilePath: message.voiceFilePath!,
                              durationMs: message.voiceDurationMs ?? 0,
                              isUser: isUser,
                              transcription: message.transcription,
                            )
                          : ChatFormattedText(
                              text: message.content,
                              isUser: isUser,
                              baseStyle: TextStyle(
                                color: isUser
                                    ? chatTheme.currentTheme.userTextColor
                                    : chatTheme.currentTheme.aiTextColor,
                                fontSize: chatTheme.fontSize,
                                fontFamily: chatTheme.fontFamily == 'Default'
                                    ? null
                                    : chatTheme.fontFamily,
                              ),
                            ),
                    ),
                    if (chatTheme.showTimestamps) ...[
                      const SizedBox(height: 4),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            DateFormat('HH:mm').format(message.timestamp),
                            style: TextStyle(
                              fontSize: 11,
                              color: textColor.withOpacity(0.5),
                            ),
                          ),
                          if (isUser) ...[
                            const SizedBox(width: 4),
                            Icon(
                              message.status == MessageStatus.error
                                  ? Iconsax.close_circle
                                  : message.status == MessageStatus.sending
                                      ? Iconsax.clock
                                      : Iconsax.tick_circle,
                              size: 12,
                              color: message.status == MessageStatus.error
                                  ? Colors.red
                                  : textColor.withOpacity(0.5),
                            ),
                          ],
                        ],
                      ),
                    ],
                    if (message.status == MessageStatus.error) ...[
                      const SizedBox(height: 4),
                      TextButton.icon(
                        onPressed: () {
                          final authProvider = context.read<AuthProvider>();
                          final chatProvider = context.read<AIChatProvider>();
                          if (authProvider.currentUser != null) {
                            chatProvider.retryMessage(
                              message.id,
                              authProvider.currentUser!.uid,
                            );
                          }
                        },
                        icon: const Icon(Iconsax.refresh, size: 14),
                        label: Text(AppLocalizations.of(context).t('retry')),
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.red,
                          padding: EdgeInsets.zero,
                        ),
                      ),
                    ],
                  ],
                );
              },
            ),
          ),
          if (isUser) ...[
            const SizedBox(width: 8),
            Consumer<AuthProvider>(
              builder: (context, authProvider, child) {
                final user = authProvider.currentUser;
                return Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    gradient: AppTheme.primaryGradient,
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      user?.email?.substring(0, 1).toUpperCase() ?? 'U',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                );
              },
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTypingIndicator(bool isDark) {
    return FadeInUp(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isDark ? Colors.grey.shade800 : Colors.grey.shade200,
          borderRadius: AppTheme.mediumRadius,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Iconsax.cpu, size: 16),
            const SizedBox(width: 8),
            AnimatedBuilder(
              animation: _typingAnimationController,
              builder: (context, child) {
                return Row(
                  mainAxisSize: MainAxisSize.min,
                  children: List.generate(3, (index) {
                    final delay = index * 0.2;
                    final animation = Tween<double>(begin: 0, end: 1).animate(
                      CurvedAnimation(
                        parent: _typingAnimationController,
                        curve: Interval(
                          delay,
                          delay + 0.4,
                          curve: Curves.easeInOut,
                        ),
                      ),
                    );
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 2),
                      child: Transform.translate(
                        offset: Offset(0, -4 * animation.value),
                        child: Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: AppTheme.primaryColor,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                    );
                  }),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInputArea(bool isDark, Color textColor, AppLocalizations loc) {
    // Show voice recorder if recording
    if (_isRecordingVoice) {
      return VoiceRecorderWidget(
        onCancel: _cancelVoiceRecording,
        onSend: (_) => _stopVoiceRecording(),
        onDurationUpdate: (duration) {
          setState(() {
            _recordingDuration = duration;
          });
        },
      );
    }

    // Show normal input
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkSurface : AppTheme.lightSurface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Voice mode indicator bar
            Consumer<AIChatProvider>(
              builder: (context, chatProvider, _) {
                if (chatProvider.voiceMode != VoiceMode.textOnly) {
                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor.withOpacity(0.1),
                      borderRadius: AppTheme.smallRadius,
                      border: Border.all(
                        color: AppTheme.primaryColor.withOpacity(0.3),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          chatProvider.voiceMode == VoiceMode.voiceToVoice
                              ? Iconsax.voice_cricle
                              : Iconsax.voice_square,
                          size: 16,
                          color: AppTheme.primaryColor,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          chatProvider.voiceMode == VoiceMode.voiceToVoice
                              ? loc.t('voice_to_voice')
                              : loc.t('voice_to_text'),
                          style: TextStyle(
                            fontSize: 12,
                            color: AppTheme.primaryColor,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(width: 8),
                        GestureDetector(
                          onTap: () =>
                              chatProvider.setVoiceMode(VoiceMode.textOnly),
                          child: Icon(
                            Iconsax.close_circle,
                            size: 16,
                            color: AppTheme.primaryColor,
                          ),
                        ),
                      ],
                    ),
                  );
                }
                return const SizedBox.shrink();
              },
            ),
            Row(
              children: [
                // Voice mode toggle button (chat mode selector)
                Consumer<AIChatProvider>(
                  builder: (context, chatProvider, _) {
                    final isVoiceMode =
                        chatProvider.voiceMode != VoiceMode.textOnly;
                    final isVoiceToVoice =
                        chatProvider.voiceMode == VoiceMode.voiceToVoice;
                    final isLoading = chatProvider.isLoading;
                    return GestureDetector(
                      onTap: isLoading ? null : () => _showQuickVoiceModeMenu(),
                      onLongPress:
                          isLoading ? null : () => _showVoiceSettingsDialog(),
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: isLoading
                              ? (isDark
                                  ? Colors.grey.shade900
                                  : Colors.grey.shade300)
                              : isVoiceMode
                                  ? (isVoiceToVoice
                                      ? Colors.green.withOpacity(0.2)
                                      : AppTheme.primaryColor.withOpacity(0.2))
                                  : (isDark
                                      ? Colors.grey.shade800
                                      : Colors.grey.shade200),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          // Use different icons: message for text, voice_square for voice-to-text, volume for voice-to-voice
                          isVoiceToVoice
                              ? Iconsax.volume_high
                              : (isVoiceMode
                                  ? Iconsax.message_text
                                  : Iconsax.messages_3),
                          size: 20,
                          color: isLoading
                              ? textColor.withOpacity(0.3)
                              : isVoiceMode
                                  ? (isVoiceToVoice
                                      ? Colors.green
                                      : AppTheme.primaryColor)
                                  : textColor.withOpacity(0.6),
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Consumer<AIChatProvider>(
                    builder: (context, chatProvider, _) {
                      final isLoading = chatProvider.isLoading;
                      return Container(
                        decoration: BoxDecoration(
                          color: isLoading
                              ? (isDark
                                  ? Colors.grey.shade900
                                  : Colors.grey.shade200)
                              : (isDark
                                  ? Colors.grey.shade800
                                  : Colors.grey.shade100),
                          borderRadius: AppTheme.mediumRadius,
                          border: Border.all(
                            color: isDark
                                ? Colors.white.withOpacity(0.1)
                                : Colors.black.withOpacity(0.1),
                          ),
                        ),
                        child: TextField(
                          controller: _messageController,
                          focusNode: _focusNode,
                          enabled: !isLoading,
                          decoration: InputDecoration(
                            hintText: isLoading
                                ? loc.t('waiting_for_response')
                                : loc.t('type_message'),
                            hintStyle: TextStyle(
                              color:
                                  textColor.withOpacity(isLoading ? 0.3 : 0.5),
                            ),
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                          ),
                          style: TextStyle(color: textColor),
                          maxLines: null,
                          textInputAction: TextInputAction.send,
                          onSubmitted: isLoading ? null : (_) => _sendMessage(),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(width: 12),

                // Action button based on state
                Consumer<AIChatProvider>(
                  builder: (context, chatProvider, _) {
                    final isLoading = chatProvider.isLoading;

                    // Show stop button while loading
                    if (isLoading) {
                      return Container(
                        decoration: BoxDecoration(
                          color: Colors.red.shade600,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.red.withOpacity(0.3),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: IconButton(
                          icon: const Icon(Iconsax.stop, color: Colors.white),
                          onPressed: () => chatProvider.cancelCurrentResponse(),
                          tooltip: loc.t('stop_response'),
                        ),
                      );
                    }

                    // Voice button (if text is empty)
                    if (_messageController.text.trim().isEmpty) {
                      return Container(
                        decoration: BoxDecoration(
                          gradient: AppTheme.primaryGradient,
                          shape: BoxShape.circle,
                          boxShadow: AppTheme.glowShadow,
                        ),
                        child: IconButton(
                          icon: const Icon(Iconsax.microphone,
                              color: Colors.white),
                          onPressed: _startVoiceRecording,
                        ),
                      );
                    }

                    // Send button (if text is not empty)
                    return Container(
                      decoration: BoxDecoration(
                        gradient: AppTheme.primaryGradient,
                        shape: BoxShape.circle,
                        boxShadow: AppTheme.glowShadow,
                      ),
                      child: IconButton(
                        icon: const Icon(Iconsax.send_1, color: Colors.white),
                        onPressed: _sendMessage,
                      ),
                    );
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showQuickVoiceModeMenu() {
    final chatProvider = context.read<AIChatProvider>();
    final loc = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? AppTheme.darkSurface : AppTheme.lightSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade400,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  loc.t('voice_mode'),
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                _buildVoiceModeBottomSheetOption(
                  context,
                  chatProvider,
                  VoiceMode.textOnly,
                  loc.t('text_only'),
                  loc.t('text_only_desc'),
                  Iconsax.messages_3,
                ),
                _buildVoiceModeBottomSheetOption(
                  context,
                  chatProvider,
                  VoiceMode.voiceToText,
                  loc.t('voice_to_text'),
                  loc.t('voice_to_text_desc'),
                  Iconsax.message_text,
                ),
                _buildVoiceModeBottomSheetOption(
                  context,
                  chatProvider,
                  VoiceMode.voiceToVoice,
                  loc.t('voice_to_voice'),
                  loc.t('voice_to_voice_desc'),
                  Iconsax.volume_high,
                  enabled: chatProvider.isVoiceChatAvailable,
                ),
                if (!chatProvider.isVoiceChatAvailable)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      '⚠️ Voice-to-voice requires backend voice chat service',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.orange.shade700,
                      ),
                    ),
                  ),
                const SizedBox(height: 16),
                const Divider(),
                const SizedBox(height: 8),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      gradient: AppTheme.primaryGradient.scale(0.3),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Iconsax.microphone_2,
                      color: AppTheme.primaryColor,
                    ),
                  ),
                  title: Text(
                    loc.t('open_voice_to_voice_screen'),
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(
                    loc.t('dedicated_voice_conversation'),
                    style: const TextStyle(fontSize: 12),
                  ),
                  trailing: const Icon(Iconsax.arrow_right_3),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.pushNamed(context, '/voice-to-voice');
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildVoiceModeBottomSheetOption(
    BuildContext context,
    AIChatProvider chatProvider,
    VoiceMode mode,
    String title,
    String subtitle,
    IconData icon, {
    bool enabled = true,
  }) {
    final isSelected = chatProvider.voiceMode == mode;
    return ListTile(
      enabled: enabled,
      contentPadding: EdgeInsets.zero,
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: isSelected
              ? AppTheme.primaryColor.withOpacity(0.2)
              : Colors.grey.withOpacity(0.1),
          shape: BoxShape.circle,
        ),
        child: Icon(
          icon,
          color: enabled
              ? (isSelected ? AppTheme.primaryColor : null)
              : Colors.grey,
        ),
      ),
      title: Text(
        title,
        style: TextStyle(
          color: enabled ? null : Colors.grey,
          fontWeight: isSelected ? FontWeight.bold : null,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(
          fontSize: 12,
          color: enabled ? null : Colors.grey,
        ),
      ),
      trailing: isSelected
          ? const Icon(Iconsax.tick_circle, color: AppTheme.primaryColor)
          : null,
      onTap: enabled
          ? () {
              chatProvider.setVoiceMode(mode);
              Navigator.pop(context);
            }
          : null,
    );
  }

  void _showServerConfigDialog() {
    final settingsProvider = context.read<SettingsProvider>();
    final textController = TextEditingController(
      text: settingsProvider.aiServerUrl ??
          'http://${MqttConfig.localBrokerAddress}:${MqttConfig.n8nPort}/api/agent',
    );

    Future.delayed(Duration.zero, () {
      showDialog(
        context: context,
        builder: (context) {
          final theme = Theme.of(context);
          final isDark = theme.brightness == Brightness.dark;
          final loc = AppLocalizations.of(context);

          return AlertDialog(
            backgroundColor:
                isDark ? AppTheme.darkSurface : AppTheme.lightSurface,
            shape: RoundedRectangleBorder(
              borderRadius: AppTheme.mediumRadius,
            ),
            title: Text(loc.t('configure_server')),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(loc.t('ai_server_url_hint')),
                const SizedBox(height: 16),
                TextField(
                  controller: textController,
                  decoration: InputDecoration(
                    labelText: loc.t('server_url'),
                    hintText: 'http://192.168.1.100:8000',
                    border: OutlineInputBorder(
                      borderRadius: AppTheme.smallRadius,
                    ),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(loc.t('cancel')),
              ),
              ElevatedButton(
                onPressed: () {
                  final url = textController.text.trim();
                  if (url.isNotEmpty) {
                    settingsProvider.setAiServerUrl(url);
                    context.read<AIChatProvider>().setServerUrl(url);
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(loc.t('server_url_updated'))),
                    );
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                ),
                child: Text(loc.t('save')),
              ),
            ],
          );
        },
      );
    });
  }

  void _showClearChatDialog() {
    Future.delayed(Duration.zero, () {
      showDialog(
        context: context,
        builder: (context) {
          final theme = Theme.of(context);
          final isDark = theme.brightness == Brightness.dark;
          final loc = AppLocalizations.of(context);

          return AlertDialog(
            backgroundColor:
                isDark ? AppTheme.darkSurface : AppTheme.lightSurface,
            shape: RoundedRectangleBorder(
              borderRadius: AppTheme.mediumRadius,
            ),
            title: Text(loc.t('clear_chat')),
            content: Text(loc.t('clear_chat_confirm')),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(loc.t('cancel')),
              ),
              ElevatedButton(
                onPressed: () {
                  final authProvider = context.read<AuthProvider>();
                  final chatProvider = context.read<AIChatProvider>();
                  if (authProvider.currentUser != null) {
                    chatProvider.clearMessages(authProvider.currentUser!.uid);
                  }
                  Navigator.pop(context);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                ),
                child: Text(loc.t('clear')),
              ),
            ],
          );
        },
      );
    });
  }

  void _showVoiceSettingsDialog() {
    Future.delayed(Duration.zero, () {
      showDialog(
        context: context,
        builder: (context) {
          final theme = Theme.of(context);
          final isDark = theme.brightness == Brightness.dark;
          final loc = AppLocalizations.of(context);

          return AlertDialog(
            backgroundColor:
                isDark ? AppTheme.darkSurface : AppTheme.lightSurface,
            shape: RoundedRectangleBorder(
              borderRadius: AppTheme.mediumRadius,
            ),
            title: Row(
              children: [
                const Icon(Iconsax.microphone, size: 24),
                const SizedBox(width: 12),
                Text(loc.t('voice_settings')),
              ],
            ),
            content: Consumer<AIChatProvider>(
              builder: (context, chatProvider, _) {
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Voice mode selection
                    Text(
                      loc.t('voice_mode'),
                      style: theme.textTheme.titleSmall,
                    ),
                    const SizedBox(height: 8),
                    _buildVoiceModeOption(
                      context,
                      chatProvider,
                      VoiceMode.textOnly,
                      loc.t('text_only'),
                      loc.t('text_only_desc'),
                      Iconsax.message_text,
                    ),
                    _buildVoiceModeOption(
                      context,
                      chatProvider,
                      VoiceMode.voiceToText,
                      loc.t('voice_to_text'),
                      loc.t('voice_to_text_desc'),
                      Iconsax.voice_square,
                    ),
                    _buildVoiceModeOption(
                      context,
                      chatProvider,
                      VoiceMode.voiceToVoice,
                      loc.t('voice_to_voice'),
                      loc.t('voice_to_voice_desc'),
                      Iconsax.voice_cricle,
                    ),
                    const SizedBox(height: 16),
                    // Service status
                    Text(
                      loc.t('service_status'),
                      style: theme.textTheme.titleSmall,
                    ),
                    const SizedBox(height: 8),
                    _buildServiceStatus(
                      loc.t('tts_service'),
                      chatProvider.isTtsAvailable,
                    ),
                    _buildServiceStatus(
                      loc.t('asr_service'),
                      chatProvider.isAsrAvailable,
                    ),
                    _buildServiceStatus(
                      loc.t('voice_chat_service'),
                      chatProvider.isVoiceChatAvailable,
                    ),
                  ],
                );
              },
            ),
            actions: [
              TextButton(
                onPressed: () {
                  // Refresh service status
                  context.read<AIChatProvider>().refreshBackendStatus();
                },
                child: Text(loc.t('refresh')),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                ),
                child: Text(loc.t('done')),
              ),
            ],
          );
        },
      );
    });
  }

  Widget _buildVoiceModeOption(
    BuildContext context,
    AIChatProvider chatProvider,
    VoiceMode mode,
    String title,
    String subtitle,
    IconData icon,
  ) {
    final isSelected = chatProvider.voiceMode == mode;
    return ListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      leading: Icon(
        icon,
        color: isSelected ? AppTheme.primaryColor : null,
      ),
      title: Text(title),
      subtitle: Text(subtitle, style: const TextStyle(fontSize: 11)),
      trailing: isSelected
          ? const Icon(Iconsax.tick_circle, color: AppTheme.primaryColor)
          : null,
      onTap: () => chatProvider.setVoiceMode(mode),
    );
  }

  Widget _buildServiceStatus(String name, bool isAvailable) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isAvailable ? Colors.green : Colors.red,
            ),
          ),
          const SizedBox(width: 8),
          Text(name),
          const Spacer(),
          Text(
            isAvailable ? '✓' : '✗',
            style: TextStyle(
              color: isAvailable ? Colors.green : Colors.red,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  void _showLlmProviderDialog() {
    Future.delayed(Duration.zero, () {
      final externalUrlController = TextEditingController(
        text: context.read<AIChatProvider>().backendVoiceService.baseUrl,
      );
      final apiKeyController = TextEditingController();

      showDialog(
        context: context,
        builder: (context) {
          final theme = Theme.of(context);
          final isDark = theme.brightness == Brightness.dark;
          final loc = AppLocalizations.of(context);

          return AlertDialog(
            backgroundColor:
                isDark ? AppTheme.darkSurface : AppTheme.lightSurface,
            shape: RoundedRectangleBorder(
              borderRadius: AppTheme.mediumRadius,
            ),
            title: Row(
              children: [
                const Icon(Iconsax.cpu, size: 24),
                const SizedBox(width: 12),
                Text(loc.t('llm_provider')),
              ],
            ),
            content: Consumer<AIChatProvider>(
              builder: (context, chatProvider, _) {
                return SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Provider selection
                      Text(
                        loc.t('select_provider'),
                        style: theme.textTheme.titleSmall,
                      ),
                      const SizedBox(height: 8),
                      _buildProviderOption(
                        context,
                        chatProvider,
                        LlmProvider.n8nLocal,
                        loc.t('n8n_local'),
                        loc.t('n8n_local_desc'),
                        Iconsax.monitor,
                      ),
                      _buildProviderOption(
                        context,
                        chatProvider,
                        LlmProvider.ollamaLocal,
                        loc.t('ollama_local'),
                        loc.t('ollama_local_desc'),
                        Iconsax.cpu_setting,
                      ),
                      _buildProviderOption(
                        context,
                        chatProvider,
                        LlmProvider.externalNgrok,
                        loc.t('external_llm'),
                        loc.t('external_llm_desc'),
                        Iconsax.cloud,
                      ),
                      const SizedBox(height: 16),
                      // External LLM config (if selected)
                      if (chatProvider.llmProvider ==
                          LlmProvider.externalNgrok) ...[
                        Text(
                          loc.t('external_config'),
                          style: theme.textTheme.titleSmall,
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: externalUrlController,
                          decoration: InputDecoration(
                            labelText: loc.t('llm_url'),
                            hintText: 'https://your-ngrok-url.ngrok-free.app',
                            border: OutlineInputBorder(
                              borderRadius: AppTheme.smallRadius,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: apiKeyController,
                          decoration: InputDecoration(
                            labelText: loc.t('api_key'),
                            hintText: 'sec',
                            border: OutlineInputBorder(
                              borderRadius: AppTheme.smallRadius,
                            ),
                          ),
                          obscureText: true,
                        ),
                      ],
                      const SizedBox(height: 16),
                      // Status
                      _buildServiceStatus(
                        loc.t('local_server'),
                        chatProvider.isServerAvailable,
                      ),
                      _buildServiceStatus(
                        loc.t('external_llm'),
                        chatProvider.isExternalLlmAvailable,
                      ),
                    ],
                  ),
                );
              },
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(loc.t('cancel')),
              ),
              ElevatedButton(
                onPressed: () {
                  final chatProvider = context.read<AIChatProvider>();
                  if (chatProvider.llmProvider == LlmProvider.externalNgrok) {
                    chatProvider.configureExternalLlm(
                      url: externalUrlController.text.trim(),
                      apiKey: apiKeyController.text.trim(),
                    );
                  }
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(loc.t('llm_provider_updated'))),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                ),
                child: Text(loc.t('save')),
              ),
            ],
          );
        },
      );
    });
  }

  Widget _buildProviderOption(
    BuildContext context,
    AIChatProvider chatProvider,
    LlmProvider provider,
    String title,
    String subtitle,
    IconData icon,
  ) {
    final isSelected = chatProvider.llmProvider == provider;
    return ListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      leading: Icon(
        icon,
        color: isSelected ? AppTheme.primaryColor : null,
      ),
      title: Text(title),
      subtitle: Text(subtitle, style: const TextStyle(fontSize: 11)),
      trailing: isSelected
          ? const Icon(Iconsax.tick_circle, color: AppTheme.primaryColor)
          : null,
      onTap: () => chatProvider.setLlmProvider(provider),
    );
  }
}

extension GradientExtension on Gradient {
  LinearGradient scale(double factor) {
    if (this is LinearGradient) {
      final linear = this as LinearGradient;
      return LinearGradient(
        colors: linear.colors.map((c) => c.withOpacity(factor)).toList(),
        begin: linear.begin,
        end: linear.end,
      );
    }
    return const LinearGradient(
        colors: [Colors.transparent, Colors.transparent]);
  }
}
