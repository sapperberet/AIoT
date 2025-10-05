import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';

import 'core/services/auth_service.dart';
import 'core/services/mqtt_service.dart';
import 'core/services/firestore_service.dart';
import 'core/providers/auth_provider.dart';
import 'core/providers/device_provider.dart';
import 'core/providers/home_visualization_provider.dart';
import 'core/theme/app_theme.dart';
import 'ui/screens/splash_screen.dart';
import 'ui/screens/auth/modern_login_screen.dart';
import 'ui/screens/auth/modern_register_screen.dart';
import 'ui/screens/auth/email_verification_screen.dart';
import 'ui/screens/home/home_screen.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

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

  runApp(const SmartHomeApp());
}

class SmartHomeApp extends StatelessWidget {
  const SmartHomeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        // Services
        Provider<AuthService>(
          create: (_) => AuthService(),
        ),
        Provider<MqttService>(
          create: (_) => MqttService(),
        ),
        Provider<FirestoreService>(
          create: (_) => FirestoreService(),
        ),

        // State Providers
        ChangeNotifierProvider<AuthProvider>(
          create: (context) => AuthProvider(
            authService: context.read<AuthService>(),
          ),
        ),
        ChangeNotifierProvider<DeviceProvider>(
          create: (context) => DeviceProvider(
            mqttService: context.read<MqttService>(),
            firestoreService: context.read<FirestoreService>(),
          ),
        ),
        ChangeNotifierProvider<HomeVisualizationProvider>(
          create: (_) => HomeVisualizationProvider(),
        ),
      ],
      child: MaterialApp(
        title: 'Smart Home',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        themeMode: ThemeMode.dark,
        home: const SplashScreen(),
        routes: {
          '/login': (context) => const ModernLoginScreen(),
          '/register': (context) => const ModernRegisterScreen(),
          '/verify-email': (context) => const EmailVerificationScreen(),
          '/home': (context) => const HomeScreen(),
        },
      ),
    );
  }
}
