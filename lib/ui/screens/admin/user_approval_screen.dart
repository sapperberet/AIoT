import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:animate_do/animate_do.dart';
import 'package:iconsax/iconsax.dart';
import 'package:intl/intl.dart';

import '../../../core/providers/auth_provider.dart';
import '../../../core/services/user_approval_service.dart';
import '../../../core/models/access_level.dart';
import '../../../core/localization/app_localizations.dart';

/// Screen for administrators to approve pending user requests
class UserApprovalScreen extends StatefulWidget {
  const UserApprovalScreen({super.key});

  @override
  State<UserApprovalScreen> createState() => _UserApprovalScreenState();
}

class _UserApprovalScreenState extends State<UserApprovalScreen> {
  final UserApprovalService _approvalService = UserApprovalService();
  List<PendingUserRequest> _pendingUsers = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadPendingUsers();
  }

  Future<void> _loadPendingUsers() async {
    setState(() => _isLoading = true);
    final users = await _approvalService.getPendingUsers();
    setState(() {
      _pendingUsers = users;
      _isLoading = false;
    });
  }

  Future<void> _showApprovalDialog(PendingUserRequest user) async {
    final otpController = TextEditingController();
    AccessLevel selectedLevel = AccessLevel.low;

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Row(
            children: [
              CircleAvatar(
                backgroundColor: Colors.orange,
                child: Text(
                  user.displayName[0].toUpperCase(),
                  style: const TextStyle(color: Colors.white),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      user.displayName,
                      style: const TextStyle(fontSize: 18),
                    ),
                    Text(
                      user.email,
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                  ],
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // OTP display
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.blue.withOpacity(0.3)),
                  ),
                  child: Column(
                    children: [
                      const Icon(Iconsax.key, color: Colors.blue, size: 32),
                      const SizedBox(height: 8),
                      const Text(
                        'OTP Code',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            user.otp ?? 'N/A',
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 4,
                            ),
                          ),
                          if (user.otp != null)
                            IconButton(
                              icon: const Icon(Icons.copy, size: 20),
                              onPressed: () {
                                Clipboard.setData(ClipboardData(text: user.otp!));
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('OTP copied to clipboard')),
                                );
                              },
                            ),
                        ],
                      ),
                      if (user.isOtpExpired)
                        Container(
                          margin: const EdgeInsets.only(top: 8),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.red.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Text(
                            'OTP Expired - Generate New',
                            style: TextStyle(color: Colors.red, fontSize: 12),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Request details
                _buildDetailRow('Requested', DateFormat.yMMMd().add_jm().format(user.requestedAt)),
                const SizedBox(height: 16),

                // Enter OTP field
                TextField(
                  controller: otpController,
                  decoration: const InputDecoration(
                    labelText: 'Enter OTP to Verify',
                    hintText: '000000',
                    prefixIcon: Icon(Iconsax.key),
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.number,
                  maxLength: 6,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                ),
                const SizedBox(height: 16),

                // Access level selection
                const Text(
                  'Assign Access Level',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                ...AccessLevel.values
                    .where((level) => level != AccessLevel.pending)
                    .map((level) => RadioListTile<AccessLevel>(
                          title: Text(level.displayName),
                          subtitle: Text(level.description),
                          value: level,
                          groupValue: selectedLevel,
                          onChanged: (value) {
                            setDialogState(() => selectedLevel = value!);
                          },
                        )),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            if (user.isOtpExpired)
              ElevatedButton.icon(
                onPressed: () async {
                  await _approvalService.generateApprovalOtp(user.uid);
                  Navigator.pop(context);
                  _loadPendingUsers();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('New OTP generated and sent to admins'),
                      backgroundColor: Colors.green,
                    ),
                  );
                },
                icon: const Icon(Iconsax.refresh),
                label: const Text('Generate New OTP'),
              ),
            ElevatedButton.icon(
              onPressed: () async {
                if (otpController.text.length != 6) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Please enter a valid 6-digit OTP'),
                      backgroundColor: Colors.red,
                    ),
                  );
                  return;
                }

                final currentUser = context.read<AuthProvider>().currentUser;
                if (currentUser == null) return;

                final success = await _approvalService.verifyOtpAndApproveUser(
                  pendingUserId: user.uid,
                  otp: otpController.text,
                  approvedByUserId: currentUser.uid,
                  assignedLevel: selectedLevel,
                );

                Navigator.pop(context);

                if (success) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('${user.displayName} has been approved as ${selectedLevel.displayName}'),
                      backgroundColor: Colors.green,
                    ),
                  );
                  _loadPendingUsers();
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Failed to approve user. OTP may be invalid or expired.'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
              icon: const Icon(Iconsax.tick_circle),
              label: const Text('Approve'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showRejectDialog(PendingUserRequest user) async {
    final reasonController = TextEditingController();

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reject User Request'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Are you sure you want to reject ${user.displayName}\'s access request?'),
            const SizedBox(height: 16),
            TextField(
              controller: reasonController,
              decoration: const InputDecoration(
                labelText: 'Reason (optional)',
                hintText: 'Enter rejection reason',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton.icon(
            onPressed: () async {
              final currentUser = context.read<AuthProvider>().currentUser;
              if (currentUser == null) return;

              final success = await _approvalService.rejectUser(
                pendingUserId: user.uid,
                rejectedByUserId: currentUser.uid,
                reason: reasonController.text.isNotEmpty ? reasonController.text : null,
              );

              Navigator.pop(context);

              if (success) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('${user.displayName}\'s request has been rejected'),
                    backgroundColor: Colors.orange,
                  ),
                );
                _loadPendingUsers();
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            icon: const Icon(Iconsax.close_circle),
            label: const Text('Reject'),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w500, color: Colors.grey),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final loc = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          loc.translate('user_approval'),
        ),
        actions: [
          IconButton(
            icon: const Icon(Iconsax.refresh),
            onPressed: _loadPendingUsers,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _pendingUsers.isEmpty
              ? Center(
                  child: FadeIn(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Iconsax.tick_circle,
                          size: 64,
                          color: Colors.green.withOpacity(0.5),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          loc.translate('no_pending_users'),
                          style: theme.textTheme.headlineSmall,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'All user requests have been processed',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadPendingUsers,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _pendingUsers.length,
                    itemBuilder: (context, index) {
                      final user = _pendingUsers[index];
                      return FadeInUp(
                        delay: Duration(milliseconds: index * 100),
                        child: Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: Colors.orange,
                              child: Text(
                                user.displayName[0].toUpperCase(),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            title: Text(
                              user.displayName,
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(user.email),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    Icon(
                                      Iconsax.clock,
                                      size: 14,
                                      color: Colors.grey[600],
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      DateFormat.yMMMd().add_jm().format(user.requestedAt),
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey[600],
                                      ),
                                    ),
                                  ],
                                ),
                                if (user.isOtpExpired)
                                  Container(
                                    margin: const EdgeInsets.only(top: 4),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.red.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: const Text(
                                      'OTP Expired',
                                      style: TextStyle(
                                        fontSize: 10,
                                        color: Colors.red,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Iconsax.close_circle, color: Colors.red),
                                  onPressed: () => _showRejectDialog(user),
                                  tooltip: 'Reject',
                                ),
                                IconButton(
                                  icon: const Icon(Iconsax.tick_circle, color: Colors.green),
                                  onPressed: () => _showApprovalDialog(user),
                                  tooltip: 'Approve',
                                ),
                              ],
                            ),
                            isThreeLine: true,
                          ),
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}
