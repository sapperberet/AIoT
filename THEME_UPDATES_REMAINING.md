# Theme-Aware Updates for All Pages

## Summary
Making all pages (except visualization) theme-aware so colors adapt between light and dark modes.

## Screens to Update

### ✅ **Already Theme-Aware**
- [x] ModernLoginScreen
- [x] EmailPasswordLayerScreen  
- [x] EmailVerificationScreen
- [x] SplashScreen
- [x] EnergyMonitorScreen (partial)
- [x] All loaders/progress indicators

### 🔄 **In Progress**
- [ ] HomeScreen (partial)
- [ ] DevicesTab (partial)
- [ ] SettingsScreen (partial)

### ⚠️ **Still Needs Updates**
- [ ] LogsTab (alarms and events display)
- [ ] NotificationsScreen
- [ ] CustomDrawer
- [ ] AutomationsScreen
- [ ] Other remaining screens

### ❌ **Skip (As Requested)**
- VisualizationTab - Keep as-is, don't change

## Pattern to Apply

For each screen's `build()` method, add:

```dart
@override
Widget build(BuildContext context) {
  final theme = Theme.of(context);
  final isDark = theme.brightness == Brightness.dark;
  final textColor = theme.colorScheme.onBackground;
  
  // Use these variables throughout the widget
}
```

## Color Replacements

### Backgrounds
- `AppTheme.darkBackground` → `theme.scaffoldBackgroundColor`
- `AppTheme.darkCard` → `isDark ? AppTheme.darkCard : AppTheme.lightCard`
- `AppTheme.darkSurface` → `isDark ? AppTheme.darkSurface : AppTheme.lightSurface`

### Text Colors
- `AppTheme.lightText` → `textColor`
- `AppTheme.lightText.withOpacity(0.6)` → `textColor.withOpacity(0.6)`
- `color: AppTheme.lightText` → `color: textColor`

### Gradients
```dart
decoration: BoxDecoration(
  gradient: isDark 
    ? AppTheme.backgroundGradient
    : LinearGradient(
        colors: [AppTheme.lightBackground, AppTheme.lightSurface],
      ),
)
```

### Cards & Containers
```dart
decoration: BoxDecoration(
  gradient: isDark ? AppTheme.cardGradient : null,
  color: isDark ? null : theme.cardTheme.color,
)
```

## Files Modified

1. ✅ `lib/ui/screens/home/home_screen.dart` - Background & icon colors
2. ✅ `lib/ui/screens/home/devices_tab.dart` - Background gradient & text colors
3. ⚠️ `lib/ui/screens/home/logs_tab.dart` - Needs full update
4. ⚠️ `lib/ui/screens/settings/settings_screen.dart` - In progress
5. ⚠️ `lib/ui/screens/notifications/notifications_screen.dart` - Needs update
6. ⚠️ `lib/ui/widgets/custom_drawer.dart` - Needs update

## Testing Checklist

After all updates:
- [ ] Home screen - both themes
- [ ] Devices tab - light & dark
- [ ] Logs tab (alarms & events) - both themes
- [ ] Settings screen - all sections
- [ ] Notifications screen - both themes
- [ ] Drawer - both themes
- [ ] All text is readable
- [ ] All cards/backgrounds adapt
- [ ] Gradients work in both modes
- [ ] Icons have correct colors

## Notes

- VisualizationTab is intentionally NOT updated (per user request)
- Keep primary colors (AppTheme.primaryColor, etc.) unchanged
- Keep error/success/warning colors unchanged
- Only adapt backgrounds, text, and card colors

