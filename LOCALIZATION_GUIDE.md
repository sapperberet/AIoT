# 🌍 Localization Guide

## Supported Languages

The Smart Home AIoT app supports 3 languages:

1. **English (en)** - Default
2. **Deutsch/German (de)**
3. **العربية/Arabic (ar)**

## How to Use Localized Strings

### Method 1: Using AppLocalizations Directly

```dart
import 'package:smart_home_app/core/localization/app_localizations.dart';

@override
Widget build(BuildContext context) {
  final t = AppLocalizations.of(context).translate;
  
  return Text(t('home'));  // Returns "Home", "Startseite", or "الرئيسية"
}
```

### Method 2: Using the Short Method

```dart
final loc = AppLocalizations.of(context);

return Text(loc.t('settings'));  // Shorter syntax
```

## Changing Language

Users can change the language from **Settings → Language**:

1. Open drawer menu
2. Tap **Settings**
3. Scroll to **General** section
4. Tap **Language**
5. Select from:
   - English
   - Deutsch (German)
   - العربية (Arabic)

The entire app will update immediately when the language is changed.

## Available Translation Keys

### Navigation
- `home`, `devices`, `visualization`, `logs`
- `settings`, `notifications`, `automations`, `energy_monitor`
- `logout`

### Settings
- `profile`, `connection_mode`, `cloud`, `local`
- `appearance`, `theme`, `light`, `dark`, `system`
- `notification_settings`, `enable_notifications`
- `device_status_notifications`, `automation_notifications`, `security_alerts`
- `sound`, `vibration`
- `app_preferences`, `auto_connect`, `offline_mode`
- `data_refresh_interval`, `language`
- `account`, `change_password`, `privacy`, `delete_account`
- `about`, `version`, `help_support`

### Notifications
- `mark_all_read`, `clear_all`
- `no_notifications`, `no_notifications_desc`
- `all`, `device_status`, `automation`, `security`, `info`

### Automations
- `create_automation`
- `no_automations`, `no_automations_desc`
- `triggers`, `conditions`, `actions`
- `last_triggered`, `never`
- `edit`, `run`, `delete`

### Energy Monitor
- `total_consumption`, `consumption_chart`
- `device_breakdown`, `cost_estimate`, `energy_tips`
- `today`, `week`, `month`, `year`

### Common
- `save`, `cancel`, `ok`, `yes`, `no`, `confirm`
- `loading`, `error`, `success`

## Adding New Translations

To add a new translatable string:

1. Open `lib/core/localization/app_localizations.dart`
2. Add the key-value pair to all three language maps (`en`, `de`, `ar`)
3. Use the key in your widget:

```dart
// In app_localizations.dart
'en': {
  'my_new_key': 'My New Text',
  // ... other keys
},
'de': {
  'my_new_key': 'Mein neuer Text',
  // ... other keys  
},
'ar': {
  'my_new_key': 'النص الجديد',
  // ... other keys
},

// In your widget
Text(AppLocalizations.of(context).t('my_new_key'))
```

## Text Direction Support

The app automatically handles RTL (Right-to-Left) text direction for Arabic:

- Arabic text flows from right to left
- Layout elements are mirrored automatically
- No additional code needed - Flutter handles this with the `Directionality` widget

## Implementation Details

### Architecture

```
SettingsProvider (language: 'en', 'de', or 'ar')
        ↓
    main.dart (Sets locale based on language)
        ↓
    MaterialApp (locale: Locale('en'), etc.)
        ↓
    AppLocalizations (Provides translations)
        ↓
    UI Screens (Use translations)
```

### Files Involved

1. **`lib/core/localization/app_localizations.dart`**
   - Contains all translations
   - Provides `AppLocalizations.of(context)` helper
   - Implements `LocalizationsDelegate`

2. **`lib/core/providers/settings_provider.dart`**
   - Stores selected language code
   - Provides `setLanguage(String code)` method

3. **`lib/main.dart`**
   - Maps language code to `Locale`
   - Configures `MaterialApp` with localization delegates
   - Sets `supportedLocales`

4. **`lib/ui/screens/settings/settings_screen.dart`**
   - Provides language picker UI
   - Shows language options with native names

## Testing Different Languages

### During Development

1. Change language in app settings
2. Navigate through different screens
3. Verify all text is translated correctly

### Programmatically

```dart
// Set language to German
Provider.of<SettingsProvider>(context, listen: false).setLanguage('de');

// Set language to Arabic  
Provider.of<SettingsProvider>(context, listen: false).setLanguage('ar');

// Set language to English
Provider.of<SettingsProvider>(context, listen: false).setLanguage('en');
```

## Common Issues

### 1. Missing Translation

**Problem**: Key not found in translation map  
**Solution**: Add the key to all three language maps

### 2. Text Not Updating

**Problem**: Language changed but UI doesn't update  
**Solution**: Ensure you're using `AppLocalizations.of(context)` which rebuilds on locale change

### 3. Arabic Text Not RTL

**Problem**: Arabic text showing LTR  
**Solution**: Flutter automatically handles this when locale is set to `ar`

## Future Improvements

- [ ] Add more languages (French, Spanish, Chinese, etc.)
- [ ] Implement language-specific date/time formatting
- [ ] Add pluralization support
- [ ] Add context-specific translations
- [ ] Integrate with translation management platform

## Quick Reference

```dart
// Get localization instance
final loc = AppLocalizations.of(context);

// Translate a key
loc.t('home')           // "Home" / "Startseite" / "الرئيسية"
loc.t('settings')       // "Settings" / "Einstellungen" / "الإعدادات"
loc.t('notifications')  // "Notifications" / "Benachrichtigungen" / "الإشعارات"

// Check current language
final currentLang = Provider.of<SettingsProvider>(context).language;
// Returns: 'en', 'de', or 'ar'

// Change language
Provider.of<SettingsProvider>(context, listen: false).setLanguage('de');
```

---

**Note**: The app will remember the selected language using `SharedPreferences` (to be implemented in `SettingsProvider.loadSettings()`).
