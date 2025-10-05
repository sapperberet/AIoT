import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:iconsax/iconsax.dart';
import 'package:animate_do/animate_do.dart';
import '../../../core/providers/settings_provider.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/theme/app_theme.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.darkBackground,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: FadeInLeft(
          child: IconButton(
            icon: const Icon(Iconsax.arrow_left, color: AppTheme.lightText),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        title: FadeInDown(
          child: ShaderMask(
            shaderCallback: (bounds) =>
                AppTheme.primaryGradient.createShader(bounds),
            child: const Text(
              'Settings',
              style: TextStyle(
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

    return FadeInUp(
      delay: const Duration(milliseconds: 100),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: AppTheme.cardGradient,
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
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.lightText,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    user?.email ?? '',
                    style: TextStyle(
                      fontSize: 14,
                      color: AppTheme.lightText.withOpacity(0.6),
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

  Widget _buildConnectionModeSection(BuildContext context) {
    final settingsProvider = context.watch<SettingsProvider>();

    return FadeInUp(
      delay: const Duration(milliseconds: 200),
      child: _buildSection(
        'Connection Mode',
        [
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
              'Cloud',
              Iconsax.cloud,
              currentMode == ConnectionMode.cloud,
              () => onChanged(ConnectionMode.cloud),
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: _buildSegmentButton(
              'Local (ESP32)',
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
    final settingsProvider = context.watch<SettingsProvider>();

    return FadeInUp(
      delay: const Duration(milliseconds: 300),
      child: _buildSection(
        'Appearance',
        [
          _buildThemeSelector(settingsProvider),
          const SizedBox(height: 12),
          _buildSettingTile(
            'Language',
            'English',
            Iconsax.language_square,
            onTap: () => _showLanguagePicker(context),
          ),
        ],
      ),
    );
  }

  Widget _buildThemeSelector(SettingsProvider provider) {
    return Row(
      children: [
        Expanded(
          child: _buildThemeOption(
            'Light',
            Iconsax.sun_1,
            provider.themeMode == ThemeMode.light,
            () => provider.setThemeMode(ThemeMode.light),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildThemeOption(
            'Dark',
            Iconsax.moon,
            provider.themeMode == ThemeMode.dark,
            () => provider.setThemeMode(ThemeMode.dark),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildThemeOption(
            'System',
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
    final settingsProvider = context.watch<SettingsProvider>();

    return FadeInUp(
      delay: const Duration(milliseconds: 400),
      child: _buildSection(
        'Notifications',
        [
          _buildSwitchTile(
            'Enable Notifications',
            settingsProvider.enableNotifications,
            (value) => settingsProvider.toggleNotifications(value),
            icon: Iconsax.notification,
          ),
          if (settingsProvider.enableNotifications) ...[
            _buildSwitchTile(
              'Device Status Updates',
              settingsProvider.deviceStatusNotifications,
              (value) =>
                  settingsProvider.toggleDeviceStatusNotifications(value),
              icon: Iconsax.status,
            ),
            _buildSwitchTile(
              'Automation Alerts',
              settingsProvider.automationNotifications,
              (value) => settingsProvider.toggleAutomationNotifications(value),
              icon: Iconsax.timer,
            ),
            _buildSwitchTile(
              'Security Alerts',
              settingsProvider.securityAlerts,
              (value) => settingsProvider.toggleSecurityAlerts(value),
              icon: Iconsax.shield_tick,
            ),
            _buildSwitchTile(
              'Sound',
              settingsProvider.soundEnabled,
              (value) => settingsProvider.toggleSound(value),
              icon: Iconsax.volume_high,
            ),
            _buildSwitchTile(
              'Vibration',
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
    final settingsProvider = context.watch<SettingsProvider>();

    return FadeInUp(
      delay: const Duration(milliseconds: 500),
      child: _buildSection(
        'App Preferences',
        [
          _buildSwitchTile(
            'Auto-Connect on Launch',
            settingsProvider.autoConnect,
            (value) => settingsProvider.toggleAutoConnect(value),
            icon: Iconsax.link,
          ),
          _buildSwitchTile(
            'Offline Mode',
            settingsProvider.offlineMode,
            (value) => settingsProvider.toggleOfflineMode(value),
            icon: Iconsax.wifi_square,
          ),
          _buildSettingTile(
            'Data Refresh Interval',
            '${settingsProvider.dataRefreshInterval} seconds',
            Iconsax.refresh,
            onTap: () => _showRefreshIntervalPicker(context, settingsProvider),
          ),
        ],
      ),
    );
  }

  Widget _buildAccountSection(BuildContext context) {
    return FadeInUp(
      delay: const Duration(milliseconds: 600),
      child: _buildSection(
        'Account',
        [
          _buildSettingTile(
            'Change Password',
            '',
            Iconsax.lock,
            onTap: () => _changePassword(context),
          ),
          _buildSettingTile(
            'Privacy & Security',
            '',
            Iconsax.shield_tick,
            onTap: () => _showPrivacySettings(context),
          ),
          _buildSettingTile(
            'Delete Account',
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
    return FadeInUp(
      delay: const Duration(milliseconds: 700),
      child: _buildSection(
        'About',
        [
          _buildSettingTile(
            'Version',
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
            'Help & Support',
            '',
            Iconsax.message_question,
            onTap: () => _showSupport(context),
          ),
        ],
      ),
    );
  }

  Widget _buildSection(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 12),
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: AppTheme.lightText,
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: AppTheme.cardGradient,
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
                      color: isDestructive
                          ? AppTheme.errorColor
                          : AppTheme.lightText,
                    ),
                  ),
                  if (subtitle.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 13,
                        color: AppTheme.lightText.withOpacity(0.6),
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
                color: AppTheme.lightText.withOpacity(0.4),
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
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w500,
                color: AppTheme.lightText,
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
    return TextField(
      controller: TextEditingController(text: initialValue),
      onChanged: onChanged,
      keyboardType: keyboardType,
      obscureText: obscureText,
      style: const TextStyle(color: AppTheme.lightText),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: AppTheme.lightText.withOpacity(0.6)),
        prefixIcon: Icon(icon, color: AppTheme.primaryColor),
        filled: true,
        fillColor: AppTheme.darkCard,
        border: OutlineInputBorder(
          borderRadius: AppTheme.mediumRadius,
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: AppTheme.mediumRadius,
          borderSide: BorderSide(
            color: AppTheme.lightText.withOpacity(0.1),
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

  void _showLanguagePicker(BuildContext context) {
    // Show language picker dialog
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.darkCard,
        title: const Text('Select Language',
            style: TextStyle(color: AppTheme.lightText)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildLanguageOption(context, 'English', 'en'),
            _buildLanguageOption(context, 'Spanish', 'es'),
            _buildLanguageOption(context, 'French', 'fr'),
            _buildLanguageOption(context, 'German', 'de'),
          ],
        ),
      ),
    );
  }

  Widget _buildLanguageOption(BuildContext context, String name, String code) {
    final settingsProvider = context.watch<SettingsProvider>();
    final isSelected = settingsProvider.language == code;

    return ListTile(
      title: Text(name, style: const TextStyle(color: AppTheme.lightText)),
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
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.darkCard,
        title: const Text('Data Refresh Interval',
            style: TextStyle(color: AppTheme.lightText)),
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

    return ListTile(
      title: Text(label, style: const TextStyle(color: AppTheme.lightText)),
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
