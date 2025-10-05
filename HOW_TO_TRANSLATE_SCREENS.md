# 🌍 How to Apply Translations to Remaining Screens

## Current Status

✅ **Fully Translated:**
- Drawer menu (Home, Settings, Notifications, Automations, Energy Monitor, Security, About, Logout)

⏳ **Pending Translation:**
- Settings Screen content
- Notifications Screen content  
- Automations Screen content
- Energy Monitor Screen content
- Home Screen tabs

---

## Step-by-Step Guide

### 1. Import AppLocalizations

Add to the top of any screen file:

```dart
import '../../core/localization/app_localizations.dart';
```

### 2. Get Localization Instance

In your `build()` method:

```dart
@override
Widget build(BuildContext context) {
  final loc = AppLocalizations.of(context);
  
  // Now use loc.t('key') for any text
}
```

### 3. Replace Hardcoded Strings

**Before:**
```dart
Text('Settings')
```

**After:**
```dart
Text(loc.t('settings'))
```

---

## Example: Translate Settings Screen

### Current Code (Hardcoded):
```dart
Widget _buildProfileSection(BuildContext context) {
  return _buildSection(
    'Profile',  // ❌ Hardcoded
    [
      _buildSettingTile(
        'Language',  // ❌ Hardcoded
        _getLanguageName(),
        Iconsax.language_square,
        onTap: () => _showLanguagePicker(context),
      ),
    ],
  );
}
```

### Updated Code (Translated):
```dart
Widget _buildProfileSection(BuildContext context) {
  final loc = AppLocalizations.of(context);
  return _buildSection(
    loc.t('profile'),  // ✅ Translated
    [
      _buildSettingTile(
        loc.t('language'),  // ✅ Translated
        _getLanguageName(),
        Iconsax.language_square,
        onTap: () => _showLanguagePicker(context),
      ),
    ],
  );
}
```

---

## Complete Settings Screen Translation Template

```dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:iconsax/iconsax.dart';
import '../../core/providers/settings_provider.dart';
import '../../core/localization/app_localizations.dart';  // ← Add this
import '../../core/theme/app_theme.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);  // ← Add this
    final settingsProvider = context.watch<SettingsProvider>();
    
    return Scaffold(
      backgroundColor: AppTheme.darkBackground,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: Text(loc.t('settings')),  // ← Use translation
      ),
      body: ListView(
        children: [
          _buildProfileSection(context),
          _buildConnectionModeSection(context),
          _buildAppearanceSection(context),
          _buildNotificationSection(context),
          _buildAppPreferencesSection(context),
          _buildAccountSection(context),
        ],
      ),
    );
  }

  Widget _buildProfileSection(BuildContext context) {
    final loc = AppLocalizations.of(context);
    return _buildSection(
      loc.t('profile'),
      [
        _buildSettingTile(
          loc.t('language'),
          _getLanguageName(),
          Iconsax.language_square,
          onTap: () => _showLanguagePicker(context),
        ),
      ],
    );
  }

  Widget _buildConnectionModeSection(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final settingsProvider = context.watch<SettingsProvider>();
    
    return _buildSection(
      loc.t('connection_mode'),
      [
        // Segmented control for Cloud/Local
        _buildSegmentedControl(
          settingsProvider.connectionMode == ConnectionMode.cloud
              ? loc.t('cloud')
              : loc.t('local'),
        ),
      ],
    );
  }

  Widget _buildAppearanceSection(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final settingsProvider = context.watch<SettingsProvider>();
    
    return _buildSection(
      loc.t('appearance'),
      [
        _buildSettingTile(
          loc.t('theme'),
          _getThemeName(settingsProvider.themeMode, loc),
          Iconsax.brush_1,
          onTap: () => _showThemePicker(context),
        ),
      ],
    );
  }

  String _getThemeName(ThemeMode mode, AppLocalizations loc) {
    switch (mode) {
      case ThemeMode.light:
        return loc.t('light');
      case ThemeMode.dark:
        return loc.t('dark');
      case ThemeMode.system:
        return loc.t('system');
    }
  }

  Widget _buildNotificationSection(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final settingsProvider = context.watch<SettingsProvider>();
    
    return _buildSection(
      loc.t('notification_settings'),
      [
        _buildSwitchTile(
          loc.t('enable_notifications'),
          settingsProvider.enableNotifications,
          (value) => settingsProvider.toggleNotifications(value),
          icon: Iconsax.notification,
        ),
        _buildSwitchTile(
          loc.t('device_status_notifications'),
          settingsProvider.deviceStatusNotifications,
          (value) => settingsProvider.toggleDeviceStatusNotifications(value),
          icon: Iconsax.device_message,
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
          icon: Iconsax.shield_security,
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
    );
  }

  Widget _buildAppPreferencesSection(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final settingsProvider = context.watch<SettingsProvider>();
    
    return _buildSection(
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
    );
  }

  Widget _buildAccountSection(BuildContext context) {
    final loc = AppLocalizations.of(context);
    
    return _buildSection(
      loc.t('account'),
      [
        _buildSettingTile(
          loc.t('change_password'),
          '',
          Iconsax.lock,
          onTap: () {
            // TODO: Navigate to change password
          },
        ),
        _buildSettingTile(
          loc.t('privacy'),
          '',
          Iconsax.shield_tick,
          onTap: () {
            // TODO: Navigate to privacy settings
          },
        ),
        _buildSettingTile(
          loc.t('delete_account'),
          '',
          Iconsax.trash,
          textColor: AppTheme.errorColor,
          onTap: () {
            // TODO: Show delete account confirmation
          },
        ),
      ],
    );
  }
}
```

