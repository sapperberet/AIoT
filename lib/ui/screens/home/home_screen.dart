import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:iconsax/iconsax.dart';
import 'package:animate_do/animate_do.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/providers/device_provider.dart';
import '../../../core/providers/ai_chat_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../widgets/custom_drawer.dart';
import '../../widgets/floating_chat_button.dart';
import '../../widgets/admin/user_activity_notification_widget.dart';
import 'devices_tab.dart';
import 'visualization_tab.dart';
import 'logs_tab.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    _checkAuthAndInitialize();
  }

  Future<void> _checkAuthAndInitialize() async {
    final authProvider = context.read<AuthProvider>();

    // Check if user is authenticated
    if (authProvider.currentUser == null) {
      // User is not authenticated, redirect to login
      debugPrint('❌ User not authenticated, redirecting to login');
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          Navigator.of(context).pushReplacementNamed('/modern-login');
        }
      });
      return;
    }

    // 🔥 CRITICAL: Try beacon discovery BEFORE connecting MQTT
    // This ensures we have the correct backend IP
    if (authProvider.discoveredBeacon == null) {
      debugPrint('🔍 Home: Attempting beacon discovery for MQTT...');
      final beaconFound = await authProvider.discoverFaceAuthBeacon();
      if (beaconFound && authProvider.discoveredBeacon != null) {
        debugPrint(
            '✅ Home: Beacon discovered at ${authProvider.discoveredBeacon!.ip}');
      } else {
        debugPrint('⚠️ Home: Beacon not found, using settings IP');
      }
    }

    // 🔥 CRITICAL: Sync beacon IP to ALL services BEFORE initializing devices
    if (authProvider.discoveredBeacon != null) {
      final beaconIp = authProvider.discoveredBeacon!.ip;
      debugPrint('🌐 Home: Syncing beacon IP ($beaconIp) to all services');

      // Update AI Chat and Voice services
      try {
        final chatProvider = context.read<AIChatProvider>();
        chatProvider.updateBrokerEndpoint(beaconIp);
        debugPrint('✅ Home: AI Chat and Voice services updated to $beaconIp');
      } catch (e) {
        debugPrint('⚠️ Home: Could not update chat provider: $e');
      }
    }

    // User is authenticated, initialize devices (this connects MQTT)
    final deviceProvider = context.read<DeviceProvider>();
    await deviceProvider.initialize(authProvider.currentUser!.uid);
  }

  @override
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textColor = theme.colorScheme.onBackground;

    final List<Widget> tabs = [
      const DevicesTab(),
      const VisualizationTab(),
      const LogsTab(),
    ];

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      drawer: const CustomDrawer(),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: Builder(
          builder: (context) => FadeInLeft(
            child: IconButton(
              icon: Icon(Iconsax.menu, color: textColor),
              onPressed: () => Scaffold.of(context).openDrawer(),
            ),
          ),
        ),
        title: FadeInDown(
          child: ShaderMask(
            shaderCallback: (bounds) =>
                AppTheme.primaryGradient.createShader(bounds),
            child: Text(
              AppLocalizations.of(context).t('app_title'),
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
        ),
        actions: [
          UserActivityNotificationWidget(
            onViewUsers: () => Navigator.pushNamed(context, '/user-management'),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Stack(
        children: [
          FadeIn(
            child: tabs[_currentIndex],
          ),
          // Floating chat button (hide on visualization tab - index 1)
          if (_currentIndex != 1) const FloatingChatButton(),
        ],
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              theme.scaffoldBackgroundColor,
              theme.scaffoldBackgroundColor.withOpacity(0.95),
            ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
          boxShadow: [
            BoxShadow(
              color: AppTheme.primaryColor.withOpacity(0.1),
              blurRadius: 20,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: NavigationBar(
          backgroundColor: Colors.transparent,
          selectedIndex: _currentIndex,
          onDestinationSelected: (index) {
            setState(() {
              _currentIndex = index;
            });
          },
          indicatorColor: AppTheme.primaryColor.withOpacity(0.2),
          destinations: [
            NavigationDestination(
              icon: const Icon(Iconsax.home),
              selectedIcon: const Icon(Iconsax.home_15),
              label: AppLocalizations.of(context).t('devices'),
            ),
            NavigationDestination(
              icon: const Icon(Iconsax.box),
              selectedIcon: const Icon(Iconsax.box5),
              label: AppLocalizations.of(context).t('visualization'),
            ),
            NavigationDestination(
              icon: const Icon(Iconsax.document_text),
              selectedIcon: const Icon(Iconsax.document_text_15),
              label: AppLocalizations.of(context).t('logs'),
            ),
          ],
        ),
      ),
    );
  }
}
