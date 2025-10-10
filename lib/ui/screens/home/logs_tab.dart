import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/services/firestore_service.dart';
import '../../../core/models/device_model.dart';

class LogsTab extends StatelessWidget {
  const LogsTab({super.key});

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final firestoreService = context.read<FirestoreService>();

    if (authProvider.currentUser == null) {
      return Center(
          child: Text(AppLocalizations.of(context).t('please_login')));
    }

    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          const TabBar(
            tabs: [
              Tab(text: 'Alarms'),
              Tab(text: 'Events'),
            ],
          ),
          Expanded(
            child: TabBarView(
              children: [
                _buildAlarmsLog(
                    context, authProvider.currentUser!.uid, firestoreService),
                _buildEventsLog(
                    context, authProvider.currentUser!.uid, firestoreService),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAlarmsLog(
      BuildContext context, String userId, FirestoreService firestoreService) {
    final theme = Theme.of(context);

    return StreamBuilder<List<AlarmEvent>>(
      stream: firestoreService.getAlarmsStream(userId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(
                theme.colorScheme.primary,
              ),
            ),
          );
        }

        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.check_circle, size: 64, color: Colors.green),
                const SizedBox(height: 16),
                Text(
                  'No alarms',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                Text(
                  'Your home is safe',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
          );
        }

        final alarms = snapshot.data!;

        return ListView.builder(
          itemCount: alarms.length,
          itemBuilder: (context, index) {
            final alarm = alarms[index];
            return Card(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: alarm.acknowledged ? null : Colors.red.shade50,
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: _getSeverityColor(alarm.severity),
                  child: Icon(
                    _getAlarmIcon(alarm.type),
                    color: Colors.white,
                  ),
                ),
                title: Text(
                  '${alarm.type} in ${alarm.location}',
                  style: TextStyle(
                    fontWeight: alarm.acknowledged
                        ? FontWeight.normal
                        : FontWeight.bold,
                  ),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(alarm.message),
                    Text(
                      _formatTimestamp(alarm.timestamp),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
                trailing: alarm.acknowledged
                    ? Icon(Icons.check, color: Colors.green)
                    : null,
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildEventsLog(
      BuildContext context, String userId, FirestoreService firestoreService) {
    final theme = Theme.of(context);

    return StreamBuilder<QuerySnapshot>(
      stream: firestoreService.getLogsStream(userId, limit: 100),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(
                theme.colorScheme.primary,
              ),
            ),
          );
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(
            child: Text(
              'No events logged',
              style: Theme.of(context).textTheme.titleMedium,
            ),
          );
        }

        final logs = snapshot.data!.docs;

        return ListView.builder(
          itemCount: logs.length,
          itemBuilder: (context, index) {
            final log = logs[index].data() as Map<String, dynamic>;
            final event = log['event'] as String;
            final data = log['data'] as Map<String, dynamic>? ?? {};
            final timestamp =
                (log['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now();

            return ListTile(
              dense: true,
              leading: Icon(Icons.circle, size: 8),
              title: Text(event),
              subtitle: Text(
                '${_formatTimestamp(timestamp)}\n${data.entries.map((e) => '${e.key}: ${e.value}').join(', ')}',
              ),
            );
          },
        );
      },
    );
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
