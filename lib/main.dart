import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'core/services/auth_service.dart';
import 'core/services/mqtt_service.dart';
import 'core/services/biometric_auth_service.dart';
import 'core/services/face_auth_service.dart';
import 'core/services/face_auth_http_service.dart';
import 'core/services/firestore_service.dart';
import 'core/services/notification_service.dart';
import 'core/services/ai_chat_service.dart';
import 'core/services/ai_chat_actions_service.dart';
import 'core/services/event_log_service.dart';
import 'core/services/sensor_service.dart';
import 'core/services/automation_service.dart';
import 'core/services/automation_engine.dart';
import 'core/services/energy_service.dart';
import 'core/services/push_notification_service.dart';
import 'core/providers/auth_provider.dart';
import 'core/providers/device_provider.dart';
import 'core/providers/home_visualization_provider.dart';
import 'core/providers/settings_provider.dart';
import 'core/providers/automation_provider.dart';
import 'core/providers/ai_chat_provider.dart';
import 'core/providers/chat_theme_provider.dart';
import 'core/providers/energy_provider.dart';
import 'core/localization/app_localizations.dart';
import 'core/theme/app_theme.dart';
import 'ui/screens/splash_screen.dart';
import 'ui/screens/auth/new_login_screen.dart';
import 'ui/screens/auth/new_register_screen.dart';
import 'ui/screens/auth/modern_login_screen.dart';
import 'ui/screens/auth/email_verification_screen.dart';
import 'ui/screens/auth/face_auth_screen.dart';
import 'ui/screens/auth/email_password_layer_screen.dart';
import 'ui/screens/auth/forgot_password_screen.dart';
import 'ui/screens/auth/pending_approval_screen.dart';
import 'ui/screens/home/home_screen.dart';
import 'ui/screens/settings/settings_screen.dart';
import 'ui/screens/notifications/notifications_screen.dart';
import 'ui/screens/automations/automations_screen.dart';
import 'ui/screens/automations/automation_management_screen.dart';
import 'ui/screens/energy/energy_monitor_screen.dart';
import 'ui/screens/chat/ai_chat_screen.dart';
import 'ui/screens/chat/chat_sessions_screen.dart';
import 'ui/screens/chat/voice_to_voice_screen.dart';
import 'ui/screens/admin/user_management_screen.dart';
import 'ui/screens/admin/user_approval_screen.dart';
import 'ui/screens/admin/device_health_screen.dart';
import 'firebase_options.dart';

// ⚠️ DEBUG MODE - Set to true to bypass authentication and go directly to home
const bool DEBUG_MODE = false;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Filter out spam debug messages from animation packages and system logs
  debugPrint = (String? message, {int? wrapWidth}) {
    if (message == null || message.isEmpty) return;
    // Suppress animation spam and gralloc messages
    final lowerMsg = message.toLowerCase();
    // Filter animation spam
    if (lowerMsg.contains('animate:') ||
        lowerMsg.contains('animate =') ||
        lowerMsg == 'animate' ||
        lowerMsg == 'animate: true' ||
        lowerMsg == 'true' ||
        lowerMsg == 'false') return;
    // Filter gralloc system messages (Android GPU memory allocator)
    if (lowerMsg.contains('gralloc') ||
        lowerMsg.contains('i/gralloc') ||
        lowerMsg.contains('@set_metadata') ||
        lowerMsg.contains('dataspace')) return;
    // Filter empty or whitespace-only messages
    if (message.trim().isEmpty) return;
    // Print other messages normally using default implementation
    // ignore: avoid_print
    print(message);
  };

  // Initialize Firebase (only if not already initialized)
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e) {
    if (e.toString().contains('duplicate-app')) {
      // Firebase already initialized, continue
      debugPrint('Firebase already initialized');
    } else {
      // Re-throw other errors
      rethrow;
    }
  }

  if (DEBUG_MODE) {
    debugPrint('🔴 DEBUG MODE ENABLED - Authentication bypassed!');
  }

  runApp(const SmartHomeApp());
}

class SmartHomeApp extends StatelessWidget {
  const SmartHomeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        // Services
        Provider<MqttService>(
          create: (_) => MqttService(),
        ),
        Provider<AuthService>(
          create: (context) => AuthService(
            mqttService: context.read<MqttService>(),
          ),
        ),
        Provider<BiometricAuthService>(
          create: (_) => BiometricAuthService(),
        ),
        Provider<FaceAuthService>(
          create: (context) => FaceAuthService(
            mqttService: context.read<MqttService>(),
          ),
        ),
        Provider<FaceAuthHttpService>(
          create: (_) => FaceAuthHttpService(),
        ),
        Provider<FirestoreService>(
          create: (_) => FirestoreService(),
        ),
        ChangeNotifierProvider<EventLogService>(
          create: (_) => EventLogService(),
        ),
        Provider<SensorService>(
          create: (_) => SensorService(),
        ),
        Provider<AIChatService>(
          create: (_) => AIChatService(),
        ),
        ChangeNotifierProvider<AutomationService>(
          create: (_) => AutomationService()..initialize(),
        ),
        Provider<EnergyService>(
          create: (context) => EnergyService(
            mqttService: context.read<MqttService>(),
          ),
        ),
        ProxyProvider6<
            SensorService,
            MqttService,
            NotificationService,
            EventLogService,
            AutomationService,
            DeviceProvider,
            AutomationEngine>(
          create: (context) => AutomationEngine(
            automationService: context.read<AutomationService>(),
            sensorService: context.read<SensorService>(),
            mqttService: context.read<MqttService>(),
            notificationService: context.read<NotificationService>(),
            eventLogService: context.read<EventLogService>(),
          )..start(),
          update: (context, sensorService, mqttService, notificationService,
              eventLogService, automationService, deviceProvider, engine) {
            return engine ??
                AutomationEngine(
                  automationService: automationService,
                  sensorService: sensorService,
                  mqttService: mqttService,
                  notificationService: notificationService,
                  eventLogService: eventLogService,
                )
              ..start();
          },
        ),

