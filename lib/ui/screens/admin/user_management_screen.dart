import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:animate_do/animate_do.dart';
import 'package:iconsax/iconsax.dart';
import 'package:intl/intl.dart';

import '../../../core/providers/auth_provider.dart';
import '../../../core/services/user_management_service.dart';
import '../../../core/services/user_approval_service.dart';
import '../../../core/localization/app_localizations.dart';

class UserManagementScreen extends StatefulWidget {
  const UserManagementScreen({super.key});

  @override
  State<UserManagementScreen> createState() => _UserManagementScreenState();
}

class _UserManagementScreenState extends State<UserManagementScreen> {
  final UserManagementService _managementService = UserManagementService();
  final UserApprovalService _approvalService = UserApprovalService();
  List<UserAccount> _users = [];
  List<UserAccount> _filteredUsers = [];
  bool _isLoading = true;
  String _searchQuery = '';
  String _filterType = 'all'; // all, new, pending, suspicious, banned, admin
  int _pendingApprovalCount = 0;

  @override
  void initState() {
    super.initState();
    _loadUsers();
    _loadPendingApprovalCount();
  }

  Future<void> _loadPendingApprovalCount() async {
    _approvalService.watchPendingUsers().listen((pending) {
      if (mounted) {
        setState(() {
          _pendingApprovalCount = pending.length;
        });
      }
    });
  }

  Future<void> _loadUsers() async {
    setState(() => _isLoading = true);

    final users = await _managementService.getAllUsers();

    setState(() {
      _users = users;
      _applyFilters();
      _isLoading = false;
    });
  }

  void _applyFilters() {
    var filtered = _users;

    // Apply type filter
    switch (_filterType) {
      case 'new':
        filtered = filtered.where((u) => u.isNewUser).toList();
        break;
      case 'pending':
        filtered = filtered.where((u) => !u.isApproved).toList();
        break;
      case 'suspicious':
        filtered = filtered.where((u) => u.isSuspicious).toList();
        break;
      case 'banned':
        filtered = filtered.where((u) => u.isBanned).toList();
        break;
      case 'admin':
        filtered = filtered.where((u) => u.isAdmin).toList();
        break;
    }

    // Apply search query
    if (_searchQuery.isNotEmpty) {
      filtered = filtered.where((user) {
        final query = _searchQuery.toLowerCase();
        return user.email.toLowerCase().contains(query) ||
            user.displayName.toLowerCase().contains(query) ||
            user.uid.toLowerCase().contains(query);
      }).toList();
    }

    setState(() => _filteredUsers = filtered);
  }

