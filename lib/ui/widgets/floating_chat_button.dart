import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:iconsax/iconsax.dart';
import 'package:animate_do/animate_do.dart';
import 'dart:async';
import '../../core/providers/ai_chat_provider.dart';
import '../../core/localization/app_localizations.dart';
import '../../core/theme/app_theme.dart';

/// Floating chat button that appears on the side of screens
/// Shows unread message count and provides quick access to AI chat
class FloatingChatButton extends StatefulWidget {
  const FloatingChatButton({super.key});

  @override
  State<FloatingChatButton> createState() => _FloatingChatButtonState();
}

class _FloatingChatButtonState extends State<FloatingChatButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  bool _isExpanded = false;
  Timer? _collapseTimer;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _collapseTimer?.cancel();
    _pulseController.dispose();
    super.dispose();
  }

  void _startCollapseTimer() {
    _collapseTimer?.cancel();
    _collapseTimer = Timer(const Duration(seconds: 5), () {
      if (mounted) {
        setState(() {
          _isExpanded = false;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);

    return Consumer<AIChatProvider>(
      builder: (context, chatProvider, child) {
        final unreadCount = chatProvider.unreadMessageCount;
        final hasUnread = unreadCount > 0;

        return Positioned(
          right: 16,
          bottom: 20,
          child: GestureDetector(
            onTap: () {
              if (_isExpanded) {
                // Second tap - navigate to chat
                _collapseTimer?.cancel();
                Navigator.pushNamed(context, '/ai-chat');
                chatProvider.markAllAsRead();
                setState(() {
                  _isExpanded = false;
                });
              } else {
                // First tap - expand button
                setState(() {
                  _isExpanded = true;
                });
                _startCollapseTimer();
              }
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
              width: _isExpanded ? 160 : 56,
              height: 56,
              decoration: BoxDecoration(
                gradient: AppTheme.primaryGradient,
                borderRadius: BorderRadius.circular(28),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.primaryColor.withOpacity(0.4),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                  if (hasUnread)
                    BoxShadow(
                      color: Colors.red.withOpacity(0.3),
                      blurRadius: 20,
                      spreadRadius: 2,
                    ),
                ],
              ),
              child: Stack(
                children: [
                  // Main content
                  Center(
                    child: Padding(
                      padding: EdgeInsets.only(left: _isExpanded ? 12 : 0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // Icon
                          AnimatedBuilder(
                            animation: _pulseController,
                            builder: (context, child) {
                              return Transform.scale(
                                scale: hasUnread
                                    ? 1.0 + (_pulseController.value * 0.1)
                                    : 1.0,
                                child: const Icon(
                                  Iconsax.message_programming5,
                                  color: Colors.white,
                                  size: 24,
                                ),
                              );
                            },
                          ),

                          // Text (when expanded)
                          if (_isExpanded) ...[
                            const SizedBox(width: 8),
                            Expanded(
                              child: FadeIn(
                                duration: const Duration(milliseconds: 200),
                                child: Text(
                                  loc.t('chat_with_me'),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),

                  // Unread badge
                  if (hasUnread)
                    Positioned(
                      top: 4,
                      right: 4,
                      child: ElasticIn(
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: Colors.red,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Colors.white,
                              width: 2,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.red.withOpacity(0.5),
                                blurRadius: 8,
                                spreadRadius: 1,
                              ),
                            ],
                          ),
                          constraints: const BoxConstraints(
                            minWidth: 20,
                            minHeight: 20,
                          ),
                          child: Text(
                            unreadCount > 99 ? '99+' : unreadCount.toString(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