        // State Providers
        ChangeNotifierProvider<NotificationService>(
          create: (_) => NotificationService(),
        ),
        // Push Notification Service (Firebase Cloud Messaging)
        ProxyProvider<NotificationService, PushNotificationService>(
          create: (_) => PushNotificationService(),
          update: (context, notificationService, pushService) {
            pushService?.initialize(notificationService: notificationService);
            return pushService ?? PushNotificationService();
          },
        ),
        ChangeNotifierProvider<AuthProvider>(
          create: (context) => AuthProvider(
            authService: context.read<AuthService>(),
            biometricAuthService: context.read<BiometricAuthService>(),
            faceAuthService: context.read<FaceAuthService>(),
            faceAuthHttpService: context.read<FaceAuthHttpService>(),
          ),
        ),
        ChangeNotifierProvider<HomeVisualizationProvider>(
          create: (_) => HomeVisualizationProvider(),
        ),
        ChangeNotifierProxyProvider<HomeVisualizationProvider, DeviceProvider>(
          create: (context) => DeviceProvider(
            mqttService: context.read<MqttService>(),
            firestoreService: context.read<FirestoreService>(),
            notificationService: context.read<NotificationService>(),
            eventLogService: context.read<EventLogService>(),
          ),
          update: (context, vizProvider, deviceProvider) {
            deviceProvider?.setHomeVisualizationProvider(vizProvider);
            deviceProvider?.setSensorService(context.read<SensorService>());
            return deviceProvider!;
          },
        ),
        ChangeNotifierProvider<SettingsProvider>(
          create: (context) => SettingsProvider(
            firestoreService: context.read<FirestoreService>(),
            authService: context.read<AuthService>(),
          ),
        ),
        ChangeNotifierProvider<AutomationProvider>(
          create: (_) => AutomationProvider(),
        ),
        ChangeNotifierProxyProvider2<MqttService, EnergyService,
            EnergyProvider>(
          create: (context) => EnergyProvider(
            energyService: context.read<EnergyService>(),
            mqttService: context.read<MqttService>(),
          )..initialize(),
          update: (context, mqttService, energyService, energyProvider) {
            return energyProvider!;
          },
        ),
        // AI Chat Actions Service (must be created before AIChatProvider)
        ProxyProvider3<AutomationService, MqttService, FirestoreService,
            AIChatActionsService>(
          create: (context) => AIChatActionsService(
            automationService: context.read<AutomationService>(),
            mqttService: context.read<MqttService>(),
            firestoreService: context.read<FirestoreService>(),
          ),
          update:
              (context, automationService, mqttService, firestoreService, _) {
            return AIChatActionsService(
              automationService: automationService,
              mqttService: mqttService,
              firestoreService: firestoreService,
            );
          },
        ),
        ChangeNotifierProxyProvider<AIChatActionsService, AIChatProvider>(
          create: (context) {
            final provider = AIChatProvider(
              chatService: context.read<AIChatService>(),
            );
            // Initialize actions service
            final actionsService = context.read<AIChatActionsService>();
            provider.initializeActionsService(actionsService);
            return provider;
          },
          update: (context, actionsService, provider) {
            if (provider != null) {
              provider.initializeActionsService(actionsService);
            }
            return provider!;
          },
        ),
        ChangeNotifierProvider<ChatThemeProvider>(
          create: (_) => ChatThemeProvider(),
        ),
      ],
      child: Consumer<SettingsProvider>(
        builder: (context, settingsProvider, child) {
          // Map language code to Locale
          Locale locale;
          switch (settingsProvider.language) {
            case 'de':
              locale = const Locale('de');
              break;
            case 'ar':
              locale = const Locale('ar');
              break;
            default:
              locale = const Locale('en');
          }

          return MaterialApp(
            key: ValueKey(
                settingsProvider.language), // Force rebuild on language change
            title: 'Smart Home',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.lightTheme,
            darkTheme: AppTheme.darkTheme,
            themeMode: settingsProvider.themeMode,
            locale: locale,
            localizationsDelegates: [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: const [
              Locale('en'),
              Locale('de'),
              Locale('ar'),
            ],
            home: const SplashScreen(),
            routes: {
              '/login': (context) => const NewLoginScreen(),
              '/register': (context) => const NewRegisterScreen(),
              '/verify-email': (context) => const EmailVerificationScreen(),
              '/face-auth': (context) => const FaceAuthScreen(),
              '/modern-login': (context) => const ModernLoginScreen(),
              '/forgot-password': (context) => const ForgotPasswordScreen(),
              '/pending-approval': (context) => const PendingApprovalScreen(),
              '/auth/email-password': (context) =>
                  const EmailPasswordLayerScreen(),
              '/home': (context) => const HomeScreen(),
              '/settings': (context) => const SettingsScreen(),
              '/notifications': (context) => const NotificationsScreen(),
              '/automations': (context) => const AutomationsScreen(),
              '/automation-management': (context) =>
                  const AutomationManagementScreen(),
              '/energy': (context) => const EnergyMonitorScreen(),
              '/ai-chat': (context) => const AIChatScreen(),
              '/chat-sessions': (context) => const ChatSessionsScreen(),
              '/voice-to-voice': (context) => const VoiceToVoiceScreen(),
              '/user-management': (context) => const UserManagementScreen(),
              '/user-approval': (context) => const UserApprovalScreen(),
              '/device-health': (context) => const DeviceHealthScreen(),
            },
          );
        },
      ),
    );
  }
}
