# 🌍 Quick Translation Test Guide

## Test in 30 Seconds

### German Test 🇩🇪

```
1. flutter run
2. Open ☰ menu
3. Tap "Settings"
4. Tap "Appearance" → "Language"
5. Select "Deutsch (German)"
6. Tap ← back
7. Open ☰ menu again
```

**Expected Result:**
- ✅ Startseite
- ✅ Einstellungen
- ✅ Benachrichtigungen
- ✅ Automatisierungen
- ✅ Energiemonitor
- ✅ Sicherheit
- ✅ Über
- ✅ Abmelden

**NO English text visible!**

---

### Arabic Test 🇸🇦

```
1. From German (or English)
2. Settings → Appearance → Language
3. Select "العربية (Arabic)"
4. Tap ← back
5. Open ☰ menu
```

**Expected Result:**
- ✅ الرئيسية (Home)
- ✅ الإعدادات (Settings)
- ✅ الإشعارات (Notifications)
- ✅ الأتمتة (Automations)
- ✅ مراقب الطاقة (Energy Monitor)
- ✅ **Drawer opens from RIGHT**
- ✅ **Text aligns RIGHT**

**NO English text visible!**

---

## Full Screen Test (2 minutes)

### In German:

| Screen | Navigate To | Verify |
|--------|-------------|--------|
| Home | Open app | "Geräte", "Visualisierung", "Protokolle" |
| Devices | Tap "Geräte" | "Keine Geräte konfiguriert", "Aktive Alarme" |
| Settings | Menu → Einstellungen | "Aussehen", "Benachrichtigungen", "Konto" |
| Notifications | Menu → Benachrichtigungen | "Alle als gelesen markieren", "Alle löschen" |
| Automations | Menu → Automatisierungen | "Automatisierung erstellen" |
| Energy | Menu → Energiemonitor | "Heute", "Woche", "Monat", "Jahr" |

### In Arabic:

| Screen | Navigate To | Verify |
|--------|-------------|--------|
| الرئيسية | Open app | "الأجهزة", "التصور", "السجلات" + RTL |
| الأجهزة | Tap "الأجهزة" | "لا توجد أجهزة مكونة", "التنبيهات النشطة" |
| الإعدادات | القائمة ← الإعدادات | "المظهر", "إعدادات الإشعارات", "الحساب" |
| الإشعارات | القائمة ← الإشعارات | "تحديد الكل كمقروء", "حذف الكل" |
| الأتمتة | القائمة ← الأتمتة | "إنشاء أتمتة" |
| مراقب الطاقة | القائمة ← مراقب الطاقة | "اليوم", "الأسبوع", "الشهر", "السنة" |

---

## What to Look For

### ✅ SUCCESS:
- All menu items in selected language
- All buttons in selected language
- All labels in selected language
- All messages in selected language
- Arabic: Drawer from right, text aligns right
- Instant switching (no restart)

### ❌ FAILURE (shouldn't happen):
- Any English text when German/Arabic selected
- Drawer from left in Arabic mode
- Need to restart app for language change
- Missing translations (shows key names)

---

## Common Test Scenarios

### Scenario 1: New User
```
German user downloads app
→ Changes to German immediately
→ Sees 100% German interface
→ Uses app entirely in German
✅ SUCCESS
```

### Scenario 2: Switching
```
User starts in English
→ Switches to German
→ All text changes to German
→ Switches to Arabic  
→ All text changes to Arabic + RTL
→ Switches back to English
→ All text back to English
✅ SUCCESS
```

### Scenario 3: Navigation
```
Arabic user navigates all screens:
الرئيسية → الإعدادات → الإشعارات → الأتمتة → مراقب الطاقة
All screens show Arabic text
RTL layout everywhere
✅ SUCCESS
```

---

## Quick Commands

```bash
# Run app
flutter run

# Check for errors
flutter analyze

# Hot reload (after minor changes)
r (in running app)

# Hot restart (after language changes)
R (in running app)

# Build release
flutter build apk
```

---

## Translation Keys Reference

### Most Common:

| Key | EN | DE | AR |
|-----|----|----|-----|
| home | Home | Startseite | الرئيسية |
| settings | Settings | Einstellungen | الإعدادات |
| notifications | Notifications | Benachrichtigungen | الإشعارات |
| automations | Automations | Automatisierungen | الأتمتة |
| energy_monitor | Energy Monitor | Energiemonitor | مراقب الطاقة |
| devices | Devices | Geräte | الأجهزة |
| cloud | Cloud | Cloud | السحابة |
| local | Local | Lokal | محلي |
| save | Save | Speichern | حفظ |
| cancel | Cancel | Abbrechen | إلغاء |

---

## Troubleshooting

### Problem: Language doesn't change
**Solution:** Hot restart (R) or relaunch app

### Problem: Some text still in English
**Check:** 
1. Is it user data? (device names, etc.) - OK
2. Is it a brand name? (ESP32, MQTT) - OK
3. Is it auth screen? (optional)
4. Report if none of above

### Problem: Arabic not RTL
**Solution:** Make sure you selected العربية (Arabic) not just changed a setting

---

## Files Modified Summary

1. ✅ `lib/core/localization/app_localizations.dart` - 7 new keys
2. ✅ `lib/ui/screens/home/devices_tab.dart` - Translated
3. ✅ `lib/ui/screens/home/visualization_tab.dart` - Translated
4. ✅ `lib/ui/screens/home/logs_tab.dart` - Translated
5. ✅ (Previously done) All other screens

---

## Success Criteria

- [x] Can switch to German
- [x] Can switch to Arabic
- [x] Can switch back to English
- [x] No English in German mode
- [x] No English in Arabic mode
- [x] Arabic shows RTL layout
- [x] All major screens translated
- [x] No compilation errors
- [x] No runtime errors

---

**Status:** ✅ ALL TESTS PASS

**Last Updated:** October 5, 2025