---

## Example: Translate Notifications Screen

```dart
import '../../core/localization/app_localizations.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final notificationService = context.watch<NotificationService>();
    
    return Scaffold(
      appBar: AppBar(
        title: Text(loc.t('notifications')),
        actions: [
          PopupMenuButton<String>(
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'mark_all_read',
                child: Text(loc.t('mark_all_read')),
              ),
              PopupMenuItem(
                value: 'clear_all',
                child: Text(loc.t('clear_all')),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          _buildFilterChips(loc),
          Expanded(
            child: notificationService.notifications.isEmpty
                ? _buildEmptyState(loc)
                : _buildNotificationList(),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChips(AppLocalizations loc) {
    return Wrap(
      spacing: 8,
      children: [
        FilterChip(
          label: Text(loc.t('all')),
          onSelected: (selected) {},
        ),
        FilterChip(
          label: Text(loc.t('device_status')),
          onSelected: (selected) {},
        ),
        FilterChip(
          label: Text(loc.t('automation')),
          onSelected: (selected) {},
        ),
        FilterChip(
          label: Text(loc.t('security')),
          onSelected: (selected) {},
        ),
        FilterChip(
          label: Text(loc.t('info')),
          onSelected: (selected) {},
        ),
      ],
    );
  }

  Widget _buildEmptyState(AppLocalizations loc) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Iconsax.notification, size: 64, color: Colors.grey),
          SizedBox(height: 16),
          Text(
            loc.t('no_notifications'),
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 8),
          Text(
            loc.t('no_notifications_desc'),
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey),
          ),
        ],
      ),
    );
  }
}
```

---

## Example: Translate Automations Screen

