import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:iconsax/iconsax.dart';
import 'package:animate_do/animate_do.dart';
import 'package:intl/intl.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/providers/ai_chat_provider.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/providers/settings_provider.dart';
import '../../../core/models/chat_message_model.dart';
import '../../../core/theme/app_theme.dart';
import '../../widgets/voice_recorder_widget.dart';
import '../../widgets/voice_message_bubble.dart';

class AIChatScreen extends StatefulWidget {
  const AIChatScreen({super.key});

  @override
  State<AIChatScreen> createState() => _AIChatScreenState();
}

class _AIChatScreenState extends State<AIChatScreen>
    with TickerProviderStateMixin {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _focusNode = FocusNode();
  late AnimationController _typingAnimationController;
  bool _showScrollToBottom = false;
  bool _isRecordingVoice = false;
  String _liveTranscription = '';
  int _recordingDuration = 0;

  @override
  void initState() {
    super.initState();
    _typingAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();

    _scrollController.addListener(_onScroll);

    // Listen to text changes to toggle send/voice button
    _messageController.addListener(() {
      setState(() {});
    });

    // Load chat history
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final authProvider = context.read<AuthProvider>();
      final chatProvider = context.read<AIChatProvider>();
      if (authProvider.currentUser != null) {
        chatProvider.loadChatHistory(authProvider.currentUser!.uid);
      }
    });
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

    // Scroll to bottom after sending
    Future.delayed(const Duration(milliseconds: 100), _scrollToBottom);
  }

  Future<void> _startVoiceRecording() async {
    final chatProvider = context.read<AIChatProvider>();
    final voiceService = chatProvider.voiceService;

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
            content:
                Text(AppLocalizations.of(context).t('voice_permission_denied')),
            backgroundColor: Colors.red,
          ),
        );
      }
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
      // Use transcription or a placeholder
      final transcription = _liveTranscription.trim().isNotEmpty
          ? _liveTranscription
          : AppLocalizations.of(context).t('voice_message');

      // Get user ID
      final userId = authProvider.currentUser?.uid ?? 'debug-user';

      // Send voice message
      await chatProvider.sendVoiceMessage(
        result.filePath,
        result.durationMs,
        transcription,
        userId,
      );

      // Scroll to bottom
      Future.delayed(const Duration(milliseconds: 100), _scrollToBottom);
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
                      const Icon(Iconsax.setting_2, size: 20),
                      const SizedBox(width: 12),
                      Text(loc.t('configure_server')),
                    ],
                  ),
                  onTap: () => _showServerConfigDialog(),
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
        ],
      ),
      floatingActionButton: _showScrollToBottom
          ? FadeInUp(
              child: FloatingActionButton(
                mini: true,
                onPressed: _scrollToBottom,
                backgroundColor: AppTheme.primaryColor,
                child: const Icon(Iconsax.arrow_down, color: Colors.white),
              ),
            )
          : null,
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
            child: Column(
              crossAxisAlignment:
                  isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                Container(
                  constraints: BoxConstraints(
                    maxWidth: MediaQuery.of(context).size.width * 0.7,
                  ),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: isUser
                        ? AppTheme.primaryGradient
                        : LinearGradient(
                            colors: isDark
                                ? [
                                    Colors.grey.shade800,
                                    Colors.grey.shade900,
                                  ]
                                : [
                                    Colors.grey.shade100,
                                    Colors.grey.shade200,
                                  ],
                          ),
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(20),
                      topRight: const Radius.circular(20),
                      bottomLeft: Radius.circular(isUser ? 20 : 4),
                      bottomRight: Radius.circular(isUser ? 4 : 20),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: (isUser ? AppTheme.primaryColor : Colors.black)
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
                      : Text(
                          message.content,
                          style: TextStyle(
                            color: isUser ? Colors.white : textColor,
                            fontSize: 15,
                          ),
                        ),
                ),
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
        child: Row(
          children: [
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: isDark ? Colors.grey.shade800 : Colors.grey.shade100,
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
                  decoration: InputDecoration(
                    hintText: loc.t('type_message'),
                    hintStyle: TextStyle(
                      color: textColor.withOpacity(0.5),
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
                  onSubmitted: (_) => _sendMessage(),
                ),
              ),
            ),
            const SizedBox(width: 12),

            // Voice button (if text is empty)
            if (_messageController.text.trim().isEmpty)
              Container(
                decoration: BoxDecoration(
                  gradient: AppTheme.primaryGradient,
                  shape: BoxShape.circle,
                  boxShadow: AppTheme.glowShadow,
                ),
                child: IconButton(
                  icon: const Icon(Iconsax.microphone, color: Colors.white),
                  onPressed: _startVoiceRecording,
                ),
              )
            else
              // Send button (if text is not empty)
              Container(
                decoration: BoxDecoration(
                  gradient: AppTheme.primaryGradient,
                  shape: BoxShape.circle,
                  boxShadow: AppTheme.glowShadow,
                ),
                child: IconButton(
                  icon: const Icon(Iconsax.send_1, color: Colors.white),
                  onPressed: _sendMessage,
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _showServerConfigDialog() {
    final settingsProvider = context.read<SettingsProvider>();
    final textController = TextEditingController(
      text: settingsProvider.aiServerUrl ?? 'http://192.168.1.100:8000',
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
