import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:iconsax/iconsax.dart';
import 'package:animate_do/animate_do.dart';
import 'package:intl/intl.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/services/notification_service.dart';
import '../../../core/theme/app_theme.dart';
import '../camera/camera_feed_screen.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  NotificationType? _selectedFilter;

  @override
  Widget build(BuildContext context) {
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
          child: ShaderMask(
            shaderCallback: (bounds) =>
                AppTheme.primaryGradient.createShader(bounds),
            child: Text(
              AppLocalizations.of(context).t('notifications'),
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
        ),
        actions: [
          FadeInRight(
            child: PopupMenuButton<String>(
              icon: Icon(Iconsax.more, color: textColor),
              color: isDark ? AppTheme.darkCard : AppTheme.lightSurface,
              itemBuilder: (context) => [
                PopupMenuItem(
                  value: 'mark_all_read',
                  child: Row(
                    children: [
                      const Icon(Iconsax.tick_circle,
                          color: AppTheme.primaryColor, size: 20),
                      const SizedBox(width: 12),
                      Text(AppLocalizations.of(context).t('mark_all_read'),
                          style: TextStyle(color: textColor)),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'clear_all',
                  child: Row(
                    children: [
                      const Icon(Iconsax.trash,
                          color: AppTheme.errorColor, size: 20),
                      const SizedBox(width: 12),
                      Text(AppLocalizations.of(context).t('clear_all'),
                          style: TextStyle(color: textColor)),
                    ],
                  ),
                ),
              ],
              onSelected: (value) {
                final notificationService = context.read<NotificationService>();
                if (value == 'mark_all_read') {
                  notificationService.markAllAsRead();
                } else if (value == 'clear_all') {
                  _showClearAllDialog(context, notificationService);
                }
              },
            ),
          ),
        ],
      ),
      body: FadeIn(
        child: Column(
          children: [
            // Filter chips
            _buildFilterChips(),
            const SizedBox(height: 16),

            // Notifications list
            Expanded(
              child: Consumer<NotificationService>(
                builder: (context, notificationService, child) {
                  final notifications = _selectedFilter == null
                      ? notificationService.notifications
                      : notificationService
                          .getNotificationsByType(_selectedFilter!);

                  if (notifications.isEmpty) {
                    return _buildEmptyState();
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    itemCount: notifications.length,
                    itemBuilder: (context, index) {
                      final notification = notifications[index];
                      return FadeInUp(
                        delay: Duration(milliseconds: 50 * index),
                        child: _buildNotificationCard(context, notification),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChips() {
    final loc = AppLocalizations.of(context);
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          _buildFilterChip(loc.t('all'), null),
          const SizedBox(width: 8),
          _buildFilterChip(
              loc.t('device_status'), NotificationType.deviceStatus),
          const SizedBox(width: 8),
          _buildFilterChip(loc.t('automation'), NotificationType.automation),
          const SizedBox(width: 8),
          _buildFilterChip(loc.t('security'), NotificationType.security),
          const SizedBox(width: 8),
          _buildFilterChip(loc.t('info'), NotificationType.info),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, NotificationType? type) {
    final isSelected = _selectedFilter == type;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final textColor = theme.colorScheme.onBackground;

    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedFilter = type;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          gradient: isSelected ? AppTheme.primaryGradient : null,
          color: isSelected
              ? null
              : (isDark ? AppTheme.darkCard : AppTheme.lightSurface),
          borderRadius: AppTheme.mediumRadius,
          border: Border.all(
            color:
                isSelected ? AppTheme.primaryColor : textColor.withOpacity(0.1),
            width: 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
            color: isSelected ? Colors.white : textColor.withOpacity(0.6),
          ),
        ),
      ),
    );
  }

  Widget _buildNotificationCard(
      BuildContext context, AppNotification notification) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final textColor = theme.colorScheme.onBackground;

    return Dismissible(
      key: Key(notification.id),
      direction: DismissDirection.endToStart,
      onDismissed: (direction) {
        context.read<NotificationService>().deleteNotification(notification.id);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Notification deleted'),
            backgroundColor: isDark ? AppTheme.darkCard : AppTheme.lightSurface,
            behavior: SnackBarBehavior.floating,
            action: SnackBarAction(
              label: 'Undo',
              textColor: AppTheme.primaryColor,
              onPressed: () {
                // TODO: Implement undo functionality
              },
            ),
          ),
        );
      },
      background: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              AppTheme.errorColor.withOpacity(0.8),
              AppTheme.errorColor,
            ],
          ),
          borderRadius: AppTheme.largeRadius,
        ),
        alignment: Alignment.centerRight,
        child: const Icon(Iconsax.trash, color: Colors.white),
      ),
      child: GestureDetector(
        onTap: () {
          context.read<NotificationService>().markAsRead(notification.id);
          _showNotificationDetails(context, notification);
        },
        child: Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: notification.isRead
                ? (isDark
                    ? AppTheme.cardGradient
                    : LinearGradient(
                        colors: [
                          AppTheme.lightSurface,
                          AppTheme.lightSurface.withOpacity(0.8),
                        ],
                      ))
                : LinearGradient(
                    colors: [
                      AppTheme.primaryColor.withOpacity(0.1),
                      isDark ? AppTheme.darkCard : AppTheme.lightSurface,
                    ],
                  ),
            borderRadius: AppTheme.largeRadius,
            border: Border.all(
              color: notification.isRead
                  ? textColor.withOpacity(0.1)
                  : AppTheme.primaryColor.withOpacity(0.3),
              width: 1,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Icon
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  gradient: _getNotificationGradient(notification.type),
                  borderRadius: AppTheme.smallRadius,
                ),
                child: Icon(
                  _getNotificationIcon(notification.type),
                  size: 24,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 16),

              // Content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            notification.title,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: notification.isRead
                                  ? FontWeight.w500
                                  : FontWeight.bold,
                              color: textColor,
                            ),
                          ),
                        ),
                        if (!notification.isRead)
                          Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              color: AppTheme.primaryColor,
                              shape: BoxShape.circle,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      notification.message,
                      style: TextStyle(
                        fontSize: 14,
                        color: textColor.withOpacity(0.7),
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(
                          Iconsax.clock,
                          size: 14,
                          color: textColor.withOpacity(0.5),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          _formatTimestamp(notification.timestamp),
                          style: TextStyle(
                            fontSize: 12,
                            color: textColor.withOpacity(0.5),
                          ),
                        ),
                        if (notification.priority ==
                            NotificationPriority.urgent) ...[
                          const SizedBox(width: 12),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppTheme.errorColor.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Text(
                              'URGENT',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.errorColor,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    final theme = Theme.of(context);
    final textColor = theme.colorScheme.onBackground;

    return Center(
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
                Iconsax.notification,
                size: 80,
                color: AppTheme.primaryColor,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'No notifications',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: textColor,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'You\'re all caught up!',
              style: TextStyle(
                fontSize: 14,
                color: textColor.withOpacity(0.6),
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _getNotificationIcon(NotificationType type) {
    switch (type) {
      case NotificationType.deviceStatus:
        return Iconsax.status;
      case NotificationType.automation:
        return Iconsax.timer;
      case NotificationType.security:
        return Iconsax.shield_tick;
      case NotificationType.info:
        return Iconsax.info_circle;
    }
  }

  LinearGradient _getNotificationGradient(NotificationType type) {
    switch (type) {
      case NotificationType.deviceStatus:
        return LinearGradient(
          colors: [
            Colors.blue.shade400,
            Colors.blue.shade600,
          ],
        );
      case NotificationType.automation:
        return LinearGradient(
          colors: [
            Colors.purple.shade400,
            Colors.purple.shade600,
          ],
        );
      case NotificationType.security:
        return LinearGradient(
          colors: [
            AppTheme.errorColor,
            Colors.red.shade700,
          ],
        );
      case NotificationType.info:
        return AppTheme.primaryGradient;
    }
  }

  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      return DateFormat('MMM d, yyyy').format(timestamp);
    }
  }

  void _showNotificationDetails(
      BuildContext context, AppNotification notification) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final textColor = theme.colorScheme.onBackground;
    
    // Check if this is an unrecognized face notification
    final isUnrecognizedFace = notification.data?['type'] == 'unrecognized_face';

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          gradient: isDark
              ? AppTheme.cardGradient
              : LinearGradient(
                  colors: [
                    AppTheme.lightSurface,
                    AppTheme.lightSurface.withOpacity(0.8),
                  ],
                ),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    gradient: _getNotificationGradient(notification.type),
                    borderRadius: AppTheme.smallRadius,
                  ),
                  child: Icon(
                    _getNotificationIcon(notification.type),
                    size: 28,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    notification.title,
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: textColor,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              notification.message,
              style: TextStyle(
                fontSize: 16,
                color: textColor.withOpacity(0.8),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Icon(
                  Iconsax.clock,
                  size: 16,
                  color: AppTheme.lightText.withOpacity(0.5),
                ),
                const SizedBox(width: 8),
                Text(
                  DateFormat('MMM d, yyyy - HH:mm')
                      .format(notification.timestamp),
                  style: TextStyle(
                    fontSize: 14,
                    color: AppTheme.lightText.withOpacity(0.5),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            
            // Show camera button for unrecognized face notifications
            if (isUnrecognizedFace)
              Column(
                children: [
                  ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(context); // Close bottom sheet
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const CameraFeedScreen(),
                        ),
                      );
                    },
                    icon: const Icon(Iconsax.video),
                    label: const Text('View Camera Feed'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.errorColor,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(double.infinity, 50),
                      shape: RoundedRectangleBorder(
                        borderRadius: AppTheme.mediumRadius,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
              ),
            
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: isUnrecognizedFace 
                    ? theme.colorScheme.surface 
                    : AppTheme.primaryColor,
                foregroundColor: isUnrecognizedFace 
                    ? textColor 
                    : Colors.white,
                minimumSize: const Size(double.infinity, 50),
                shape: RoundedRectangleBorder(
                  borderRadius: AppTheme.mediumRadius,
                ),
              ),
              child: const Text('Close'),
            ),
          ],
        ),
      ),
    );
  }

  void _showClearAllDialog(BuildContext context, NotificationService service) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.darkCard,
        title: const Text('Clear All Notifications',
            style: TextStyle(color: AppTheme.lightText)),
        content: const Text(
          'Are you sure you want to clear all notifications? This action cannot be undone.',
          style: TextStyle(color: AppTheme.lightText),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              service.clearAll();
              Navigator.pop(context);
            },
            child: const Text('Clear All',
                style: TextStyle(color: AppTheme.errorColor)),
          ),
        ],
      ),
    );
  }
}
