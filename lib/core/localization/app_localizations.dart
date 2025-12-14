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
      'search_notifications': 'Search notifications...',
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

      // Camera Feed
      'camera_feed': 'Camera Feed',

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

      // Devices Tab
      'active_alarms': 'Active Alarms',
      'clear': 'Clear',
      'no_devices': 'No devices configured',
      'add_devices_desc': 'Add your ESP32 devices to get started',
      'control_lights': 'Control Lights',
      'temperature': 'Temperature',

      // Logs Tab
      'please_login': 'Please log in to view logs',

      // Splash Screen
      'control_world': 'Control your world, effortlessly',

      // Auth Screens
      'create_account': 'Create Account',
      'sign_in': 'Sign In',
      'no_account': 'Don\'t have an account? Sign Up',
      'have_account': 'Already have an account? Sign In',
      'email': 'Email',
      'password': 'Password',
      'full_name': 'Full Name',
      'confirm_password': 'Confirm Password',
      'welcome_back': 'Welcome Back',
      'sign_in_subtitle': 'Sign in to control your smart home',
      'join_us': 'Join Us',
      'create_account_subtitle': 'Create your smart home account',
      'enter_email': 'Please enter your email',
      'valid_email': 'Please enter a valid email',
      'enter_password': 'Please enter your password',
      'password_length': 'Password must be at least 6 characters',
      'enter_name': 'Please enter your name',
      'passwords_match': 'Passwords do not match',
      'passwords_dont_match': 'Passwords do not match',
      'enter_confirm_password': 'Please confirm your password',
      'sign_up': 'Sign Up',
      'already_have_account': 'Already have an account?',
      'account_created_successfully': 'Account created successfully!',

      // Password Recovery
      'forgot_password': 'Forgot Password?',
      'forgot_password_desc':
          'Enter your email address and we\'ll send you a link to reset your password.',
      'send_reset_link': 'Send Reset Link',
      'password_reset_sent': 'Password reset email sent!',
      'check_your_email': 'Check Your Email',
      'password_reset_email_sent_desc':
          'We\'ve sent you a password reset link.',
      'password_reset_instructions':
          'Click the link in the email to reset your password. The link will expire in 1 hour.',
      'back_to_login': 'Back to Login',
      'password_reset_info':
          'If you don\'t receive the email within a few minutes, check your spam folder or try again.',

      // Biometric Authentication
      'enable_biometric': 'Enable Biometric Authentication',
      'biometric_enabled': 'Biometric authentication enabled',
      'skip': 'Skip',
      'enable': 'Enable',

      // Face Authentication
      'face_auth_title': 'Face Recognition',
      'face_auth_subtitle': 'Secure and fast authentication',
      'sign_in_with_face': 'Sign in with Face Recognition',
      'discovering': 'Discovering service...',
      'connecting': 'Connecting...',
      'requesting_scan': 'Requesting scan...',
      'initializing': 'Initializing camera...',
      'scanning': 'Look at the Camera',
      'scanning_subtitle': 'Position your face in front of the camera',
      'processing': 'Processing...',
      'processing_subtitle': 'Verifying your identity',
      'auth_success': 'Success!',
      'auth_success_subtitle': 'Authentication successful',
      'auth_failed': 'Failed',
      'auth_failed_subtitle': 'Face not recognized',
      'auth_timeout': 'Timeout',
      'auth_timeout_subtitle': 'Request timed out. Please try again.',
      'auth_error': 'Error',
      'auth_error_subtitle': 'An error occurred',
      'try_again': 'Try Again',
      'beacon_info': 'Beacon Information',
      'service_name': 'Service',
      'ip_address': 'IP Address',
      'port': 'Port',
      'discovered_at': 'Discovered',
      'authentication_failed': 'Authentication Failed',
      'please_try_again': 'Please try again or use email/password.',

      // Login Screen
      'authenticate_with_face': 'Authenticate with face recognition',
      'tap_to_authenticate': 'Tap to Authenticate',
      'two_factor_info':
          'Face recognition is required. Configure additional security layer (email/password) in Settings after login.',

      // Layer 2 Authentication
      'second_layer_auth': 'Second Layer Authentication',
      'face_success_verify':
          'Face recognition successful ✓\nVerify your email and password to continue',
      'verify_credentials': 'Verify Credentials',
      'verifying': 'Verifying...',

      // Language Names
      'language_english': 'English',
      'language_german': 'Deutsch (German)',
      'language_arabic': 'العربية (Arabic)',

      // AI Chat
      'ai_assistant': 'AI Assistant',
      'ai_chat': 'AI Chat',
      'online': 'Online',
      'offline': 'Offline',
      'ai_chat_welcome':
          'Ask me anything about your smart home. I can help you control devices, create automations, and answer questions.',
      'suggestion_status': 'What\'s the status of my devices?',
      'suggestion_automation': 'Help me create an automation',
      'suggestion_energy': 'Show me my energy consumption',
      'type_message': 'Type a message...',
      'waiting_for_response': 'Waiting for response...',
      'stop_response': 'Stop response',
      'configure_server': 'Configure Server',
      'clear_chat': 'Clear Chat',
      'clear_chat_confirm': 'Are you sure you want to clear all chat messages?',
      'server_url': 'Server URL',
      'ai_server_url_hint':
          'Enter the URL of your AI agent server running on your Linux machine',
      'server_url_updated': 'Server URL updated successfully',
      'retry': 'Retry',
      'show_think_mode': 'Show AI Reasoning',
      'think_mode_description': 'Display internal AI thought process',
      'chat_with_me': 'Chat with me',

      // Chat Sessions
      'chat_history': 'Chat History',
      'new_chat': 'New Chat',
      'no_chat_history': 'No chat history',
      'start_new_chat_hint': 'Start a new conversation with the AI assistant',
      'delete_sessions': 'Delete Sessions',
      'delete_sessions_confirm':
          'Are you sure you want to delete {count} session(s)?',
      'delete_all_sessions': 'Delete All Sessions',
      'delete_all_sessions_confirm':
          'Are you sure you want to delete all chat sessions? This cannot be undone.',
      'selected': 'selected',
      'select': 'Select',
      'delete_all': 'Delete All',
      'active': 'Active',

      // Voice Messages
      'voice_permission_denied':
          'Microphone permission denied. Please enable it in settings.',
      'voice_message': 'Voice message',
      'recording': 'Recording...',
      'send_voice': 'Send voice message',
      'microphone_permission_required': 'Microphone Permission Required',
      'microphone_permission_message':
          'This app needs microphone access to record voice messages. Please grant permission in your device settings.',
      'open_settings': 'Open Settings',
      'error_starting_recording': 'Error starting recording',
      'open_voice_to_voice_screen': 'Open Voice-to-Voice Screen',
      'dedicated_voice_conversation':
          'Dedicated screen for hands-free voice conversation',

      // Voice Settings
      'voice_settings': 'Voice Settings',
      'voice_mode': 'Voice Mode',
      'text_only': 'Text Only',
      'text_only_desc': 'Standard text-based chat',
      'voice_to_text': 'Voice to Text',
      'voice_to_text_desc': 'Speak your message, receive text reply',
      'voice_to_voice': 'Voice to Voice',
      'voice_to_voice_desc': 'Full voice conversation with AI',
      'service_status': 'Service Status',
      'tts_service': 'Text-to-Speech (Piper)',
      'asr_service': 'Speech Recognition (Whisper)',
      'voice_chat_service': 'Voice Chat API',
      'refresh': 'Refresh',
      'done': 'Done',
      'ready_to_talk': 'Ready to talk',
      'listening': 'Listening...',
      'recording_failed': 'Recording failed',
      'tap_to_speak': 'Tap to Speak',
      'v2v_instructions':
          'Tap the button to start speaking. The system will automatically detect when you finish, or you can tap Send.',

      // LLM Provider Settings
      'llm_provider': 'AI Model Provider',
      'select_provider': 'Select Provider',
      'n8n_local': 'Local n8n Workflow',
      'n8n_local_desc': 'Uses n8n automation server on your network',
      'ollama_local': 'Local Ollama',
      'ollama_local_desc': 'Direct connection to Ollama LLM server',
      'external_llm': 'External LLM (Cloud)',
      'external_llm_desc': 'Connect to cloud-hosted LLM via ngrok',
      'external_config': 'External LLM Configuration',
      'llm_url': 'LLM Server URL',
      'api_key': 'API Key',
      'local_server': 'Local AI Server',
      'llm_provider_updated': 'AI provider settings updated',

      // Biometric Authentication
      'enable_biometric_login': 'Enable Biometric Login',
      'biometric_verify_to_enable':
          'Verify your identity to enable biometric login',
      'biometric_enabled_success': 'Biometric login enabled successfully',
      'biometric_login_description':
          'Use {biometricType} for quick login and bypass face recognition',
      'biometric_login_prompt': 'Authenticate to access Smart Home',
      'biometric_not_available':
          'Biometric authentication is not available on this device',
      'biometric_login_failed': 'Biometric authentication failed',
      'biometric_disabled': 'Biometric Login',
      'enable_in_settings': 'Enable in Settings after logging in',
      'enable_biometric_in_settings':
          'Enable biometric login in Settings after your first login',

      // User Management
      'user_management': 'User Management',
      'search_users': 'Search users by name, email, or ID...',
      'new_users': 'New Users',
      'pending': 'Pending',
      'suspicious': 'Suspicious',
      'banned': 'Banned',
      'admins': 'Administrators',
      'no_users_found': 'No users found',
      'pending_approvals': 'Pending Approvals',
      'user_approval': 'User Approval',
      'no_pending_users': 'No Pending Requests',
      'approve': 'Approve',
      'reject': 'Reject',
      'approval_pending': 'Your account is pending approval',
      'waiting_for_admin': 'Waiting for administrator approval',
      'account_approved': 'Account Approved',
      'account_rejected': 'Account Rejected',
      'pending_approval_title': 'Account Pending Approval',
      'pending_approval_description':
          'Your registration was successful! An administrator has been notified and will review your access request shortly.',
      'pending_approval_info':
          'An OTP code has been sent to administrators. You will be able to access the app once an admin approves your request.',
      'check_approval_status': 'Check Approval Status',
      'approval_still_pending':
          'Your account is still pending approval. Please wait for an administrator to approve your access.',
      'account_created_pending_approval':
          'Account created! Waiting for admin approval.',

      // Chat Theme Settings
      'chat_appearance': 'Chat Appearance',
      'themes': 'Themes',
      'colors': 'Colors',
      'style': 'Style',
      'reset': 'Reset',
      'your_messages': 'Your Messages',
      'customize_your_bubble_color': 'Customize your bubble color',
      'ai_messages': 'AI Messages',
      'customize_ai_bubble_color': 'Customize AI bubble color',
      'quick_colors': 'Quick Colors',
      'font_size': 'Font Size',
      'bubble_roundness': 'Bubble Roundness',
      'font_family': 'Font Family',
      'show_timestamps': 'Show Timestamps',
      'show_message_time': 'Display time on each message',
      'show_avatars': 'Show Avatars',
      'show_profile_pictures': 'Display profile pictures',
      'preview': 'Preview',
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
      'search_notifications': 'Benachrichtigungen durchsuchen...',
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

      // Camera Feed
      'camera_feed': 'Kamera-Feed',

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

      // Devices Tab
      'active_alarms': 'Aktive Alarme',
      'clear': 'Löschen',
      'no_devices': 'Keine Geräte konfiguriert',
      'add_devices_desc': 'Fügen Sie Ihre ESP32-Geräte hinzu, um zu beginnen',
      'control_lights': 'Lichter steuern',
      'temperature': 'Temperatur',

      // Logs Tab
      'please_login': 'Bitte melden Sie sich an, um Protokolle anzuzeigen',

      // Splash Screen
      'control_world': 'Steuern Sie Ihre Welt mühelos',

      // Auth Screens
      'create_account': 'Konto erstellen',
      'sign_in': 'Anmelden',
      'no_account': 'Noch kein Konto? Registrieren',
      'have_account': 'Haben Sie bereits ein Konto? Anmelden',
      'email': 'E-Mail',
      'password': 'Passwort',
      'full_name': 'Vollständiger Name',
      'confirm_password': 'Passwort bestätigen',
      'welcome_back': 'Willkommen zurück',
      'sign_in_subtitle': 'Melden Sie sich an, um Ihr Smart Home zu steuern',
      'join_us': 'Registrieren Sie sich',
      'create_account_subtitle': 'Erstellen Sie Ihr Smart-Home-Konto',
      'enter_email': 'Bitte geben Sie Ihre E-Mail ein',
      'valid_email': 'Bitte geben Sie eine gültige E-Mail ein',
      'enter_password': 'Bitte geben Sie Ihr Passwort ein',
      'password_length': 'Passwort muss mindestens 6 Zeichen lang sein',
      'enter_name': 'Bitte geben Sie Ihren Namen ein',
      'passwords_match': 'Passwörter stimmen nicht überein',
      'enter_confirm_password': 'Bitte bestätigen Sie Ihr Passwort',

      // Face Authentication
      'face_auth_title': 'Gesichtserkennung',
      'face_auth_subtitle': 'Sichere und schnelle Authentifizierung',
      'sign_in_with_face': 'Mit Gesichtserkennung anmelden',
      'discovering': 'Dienst wird gesucht...',
      'connecting': 'Verbinde...',
      'requesting_scan': 'Scan wird angefordert...',
      'initializing': 'Kamera wird initialisiert...',
      'scanning': 'Schauen Sie in die Kamera',
      'scanning_subtitle': 'Positionieren Sie Ihr Gesicht vor der Kamera',
      'processing': 'Verarbeitung...',
      'processing_subtitle': 'Ihre Identität wird überprüft',
      'auth_success': 'Erfolg!',
      'auth_success_subtitle': 'Authentifizierung erfolgreich',
      'auth_failed': 'Fehlgeschlagen',
      'auth_failed_subtitle': 'Gesicht nicht erkannt',
      'auth_timeout': 'Zeitüberschreitung',
      'auth_timeout_subtitle':
          'Anfrage zeitüberschritten. Bitte versuchen Sie es erneut.',
      'auth_error': 'Fehler',
      'auth_error_subtitle': 'Ein Fehler ist aufgetreten',
      'try_again': 'Erneut versuchen',
      'beacon_info': 'Beacon-Informationen',
      'service_name': 'Dienst',
      'ip_address': 'IP-Adresse',
      'port': 'Port',
      'discovered_at': 'Entdeckt',
      'authentication_failed': 'Authentifizierung fehlgeschlagen',
      'please_try_again':
          'Bitte versuchen Sie es erneut oder verwenden Sie E-Mail/Passwort.',

      // Login Screen
      'authenticate_with_face': 'Mit Gesichtserkennung authentifizieren',
      'tap_to_authenticate': 'Zum Authentifizieren tippen',
      'two_factor_info':
          'Gesichtserkennung ist erforderlich. Konfigurieren Sie nach der Anmeldung eine zusätzliche Sicherheitsebene (E-Mail/Passwort) in den Einstellungen.',

      // Layer 2 Authentication
      'second_layer_auth': 'Zweite Authentifizierungsebene',
      'face_success_verify':
          'Gesichtserkennung erfolgreich ✓\nBestätigen Sie Ihre E-Mail und Passwort, um fortzufahren',
      'verify_credentials': 'Anmeldedaten überprüfen',
      'verifying': 'Überprüfung läuft...',

      // Language Names
      'language_english': 'English',
      'language_german': 'Deutsch (German)',
      'language_arabic': 'العربية (Arabic)',

      // AI Chat
      'ai_assistant': 'KI-Assistent',
      'ai_chat': 'KI-Chat',
      'online': 'Online',
      'offline': 'Offline',
      'ai_chat_welcome':
          'Fragen Sie mich alles über Ihr Smart Home. Ich kann Ihnen helfen, Geräte zu steuern, Automatisierungen zu erstellen und Fragen zu beantworten.',
      'suggestion_status': 'Was ist der Status meiner Geräte?',
      'suggestion_automation': 'Hilf mir eine Automatisierung zu erstellen',
      'suggestion_energy': 'Zeige mir meinen Energieverbrauch',
      'type_message': 'Nachricht eingeben...',
      'waiting_for_response': 'Warte auf Antwort...',
      'stop_response': 'Antwort stoppen',
      'configure_server': 'Server konfigurieren',
      'clear_chat': 'Chat löschen',
      'clear_chat_confirm':
          'Sind Sie sicher, dass Sie alle Chat-Nachrichten löschen möchten?',
      'server_url': 'Server-URL',
      'ai_server_url_hint':
          'Geben Sie die URL Ihres KI-Agentenservers ein, der auf Ihrer Linux-Maschine läuft',
      'server_url_updated': 'Server-URL erfolgreich aktualisiert',
      'retry': 'Wiederholen',
      'show_think_mode': 'KI-Denken anzeigen',
      'think_mode_description': 'Internen KI-Denkprozess anzeigen',
      'chat_with_me': 'Chatte mit mir',

      // Chat Sessions
      'chat_history': 'Chat-Verlauf',
      'new_chat': 'Neuer Chat',
      'no_chat_history': 'Kein Chat-Verlauf',
      'start_new_chat_hint':
          'Starten Sie eine neue Unterhaltung mit dem KI-Assistenten',
      'delete_sessions': 'Sitzungen löschen',
      'delete_sessions_confirm':
          'Sind Sie sicher, dass Sie {count} Sitzung(en) löschen möchten?',
      'delete_all_sessions': 'Alle Sitzungen löschen',
      'delete_all_sessions_confirm':
          'Sind Sie sicher, dass Sie alle Chat-Sitzungen löschen möchten? Dies kann nicht rückgängig gemacht werden.',
      'selected': 'ausgewählt',
      'select': 'Auswählen',
      'delete_all': 'Alle löschen',
      'active': 'Aktiv',

      // Voice Messages
      'voice_permission_denied':
          'Mikrofon-Berechtigung verweigert. Bitte aktivieren Sie sie in den Einstellungen.',
      'voice_message': 'Sprachnachricht',
      'recording': 'Aufnahme läuft...',
      'send_voice': 'Sprachnachricht senden',
      'microphone_permission_required': 'Mikrofon-Berechtigung erforderlich',
      'microphone_permission_message':
          'Diese App benötigt Mikrofon-Zugriff, um Sprachnachrichten aufzunehmen. Bitte erteilen Sie die Berechtigung in Ihren Geräteeinstellungen.',
      'open_settings': 'Einstellungen öffnen',
      'error_starting_recording': 'Fehler beim Starten der Aufnahme',
      'open_voice_to_voice_screen': 'Sprache-zu-Sprache-Bildschirm öffnen',
      'dedicated_voice_conversation':
          'Dedizierter Bildschirm für freihändige Sprachkonversation',

      // Voice Settings
      'voice_settings': 'Spracheinstellungen',
      'voice_mode': 'Sprachmodus',
      'text_only': 'Nur Text',
      'text_only_desc': 'Standard textbasierter Chat',
      'voice_to_text': 'Sprache zu Text',
      'voice_to_text_desc':
          'Sprechen Sie Ihre Nachricht, erhalten Sie Textantwort',
      'voice_to_voice': 'Sprache zu Sprache',
      'voice_to_voice_desc': 'Vollständiges Sprachgespräch mit KI',
      'service_status': 'Dienststatus',
      'tts_service': 'Text-zu-Sprache (Piper)',
      'asr_service': 'Spracherkennung (Whisper)',
      'voice_chat_service': 'Sprach-Chat-API',
      'refresh': 'Aktualisieren',
      'done': 'Fertig',
      'ready_to_talk': 'Bereit zum Sprechen',
      'listening': 'Zuhören...',
      'recording_failed': 'Aufnahme fehlgeschlagen',
      'tap_to_speak': 'Tippen zum Sprechen',
      'v2v_instructions':
          'Tippen Sie auf die Schaltfläche, um zu sprechen. Das System erkennt automatisch, wenn Sie fertig sind, oder Sie können auf Senden tippen.',

      // LLM Provider Settings
      'llm_provider': 'KI-Modell-Anbieter',
      'select_provider': 'Anbieter auswählen',
      'n8n_local': 'Lokaler n8n-Workflow',
      'n8n_local_desc':
          'Verwendet n8n-Automatisierungsserver in Ihrem Netzwerk',
      'ollama_local': 'Lokales Ollama',
      'ollama_local_desc': 'Direkte Verbindung zum Ollama-LLM-Server',
      'external_llm': 'Externes LLM (Cloud)',
      'external_llm_desc': 'Verbindung zu Cloud-gehostetem LLM über ngrok',
      'external_config': 'Externe LLM-Konfiguration',
      'llm_url': 'LLM-Server-URL',
      'api_key': 'API-Schlüssel',
      'local_server': 'Lokaler KI-Server',
      'llm_provider_updated': 'KI-Anbieter-Einstellungen aktualisiert',

      // Biometric Authentication
      'enable_biometric_login': 'Biometrische Anmeldung aktivieren',
      'biometric_verify_to_enable':
          'Bestätigen Sie Ihre Identität, um die biometrische Anmeldung zu aktivieren',
      'biometric_enabled_success':
          'Biometrische Anmeldung erfolgreich aktiviert',
      'biometric_login_description':
          'Verwenden Sie {biometricType}, um sich schnell anzumelden und die Gesichtserkennung zu umgehen',
      'biometric_login_prompt':
          'Authentifizieren Sie sich, um auf Smart Home zuzugreifen',
      'biometric_not_available':
          'Biometrische Authentifizierung ist auf diesem Gerät nicht verfügbar',
      'biometric_login_failed': 'Biometrische Authentifizierung fehlgeschlagen',
      'biometric_disabled': 'Biometrische Anmeldung',
      'enable_in_settings': 'Nach der Anmeldung in Einstellungen aktivieren',
      'enable_biometric_in_settings':
          'Biometrische Anmeldung in den Einstellungen nach der ersten Anmeldung aktivieren',

      // User Management
      'user_management': 'Benutzerverwaltung',
      'search_users': 'Benutzer nach Name, E-Mail oder ID suchen...',
      'new_users': 'Neue Benutzer',
      'pending': 'Ausstehend',
      'suspicious': 'Verdächtig',
      'banned': 'Gesperrt',
      'admins': 'Administratoren',
      'no_users_found': 'Keine Benutzer gefunden',
      'pending_approvals': 'Ausstehende Genehmigungen',
      'user_approval': 'Benutzergenehmigung',
      'no_pending_users': 'Keine ausstehenden Anfragen',
      'approve': 'Genehmigen',
      'reject': 'Ablehnen',
      'approval_pending': 'Ihr Konto wartet auf Genehmigung',
      'waiting_for_admin': 'Warten auf Administratorgenehmigung',
      'account_approved': 'Konto Genehmigt',
      'account_rejected': 'Konto Abgelehnt',
      'pending_approval_title': 'Konto wartet auf Genehmigung',
      'pending_approval_description':
          'Ihre Registrierung war erfolgreich! Ein Administrator wurde benachrichtigt und wird Ihre Zugriffsanfrage in Kürze prüfen.',
      'pending_approval_info':
          'Ein OTP-Code wurde an Administratoren gesendet. Sie können auf die App zugreifen, sobald ein Administrator Ihre Anfrage genehmigt.',
      'check_approval_status': 'Genehmigungsstatus prüfen',
      'approval_still_pending':
          'Ihr Konto wartet noch auf Genehmigung. Bitte warten Sie, bis ein Administrator Ihren Zugang genehmigt.',
      'account_created_pending_approval':
          'Konto erstellt! Warten auf Admin-Genehmigung.',

      // Chat Theme Settings
      'chat_appearance': 'Chat-Erscheinung',
      'themes': 'Themen',
      'colors': 'Farben',
      'style': 'Stil',
      'reset': 'Zurücksetzen',
      'your_messages': 'Ihre Nachrichten',
      'customize_your_bubble_color': 'Passen Sie Ihre Sprechblasenfarbe an',
      'ai_messages': 'AI-Nachrichten',
      'customize_ai_bubble_color': 'AI-Sprechblasenfarbe anpassen',
      'quick_colors': 'Schnellfarben',
      'font_size': 'Schriftgröße',
      'bubble_roundness': 'Blasenrundheit',
      'font_family': 'Schriftart',
      'show_timestamps': 'Zeitstempel anzeigen',
      'show_message_time': 'Zeit bei jeder Nachricht anzeigen',
      'show_avatars': 'Avatare anzeigen',
      'show_profile_pictures': 'Profilbilder anzeigen',
      'preview': 'Vorschau',
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
      'search_notifications': 'البحث في الإشعارات...',
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

      // Camera Feed
      'camera_feed': 'تغذية الكاميرا',

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

      // Devices Tab
      'active_alarms': 'التنبيهات النشطة',
      'clear': 'مسح',
      'no_devices': 'لا توجد أجهزة مكونة',
      'add_devices_desc': 'أضف أجهزة ESP32 الخاصة بك للبدء',
      'control_lights': 'التحكم بالإضاءة',
      'temperature': 'درجة الحرارة',

      // Logs Tab
      'please_login': 'يرجى تسجيل الدخول لعرض السجلات',

      // Splash Screen
      'control_world': 'تحكم في عالمك بسهولة',

      // Auth Screens
      'create_account': 'إنشاء حساب',
      'sign_in': 'تسجيل الدخول',
      'no_account': 'ليس لديك حساب؟ سجل الآن',
      'have_account': 'لديك حساب بالفعل؟ تسجيل الدخول',
      'email': 'البريد الإلكتروني',
      'password': 'كلمة المرور',
      'full_name': 'الاسم الكامل',
      'confirm_password': 'تأكيد كلمة المرور',
      'welcome_back': 'مرحبًا بعودتك',
      'sign_in_subtitle': 'قم بتسجيل الدخول للتحكم في منزلك الذكي',
      'join_us': 'انضم إلينا',
      'create_account_subtitle': 'أنشئ حساب منزلك الذكي',
      'enter_email': 'الرجاء إدخال بريدك الإلكتروني',
      'valid_email': 'الرجاء إدخال بريد إلكتروني صالح',
      'enter_password': 'الرجاء إدخال كلمة المرور',
      'password_length': 'يجب أن تتكون كلمة المرور من 6 أحرف على الأقل',
      'enter_name': 'الرجاء إدخال اسمك',
      'passwords_match': 'كلمات المرور غير متطابقة',
      'enter_confirm_password': 'الرجاء تأكيد كلمة المرور',

      // Face Authentication
      'face_auth_title': 'التعرف على الوجه',
      'face_auth_subtitle': 'مصادقة آمنة وسريعة',
      'sign_in_with_face': 'تسجيل الدخول بالتعرف على الوجه',
      'discovering': 'جاري اكتشاف الخدمة...',
      'connecting': 'جاري الاتصال...',
      'requesting_scan': 'طلب المسح...',
      'initializing': 'جاري تشغيل الكاميرا...',
      'scanning': 'انظر إلى الكاميرا',
      'scanning_subtitle': 'ضع وجهك أمام الكاميرا',
      'processing': 'جاري المعالجة...',
      'processing_subtitle': 'التحقق من هويتك',
      'auth_success': 'نجاح!',
      'auth_success_subtitle': 'تمت المصادقة بنجاح',
      'auth_failed': 'فشل',
      'auth_failed_subtitle': 'لم يتم التعرف على الوجه',
      'auth_timeout': 'انتهت المهلة',
      'auth_timeout_subtitle': 'انتهت مهلة الطلب. يرجى المحاولة مرة أخرى.',
      'auth_error': 'خطأ',
      'auth_error_subtitle': 'حدث خطأ',
      'try_again': 'حاول مرة أخرى',
      'beacon_info': 'معلومات البيكون',
      'service_name': 'الخدمة',
      'ip_address': 'عنوان IP',
      'port': 'المنفذ',
      'discovered_at': 'اكتشف في',
      'authentication_failed': 'فشلت المصادقة',
      'please_try_again':
          'يرجى المحاولة مرة أخرى أو استخدام البريد الإلكتروني/كلمة المرور.',

      // Login Screen
      'authenticate_with_face': 'المصادقة بالتعرف على الوجه',
      'tap_to_authenticate': 'اضغط للمصادقة',
      'two_factor_info':
          'التعرف على الوجه مطلوب. يمكنك تكوين طبقة أمان إضافية (بريد إلكتروني/كلمة مرور) في الإعدادات بعد تسجيل الدخول.',

      // Layer 2 Authentication
      'second_layer_auth': 'المصادقة الثانية',
      'face_success_verify':
          'نجح التعرف على الوجه ✓\nتحقق من بريدك الإلكتروني وكلمة المرور للمتابعة',
      'verify_credentials': 'التحقق من بيانات الاعتماد',
      'verifying': 'جاري التحقق...',

      // Language Names
      'language_english': 'English',
      'language_german': 'Deutsch (German)',
      'language_arabic': 'العربية (Arabic)',

      // AI Chat
      'ai_assistant': 'مساعد الذكاء الاصطناعي',
      'ai_chat': 'دردشة الذكاء الاصطناعي',
      'online': 'متصل',
      'offline': 'غير متصل',
      'ai_chat_welcome':
          'اسألني أي شيء عن منزلك الذكي. يمكنني مساعدتك في التحكم في الأجهزة وإنشاء الأتمتة والإجابة على الأسئلة.',
      'suggestion_status': 'ما هي حالة أجهزتي؟',
      'suggestion_automation': 'ساعدني في إنشاء أتمتة',
      'suggestion_energy': 'أظهر لي استهلاك الطاقة',
      'type_message': 'اكتب رسالة...',
      'waiting_for_response': 'في انتظار الرد...',
      'stop_response': 'إيقاف الرد',
      'configure_server': 'تكوين الخادم',
      'clear_chat': 'مسح الدردشة',
      'clear_chat_confirm': 'هل أنت متأكد من أنك تريد مسح جميع رسائل الدردشة؟',
      'server_url': 'عنوان URL للخادم',
      'ai_server_url_hint':
          'أدخل عنوان URL لخادم وكيل الذكاء الاصطناعي الذي يعمل على جهاز Linux الخاص بك',
      'server_url_updated': 'تم تحديث عنوان URL للخادم بنجاح',
      'retry': 'إعادة المحاولة',
      'show_think_mode': 'إظهار تفكير الذكاء الاصطناعي',
      'think_mode_description': 'عرض عملية تفكير الذكاء الاصطناعي الداخلية',
      'chat_with_me': 'تحدث معي',

      // Chat Sessions
      'chat_history': 'سجل الدردشة',
      'new_chat': 'دردشة جديدة',
      'no_chat_history': 'لا يوجد سجل دردشة',
      'start_new_chat_hint': 'ابدأ محادثة جديدة مع مساعد الذكاء الاصطناعي',
      'delete_sessions': 'حذف الجلسات',
      'delete_sessions_confirm':
          'هل أنت متأكد من أنك تريد حذف {count} جلسة/جلسات؟',
      'delete_all_sessions': 'حذف جميع الجلسات',
      'delete_all_sessions_confirm':
          'هل أنت متأكد من أنك تريد حذف جميع جلسات الدردشة؟ لا يمكن التراجع عن هذا.',
      'selected': 'محدد',
      'select': 'تحديد',
      'delete_all': 'حذف الكل',
      'active': 'نشط',

      // Voice Messages
      'voice_permission_denied':
          'تم رفض إذن الميكروفون. يرجى تمكينه في الإعدادات.',
      'voice_message': 'رسالة صوتية',
      'recording': 'جارٍ التسجيل...',
      'send_voice': 'إرسال رسالة صوتية',
      'microphone_permission_required': 'إذن الميكروفون مطلوب',
      'microphone_permission_message':
          'يحتاج هذا التطبيق إلى الوصول إلى الميكروفون لتسجيل الرسائل الصوتية. يرجى منح الإذن في إعدادات جهازك.',
      'open_settings': 'فتح الإعدادات',
      'error_starting_recording': 'خطأ في بدء التسجيل',
      'open_voice_to_voice_screen': 'فتح شاشة الصوت إلى الصوت',
      'dedicated_voice_conversation':
          'شاشة مخصصة للمحادثة الصوتية بدون استخدام اليدين',

      // Voice Settings
      'voice_settings': 'إعدادات الصوت',
      'voice_mode': 'وضع الصوت',
      'text_only': 'نص فقط',
      'text_only_desc': 'دردشة نصية عادية',
      'voice_to_text': 'صوت إلى نص',
      'voice_to_text_desc': 'تحدث رسالتك واحصل على رد نصي',
      'voice_to_voice': 'صوت إلى صوت',
      'voice_to_voice_desc': 'محادثة صوتية كاملة مع الذكاء الاصطناعي',
      'service_status': 'حالة الخدمة',
      'tts_service': 'تحويل النص إلى كلام (Piper)',
      'asr_service': 'التعرف على الكلام (Whisper)',
      'voice_chat_service': 'واجهة برمجة تطبيقات الدردشة الصوتية',
      'refresh': 'تحديث',
      'done': 'تم',
      'ready_to_talk': 'جاهز للتحدث',
      'listening': 'استماع...',
      'recording_failed': 'فشل التسجيل',
      'tap_to_speak': 'اضغط للتحدث',
      'v2v_instructions':
          'اضغط على الزر لبدء التحدث. سيكتشف النظام تلقائيًا عند الانتهاء، أو يمكنك النقر على إرسال.',

      // LLM Provider Settings
      'llm_provider': 'مزود نموذج الذكاء الاصطناعي',
      'select_provider': 'اختر المزود',
      'n8n_local': 'سير عمل n8n المحلي',
      'n8n_local_desc': 'يستخدم خادم أتمتة n8n في شبكتك',
      'ollama_local': 'Ollama المحلي',
      'ollama_local_desc': 'اتصال مباشر بخادم Ollama LLM',
      'external_llm': 'LLM خارجي (السحابة)',
      'external_llm_desc': 'الاتصال بـ LLM مستضاف على السحابة عبر ngrok',
      'external_config': 'تكوين LLM الخارجي',
      'llm_url': 'عنوان URL لخادم LLM',
      'api_key': 'مفتاح API',
      'local_server': 'خادم الذكاء الاصطناعي المحلي',
      'llm_provider_updated': 'تم تحديث إعدادات مزود الذكاء الاصطناعي',

      // Biometric Authentication
      'enable_biometric_login': 'تفعيل تسجيل الدخول بالبصمة',
      'biometric_verify_to_enable': 'تحقق من هويتك لتفعيل تسجيل الدخول بالبصمة',
      'biometric_enabled_success': 'تم تفعيل تسجيل الدخول بالبصمة بنجاح',
      'biometric_login_description':
          'استخدم {biometricType} لتسجيل الدخول بسرعة وتجاوز التعرف على الوجه',
      'biometric_login_prompt': 'قم بالمصادقة للوصول إلى المنزل الذكي',
      'biometric_not_available': 'المصادقة بالبصمة غير متوفرة على هذا الجهاز',
      'biometric_login_failed': 'فشلت المصادقة بالبصمة',
      'biometric_disabled': 'تسجيل الدخول بالبصمة',
      'enable_in_settings': 'تفعيل في الإعدادات بعد تسجيل الدخول',
      'enable_biometric_in_settings':
          'تفعيل تسجيل الدخول بالبصمة في الإعدادات بعد أول تسجيل دخول',

      // User Management
      'user_management': 'إدارة المستخدمين',
      'search_users':
          'البحث عن المستخدمين بالاسم أو البريد الإلكتروني أو المعرف...',
      'new_users': 'مستخدمون جدد',
      'pending': 'قيد الانتظار',
      'suspicious': 'مشبوه',
      'banned': 'محظور',
      'admins': 'المسؤولون',
      'no_users_found': 'لم يتم العثور على مستخدمين',
      'pending_approvals': 'موافقات معلقة',
      'user_approval': 'موافقة المستخدم',
      'no_pending_users': 'لا توجد طلبات معلقة',
      'approve': 'موافقة',
      'reject': 'رفض',
      'approval_pending': 'حسابك في انتظار الموافقة',
      'waiting_for_admin': 'في انتظار موافقة المسؤول',
      'account_approved': 'تمت الموافقة على الحساب',
      'account_rejected': 'تم رفض الحساب',
      'pending_approval_title': 'الحساب في انتظار الموافقة',
      'pending_approval_description':
          'تم التسجيل بنجاح! تم إخطار المسؤول وسيراجع طلب الوصول الخاص بك قريباً.',
      'pending_approval_info':
          'تم إرسال رمز OTP إلى المسؤولين. ستتمكن من الوصول إلى التطبيق بمجرد موافقة المسؤول على طلبك.',
      'check_approval_status': 'التحقق من حالة الموافقة',
      'approval_still_pending':
          'حسابك لا يزال في انتظار الموافقة. يرجى الانتظار حتى يوافق المسؤول على وصولك.',
      'account_created_pending_approval':
          'تم إنشاء الحساب! في انتظار موافقة المسؤول.',

      // Chat Theme Settings
      'chat_appearance': 'مظهر المحادثة',
      'themes': 'السمات',
      'colors': 'الألوان',
      'style': 'النمط',
      'reset': 'إعادة تعيين',
      'your_messages': 'رسائلك',
      'customize_your_bubble_color': 'تخصيص لون فقاعة رسائلك',
      'ai_messages': 'رسائل المساعد',
      'customize_ai_bubble_color': 'تخصيص لون فقاعة رسائل المساعد',
      'quick_colors': 'ألوان سريعة',
      'font_size': 'حجم الخط',
      'bubble_roundness': 'استدارة الفقاعة',
      'font_family': 'نوع الخط',
      'show_timestamps': 'إظهار الوقت',
      'show_message_time': 'إظهار وقت الرسالة',
      'show_avatars': 'إظهار الصور الرمزية',
      'show_profile_pictures': 'إظهار صور الملف الشخصي',
      'preview': 'معاينة',
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
