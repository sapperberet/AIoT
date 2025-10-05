import 'package:flutter/material.dart';

class AppLocalizations {
  final Locale locale;

  AppLocalizations(this.locale);

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  static final Map<String, Map<String, String>> _localizedValues = {
    'en': {
      'app_title': 'Smart Home',
      'home': 'Home',
      'devices': 'Devices',
      'visualization': 'Visualization',
      'logs': 'Logs',
      'settings': 'Settings',
      'notifications': 'Notifications',
      'automations': 'Automations',
      'energy_monitor': 'Energy Monitor',
      'logout': 'Logout',

      // Settings
      'profile': 'Profile',
      'connection_mode': 'Connection Mode',
      'cloud': 'Cloud',
      'local': 'Local',
      'appearance': 'Appearance',
      'theme': 'Theme',
      'light': 'Light',
      'dark': 'Dark',
      'system': 'System',
      'notification_settings': 'Notification Settings',
      'enable_notifications': 'Enable Notifications',
      'device_status_notifications': 'Device Status',
      'automation_notifications': 'Automation Alerts',
      'security_alerts': 'Security Alerts',
      'sound': 'Sound',
      'vibration': 'Vibration',
      'app_preferences': 'App Preferences',
      'auto_connect': 'Auto-Connect',
      'offline_mode': 'Offline Mode',
      'data_refresh_interval': 'Data Refresh Interval',
      'language': 'Language',
      'account': 'Account',
      'change_password': 'Change Password',
      'privacy': 'Privacy & Security',
      'delete_account': 'Delete Account',
      'about': 'About',
      'version': 'Version',
      'help_support': 'Help & Support',

      // Notifications
      'mark_all_read': 'Mark all as read',
      'clear_all': 'Clear all',
      'no_notifications': 'No notifications yet',
      'no_notifications_desc':
          'When you receive notifications, they will appear here.',
      'all': 'All',
      'device_status': 'Device Status',
      'automation': 'Automation',
      'security': 'Security',
      'info': 'Info',

      // Automations
      'create_automation': 'Create Automation',
      'no_automations': 'No automations yet',
      'no_automations_desc':
          'Create your first automation to make your home smarter.',
      'triggers': 'Triggers',
      'conditions': 'Conditions',
      'actions': 'Actions',
      'last_triggered': 'Last triggered',
      'never': 'Never',
      'edit': 'Edit',
      'run': 'Run',
      'delete': 'Delete',

      // Energy Monitor
      'total_consumption': 'Total Consumption',
      'consumption_chart': 'Consumption Chart',
      'device_breakdown': 'Device Breakdown',
      'cost_estimate': 'Cost Estimate',
      'energy_tips': 'Energy Saving Tips',
      'today': 'Today',
      'week': 'Week',
      'month': 'Month',
      'year': 'Year',

      // Common
      'save': 'Save',
      'cancel': 'Cancel',
      'ok': 'OK',
      'yes': 'Yes',
      'no': 'No',
      'confirm': 'Confirm',
      'loading': 'Loading...',
      'error': 'Error',
      'success': 'Success',
      'seconds': 'seconds',
    },
    'de': {
      'app_title': 'Smart Home',
      'home': 'Startseite',
      'devices': 'Geräte',
      'visualization': 'Visualisierung',
      'logs': 'Protokolle',
      'settings': 'Einstellungen',
      'notifications': 'Benachrichtigungen',
      'automations': 'Automatisierungen',
      'energy_monitor': 'Energiemonitor',
      'logout': 'Abmelden',

      // Settings
      'profile': 'Profil',
      'connection_mode': 'Verbindungsmodus',
      'cloud': 'Cloud',
      'local': 'Lokal',
      'appearance': 'Aussehen',
      'theme': 'Thema',
      'light': 'Hell',
      'dark': 'Dunkel',
      'system': 'System',
      'notification_settings': 'Benachrichtigungseinstellungen',
      'enable_notifications': 'Benachrichtigungen aktivieren',
      'device_status_notifications': 'Gerätestatus',
      'automation_notifications': 'Automatisierungswarnungen',
      'security_alerts': 'Sicherheitswarnungen',
      'sound': 'Ton',
      'vibration': 'Vibration',
      'app_preferences': 'App-Einstellungen',
      'auto_connect': 'Automatisch verbinden',
      'offline_mode': 'Offline-Modus',
      'data_refresh_interval': 'Datenaktualisierungsintervall',
      'language': 'Sprache',
      'account': 'Konto',
      'change_password': 'Passwort ändern',
      'privacy': 'Datenschutz & Sicherheit',
      'delete_account': 'Konto löschen',
      'about': 'Über',
      'version': 'Version',
      'help_support': 'Hilfe & Support',

      // Notifications
      'mark_all_read': 'Alle als gelesen markieren',
      'clear_all': 'Alle löschen',
      'no_notifications': 'Noch keine Benachrichtigungen',
      'no_notifications_desc':
          'Wenn Sie Benachrichtigungen erhalten, werden sie hier angezeigt.',
      'all': 'Alle',
      'device_status': 'Gerätestatus',
      'automation': 'Automatisierung',
      'security': 'Sicherheit',
      'info': 'Info',

      // Automations
      'create_automation': 'Automatisierung erstellen',
      'no_automations': 'Noch keine Automatisierungen',
      'no_automations_desc':
          'Erstellen Sie Ihre erste Automatisierung, um Ihr Zuhause intelligenter zu machen.',
      'triggers': 'Auslöser',
      'conditions': 'Bedingungen',
      'actions': 'Aktionen',
      'last_triggered': 'Zuletzt ausgelöst',
      'never': 'Nie',
      'edit': 'Bearbeiten',
      'run': 'Ausführen',
      'delete': 'Löschen',

      // Energy Monitor
      'total_consumption': 'Gesamtverbrauch',
      'consumption_chart': 'Verbrauchsdiagramm',
      'device_breakdown': 'Geräteaufschlüsselung',
      'cost_estimate': 'Kostenschätzung',
      'energy_tips': 'Energiespartipps',
      'today': 'Heute',
      'week': 'Woche',
      'month': 'Monat',
      'year': 'Jahr',

      // Common
      'save': 'Speichern',
      'cancel': 'Abbrechen',
      'ok': 'OK',
      'yes': 'Ja',
      'no': 'Nein',
      'confirm': 'Bestätigen',
      'loading': 'Lädt...',
      'error': 'Fehler',
      'success': 'Erfolg',
      'seconds': 'Sekunden',
    },
    'ar': {
      'app_title': 'المنزل الذكي',
      'home': 'الرئيسية',
      'devices': 'الأجهزة',
      'visualization': 'التصور',
      'logs': 'السجلات',
      'settings': 'الإعدادات',
      'notifications': 'الإشعارات',
      'automations': 'الأتمتة',
      'energy_monitor': 'مراقب الطاقة',
      'logout': 'تسجيل الخروج',

      // Settings
      'profile': 'الملف الشخصي',
      'connection_mode': 'وضع الاتصال',
      'cloud': 'السحابة',
      'local': 'محلي',
      'appearance': 'المظهر',
      'theme': 'السمة',
      'light': 'فاتح',
      'dark': 'داكن',
      'system': 'النظام',
      'notification_settings': 'إعدادات الإشعارات',
      'enable_notifications': 'تفعيل الإشعارات',
      'device_status_notifications': 'حالة الجهاز',
      'automation_notifications': 'تنبيهات الأتمتة',
      'security_alerts': 'تنبيهات الأمان',
      'sound': 'الصوت',
      'vibration': 'الاهتزاز',
      'app_preferences': 'تفضيلات التطبيق',
      'auto_connect': 'الاتصال التلقائي',
      'offline_mode': 'وضع عدم الاتصال',
      'data_refresh_interval': 'فترة تحديث البيانات',
      'language': 'اللغة',
      'account': 'الحساب',
      'change_password': 'تغيير كلمة المرور',
      'privacy': 'الخصوصية والأمان',
      'delete_account': 'حذف الحساب',
      'about': 'حول',
      'version': 'الإصدار',
      'help_support': 'المساعدة والدعم',

      // Notifications
      'mark_all_read': 'تحديد الكل كمقروء',
      'clear_all': 'حذف الكل',
      'no_notifications': 'لا توجد إشعارات حتى الآن',
      'no_notifications_desc': 'عند استلام الإشعارات، ستظهر هنا.',
      'all': 'الكل',
      'device_status': 'حالة الجهاز',
      'automation': 'الأتمتة',
      'security': 'الأمان',
      'info': 'معلومات',

      // Automations
      'create_automation': 'إنشاء أتمتة',
      'no_automations': 'لا توجد أتمتة حتى الآن',
      'no_automations_desc': 'أنشئ أول أتمتة لجعل منزلك أكثر ذكاءً.',
      'triggers': 'المحفزات',
      'conditions': 'الشروط',
      'actions': 'الإجراءات',
      'last_triggered': 'آخر تفعيل',
      'never': 'أبداً',
      'edit': 'تعديل',
      'run': 'تشغيل',
      'delete': 'حذف',

      // Energy Monitor
      'total_consumption': 'إجمالي الاستهلاك',
      'consumption_chart': 'مخطط الاستهلاك',
      'device_breakdown': 'تفصيل الأجهزة',
      'cost_estimate': 'تقدير التكلفة',
      'energy_tips': 'نصائح توفير الطاقة',
      'today': 'اليوم',
      'week': 'الأسبوع',
      'month': 'الشهر',
      'year': 'السنة',

      // Common
      'save': 'حفظ',
      'cancel': 'إلغاء',
      'ok': 'موافق',
      'yes': 'نعم',
      'no': 'لا',
      'confirm': 'تأكيد',
      'loading': 'جاري التحميل...',
      'error': 'خطأ',
      'success': 'نجاح',
      'seconds': 'ثواني',
    },
  };

  String translate(String key) {
    return _localizedValues[locale.languageCode]?[key] ?? key;
  }

  // Shorthand method
  String t(String key) => translate(key);
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) {
    return ['en', 'de', 'ar'].contains(locale.languageCode);
  }

  @override
  Future<AppLocalizations> load(Locale locale) async {
    return AppLocalizations(locale);
  }

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}