  Future<void> _showUserDetailsDialog(UserAccount user) async {
    final currentUser = context.read<AuthProvider>().currentUser;
    final isCurrentUser = currentUser?.uid == user.uid;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            CircleAvatar(
              backgroundColor: user.isAdmin
                  ? Colors.purple
                  : user.isBanned
                      ? Colors.red
                      : Colors.blue,
              child: Icon(
                user.isAdmin ? Iconsax.shield_tick : Iconsax.user,
                color: Colors.white,
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
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
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
              _buildDetailRow('User ID', user.uid),
              _buildDetailRow('Created',
                  DateFormat.yMMMd().add_jm().format(user.createdAt)),
              if (user.lastSignIn != null)
                _buildDetailRow('Last Sign In',
                    DateFormat.yMMMd().add_jm().format(user.lastSignIn!)),
              if (user.lastSignInDevice != null)
                _buildDetailRow('Device', user.lastSignInDevice!),
              _buildDetailRow('Sign In Count', '${user.signInCount}'),
              if (user.isNewUser) _buildBadge('🆕 New User', Colors.green),
              if (user.isSuspicious)
                _buildBadge('⚠️ Suspicious Activity', Colors.orange),
              if (user.isBanned) _buildBadge('🚫 Banned', Colors.red),
              if (user.isAdmin) _buildBadge('👑 Administrator', Colors.purple),
              if (user.isBanned && user.banReason != null) ...[
                const SizedBox(height: 16),
                const Text(
                  'Ban Reason:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                Text(user.banReason!),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
          if (!isCurrentUser) ...[
            if (!user.isBanned)
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  _kickUser(user);
                },
                style: TextButton.styleFrom(foregroundColor: Colors.orange),
                child: const Text('Kick'),
              ),
            if (user.isBanned)
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  _unbanUser(user);
                },
                style: TextButton.styleFrom(foregroundColor: Colors.green),
                child: const Text('Unban'),
              )
            else
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  _banUser(user);
                },
                style: TextButton.styleFrom(foregroundColor: Colors.red),
                child: const Text('Ban'),
              ),
          ],
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
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(color: Colors.grey[700]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBadge(String text, Color color) {
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.bold,
          fontSize: 12,
        ),
      ),
    );
  }

  Future<void> _kickUser(UserAccount user) async {
    final confirmed = await _showConfirmDialog(
      'Kick User',
      'Are you sure you want to kick ${user.displayName}? They will be forced to log out.',
    );

    if (confirmed == true && mounted) {
      final authProvider = context.read<AuthProvider>();
      final currentUserId = authProvider.currentUser?.uid;

      if (currentUserId != null) {
        final success = await _managementService.kickUser(
          userId: user.uid,
          kickedByUserId: currentUserId,
          reason: 'Kicked by admin',
        );

        if (success && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${user.displayName} has been kicked'),
              backgroundColor: Colors.orange,
            ),
          );
          _loadUsers();
        }
      }
    }
  }

  Future<void> _banUser(UserAccount user) async {
    final TextEditingController reasonController = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Ban User'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Are you sure you want to ban ${user.displayName}?'),
            const SizedBox(height: 16),
            TextField(
              controller: reasonController,
              decoration: const InputDecoration(
                labelText: 'Reason',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Ban'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      final authProvider = context.read<AuthProvider>();
      final currentUserId = authProvider.currentUser?.uid;

      if (currentUserId != null) {
        final success = await _managementService.banUser(
          userId: user.uid,
          bannedByUserId: currentUserId,
          reason: reasonController.text.isNotEmpty
              ? reasonController.text
              : 'Banned by admin',
        );

        if (success && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${user.displayName} has been banned'),
              backgroundColor: Colors.red,
            ),
          );
          _loadUsers();
        }
      }
    }
  }

  Future<void> _unbanUser(UserAccount user) async {
    final confirmed = await _showConfirmDialog(
      'Unban User',
      'Are you sure you want to unban ${user.displayName}?',
    );

    if (confirmed == true && mounted) {
      final authProvider = context.read<AuthProvider>();
      final currentUserId = authProvider.currentUser?.uid;

      if (currentUserId != null) {
        final success = await _managementService.unbanUser(
          userId: user.uid,
          unbannedByUserId: currentUserId,
        );

        if (success && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${user.displayName} has been unbanned'),
              backgroundColor: Colors.green,
            ),
          );
          _loadUsers();
        }
      }
    }
  }

  Future<bool?> _showConfirmDialog(String title, String message) {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Confirm'),
          ),
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
        title: Text(loc.translate('user_management')),
        actions: [
          // Pending Approvals Button with Badge
          Stack(
            children: [
              IconButton(
                icon: const Icon(Iconsax.user_tick),
                onPressed: () {
                  Navigator.pushNamed(context, '/user-approval');
                },
                tooltip: loc.translate('pending_approvals'),
              ),
              if (_pendingApprovalCount > 0)
                Positioned(
                  right: 6,
                  top: 6,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.red,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    constraints: const BoxConstraints(
                      minWidth: 18,
                      minHeight: 18,
                    ),
                    child: Text(
                      '$_pendingApprovalCount',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
            ],
          ),
          IconButton(
            icon: const Icon(Iconsax.refresh),
            onPressed: _loadUsers,
            tooltip: loc.translate('refresh'),
          ),
        ],
      ),
      body: Column(
        children: [
          // Search and Filter Bar
          Container(
            padding: const EdgeInsets.all(16),
            color: theme.primaryColor.withOpacity(0.1),
            child: Column(
              children: [
                // Search
                TextField(
                  decoration: InputDecoration(
                    hintText: loc.translate('search_users'),
                    prefixIcon: const Icon(Iconsax.search_normal),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    filled: true,
                    fillColor: Colors.white,
                  ),
                  onChanged: (value) {
                    setState(() {
                      _searchQuery = value;
                      _applyFilters();
                    });
                  },
                ),

                const SizedBox(height: 12),

                // Filter Chips
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildFilterChip('all', loc.translate('all')),
                      _buildFilterChip('new', loc.translate('new_users')),
                      _buildFilterChip('pending', loc.translate('pending')),
                      _buildFilterChip(
                          'suspicious', loc.translate('suspicious')),
                      _buildFilterChip('banned', loc.translate('banned')),
                      _buildFilterChip('admin', loc.translate('admins')),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // User List
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredUsers.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Iconsax.user,
                              size: 64,
                              color: Colors.grey[400],
                            ),
                            const SizedBox(height: 16),
                            Text(
                              loc.translate('no_users_found'),
                              style: TextStyle(
                                fontSize: 18,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _loadUsers,
                        child: ListView.builder(
                          itemCount: _filteredUsers.length,
                          padding: const EdgeInsets.all(8),
                          itemBuilder: (context, index) {
                            final user = _filteredUsers[index];
                            return FadeInUp(
                              delay: Duration(milliseconds: index * 50),
                              duration: const Duration(milliseconds: 400),
                              child: _buildUserCard(user),
                            );
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String type, String label) {
    final isSelected = _filterType == type;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(label),
        selected: isSelected,
        onSelected: (selected) {
          setState(() {
            _filterType = type;
            _applyFilters();
          });
        },
      ),
    );
  }

  Widget _buildUserCard(UserAccount user) {
    final currentUser = context.read<AuthProvider>().currentUser;
    final isCurrentUser = currentUser?.uid == user.uid;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: user.isAdmin
              ? Colors.purple
              : user.isBanned
                  ? Colors.red
                  : user.isSuspicious
                      ? Colors.orange
                      : Colors.blue,
          child: Icon(
            user.isAdmin ? Iconsax.shield_tick : Iconsax.user,
            color: Colors.white,
          ),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                user.displayName,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            if (isCurrentUser)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.blue,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  'You',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(user.email),
            const SizedBox(height: 4),
            Row(
              children: [
                if (user.isNewUser) ...[
                  const Icon(Icons.new_releases, size: 14, color: Colors.green),
                  const SizedBox(width: 4),
                  const Text('New', style: TextStyle(fontSize: 12)),
                  const SizedBox(width: 8),
                ],
                if (user.isSuspicious) ...[
                  const Icon(Icons.warning, size: 14, color: Colors.orange),
                  const SizedBox(width: 4),
                  const Text('Suspicious', style: TextStyle(fontSize: 12)),
                  const SizedBox(width: 8),
                ],
                if (user.isBanned) ...[
                  const Icon(Icons.block, size: 14, color: Colors.red),
                  const SizedBox(width: 4),
                  const Text('Banned', style: TextStyle(fontSize: 12)),
                ],
                if (user.isAdmin) ...[
                  const Icon(Iconsax.crown, size: 14, color: Colors.purple),
                  const SizedBox(width: 4),
                  const Text('Admin', style: TextStyle(fontSize: 12)),
                ],
              ],
            ),
          ],
        ),
        trailing: const Icon(Iconsax.arrow_right_3),
        onTap: () => _showUserDetailsDialog(user),
      ),
    );
  }
}
