import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:iconsax/iconsax.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/services/firestore_service.dart';
import '../../../core/services/event_log_service.dart';
import '../../../core/models/device_model.dart';

class LogsTab extends StatefulWidget {
  const LogsTab({super.key});

  @override
  State<LogsTab> createState() => _LogsTabState();
}

class _LogsTabState extends State<LogsTab> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _searchQuery = '';
  String? _selectedFilter;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final firestoreService = context.read<FirestoreService>();
    final eventLogService = context.read<EventLogService>();
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    if (authProvider.currentUser == null) {
      return Center(
          child: Text(AppLocalizations.of(context).t('please_login')));
    }

    final userId = authProvider.currentUser!.uid;

    return Column(
      children: [
        // Search bar
        Padding(
          padding: const EdgeInsets.all(16),
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Search events...',
              prefixIcon: const Icon(Iconsax.search_normal),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        _searchController.clear();
                        setState(() => _searchQuery = '');
                      },
                    )
                  : null,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              filled: true,
              fillColor: isDark ? Colors.grey[800] : Colors.grey[100],
            ),
            onChanged: (value) => setState(() => _searchQuery = value),
          ),
        ),

        // Filter chips
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              _buildFilterChip('All', null, icon: Iconsax.category),
              _buildFilterChip('Doors', 'door', icon: Icons.door_front_door),
              _buildFilterChip('Windows', 'window', icon: Icons.window),
              _buildFilterChip('Garage', 'garage', icon: Icons.garage),
              _buildFilterChip('Lights', 'light', icon: Iconsax.lamp_on5),
              _buildFilterChip('Fans', 'fan', icon: Icons.air),
              _buildFilterChip('Buzzer', 'buzzer',
                  icon: Icons.notifications_active),
              _buildFilterChip('Alarms', 'alarm', icon: Iconsax.warning_2),
              _buildFilterChip('People', 'person', icon: Iconsax.user),
            ],
          ),
        ),

        const SizedBox(height: 8),

        // Tab bar
        TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'All Events', icon: Icon(Iconsax.activity)),
            Tab(text: 'Security', icon: Icon(Iconsax.shield_tick)),
            Tab(text: 'Alarms', icon: Icon(Iconsax.warning_2)),
          ],
        ),

        // Tab content
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildEventsTab(context, userId, eventLogService),
              _buildSecurityTab(context, userId, eventLogService),
              _buildAlarmsTab(context, userId, firestoreService),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFilterChip(String label, String? filter, {IconData? icon}) {
    final isSelected = _selectedFilter == filter;
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        avatar: icon != null
            ? Icon(
                icon,
                size: 16,
                color: isSelected
                    ? theme.colorScheme.primary
                    : theme.colorScheme.onSurface.withOpacity(0.6),
              )
            : null,
        label: Text(label),
        selected: isSelected,
        onSelected: (selected) {
          setState(() {
            _selectedFilter = selected ? filter : null;
          });
        },
        selectedColor: theme.colorScheme.primary.withOpacity(0.2),
        checkmarkColor: theme.colorScheme.primary,
      ),
    );
  }

  Widget _buildEventsTab(
      BuildContext context, String userId, EventLogService eventLogService) {
    final theme = Theme.of(context);

    return StreamBuilder<List<EventLog>>(
      stream: eventLogService.getEventsStream(userId, limit: 200),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(
            child: CircularProgressIndicator(
              valueColor:
                  AlwaysStoppedAnimation<Color>(theme.colorScheme.primary),
            ),
          );
        }

        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return _buildEmptyState(context, 'No events logged',
              'Events will appear here as they happen');
        }

        var events = snapshot.data!;

        // Apply search filter
        if (_searchQuery.isNotEmpty) {
          final query = _searchQuery.toLowerCase();
          events = events
              .where((e) =>
                  e.title.toLowerCase().contains(query) ||
                  e.description.toLowerCase().contains(query) ||
                  (e.location?.toLowerCase().contains(query) ?? false))
              .toList();
        }

        // Apply type filter
        if (_selectedFilter != null) {
          events = events
              .where(
                  (e) => e.type.name.toLowerCase().contains(_selectedFilter!))
              .toList();
        }

        return ListView.builder(
          itemCount: events.length,
          padding: const EdgeInsets.all(16),
          itemBuilder: (context, index) {
            final event = events[index];
            return _buildEventCard(context, event);
          },
        );
      },
    );
  }

  Widget _buildSecurityTab(
      BuildContext context, String userId, EventLogService eventLogService) {
    final theme = Theme.of(context);

    return StreamBuilder<List<EventLog>>(
      stream: eventLogService.getSecurityEventsStream(userId, limit: 100),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(
            child: CircularProgressIndicator(
              valueColor:
                  AlwaysStoppedAnimation<Color>(theme.colorScheme.primary),
            ),
          );
        }

        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return _buildEmptyState(context, 'No security events',
              'Door, window, and access events will appear here');
        }

        var events = snapshot.data!;

        // Apply search filter
        if (_searchQuery.isNotEmpty) {
          final query = _searchQuery.toLowerCase();
          events = events
              .where((e) =>
                  e.title.toLowerCase().contains(query) ||
                  e.description.toLowerCase().contains(query))
              .toList();
        }

        return ListView.builder(
          itemCount: events.length,
          padding: const EdgeInsets.all(16),
          itemBuilder: (context, index) {
            final event = events[index];
            return _buildEventCard(context, event);
          },
        );
      },
    );
  }

  Widget _buildAlarmsTab(
      BuildContext context, String userId, FirestoreService firestoreService) {
    final theme = Theme.of(context);

    return StreamBuilder<List<AlarmEvent>>(
      stream: firestoreService.getAlarmsStream(userId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(
            child: CircularProgressIndicator(
              valueColor:
                  AlwaysStoppedAnimation<Color>(theme.colorScheme.primary),
            ),
          );
        }

        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return _buildEmptyState(context, 'No alarms', 'Your home is safe');
        }

        var alarms = snapshot.data!;

        // Apply search filter
        if (_searchQuery.isNotEmpty) {
          final query = _searchQuery.toLowerCase();
          alarms = alarms
              .where((a) =>
                  a.type.toLowerCase().contains(query) ||
                  a.message.toLowerCase().contains(query) ||
                  a.location.toLowerCase().contains(query))
              .toList();
        }

        return ListView.builder(
          itemCount: alarms.length,
          padding: const EdgeInsets.all(16),
          itemBuilder: (context, index) {
            final alarm = alarms[index];
            return _buildAlarmCard(context, alarm);
          },
        );
      },
    );
  }

  Widget _buildEmptyState(BuildContext context, String title, String subtitle) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.check_circle, size: 64, color: Colors.green),
          const SizedBox(height: 16),
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Text(subtitle,
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: Colors.grey)),
        ],
      ),
    );
  }

  Widget _buildEventCard(BuildContext context, EventLog event) {
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: event.isRead ? 1 : 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: CircleAvatar(
          backgroundColor: _getEventColor(event.severity).withOpacity(0.2),
          child: Icon(
            _getEventIcon(event.type),
            color: _getEventColor(event.severity),
          ),
        ),
        title: Text(
          event.title,
          style: TextStyle(
            fontWeight: event.isRead ? FontWeight.normal : FontWeight.bold,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(event.description),
            const SizedBox(height: 4),
            Row(
              children: [
                if (event.location != null) ...[
                  Icon(Iconsax.location, size: 12, color: Colors.grey),
                  const SizedBox(width: 4),
                  Text(event.location!,
                      style: TextStyle(fontSize: 12, color: Colors.grey)),
                  const SizedBox(width: 12),
                ],
                Icon(Iconsax.clock, size: 12, color: Colors.grey),
                const SizedBox(width: 4),
                Text(_formatTimestamp(event.timestamp),
                    style: TextStyle(fontSize: 12, color: Colors.grey)),
              ],
            ),
          ],
        ),
        trailing: !event.isRead
            ? Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary,
                  shape: BoxShape.circle,
                ),
              )
            : null,
      ),
    );
  }

  Widget _buildAlarmCard(BuildContext context, AlarmEvent alarm) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: alarm.acknowledged ? null : Colors.red.shade50,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: CircleAvatar(
          backgroundColor: _getSeverityColor(alarm.severity),
          child: Icon(_getAlarmIcon(alarm.type), color: Colors.white),
        ),
        title: Text(
          '${alarm.type} in ${alarm.location}',
          style: TextStyle(
            fontWeight:
                alarm.acknowledged ? FontWeight.normal : FontWeight.bold,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(alarm.message),
            const SizedBox(height: 4),
            Text(
              _formatTimestamp(alarm.timestamp),
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
        trailing:
            alarm.acknowledged ? Icon(Icons.check, color: Colors.green) : null,
      ),
    );
  }

  Color _getEventColor(EventSeverity severity) {
    switch (severity) {
      case EventSeverity.critical:
        return Colors.red;
      case EventSeverity.warning:
        return Colors.orange;
      case EventSeverity.info:
        return Colors.blue;
    }
  }

  IconData _getEventIcon(EventType type) {
    switch (type) {
      case EventType.doorOpened:
      case EventType.doorClosed:
        return Icons.door_front_door;
      case EventType.windowOpened:
      case EventType.windowClosed:
        return Icons.window;
      case EventType.garageOpened:
      case EventType.garageClosed:
        return Icons.garage;
      case EventType.lightTurnedOn:
      case EventType.lightTurnedOff:
      case EventType.lightBrightnessChanged:
        return Iconsax.lamp_on5;
      case EventType.buzzerActivated:
      case EventType.buzzerDeactivated:
        return Icons.notifications_active;
      case EventType.alarmTriggered:
      case EventType.alarmAcknowledged:
      case EventType.alarmCleared:
        return Iconsax.warning_2;
      case EventType.personRecognized:
      case EventType.personUnrecognized:
      case EventType.accessGranted:
      case EventType.accessDenied:
        return Iconsax.user;
      default:
        return Iconsax.activity;
    }
  }

  Color _getSeverityColor(String severity) {
    switch (severity) {
      case 'critical':
        return Colors.red;
      case 'warning':
        return Colors.orange;
      case 'info':
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }

  IconData _getAlarmIcon(String type) {
    if (type.contains('fire')) return Icons.local_fire_department;
    if (type.contains('motion')) return Icons.directions_walk;
    if (type.contains('door')) return Icons.door_front_door;
    return Icons.warning;
  }

  String _formatTimestamp(DateTime time) {
    final now = DateTime.now();
    final difference = now.difference(time);

    if (difference.inSeconds < 60) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes} minutes ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours} hours ago';
    } else if (difference.inDays == 1) {
      return 'Yesterday at ${time.hour}:${time.minute.toString().padLeft(2, '0')}';
    } else {
      return '${time.day}/${time.month}/${time.year} at ${time.hour}:${time.minute.toString().padLeft(2, '0')}';
    }
  }
}
