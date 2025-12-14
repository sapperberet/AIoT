import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/services/user_activity_service.dart';

class UserActivityNotificationWidget extends StatefulWidget {
  final VoidCallback? onViewUsers;

  const UserActivityNotificationWidget({
    super.key,
    this.onViewUsers,
  });

  @override
  State<UserActivityNotificationWidget> createState() =>
      _UserActivityNotificationWidgetState();
}

class _UserActivityNotificationWidgetState
    extends State<UserActivityNotificationWidget> {
  final UserActivityService _activityService = UserActivityService();
  int _newUserCount = 0;

  @override
  void initState() {
    super.initState();
    _startListening();
  }

  void _startListening() {
    _activityService.watchNewUserSignIns().listen((snapshot) {
      if (mounted) {
        final activities = snapshot.docs.map((doc) {
          return {
            'id': doc.id,
            ...doc.data() as Map<String, dynamic>,
          };
        }).toList();

        setState(() {
          _newUserCount = activities.length;
        });

        // Show snackbar for new user sign-ins
        if (activities.isNotEmpty) {
          _showNewUserNotification(activities);
        }
      }
    });
  }

  void _showNewUserNotification(List<Map<String, dynamic>> activitiesList) {
    final latestActivity = activitiesList.first;
    final userEmail = latestActivity['email'] ?? 'Unknown user';
    final timestamp = latestActivity['timestamp'];
    DateTime? signInTime;

    if (timestamp is Timestamp) {
      signInTime = timestamp.toDate();
    } else if (timestamp is DateTime) {
      signInTime = timestamp;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Iconsax.user_add, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'New User Signed In',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Text(
                    userEmail,
                    style: const TextStyle(fontSize: 12),
                  ),
                  if (signInTime != null)
                    Text(
                      DateFormat.jm().format(signInTime),
                      style: const TextStyle(fontSize: 10),
                    ),
                ],
              ),
            ),
          ],
        ),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 5),
        action: SnackBarAction(
          label: 'View',
          textColor: Colors.white,
          onPressed: () {
            if (widget.onViewUsers != null) {
              widget.onViewUsers!();
            }
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_newUserCount == 0) {
      return const SizedBox.shrink();
    }

    return Stack(
      children: [
        IconButton(
          icon: const Icon(Iconsax.notification),
          onPressed: widget.onViewUsers,
        ),
        Positioned(
          right: 8,
          top: 8,
          child: Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: Colors.red,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2),
            ),
            constraints: const BoxConstraints(
              minWidth: 18,
              minHeight: 18,
            ),
            child: Center(
              child: Text(
                _newUserCount > 99 ? '99+' : '$_newUserCount',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
