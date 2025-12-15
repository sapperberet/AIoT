import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:iconsax/iconsax.dart';
import 'package:animate_do/animate_do.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/providers/settings_provider.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/services/session_service.dart';
import '../../../core/services/biometric_service.dart';
import '../../../core/services/email_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  int _sessionDuration = 2; // Default value
  final BiometricService _biometricService = BiometricService();
  bool _isBiometricAvailable = false;
  String _biometricTypeName = 'Biometric';

  // Email/SMTP configuration
  bool _isEmailConfigured = false;
  String? _configuredEmail;

  @override
  void initState() {
    super.initState();
    _loadSessionDuration();
    _checkBiometricAvailability();
    _loadEmailConfig();
  }

  Future<void> _loadEmailConfig() async {
    final isConfigured = await EmailService.isConfigured();
    final email = await EmailService.getConfiguredEmail();
    setState(() {
      _isEmailConfigured = isConfigured;
      _configuredEmail = email;
    });
  }

  Future<void> _loadSessionDuration() async {
    final duration = await SessionService.getSessionDuration();
    setState(() {
      _sessionDuration = duration;
    });
  }

  Future<void> _checkBiometricAvailability() async {
    final isAvailable = await _biometricService.isBiometricAvailable();
    final typeName = await _biometricService.getBiometricTypeName();
    setState(() {
      _isBiometricAvailable = isAvailable;
      _biometricTypeName = typeName;
    });
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final theme = Theme.of(context);
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
              loc.t('settings'),
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
        ),
      ),
      body: FadeIn(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Profile Section
              _buildProfileSection(context),
              const SizedBox(height: 24),

              // Authentication Section
              _buildAuthenticationSection(context),
              const SizedBox(height: 24),

              // User Management Section (Admin Only)
              _buildUserManagementSection(context),
              const SizedBox(height: 24),

              // Email Configuration Section (Admin Only)
              _buildEmailConfigSection(context),
              const SizedBox(height: 24),

              // Connection Mode Section
              _buildConnectionModeSection(context),
              const SizedBox(height: 24),

              // Appearance Section
              _buildAppearanceSection(context),
              const SizedBox(height: 24),

              // Notifications Section
              _buildNotificationsSection(context),
              const SizedBox(height: 24),

              // App Preferences Section
              _buildAppPreferencesSection(context),
              const SizedBox(height: 24),

              // Account Section
              _buildAccountSection(context),
              const SizedBox(height: 24),

              // About Section
              _buildAboutSection(context),
              const SizedBox(height: 100),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProfileSection(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final user = authProvider.currentUser;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final textColor = theme.colorScheme.onBackground;

    return FadeInUp(
      delay: const Duration(milliseconds: 100),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: isDark
              ? AppTheme.cardGradient
              : LinearGradient(
                  colors: [
                    AppTheme.lightSurface,
                    AppTheme.lightSurface.withOpacity(0.8),
                  ],
                ),
          borderRadius: AppTheme.largeRadius,
          border: Border.all(
            color: AppTheme.primaryColor.withOpacity(0.3),
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 70,
              height: 70,
              decoration: BoxDecoration(
                gradient: AppTheme.primaryGradient,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.primaryColor.withOpacity(0.3),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: const Icon(
                Iconsax.user,
                size: 35,
                color: Colors.white,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    user?.displayName ?? 'User',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: textColor,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    user?.email ?? '',
                    style: TextStyle(
                      fontSize: 14,
                      color: textColor.withOpacity(0.6),
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(
                Iconsax.edit,
                color: AppTheme.primaryColor,
              ),
              onPressed: () => _editProfile(context),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAuthenticationSection(BuildContext context) {
    final settingsProvider = context.watch<SettingsProvider>();
    final theme = Theme.of(context);
    final textColor = theme.colorScheme.onBackground;
    final loc = AppLocalizations.of(context);

    return FadeInUp(
      delay: const Duration(milliseconds: 150),
      child: _buildSection(
        'Authentication',
        [
          // Info text about 2FA vs New User Approval
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withOpacity(0.1),
              borderRadius: AppTheme.smallRadius,
              border: Border.all(
                color: AppTheme.primaryColor.withOpacity(0.3),
                width: 1,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Iconsax.shield_tick,
                  color: AppTheme.primaryColor,
                  size: 20,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Two-Factor Authentication (2FA) sends a one-time password (OTP) to your email for additional security when signing in.',
                    style: TextStyle(
                      fontSize: 13,
                      color: textColor.withOpacity(0.8),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          // Clarification about New User Approval
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.orange.withOpacity(0.1),
              borderRadius: AppTheme.smallRadius,
              border: Border.all(
                color: Colors.orange.withOpacity(0.3),
                width: 1,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Iconsax.info_circle,
                  color: Colors.orange,
                  size: 20,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Note: New User Approval (first-time registration OTP) is DIFFERENT from 2FA. New users must be approved by an admin or enter the OTP sent during registration.',
                    style: TextStyle(
                      fontSize: 12,
                      color: textColor.withOpacity(0.7),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Enable 2FA (OTP) Toggle
          _buildSwitchTile(
            'Enable Two-Factor Authentication (OTP)',
            settingsProvider.enableEmailPasswordAuth,
            (value) => settingsProvider.toggleEmailPasswordAuth(value),
            icon: Iconsax.sms_tracking,
          ),

          // 2FA info when enabled
          if (settingsProvider.enableEmailPasswordAuth)
            Container(
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.only(top: 8),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.1),
                borderRadius: AppTheme.smallRadius,
                border: Border.all(
                  color: Colors.green.withOpacity(0.3),
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Iconsax.tick_circle,
                    color: Colors.green,
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'When you sign in, a 6-digit OTP code will be sent to your registered email address.',
                      style: TextStyle(
                        fontSize: 12,
                        color: textColor.withOpacity(0.7),
                      ),
                    ),
                  ),
                ],
              ),
            ),

          const SizedBox(height: 16),

          // Enable Biometric Login Toggle (only show if device supports it)
          if (_isBiometricAvailable) ...[
            _buildSwitchTile(
              loc.translate('enable_biometric_login'),
              settingsProvider.enableBiometricLogin,
              (value) async {
                final authProvider = context.read<AuthProvider>();
                if (value) {
                  // Verify biometric before enabling
                  final authenticated = await _biometricService.authenticate(
                    localizedReason:
                        loc.translate('biometric_verify_to_enable'),
                  );
                  if (authenticated) {
                    // Enable biometric in auth provider (stores credentials)
                    final success = await authProvider.enableBiometric();
                    if (success) {
                      settingsProvider.toggleBiometricLogin(true);
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                                loc.translate('biometric_enabled_success')),
                            backgroundColor: Colors.green,
                          ),
                        );
                      }
                    } else {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(authProvider.errorMessage ??
                                'Failed to enable biometric'),
                            backgroundColor: Colors.orange,
                          ),
                        );
                      }
                    }
                  }
                } else {
                  // Disable biometric in auth provider (clears credentials)
                  await authProvider.disableBiometric();
                  settingsProvider.toggleBiometricLogin(false);
                }
              },
              icon: Iconsax.finger_scan,
            ),
            // Biometric info
            Container(
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.only(top: 8),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withOpacity(0.1),
                borderRadius: AppTheme.smallRadius,
                border: Border.all(
                  color: AppTheme.primaryColor.withOpacity(0.3),
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Iconsax.finger_scan,
                    color: AppTheme.primaryColor,
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      loc
                          .translate('biometric_login_description')
                          .replaceAll('{biometricType}', _biometricTypeName),
                      style: TextStyle(
                        fontSize: 12,
                        color: textColor.withOpacity(0.7),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],

          // Enable Authentication Audio Toggle
          _buildSwitchTile(
            'Authentication Audio',
            settingsProvider.enableAuthAudio,
            (value) => settingsProvider.toggleAuthAudio(value),
            icon: Iconsax.volume_high,
          ),

          // Audio info
          Container(
            padding: const EdgeInsets.all(12),
            margin: const EdgeInsets.only(top: 8),
            decoration: BoxDecoration(
              color: AppTheme.accentColor.withOpacity(0.1),
              borderRadius: AppTheme.smallRadius,
              border: Border.all(
                color: AppTheme.accentColor.withOpacity(0.3),
                width: 1,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Iconsax.music,
                  color: AppTheme.accentColor,
                  size: 20,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Play audio notifications during face authentication (e.g., "Look at camera", success sound)',
                    style: TextStyle(
                      fontSize: 12,
                      color: textColor.withOpacity(0.7),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUserManagementSection(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final authProvider = context.watch<AuthProvider>();

    // Only show for admin users (high access level)
    if (authProvider.currentUser == null || !authProvider.isAdmin) {
      return const SizedBox.shrink();
    }

    return FadeInUp(
      delay: const Duration(milliseconds: 175),
      child: _buildSection(
        loc.t('user_management'),
        [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.purple.withOpacity(0.1),
              borderRadius: AppTheme.smallRadius,
              border: Border.all(
                color: Colors.purple.withOpacity(0.3),
                width: 1,
              ),
            ),
            child: Row(
              children: [
                const Icon(
                  Iconsax.shield_tick,
                  color: Colors.purple,
                  size: 20,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'View and manage user accounts, approve new registrations, and monitor activity.',
                    style: TextStyle(
                      fontSize: 13,
                      color: AppTheme.lightText.withOpacity(0.8),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          ListTile(
            leading: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.purple.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Iconsax.people,
                color: Colors.purple,
                size: 20,
              ),
            ),
            title: const Text('Manage Users'),
            subtitle: const Text('View all users, ban/kick accounts'),
            trailing: const Icon(Iconsax.arrow_right_3),
            onTap: () => Navigator.pushNamed(context, '/user-management'),
          ),
          ListTile(
            leading: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Iconsax.user_tick,
                color: Colors.orange,
                size: 20,
              ),
            ),
            title: Text(loc.translate('pending_approvals')),
            subtitle: const Text('Approve new user registrations'),
            trailing: const Icon(Iconsax.arrow_right_3),
            onTap: () => Navigator.pushNamed(context, '/user-approval'),
          ),
        ],
      ),
    );
  }

  Widget _buildEmailConfigSection(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();

    // Only show for admin users
    if (authProvider.currentUser == null || !authProvider.isAdmin) {
      return const SizedBox.shrink();
    }

    return FadeInUp(
      delay: const Duration(milliseconds: 185),
      child: _buildSection(
        'Email Configuration',
        [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _isEmailConfigured
                  ? Colors.green.withOpacity(0.1)
                  : Colors.orange.withOpacity(0.1),
              borderRadius: AppTheme.smallRadius,
              border: Border.all(
                color: _isEmailConfigured
                    ? Colors.green.withOpacity(0.3)
                    : Colors.orange.withOpacity(0.3),
                width: 1,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  _isEmailConfigured ? Iconsax.tick_circle : Iconsax.warning_2,
                  color: _isEmailConfigured ? Colors.green : Colors.orange,
                  size: 20,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _isEmailConfigured
                        ? 'Email configured: $_configuredEmail\nOTP codes will be sent via email.'
                        : 'Email not configured. OTP codes will only be shown in the admin panel.',
                    style: TextStyle(
                      fontSize: 13,
                      color: AppTheme.lightText.withOpacity(0.8),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          ListTile(
            leading: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Iconsax.sms,
                color: Colors.blue,
                size: 20,
              ),
            ),
            title: Text(_isEmailConfigured
                ? 'Update Email Settings'
                : 'Configure Email'),
            subtitle: const Text('Set up Gmail SMTP for OTP delivery'),
            trailing: const Icon(Iconsax.arrow_right_3),
            onTap: () => _showEmailConfigDialog(context),
          ),
          if (_isEmailConfigured)
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Iconsax.trash,
                  color: Colors.red,
                  size: 20,
                ),
              ),
              title: const Text('Remove Email Configuration'),
              subtitle: const Text('Stop sending OTP via email'),
              trailing: const Icon(Iconsax.arrow_right_3),
              onTap: () async {
                await EmailService.clearConfiguration();
                await _loadEmailConfig();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Email configuration removed'),
                      backgroundColor: Colors.orange,
                    ),
                  );
                }
              },
            ),
        ],
      ),
    );
  }

  Future<void> _showEmailConfigDialog(BuildContext context) async {
    final emailController = TextEditingController(text: _configuredEmail ?? '');
    final passwordController = TextEditingController();
    bool isLoading = false;

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Configure Gmail SMTP'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '📧 Gmail App Password Required',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      SizedBox(height: 8),
                      Text(
                        '1. Go to myaccount.google.com\n'
                        '2. Security → 2-Step Verification\n'
                        '3. App passwords → Generate\n'
                        '4. Copy the 16-character password',
                        style: TextStyle(fontSize: 12),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: emailController,
                  decoration: const InputDecoration(
                    labelText: 'Gmail Address',
                    hintText: 'your.email@gmail.com',
                    prefixIcon: Icon(Iconsax.sms),
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.emailAddress,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: passwordController,
                  decoration: const InputDecoration(
                    labelText: 'App Password',
                    hintText: '16-character app password',
                    prefixIcon: Icon(Iconsax.key),
                    border: OutlineInputBorder(),
                  ),
                  obscureText: true,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: isLoading
                  ? null
                  : () async {
                      if (emailController.text.isEmpty ||
                          passwordController.text.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Please fill in all fields'),
                            backgroundColor: Colors.red,
                          ),
                        );
                        return;
                      }

                      setDialogState(() => isLoading = true);

                      final success = await EmailService.configure(
                        email: emailController.text.trim(),
                        appPassword: passwordController.text.trim(),
                      );

                      setDialogState(() => isLoading = false);

                      if (success) {
                        await _loadEmailConfig();
                        if (context.mounted) {
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                  '✅ Email configured successfully! Test email sent.'),
                              backgroundColor: Colors.green,
                            ),
                          );
                        }
                      } else {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                  '❌ Configuration failed. Check your credentials.'),
                              backgroundColor: Colors.red,
                            ),
                          );
                        }
                      }
                    },
              child: isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Configure'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildConnectionModeSection(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final settingsProvider = context.watch<SettingsProvider>();
    final theme = Theme.of(context);

    return FadeInUp(
      delay: const Duration(milliseconds: 200),
      child: _buildSection(
        loc.t('connection_mode'),
        [
          // Info about server IP
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withOpacity(0.1),
              borderRadius: AppTheme.smallRadius,
              border: Border.all(
                color: AppTheme.primaryColor.withOpacity(0.3),
                width: 1,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Iconsax.global,
                  color: AppTheme.primaryColor,
                  size: 20,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Backend Server IP: ${settingsProvider.mqttBrokerAddress}',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'This IP is used for MQTT, Camera, AI Chat, and Voice services. Change it below if your backend is on a different network.',
                        style: TextStyle(
                          fontSize: 11,
                          color: theme.colorScheme.onSurface.withOpacity(0.7),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _buildSegmentedControl(
            settingsProvider.connectionMode,
            (mode) => settingsProvider.setConnectionMode(mode),
          ),
          if (settingsProvider.connectionMode == ConnectionMode.local) ...[
            const SizedBox(height: 16),
            _buildMqttSettings(context, settingsProvider),
          ],
        ],
      ),
    );
  }

  Widget _buildSegmentedControl(
    ConnectionMode currentMode,
    Function(ConnectionMode) onChanged,
  ) {
    final loc = AppLocalizations.of(context);
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppTheme.darkCard,
        borderRadius: AppTheme.mediumRadius,
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildSegmentButton(
              loc.t('cloud'),
              Iconsax.cloud,
              currentMode == ConnectionMode.cloud,
              () => onChanged(ConnectionMode.cloud),
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: _buildSegmentButton(
              '${loc.t('local')} (ESP32)',
              Iconsax.wifi,
              currentMode == ConnectionMode.local,
              () => onChanged(ConnectionMode.local),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSegmentButton(
    String label,
    IconData icon,
    bool isSelected,
    VoidCallback onTap,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          gradient: isSelected ? AppTheme.primaryGradient : null,
          borderRadius: AppTheme.mediumRadius,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 18,
              color: isSelected
                  ? Colors.white
                  : AppTheme.lightText.withOpacity(0.6),
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                color: isSelected
                    ? Colors.white
                    : AppTheme.lightText.withOpacity(0.6),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMqttSettings(BuildContext context, SettingsProvider provider) {
    return Column(
      children: [
        _buildTextField(
          'MQTT Broker Address',
          provider.mqttBrokerAddress,
          (value) => provider.updateMqttSettings(brokerAddress: value),
          icon: Iconsax.global,
        ),
        const SizedBox(height: 12),
        _buildTextField(
          'Port',
          provider.mqttBrokerPort.toString(),
          (value) =>
              provider.updateMqttSettings(brokerPort: int.tryParse(value)),
          icon: Iconsax.setting_2,
          keyboardType: TextInputType.number,
        ),
        const SizedBox(height: 12),
        _buildTextField(
          'Username (Optional)',
          provider.mqttUsername,
          (value) => provider.updateMqttSettings(username: value),
          icon: Iconsax.user,
        ),
        const SizedBox(height: 12),
        _buildTextField(
          'Password (Optional)',
          provider.mqttPassword,
          (value) => provider.updateMqttSettings(password: value),
          icon: Iconsax.lock,
          obscureText: true,
        ),
      ],
    );
  }

  Widget _buildAppearanceSection(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final settingsProvider = context.watch<SettingsProvider>();

    return FadeInUp(
      delay: const Duration(milliseconds: 300),
      child: _buildSection(
        loc.t('appearance'),
        [
          _buildThemeSelector(settingsProvider),
          const SizedBox(height: 12),
          _buildSettingTile(
            loc.t('language'),
            _getLanguageDisplayName(settingsProvider.language),
            Iconsax.language_square,
            onTap: () => _showLanguagePicker(context),
          ),
        ],
      ),
    );
  }

  Widget _buildThemeSelector(SettingsProvider provider) {
    final loc = AppLocalizations.of(context);
    return Row(
      children: [
        Expanded(
          child: _buildThemeOption(
            loc.t('light'),
            Iconsax.sun_1,
            provider.themeMode == ThemeMode.light,
            () => provider.setThemeMode(ThemeMode.light),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildThemeOption(
            loc.t('dark'),
            Iconsax.moon,
            provider.themeMode == ThemeMode.dark,
            () => provider.setThemeMode(ThemeMode.dark),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildThemeOption(
            loc.t('system'),
            Iconsax.mobile,
            provider.themeMode == ThemeMode.system,
            () => provider.setThemeMode(ThemeMode.system),
          ),
        ),
      ],
    );
  }

  Widget _buildThemeOption(
    String label,
    IconData icon,
    bool isSelected,
    VoidCallback onTap,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          gradient: isSelected ? AppTheme.primaryGradient : null,
          color: isSelected ? null : AppTheme.darkCard,
          borderRadius: AppTheme.mediumRadius,
          border: Border.all(
            color: isSelected
                ? AppTheme.primaryColor
                : AppTheme.lightText.withOpacity(0.1),
            width: 1,
          ),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              color: isSelected
                  ? Colors.white
                  : AppTheme.lightText.withOpacity(0.6),
              size: 24,
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                color: isSelected
                    ? Colors.white
                    : AppTheme.lightText.withOpacity(0.6),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNotificationsSection(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final settingsProvider = context.watch<SettingsProvider>();

    return FadeInUp(
      delay: const Duration(milliseconds: 400),
      child: _buildSection(
        loc.t('notification_settings'),
        [
          _buildSwitchTile(
            loc.t('enable_notifications'),
            settingsProvider.enableNotifications,
            (value) => settingsProvider.toggleNotifications(value),
            icon: Iconsax.notification,
          ),
          if (settingsProvider.enableNotifications) ...[
            _buildSwitchTile(
              loc.t('device_status_notifications'),
              settingsProvider.deviceStatusNotifications,
              (value) =>
                  settingsProvider.toggleDeviceStatusNotifications(value),
              icon: Iconsax.status,
            ),
            _buildSwitchTile(
              loc.t('automation_notifications'),
              settingsProvider.automationNotifications,
              (value) => settingsProvider.toggleAutomationNotifications(value),
              icon: Iconsax.timer,
            ),
            _buildSwitchTile(
              loc.t('security_alerts'),
              settingsProvider.securityAlerts,
              (value) => settingsProvider.toggleSecurityAlerts(value),
              icon: Iconsax.shield_tick,
            ),
            _buildSwitchTile(
              loc.t('sound'),
              settingsProvider.soundEnabled,
              (value) => settingsProvider.toggleSound(value),
              icon: Iconsax.volume_high,
            ),
            _buildSwitchTile(
              loc.t('vibration'),
              settingsProvider.vibrationEnabled,
              (value) => settingsProvider.toggleVibration(value),
              icon: Iconsax.mobile,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildAppPreferencesSection(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final settingsProvider = context.watch<SettingsProvider>();

    return FadeInUp(
      delay: const Duration(milliseconds: 500),
      child: _buildSection(
        loc.t('app_preferences'),
        [
          _buildSwitchTile(
            loc.t('auto_connect'),
            settingsProvider.autoConnect,
            (value) => settingsProvider.toggleAutoConnect(value),
            icon: Iconsax.link,
          ),
          _buildSettingTile(
            loc.t('data_refresh_interval'),
            '${settingsProvider.dataRefreshInterval} ${loc.t('seconds')}',
            Iconsax.refresh,
            onTap: () => _showRefreshIntervalPicker(context, settingsProvider),
          ),
        ],
      ),
    );
  }

  Widget _buildAccountSection(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final textColor = theme.colorScheme.onBackground;

    return FadeInUp(
      delay: const Duration(milliseconds: 600),
      child: _buildSection(
        loc.t('account'),
        [
          // Session Duration Setting
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withOpacity(0.1),
              borderRadius: AppTheme.smallRadius,
              border: Border.all(
                color: AppTheme.primaryColor.withOpacity(0.3),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Iconsax.timer_1,
                      color: AppTheme.primaryColor,
                      size: 20,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Session Duration',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: textColor,
                        ),
                      ),
                    ),
                    Text(
                      '$_sessionDuration ${_sessionDuration == 1 ? 'day' : 'days'}',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.primaryColor,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  'You will be automatically logged out after this period of inactivity',
                  style: TextStyle(
                    fontSize: 12,
                    color: textColor.withOpacity(0.6),
                  ),
                ),
                const SizedBox(height: 16),
                SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    activeTrackColor: AppTheme.primaryColor,
                    inactiveTrackColor: AppTheme.primaryColor.withOpacity(0.3),
                    thumbColor: AppTheme.primaryColor,
                    overlayColor: AppTheme.primaryColor.withOpacity(0.2),
                    trackHeight: 4,
                  ),
                  child: Slider(
                    value: _sessionDuration.toDouble(),
                    min: 1,
                    max: 30,
                    divisions: 29,
                    label:
                        '$_sessionDuration ${_sessionDuration == 1 ? 'day' : 'days'}',
                    onChanged: (value) async {
                      setState(() {
                        _sessionDuration = value.toInt();
                      });
                      await SessionService.setSessionDuration(_sessionDuration);

                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                                'Session duration set to $_sessionDuration ${_sessionDuration == 1 ? 'day' : 'days'}'),
                            backgroundColor: AppTheme.successColor,
                            behavior: SnackBarBehavior.floating,
                            duration: const Duration(seconds: 2),
                          ),
                        );
                      }
                    },
                  ),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '1 day',
                      style: TextStyle(
                        fontSize: 11,
                        color: textColor.withOpacity(0.5),
                      ),
                    ),
                    Text(
                      '30 days',
                      style: TextStyle(
                        fontSize: 11,
                        color: textColor.withOpacity(0.5),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          // Session expiry info
          FutureBuilder<DateTime?>(
            future: SessionService.getSessionExpiryDate(),
            builder: (context, snapshot) {
              if (snapshot.hasData && snapshot.data != null) {
                final expiry = snapshot.data!;
                final now = DateTime.now();
                final remaining = expiry.difference(now);

                String expiryText;
                if (remaining.inHours < 1) {
                  expiryText = 'Expires in ${remaining.inMinutes} minutes';
                } else if (remaining.inHours < 24) {
                  expiryText = 'Expires in ${remaining.inHours} hours';
                } else {
                  expiryText = 'Expires in ${remaining.inDays} days';
                }

                return _buildSettingTile(
                  'Current Session',
                  expiryText,
                  Iconsax.clock,
                );
              }
              return const SizedBox.shrink();
            },
          ),
          _buildSettingTile(
            loc.t('change_password'),
            '',
            Iconsax.lock,
            onTap: () => _changePassword(context),
          ),
          _buildSettingTile(
            loc.t('privacy'),
            '',
            Iconsax.shield_tick,
            onTap: () => _showPrivacySettings(context),
          ),
          _buildSettingTile(
            loc.t('delete_account'),
            '',
            Iconsax.trash,
            onTap: () => _deleteAccount(context),
            isDestructive: true,
          ),
        ],
      ),
    );
  }

  Widget _buildAboutSection(BuildContext context) {
    final loc = AppLocalizations.of(context);
    return FadeInUp(
      delay: const Duration(milliseconds: 700),
      child: _buildSection(
        loc.t('about'),
        [
          _buildSettingTile(
            loc.t('version'),
            '1.0.0',
            Iconsax.info_circle,
          ),
          _buildSettingTile(
            'Terms of Service',
            '',
            Iconsax.document_text,
            onTap: () => _showTerms(context),
          ),
          _buildSettingTile(
            'Privacy Policy',
            '',
            Iconsax.shield,
            onTap: () => _showPrivacyPolicy(context),
          ),
          _buildSettingTile(
            loc.t('help_support'),
            '',
            Iconsax.message_question,
            onTap: () => _showSupport(context),
          ),
        ],
      ),
    );
  }

  Widget _buildSection(String title, List<Widget> children) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final textColor = theme.colorScheme.onBackground;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 12),
          child: Text(
            title,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: textColor,
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: isDark
                ? AppTheme.cardGradient
                : LinearGradient(
                    colors: [
                      AppTheme.lightSurface,
                      AppTheme.lightSurface.withOpacity(0.8),
                    ],
                  ),
            borderRadius: AppTheme.largeRadius,
            border: Border.all(
              color: AppTheme.primaryColor.withOpacity(0.3),
              width: 1,
            ),
          ),
          child: Column(
            children: children,
          ),
        ),
      ],
    );
  }

  Widget _buildSettingTile(
    String title,
    String subtitle,
    IconData icon, {
    VoidCallback? onTap,
    bool isDestructive = false,
  }) {
    final theme = Theme.of(context);
    final textColor = theme.colorScheme.onBackground;

    return InkWell(
      onTap: onTap,
      borderRadius: AppTheme.mediumRadius,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                gradient: isDestructive
                    ? LinearGradient(
                        colors: [
                          AppTheme.errorColor.withOpacity(0.3),
                          AppTheme.errorColor.withOpacity(0.1),
                        ],
                      )
                    : AppTheme.primaryGradient.scale(0.3),
                borderRadius: AppTheme.smallRadius,
              ),
              child: Icon(
                icon,
                size: 20,
                color:
                    isDestructive ? AppTheme.errorColor : AppTheme.primaryColor,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: isDestructive ? AppTheme.errorColor : textColor,
                    ),
                  ),
                  if (subtitle.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 13,
                        color: textColor.withOpacity(0.6),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (onTap != null)
              Icon(
                Iconsax.arrow_right_3,
                size: 20,
                color: textColor.withOpacity(0.4),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSwitchTile(
    String title,
    bool value,
    Function(bool) onChanged, {
    required IconData icon,
  }) {
    final theme = Theme.of(context);
    final textColor = theme.colorScheme.onBackground;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              gradient: AppTheme.primaryGradient.scale(0.3),
              borderRadius: AppTheme.smallRadius,
            ),
            child: Icon(
              icon,
              size: 20,
              color: AppTheme.primaryColor,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w500,
                color: textColor,
              ),
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: AppTheme.primaryColor,
          ),
        ],
      ),
    );
  }

  Widget _buildTextField(
    String label,
    String initialValue,
    Function(String) onChanged, {
    required IconData icon,
    TextInputType? keyboardType,
    bool obscureText = false,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final textColor = theme.colorScheme.onBackground;

    return TextField(
      controller: TextEditingController(text: initialValue),
      onChanged: onChanged,
      keyboardType: keyboardType,
      obscureText: obscureText,
      style: TextStyle(color: textColor),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: textColor.withOpacity(0.6)),
        prefixIcon: Icon(icon, color: AppTheme.primaryColor),
        filled: true,
        fillColor:
            isDark ? AppTheme.darkCard : AppTheme.lightSurface.withOpacity(0.5),
        border: OutlineInputBorder(
          borderRadius: AppTheme.mediumRadius,
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: AppTheme.mediumRadius,
          borderSide: BorderSide(
            color: textColor.withOpacity(0.1),
            width: 1,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: AppTheme.mediumRadius,
          borderSide: const BorderSide(
            color: AppTheme.primaryColor,
            width: 2,
          ),
        ),
      ),
    );
  }

  // Helper methods
  void _editProfile(BuildContext context) {
    // Navigate to profile edit screen
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Edit profile feature coming soon!')),
    );
  }

  String _getLanguageDisplayName(String languageCode) {
    switch (languageCode) {
      case 'de':
        return 'Deutsch';
      case 'ar':
        return 'العربية';
      default:
        return 'English';
    }
  }

  void _showLanguagePicker(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final textColor = theme.colorScheme.onBackground;

    // Show language picker dialog
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDark ? AppTheme.darkCard : AppTheme.lightSurface,
        title: Text(loc.t('language'), style: TextStyle(color: textColor)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildLanguageOption(context, loc.t('language_english'), 'en'),
            _buildLanguageOption(context, loc.t('language_german'), 'de'),
            _buildLanguageOption(context, loc.t('language_arabic'), 'ar'),
          ],
        ),
      ),
    );
  }

  Widget _buildLanguageOption(BuildContext context, String name, String code) {
    final settingsProvider = context.watch<SettingsProvider>();
    final isSelected = settingsProvider.language == code;
    final theme = Theme.of(context);
    final textColor = theme.colorScheme.onBackground;

    return ListTile(
      title: Text(name, style: TextStyle(color: textColor)),
      trailing: isSelected
          ? const Icon(Iconsax.tick_circle5, color: AppTheme.primaryColor)
          : null,
      onTap: () {
        settingsProvider.setLanguage(code);
        Navigator.pop(context);
      },
    );
  }

  void _showRefreshIntervalPicker(
      BuildContext context, SettingsProvider provider) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final textColor = theme.colorScheme.onBackground;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDark ? AppTheme.darkCard : AppTheme.lightSurface,
        title:
            Text('Data Refresh Interval', style: TextStyle(color: textColor)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildIntervalOption(context, provider, '3 seconds', 3),
            _buildIntervalOption(context, provider, '5 seconds', 5),
            _buildIntervalOption(context, provider, '10 seconds', 10),
            _buildIntervalOption(context, provider, '30 seconds', 30),
          ],
        ),
      ),
    );
  }

  Widget _buildIntervalOption(
    BuildContext context,
    SettingsProvider provider,
    String label,
    int seconds,
  ) {
    final isSelected = provider.dataRefreshInterval == seconds;
    final theme = Theme.of(context);
    final textColor = theme.colorScheme.onBackground;

    return ListTile(
      title: Text(label, style: TextStyle(color: textColor)),
      trailing: isSelected
          ? const Icon(Iconsax.tick_circle5, color: AppTheme.primaryColor)
          : null,
      onTap: () {
        provider.setDataRefreshInterval(seconds);
        Navigator.pop(context);
      },
    );
  }

  void _changePassword(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Change password feature coming soon!')),
    );
  }

  void _showPrivacySettings(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Privacy settings feature coming soon!')),
    );
  }

  void _deleteAccount(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.darkCard,
        title: const Text('Delete Account',
            style: TextStyle(color: AppTheme.errorColor)),
        content: const Text(
          'Are you sure you want to delete your account? This action cannot be undone.',
          style: TextStyle(color: AppTheme.lightText),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              // Delete account logic
              Navigator.pop(context);
            },
            child: const Text('Delete',
                style: TextStyle(color: AppTheme.errorColor)),
          ),
        ],
      ),
    );
  }

  void _showTerms(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Terms of Service feature coming soon!')),
    );
  }

  void _showPrivacyPolicy(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Privacy Policy feature coming soon!')),
    );
  }

  void _showSupport(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Help & Support feature coming soon!')),
    );
  }
}