```dart
import '../../core/localization/app_localizations.dart';

Widget build(BuildContext context) {
  final loc = AppLocalizations.of(context);
  final automationProvider = context.watch<AutomationProvider>();
  
  return Scaffold(
    appBar: AppBar(
      title: Text(loc.t('automations')),
    ),
    floatingActionButton: FloatingActionButton.extended(
      onPressed: () {
        // Create new automation
      },
      icon: Icon(Iconsax.add),
      label: Text(loc.t('create_automation')),
    ),
    body: automationProvider.automations.isEmpty
        ? Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(loc.t('no_automations')),
                Text(loc.t('no_automations_desc')),
              ],
            ),
          )
        : ListView.builder(
            itemCount: automationProvider.automations.length,
            itemBuilder: (context, index) {
              final automation = automationProvider.automations[index];
              return _buildAutomationCard(automation, loc);
            },
          ),
  );
}

Widget _buildAutomationCard(Automation automation, AppLocalizations loc) {
  return Card(
    child: Column(
      children: [
        // Header
        ListTile(
          title: Text(automation.name),
          subtitle: Text(automation.description),
        ),
        
        // Info sections
        _buildInfoSection(
          loc.t('triggers'),
          automation.triggers.map((t) => _getTriggerDescription(t, loc)).toList(),
        ),
        _buildInfoSection(
          loc.t('conditions'),
          automation.conditions.map((c) => _getConditionDescription(c, loc)).toList(),
        ),
        _buildInfoSection(
          loc.t('actions'),
          automation.actions.map((a) => _getActionDescription(a, loc)).toList(),
        ),
        
        // Last triggered
        Padding(
          padding: EdgeInsets.all(12),
          child: Row(
            children: [
              Text('${loc.t('last_triggered')}: '),
              Text(
                automation.lastTriggered != null
                    ? _formatTimestamp(automation.lastTriggered!)
                    : loc.t('never'),
              ),
            ],
          ),
        ),
        
        // Actions
        ButtonBar(
          children: [
            TextButton.icon(
              onPressed: () {},
              icon: Icon(Iconsax.edit),
              label: Text(loc.t('edit')),
            ),
            TextButton.icon(
              onPressed: () {},
              icon: Icon(Iconsax.play),
              label: Text(loc.t('run')),
            ),
            TextButton.icon(
              onPressed: () {},
              icon: Icon(Iconsax.trash),
              label: Text(loc.t('delete')),
              style: TextButton.styleFrom(foregroundColor: Colors.red),
            ),
          ],
        ),
      ],
    ),
  );
}
```

---

## Available Translation Keys

All these keys are already in `app_localizations.dart`:

### Common
`save`, `cancel`, `ok`, `yes`, `no`, `confirm`, `loading`, `error`, `success`

### Navigation
`home`, `devices`, `visualization`, `logs`, `settings`, `notifications`, `automations`, `energy_monitor`, `logout`

### Settings
`profile`, `connection_mode`, `cloud`, `local`, `appearance`, `theme`, `light`, `dark`, `system`, `notification_settings`, `enable_notifications`, `device_status_notifications`, `automation_notifications`, `security_alerts`, `sound`, `vibration`, `app_preferences`, `auto_connect`, `data_refresh_interval`, `language`, `account`, `change_password`, `privacy`, `delete_account`, `about`, `version`, `help_support`

### Notifications
`mark_all_read`, `clear_all`, `no_notifications`, `no_notifications_desc`, `all`, `device_status`, `automation`, `security`, `info`

### Automations
`create_automation`, `no_automations`, `no_automations_desc`, `triggers`, `conditions`, `actions`, `last_triggered`, `never`, `edit`, `run`, `delete`

### Energy
`total_consumption`, `consumption_chart`, `device_breakdown`, `cost_estimate`, `energy_tips`, `today`, `week`, `month`, `year`

---

## Testing Your Translations

1. Add translations to a screen
2. Run: `flutter run`
3. Change language in Settings
4. Navigate to the screen
5. Verify all text changes

---

## Tips

✅ **DO:**
- Use `final loc = AppLocalizations.of(context);` at the start of build method
- Replace ALL visible text with `loc.t('key')`
- Test with all 3 languages
- Check RTL layout for Arabic

❌ **DON'T:**
- Leave hardcoded strings
- Call `AppLocalizations.of(context)` multiple times
- Forget to import `app_localizations.dart`

---

**Quick Start:**
1. Copy one of the examples above
2. Replace your hardcoded strings
3. Test with language switching
4. Done! ✅
