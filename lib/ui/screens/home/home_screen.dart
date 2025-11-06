import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:iconsax/iconsax.dart';
import 'package:animate_do/animate_do.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/providers/device_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../widgets/custom_drawer.dart';
import '../../widgets/floating_chat_button.dart';
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
    _initializeDevices();
  }

  Future<void> _initializeDevices() async {
    final authProvider = context.read<AuthProvider>();
    final deviceProvider = context.read<DeviceProvider>();

    if (authProvider.currentUser != null) {
      await deviceProvider.initialize(authProvider.currentUser!.uid);
    }
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
          Consumer<DeviceProvider>(
            builder: (context, deviceProvider, child) {
              return FadeInRight(
                child: Container(
                  margin: const EdgeInsets.only(right: 16),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    gradient: deviceProvider.isConnectedToMqtt
                        ? LinearGradient(
                            colors: [
                              AppTheme.successColor.withOpacity(0.3),
                              AppTheme.successColor.withOpacity(0.1),
                            ],
                          )
                        : LinearGradient(
                            colors: [
                              AppTheme.errorColor.withOpacity(0.3),
                              AppTheme.errorColor.withOpacity(0.1),
                            ],
                          ),
                    borderRadius: AppTheme.mediumRadius,
                    border: Border.all(
                      color: deviceProvider.isConnectedToMqtt
                          ? AppTheme.successColor
                          : AppTheme.errorColor,
                      width: 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        deviceProvider.isConnectedToMqtt
                            ? Iconsax.wifi
                            : Iconsax.wifi_square,
                        size: 16,
                        color: deviceProvider.isConnectedToMqtt
                            ? AppTheme.successColor
                            : AppTheme.errorColor,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        deviceProvider.isConnectedToMqtt
                            ? AppLocalizations.of(context).t('local')
                            : AppLocalizations.of(context).t('cloud'),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: deviceProvider.isConnectedToMqtt
                              ? AppTheme.successColor
                              : AppTheme.errorColor,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          FadeIn(
            child: tabs[_currentIndex],
          ),
          // Floating chat button
          const FloatingChatButton(),
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
