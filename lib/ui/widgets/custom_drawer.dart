import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:animate_do/animate_do.dart';
import 'package:glassmorphism/glassmorphism.dart';
import 'package:iconsax/iconsax.dart';
import '../../core/providers/auth_provider.dart';
import '../../core/localization/app_localizations.dart';
import '../../core/theme/app_theme.dart';
import '../screens/camera/camera_feed_screen.dart';

class CustomDrawer extends StatelessWidget {
  const CustomDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final user = authProvider.currentUser;
    final userModel = authProvider.userModel;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final textColor = theme.colorScheme.onBackground;

    return Drawer(
      backgroundColor: Colors.transparent,
      child: Container(
        decoration: BoxDecoration(
          gradient: isDark
              ? AppTheme.backgroundGradient
              : LinearGradient(
                  colors: [
                    AppTheme.lightBackground,
                    AppTheme.lightSurface,
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              const SizedBox(height: 20),

              // User Profile Section
              FadeInDown(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: GlassmorphicContainer(
                    width: double.infinity,
                    height: 185,
                    borderRadius: 20,
                    blur: 20,
                    alignment: Alignment.center,
                    border: 2,
                    linearGradient: LinearGradient(
                      colors: isDark
                          ? [
                              Colors.white.withOpacity(0.1),
                              Colors.white.withOpacity(0.05),
                            ]
                          : [
                              Colors.white.withOpacity(0.95),
                              Colors.white.withOpacity(0.85),
                            ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderGradient: LinearGradient(
                      colors: [
                        Colors.white.withOpacity(0.2),
                        Colors.white.withOpacity(0.1),
                      ],
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Avatar
                          Container(
                            width: 80,
                            height: 80,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: AppTheme.primaryGradient,
                              boxShadow: AppTheme.glowShadow,
                            ),
                            child: user?.photoURL != null
                                ? ClipOval(
                                    child: Image.network(
                                      user!.photoURL!,
                                      fit: BoxFit.cover,
                                    ),
                                  )
                                : Center(
                                    child: Text(
                                      userModel?.displayName
                                              ?.substring(0, 1)
                                              .toUpperCase() ??
                                          user?.email
                                              ?.substring(0, 1)
                                              .toUpperCase() ??
                                          'U',
                                      style: const TextStyle(
                                        fontSize: 32,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                          ),

                          const SizedBox(height: 12),

                          // Name
                          Text(
                            userModel?.displayName ??
                                user?.displayName ??
                                'User',
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(
                                  color: textColor,
                                  fontWeight: FontWeight.bold,
                                ),
                            textAlign: TextAlign.center,
                          ),

                          const SizedBox(height: 4),

                          // Email
                          Text(
                            user?.email ?? '',
                            style:
                                Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: textColor.withOpacity(0.7),
                                    ),
                            textAlign: TextAlign.center,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 10),

              // Menu Items
              Expanded(
                child: Builder(
                  builder: (context) {
                    final loc = AppLocalizations.of(context);
                    return ListView(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      children: [
                        FadeInLeft(
                          delay: const Duration(milliseconds: 100),
                          child: _buildMenuItem(
                            context,
                            icon: Iconsax.home_2,
                            title: loc.t('home'),
                            onTap: () {
                              Navigator.pop(context);
                            },
                          ),
                        ),
                        FadeInLeft(
                          delay: const Duration(milliseconds: 200),
                          child: _buildMenuItem(
                            context,
                            icon: Iconsax.setting_2,
                            title: loc.t('settings'),
                            onTap: () {
                              Navigator.pop(context);
                              Navigator.pushNamed(context, '/settings');
                            },
                          ),
                        ),
                        FadeInLeft(
                          delay: const Duration(milliseconds: 300),
                          child: _buildMenuItem(
                            context,
                            icon: Iconsax.video,
                            title: loc.t('camera_feed'),
                            onTap: () {
                              Navigator.pop(context);
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => const CameraFeedScreen(),
                                ),
                              );
                            },
                          ),
                        ),
                        FadeInLeft(
                          delay: const Duration(milliseconds: 400),
                          child: _buildMenuItem(
                            context,
                            icon: Iconsax.notification,
                            title: loc.t('notifications'),
                            badge: '3',
                            onTap: () {
                              Navigator.pop(context);
                              Navigator.pushNamed(context, '/notifications');
                            },
                          ),
                        ),
                        FadeInLeft(
                          delay: const Duration(milliseconds: 500),
                          child: _buildMenuItem(
                            context,
                            icon: Iconsax.timer,
                            title: loc.t('automations'),
                            onTap: () {
                              Navigator.pop(context);
                              Navigator.pushNamed(context, '/automations');
                            },
                          ),
                        ),
                        FadeInLeft(
                          delay: const Duration(milliseconds: 600),
                          child: _buildMenuItem(
                            context,
                            icon: Iconsax.flash_1,
                            title: loc.t('energy_monitor'),
                            onTap: () {
                              Navigator.pop(context);
                              Navigator.pushNamed(context, '/energy');
                            },
                          ),
                        ),
                        FadeInLeft(
                          delay: const Duration(milliseconds: 700),
                          child: _buildMenuItem(
                            context,
                            icon: Iconsax.info_circle,
                            title: loc.t('about'),
                            onTap: () {
                              Navigator.pop(context);
                              _showAboutDialog(context);
                            },
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),

              // Logout Button
              FadeInUp(
                delay: const Duration(milliseconds: 600),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: _buildLogoutButton(context, authProvider),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMenuItem(
    BuildContext context, {
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    String? badge,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final textColor = theme.colorScheme.onBackground;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: AppTheme.mediumRadius,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            decoration: BoxDecoration(
              borderRadius: AppTheme.mediumRadius,
              border: Border.all(
                color: isDark
                    ? Colors.white.withOpacity(0.1)
                    : Colors.black.withOpacity(0.1),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    gradient: AppTheme.primaryGradient.scale(0.3),
                    borderRadius: AppTheme.smallRadius,
                  ),
                  child: Icon(
                    icon,
                    color: AppTheme.primaryColor,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: textColor,
                          fontWeight: FontWeight.w500,
                        ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (badge != null) ...[
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      gradient: AppTheme.primaryGradient,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      badge,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                Icon(
                  Iconsax.arrow_right_3,
                  color: textColor.withOpacity(0.5),
                  size: 18,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLogoutButton(BuildContext context, AuthProvider authProvider) {
    final loc = AppLocalizations.of(context);
    return Container(
      width: double.infinity,
      height: 56,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.red.shade400,
            Colors.red.shade600,
          ],
        ),
        borderRadius: AppTheme.mediumRadius,
        boxShadow: [
          BoxShadow(
            color: Colors.red.withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ElevatedButton(
        onPressed: () async {
          await authProvider.signOut();
          if (context.mounted) {
            Navigator.of(context).pushReplacementNamed('/login');
          }
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: AppTheme.mediumRadius,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Iconsax.logout, color: Colors.white),
            const SizedBox(width: 12),
            Text(
              loc.t('logout'),
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
            ),
          ],
        ),
      ),
    );
  }

  void _showAboutDialog(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final textColor = theme.colorScheme.onBackground;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor:
            isDark ? AppTheme.darkBackground : AppTheme.lightBackground,
        shape: RoundedRectangleBorder(
          borderRadius: AppTheme.mediumRadius,
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                gradient: AppTheme.primaryGradient,
                borderRadius: AppTheme.smallRadius,
              ),
              child: const Icon(Iconsax.info_circle, color: Colors.white),
            ),
            const SizedBox(width: 12),
            Text(loc.t('about'), style: TextStyle(color: textColor)),
          ],
        ),
        content: Text(
          'Smart Home IoT Control\n\nVersion 1.0.0\n\nControl your smart home devices with ESP32 integration, real-time monitoring, and 3D visualization.',
          style: TextStyle(color: textColor.withOpacity(0.7)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Close',
              style: TextStyle(color: AppTheme.primaryColor),
            ),
          ),
        ],
      ),
    );
  }
}

extension GradientExtension on Gradient {
  LinearGradient scale(double factor) {
    if (this is LinearGradient) {
      final linear = this as LinearGradient;
      return LinearGradient(
        colors: linear.colors.map((c) => c.withOpacity(factor)).toList(),
        begin: linear.begin,
        end: linear.end,
      );
    }
    return const LinearGradient(
        colors: [Colors.transparent, Colors.transparent]);
  }
}
