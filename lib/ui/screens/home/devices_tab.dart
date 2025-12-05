import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:animate_do/animate_do.dart';
import 'package:iconsax/iconsax.dart';
import 'package:glassmorphism/glassmorphism.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/providers/device_provider.dart';
import '../../../core/models/device_model.dart';
import '../../../core/theme/app_theme.dart';

class DevicesTab extends StatelessWidget {
  const DevicesTab({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final textColor = theme.colorScheme.onBackground;

    return Consumer<DeviceProvider>(
      builder: (context, deviceProvider, child) {
        final devices = deviceProvider.devices;
        final alarms = deviceProvider.activeAlarms;

        return Container(
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
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Column(
              children: [
                // Active Alarms Section
                if (alarms.isNotEmpty)
                  FadeInDown(
                    child: Container(
                      margin: const EdgeInsets.all(16),
                      child: GlassmorphicContainer(
                        width: double.infinity,
                        height:
                            alarms.length > 2 ? 180 : alarms.length * 70 + 50,
                        borderRadius: 20,
                        blur: 20,
                        alignment: Alignment.center,
                        border: 2,
                        linearGradient: LinearGradient(
                          colors: [
                            AppTheme.errorColor.withOpacity(0.2),
                            AppTheme.errorColor.withOpacity(0.1),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderGradient: LinearGradient(
                          colors: [
                            AppTheme.errorColor.withOpacity(0.5),
                            AppTheme.errorColor.withOpacity(0.2),
                          ],
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: AppTheme.errorColor,
                                      borderRadius: AppTheme.smallRadius,
                                    ),
                                    child: const Icon(Iconsax.warning_2,
                                        color: Colors.white, size: 20),
                                  ),
                                  const SizedBox(width: 12),
                                  Text(
                                    '${AppLocalizations.of(context).t('active_alarms')} (${alarms.length})',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: AppTheme.errorColor,
                                      fontSize: 16,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Expanded(
                                child: ListView(
                                  children: alarms
                                      .take(2)
                                      .map((alarm) => Padding(
                                            padding: const EdgeInsets.symmetric(
                                                vertical: 4),
                                            child: Row(
                                              children: [
                                                Icon(Iconsax.danger,
                                                    color: AppTheme.errorColor,
                                                    size: 16),
                                                const SizedBox(width: 8),
                                                Expanded(
                                                  child: Text(
                                                    '${alarm.type} in ${alarm.location}',
                                                    style: TextStyle(
                                                        color: textColor),
                                                  ),
                                                ),
                                                TextButton(
                                                  onPressed: () =>
                                                      deviceProvider
                                                          .acknowledgeAlarm(
                                                              alarm.id),
                                                  child: Text(
                                                      AppLocalizations.of(
                                                              context)
                                                          .t('clear')),
                                                ),
                                              ],
                                            ),
                                          ))
                                      .toList(),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),

                // Quick Controls Section - Always visible
                FadeInDown(
                  delay: const Duration(milliseconds: 100),
                  child: _QuickControlsSection(deviceProvider: deviceProvider),
                ),

                // Devices List (inline, not in Expanded since we're in SingleChildScrollView)
                // Note: "No devices configured" message removed - quick controls are always shown
                if (devices.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: AnimationLimiter(
                      child: Column(
                        children: List.generate(devices.length, (index) {
                          final device = devices[index];
                          return AnimationConfiguration.staggeredList(
                            position: index,
                            duration: const Duration(milliseconds: 375),
                            child: SlideAnimation(
                              verticalOffset: 50.0,
                              child: FadeInAnimation(
                                child: ModernDeviceCard(device: device),
                              ),
                            ),
                          );
                        }),
                      ),
                    ),
                  ),

                // Bottom padding for scroll comfort
                const SizedBox(height: 100),
              ],
            ),
          ),
        );
      },
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

class ModernDeviceCard extends StatelessWidget {
  final Device device;

  const ModernDeviceCard({super.key, required this.device});

  @override
  Widget build(BuildContext context) {
    final deviceProvider = context.read<DeviceProvider>();
    final gradient = _getDeviceGradient(device.type);
    final icon = _getDeviceIcon(device.type);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final textColor = theme.colorScheme.onBackground;

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: GestureDetector(
        onTap: () {
          HapticFeedback.lightImpact();
          _showDeviceDetails(context, device);
        },
        child: GlassmorphicContainer(
          width: double.infinity,
          height: 110,
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
                    Colors.white.withOpacity(0.9),
                    Colors.white.withOpacity(0.7),
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
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // Device Icon with Gradient
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    gradient: gradient,
                    borderRadius: AppTheme.mediumRadius,
                    boxShadow: [
                      BoxShadow(
                        color: gradient.colors.first.withOpacity(0.4),
                        blurRadius: 15,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: Icon(icon, color: Colors.white, size: 28),
                ),

                const SizedBox(width: 16),

                // Device Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        device.name,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: textColor,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(
                            Iconsax.location,
                            size: 14,
                            color: AppTheme.mutedText,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            device.room,
                            style: const TextStyle(
                              fontSize: 13,
                              color: AppTheme.mutedText,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: device.status == DeviceStatus.online
                                  ? AppTheme.successColor.withOpacity(0.2)
                                  : AppTheme.mutedText.withOpacity(0.2),
                              borderRadius: AppTheme.smallRadius,
                            ),
                            child: Text(
                              device.status == DeviceStatus.online
                                  ? 'Online'
                                  : 'Offline',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: device.status == DeviceStatus.online
                                    ? AppTheme.successColor
                                    : AppTheme.mutedText,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Updated ${_formatTime(device.lastUpdated)}',
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppTheme.mutedText,
                        ),
                      ),
                    ],
                  ),
                ),

                // Device Control based on type
                _buildDeviceControl(deviceProvider, device),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDeviceControl(DeviceProvider provider, Device device) {
    switch (device.type) {
      case DeviceType.light:
        return _buildLightControl(provider, device);
      case DeviceType.lock:
        return _buildLockIcon(device);
      case DeviceType.door:
        return _buildDoorControl(provider, device);
      case DeviceType.window:
        return _buildWindowControl(provider, device);
      case DeviceType.garage:
        return _buildGarageControl(provider, device);
      case DeviceType.buzzer:
        return _buildBuzzerControl(provider, device);
      default:
        return const Icon(Iconsax.arrow_right_3,
            color: AppTheme.mutedText, size: 20);
    }
  }

  Widget _buildLightControl(DeviceProvider provider, Device device) {
    final isOn = device.state['state'] == 'on';
    return GestureDetector(
      onTap: () {
        HapticFeedback.mediumImpact();
        provider.toggleLight(device.id);
      },
      child: Container(
        width: 50,
        height: 50,
        decoration: BoxDecoration(
          gradient: isOn ? AppTheme.accentGradient : null,
          color: isOn ? null : AppTheme.mutedText.withOpacity(0.2),
          borderRadius: AppTheme.smallRadius,
        ),
        child: Icon(
          isOn ? Iconsax.lamp_on5 : Iconsax.lamp_slash,
          color: isOn ? Colors.white : AppTheme.mutedText,
          size: 24,
        ),
      ),
    );
  }

  Widget _buildLockIcon(Device device) {
    final isLocked = device.state['locked'] == true;
    return Container(
      width: 50,
      height: 50,
      decoration: BoxDecoration(
        gradient: isLocked
            ? LinearGradient(
                colors: [Colors.green.shade400, Colors.green.shade600])
            : LinearGradient(
                colors: [Colors.orange.shade400, Colors.orange.shade600]),
        borderRadius: AppTheme.smallRadius,
      ),
      child: Icon(
        isLocked ? Iconsax.lock_15 : Iconsax.unlock,
        color: Colors.white,
        size: 24,
      ),
    );
  }

  Widget _buildDoorControl(DeviceProvider provider, Device device) {
    final isOpen = device.isOpen;
    return GestureDetector(
      onTap: () {
        HapticFeedback.mediumImpact();
        provider.toggleDoor();
      },
      child: Container(
        width: 50,
        height: 50,
        decoration: BoxDecoration(
          gradient: isOpen
              ? LinearGradient(
                  colors: [Colors.orange.shade400, Colors.orange.shade600])
              : LinearGradient(
                  colors: [Colors.green.shade400, Colors.green.shade600]),
          borderRadius: AppTheme.smallRadius,
        ),
        child: Icon(
          isOpen ? Icons.door_front_door : Icons.door_front_door_outlined,
          color: Colors.white,
          size: 24,
        ),
      ),
    );
  }

  Widget _buildWindowControl(DeviceProvider provider, Device device) {
    final isOpen = device.isOpen;
    return GestureDetector(
      onTap: () {
        HapticFeedback.mediumImpact();
        provider.toggleWindow(device.id);
      },
      child: Container(
        width: 50,
        height: 50,
        decoration: BoxDecoration(
          gradient: isOpen
              ? LinearGradient(
                  colors: [Colors.blue.shade300, Colors.blue.shade500])
              : LinearGradient(
                  colors: [Colors.grey.shade400, Colors.grey.shade600]),
          borderRadius: AppTheme.smallRadius,
        ),
        child: Icon(
          isOpen ? Icons.window : Icons.window_outlined,
          color: Colors.white,
          size: 24,
        ),
      ),
    );
  }

  Widget _buildGarageControl(DeviceProvider provider, Device device) {
    final isOpen = device.isOpen;
    return GestureDetector(
      onTap: () {
        HapticFeedback.mediumImpact();
        provider.toggleGarage();
      },
      child: Container(
        width: 50,
        height: 50,
        decoration: BoxDecoration(
          gradient: isOpen
              ? LinearGradient(
                  colors: [Colors.red.shade400, Colors.red.shade600])
              : LinearGradient(
                  colors: [Colors.green.shade400, Colors.green.shade600]),
          borderRadius: AppTheme.smallRadius,
        ),
        child: Icon(
          isOpen ? Icons.garage : Icons.garage_outlined,
          color: Colors.white,
          size: 24,
        ),
      ),
    );
  }

  Widget _buildBuzzerControl(DeviceProvider provider, Device device) {
    final isActive = device.isBuzzerActive;
    return GestureDetector(
      onTap: () {
        HapticFeedback.mediumImpact();
        provider.toggleBuzzer();
      },
      child: Container(
        width: 50,
        height: 50,
        decoration: BoxDecoration(
          gradient: isActive
              ? LinearGradient(
                  colors: [Colors.red.shade400, Colors.red.shade600])
              : LinearGradient(
                  colors: [Colors.grey.shade400, Colors.grey.shade600]),
          borderRadius: AppTheme.smallRadius,
        ),
        child: Icon(
          isActive ? Icons.notifications_active : Icons.notifications_off,
          color: Colors.white,
          size: 24,
        ),
      ),
    );
  }

  LinearGradient _getDeviceGradient(DeviceType type) {
    switch (type) {
      case DeviceType.light:
        return AppTheme.accentGradient;
      case DeviceType.alarm:
        return LinearGradient(
            colors: [Colors.red.shade400, Colors.red.shade600]);
      case DeviceType.sensor:
        return LinearGradient(
            colors: [Colors.blue.shade400, Colors.blue.shade600]);
      case DeviceType.camera:
        return LinearGradient(
            colors: [Colors.purple.shade400, Colors.purple.shade600]);
      case DeviceType.thermostat:
        return LinearGradient(
            colors: [Colors.orange.shade400, Colors.orange.shade600]);
      case DeviceType.lock:
        return LinearGradient(
            colors: [Colors.green.shade400, Colors.green.shade600]);
      case DeviceType.door:
        return LinearGradient(
            colors: [Colors.brown.shade400, Colors.brown.shade600]);
      case DeviceType.window:
        return LinearGradient(
            colors: [Colors.cyan.shade400, Colors.cyan.shade600]);
      case DeviceType.garage:
        return LinearGradient(
            colors: [Colors.indigo.shade400, Colors.indigo.shade600]);
      case DeviceType.buzzer:
        return LinearGradient(
            colors: [Colors.amber.shade400, Colors.amber.shade600]);
      case DeviceType.fan:
        return LinearGradient(
            colors: [Colors.teal.shade400, Colors.teal.shade600]);
    }
  }

  IconData _getDeviceIcon(DeviceType type) {
    switch (type) {
      case DeviceType.light:
        return Iconsax.lamp_on5;
      case DeviceType.alarm:
        return Iconsax.warning_25;
      case DeviceType.sensor:
        return Iconsax.radar_25;
      case DeviceType.camera:
        return Iconsax.video5;
      case DeviceType.thermostat:
        return Iconsax.status_up;
      case DeviceType.lock:
        return Iconsax.lock_15;
      case DeviceType.door:
        return Icons.door_front_door;
      case DeviceType.window:
        return Icons.window;
      case DeviceType.garage:
        return Icons.garage;
      case DeviceType.buzzer:
        return Icons.notifications_active;
      case DeviceType.fan:
        return Icons.air;
    }
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final difference = now.difference(time);

    if (difference.inSeconds < 60) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else {
      return '${difference.inDays}d ago';
    }
  }

  void _showDeviceDetails(BuildContext context, Device device) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          gradient: AppTheme.cardGradient,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    gradient: _getDeviceGradient(device.type),
                    borderRadius: AppTheme.smallRadius,
                  ),
                  child: Icon(_getDeviceIcon(device.type), color: Colors.white),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    device.name,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.lightText,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            _buildDetailRow('ID', device.id),
            _buildDetailRow('Room', device.room),
            _buildDetailRow('Type', device.type.toString().split('.').last),
            _buildDetailRow('Status', device.status.toString().split('.').last),
            const SizedBox(height: 16),
            const Text(
              'State:',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppTheme.lightText,
              ),
            ),
            const SizedBox(height: 8),
            ...device.state.entries.map(
              (entry) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      entry.key,
                      style: const TextStyle(color: AppTheme.mutedText),
                    ),
                    Text(
                      '${entry.value}',
                      style: const TextStyle(
                        color: AppTheme.primaryColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(color: AppTheme.mutedText, fontSize: 14),
          ),
          Text(
            value,
            style: const TextStyle(
              color: AppTheme.lightText,
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}

/// Quick Controls Section Widget - Always visible controls for door, garage, windows, lights, buzzer
class _QuickControlsSection extends StatelessWidget {
  final DeviceProvider deviceProvider;

  const _QuickControlsSection({required this.deviceProvider});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 12),
            child: Row(
              children: [
                Icon(Iconsax.setting_4, size: 20, color: AppTheme.primaryColor),
                const SizedBox(width: 8),
                Text(
                  'Quick Controls',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.onBackground,
                  ),
                ),
              ],
            ),
          ),

          // Security Controls Section
          _buildSectionHeader(context, 'Security', Iconsax.shield_tick, isDark),
          const SizedBox(height: 8),
          _buildDeviceListItem(
            context,
            icon: Icons.door_front_door,
            name: 'Main Door',
            deviceId: 'main_door',
            mqttTopic: 'home/main_door/command',
            isActive: deviceProvider.isDoorOpen,
            activeColor: Colors.orange,
            inactiveColor: Colors.green,
            activeLabel: 'OPEN',
            inactiveLabel: 'CLOSED',
            onTap: () {
              HapticFeedback.mediumImpact();
              deviceProvider.toggleDoor();
            },
            isDark: isDark,
          ),
          const SizedBox(height: 8),
          _buildDeviceListItem(
            context,
            icon: Icons.garage,
            name: 'Garage Door',
            deviceId: 'garage_door',
            mqttTopic: 'home/garage_door/command',
            isActive: deviceProvider.isGarageOpen,
            activeColor: Colors.red,
            inactiveColor: Colors.green,
            activeLabel: 'OPEN',
            inactiveLabel: 'CLOSED',
            onTap: () {
              HapticFeedback.mediumImpact();
              deviceProvider.toggleGarage();
            },
            isDark: isDark,
          ),
          const SizedBox(height: 8),
          _buildDeviceListItem(
            context,
            icon: Icons.notifications_active,
            name: 'Alert Buzzer',
            deviceId: 'buzzer',
            mqttTopic: 'home/buzzer/command',
            isActive: deviceProvider.isBuzzerActive,
            activeColor: Colors.red,
            inactiveColor: Colors.grey,
            activeLabel: 'ACTIVE',
            inactiveLabel: 'OFF',
            onTap: () {
              HapticFeedback.mediumImpact();
              deviceProvider.toggleBuzzer();
            },
            isDark: isDark,
          ),

          const SizedBox(height: 16),

          // Windows Section
          _buildSectionHeader(context, 'Windows', Icons.window, isDark),
          const SizedBox(height: 8),
          ...deviceProvider.windowStates.entries.map((entry) {
            final windowName = _formatName(entry.key);
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _buildDeviceListItem(
                context,
                icon: Icons.window,
                name: '$windowName Window',
                deviceId: 'window_${entry.key}',
                mqttTopic: 'home/${entry.key}/window/command',
                isActive: entry.value,
                activeColor: Colors.blue,
                inactiveColor: Colors.grey,
                activeLabel: 'OPEN',
                inactiveLabel: 'CLOSED',
                onTap: () {
                  HapticFeedback.mediumImpact();
                  deviceProvider.toggleWindow(entry.key);
                },
                isDark: isDark,
              ),
            );
          }).toList(),

          const SizedBox(height: 16),

          // Lights Section
          _buildSectionHeader(context, 'Lights', Iconsax.lamp_on5, isDark),
          const SizedBox(height: 8),
          ...deviceProvider.lightStates.entries.map((entry) {
            final lightName = _formatName(entry.key);
            final isRgb = entry.key == 'rgb';
            final brightness = deviceProvider.lightBrightness[entry.key] ?? 100;
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _buildLightListItem(
                context,
                icon: isRgb ? Icons.color_lens : Iconsax.lamp_on5,
                name: '$lightName Light',
                deviceId: 'light_${entry.key}',
                lightId: entry.key,
                mqttTopic: 'home/${entry.key}/light/set',
                isActive: entry.value,
                brightness: brightness,
                activeColor: isRgb
                    ? Color(deviceProvider.rgbLightColor | 0xFF000000)
                    : Colors.amber,
                inactiveColor: Colors.grey,
                activeLabel: 'ON',
                inactiveLabel: 'OFF',
                isRgb: isRgb,
                onTap: () {
                  HapticFeedback.mediumImpact();
                  deviceProvider.toggleLightById(entry.key);
                },
                onLongPress: () {
                  HapticFeedback.heavyImpact();
                  if (isRgb) {
                    _showRgbColorDialog(context, deviceProvider);
                  } else {
                    _showBrightnessDialog(
                        context, deviceProvider, entry.key, lightName);
                  }
                },
                isDark: isDark,
              ),
            );
          }).toList(),

          const SizedBox(height: 16),

          // Fans Section
          _buildSectionHeader(context, 'Fans', Icons.air, isDark),
          const SizedBox(height: 8),
          ...deviceProvider.fanStates.entries.map((entry) {
            final fanName = _formatName(entry.key);
            final speed = entry.value;
            final speedLabels = ['OFF', 'LOW', 'MED', 'HIGH'];
            final speedColors = [
              Colors.grey,
              Colors.green,
              Colors.blue,
              Colors.orange
            ];
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _buildFanListItem(
                context,
                name: '$fanName Fan',
                deviceId: 'fan_${entry.key}',
                mqttTopic: 'home/${entry.key}/fan/command',
                speed: speed,
                speedLabel: speedLabels[speed],
                speedColor: speedColors[speed],
                onTap: () {
                  HapticFeedback.mediumImpact();
                  deviceProvider.toggleFan(entry.key);
                },
                onLongPress: () {
                  HapticFeedback.heavyImpact();
                  _showFanSpeedDialog(
                      context, deviceProvider, entry.key, fanName);
                },
                isDark: isDark,
              ),
            );
          }).toList(),
        ],
      ),
    );
  }

  void _showFanSpeedDialog(BuildContext context, DeviceProvider provider,
      String fanId, String fanName) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '$fanName Fan Speed',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildSpeedButton(context, provider, fanId, 0, 'Off',
                    Icons.power_settings_new, Colors.grey),
                _buildSpeedButton(context, provider, fanId, 1, 'Low', Icons.air,
                    Colors.green),
                _buildSpeedButton(
                    context, provider, fanId, 2, 'Med', Icons.air, Colors.blue),
                _buildSpeedButton(context, provider, fanId, 3, 'High',
                    Icons.air, Colors.orange),
              ],
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildSpeedButton(BuildContext context, DeviceProvider provider,
      String fanId, int speed, String label, IconData icon, Color color) {
    final currentSpeed = provider.fanStates[fanId] ?? 0;
    final isSelected = currentSpeed == speed;
    return GestureDetector(
      onTap: () {
        provider.setFanSpeed(fanId, speed);
        Navigator.pop(context);
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? color.withOpacity(0.2) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? color : Colors.grey.withOpacity(0.3),
            width: 2,
          ),
        ),
        child: Column(
          children: [
            Icon(icon, color: isSelected ? color : Colors.grey, size: 28),
            const SizedBox(height: 8),
            Text(label,
                style: TextStyle(
                    color: isSelected ? color : Colors.grey,
                    fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  Widget _buildFanListItem(
    BuildContext context, {
    required String name,
    required String deviceId,
    required String mqttTopic,
    required int speed,
    required String speedLabel,
    required Color speedColor,
    required VoidCallback onTap,
    required VoidCallback onLongPress,
    required bool isDark,
  }) {
    final isOn = speed > 0;
    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: GlassmorphicContainer(
        width: double.infinity,
        height: 72,
        borderRadius: 12,
        blur: 15,
        alignment: Alignment.center,
        border: 1.5,
        linearGradient: LinearGradient(
          colors: isOn
              ? [
                  speedColor.withOpacity(0.2),
                  speedColor.withOpacity(0.1),
                ]
              : isDark
                  ? [
                      Colors.white.withOpacity(0.08),
                      Colors.white.withOpacity(0.04),
                    ]
                  : [
                      Colors.white.withOpacity(0.9),
                      Colors.white.withOpacity(0.7),
                    ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderGradient: LinearGradient(
          colors: isOn
              ? [
                  speedColor.withOpacity(0.5),
                  speedColor.withOpacity(0.2),
                ]
              : [
                  Colors.white.withOpacity(0.15),
                  Colors.white.withOpacity(0.05),
                ],
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            children: [
              // Animated fan icon
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [speedColor.shade400, speedColor.shade600],
                  ),
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [
                    BoxShadow(
                      color: speedColor.withOpacity(0.3),
                      blurRadius: 6,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Icon(Icons.air, color: Colors.white, size: 20),
              ),
              const SizedBox(width: 12),

              // Name and ID
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      name,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'ID: $deviceId • Hold to set speed',
                      style: TextStyle(
                        fontSize: 10,
                        fontFamily: 'monospace',
                        color: AppTheme.mutedText,
                      ),
                    ),
                    Text(
                      mqttTopic,
                      style: TextStyle(
                        fontSize: 9,
                        fontFamily: 'monospace',
                        color: AppTheme.mutedText.withOpacity(0.7),
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),

              // Speed Badge
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [speedColor.shade400, speedColor.shade600],
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: speedColor.withOpacity(0.3),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Text(
                  speedLabel,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLightListItem(
    BuildContext context, {
    required IconData icon,
    required String name,
    required String deviceId,
    required String lightId,
    required String mqttTopic,
    required bool isActive,
    required int brightness,
    required Color activeColor,
    required Color inactiveColor,
    required String activeLabel,
    required String inactiveLabel,
    required bool isRgb,
    required VoidCallback onTap,
    required VoidCallback onLongPress,
    required bool isDark,
  }) {
    final stateColor = isActive ? activeColor : inactiveColor;
    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: GlassmorphicContainer(
        width: double.infinity,
        height: 80,
        borderRadius: 12,
        blur: 15,
        alignment: Alignment.center,
        border: 1.5,
        linearGradient: LinearGradient(
          colors: isActive
              ? [
                  activeColor.withOpacity(0.2),
                  activeColor.withOpacity(0.1),
                ]
              : isDark
                  ? [
                      Colors.white.withOpacity(0.08),
                      Colors.white.withOpacity(0.04),
                    ]
                  : [
                      Colors.white.withOpacity(0.9),
                      Colors.white.withOpacity(0.7),
                    ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderGradient: LinearGradient(
          colors: isActive
              ? [
                  activeColor.withOpacity(0.5),
                  activeColor.withOpacity(0.2),
                ]
              : [
                  Colors.white.withOpacity(0.15),
                  Colors.white.withOpacity(0.05),
                ],
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            children: [
              // Icon
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [stateColor.shade400, stateColor.shade600],
                  ),
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [
                    BoxShadow(
                      color: stateColor.withOpacity(0.3),
                      blurRadius: 6,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Icon(icon, color: Colors.white, size: 20),
              ),
              const SizedBox(width: 12),

              // Name and info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      name,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      isRgb
                          ? 'Hold to change color'
                          : 'Hold to adjust brightness',
                      style: TextStyle(
                        fontSize: 10,
                        color: AppTheme.mutedText,
                      ),
                    ),
                    if (isActive && !isRgb) ...[
                      const SizedBox(height: 4),
                      // Mini brightness bar
                      Container(
                        height: 4,
                        width: 80,
                        decoration: BoxDecoration(
                          color: Colors.grey.withOpacity(0.3),
                          borderRadius: BorderRadius.circular(2),
                        ),
                        child: FractionallySizedBox(
                          alignment: Alignment.centerLeft,
                          widthFactor: brightness / 100,
                          child: Container(
                            decoration: BoxDecoration(
                              color: activeColor,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              // State Badge
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [stateColor.shade400, stateColor.shade600],
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: stateColor.withOpacity(0.3),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (isActive && !isRgb) ...[
                      Text(
                        '$brightness%',
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(width: 4),
                    ],
                    Text(
                      isActive ? activeLabel : inactiveLabel,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showBrightnessDialog(BuildContext context, DeviceProvider provider,
      String lightId, String lightName) {
    double currentBrightness =
        (provider.lightBrightness[lightId] ?? 100).toDouble();

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Icon(Iconsax.lamp_on5, color: Colors.amber, size: 28),
                  const SizedBox(width: 12),
                  Text(
                    '$lightName Light Brightness',
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Icon(Icons.brightness_low, color: Colors.grey),
                  Expanded(
                    child: Slider(
                      value: currentBrightness,
                      min: 0,
                      max: 100,
                      divisions: 10,
                      label: '${currentBrightness.round()}%',
                      activeColor: Colors.amber,
                      onChanged: (value) {
                        setModalState(() {
                          currentBrightness = value;
                        });
                      },
                    ),
                  ),
                  Icon(Icons.brightness_high, color: Colors.amber),
                ],
              ),
              Text(
                '${currentBrightness.round()}%',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: Colors.amber.shade700,
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  ElevatedButton.icon(
                    onPressed: () {
                      provider.setLightBrightness(
                          lightId, currentBrightness.round());
                      Navigator.pop(context);
                    },
                    icon: const Icon(Icons.check),
                    label: const Text('Apply'),
                    style:
                        ElevatedButton.styleFrom(backgroundColor: Colors.amber),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                ],
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  void _showRgbColorDialog(BuildContext context, DeviceProvider provider) {
    int currentColor = provider.rgbLightColor;
    int currentBrightness = provider.rgbBrightness;

    final presetColors = [
      0xFF0000, // Red
      0xFF4500, // Orange Red
      0xFF8000, // Orange
      0xFFD700, // Gold
      0xFFFF00, // Yellow
      0x7FFF00, // Chartreuse
      0x00FF00, // Green
      0x00FF7F, // Spring Green
      0x00FFFF, // Cyan
      0x00BFFF, // Deep Sky Blue
      0x0000FF, // Blue
      0x4B0082, // Indigo
      0x8000FF, // Purple
      0x9400D3, // Dark Violet
      0xFF00FF, // Magenta
      0xFF1493, // Deep Pink
      0xFF69B4, // Hot Pink
      0xFFFFFF, // White
    ];

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          final isDark = Theme.of(context).brightness == Brightness.dark;
          return Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: isDark
                    ? [const Color(0xFF1E1E2E), const Color(0xFF15151F)]
                    : [Colors.white, const Color(0xFFF5F5F5)],
              ),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(24)),
              boxShadow: [
                BoxShadow(
                  color: Color(currentColor | 0xFF000000).withOpacity(0.3),
                  blurRadius: 20,
                  spreadRadius: 5,
                ),
              ],
            ),
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Drag handle
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 20),

                // Header with color preview
                Row(
                  children: [
                    // Animated color preview
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [
                            Color(currentColor | 0xFF000000),
                            Color(currentColor | 0xFF000000).withOpacity(0.7),
                          ],
                        ),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.5),
                          width: 3,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Color(currentColor | 0xFF000000)
                                .withOpacity(0.6),
                            blurRadius: 20,
                            spreadRadius: 4,
                          ),
                        ],
                      ),
                      child: Icon(
                        Icons.lightbulb,
                        color: Colors.white.withOpacity(0.9),
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'RGB Corner Lights',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.white : Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '#${currentColor.toRadixString(16).toUpperCase().padLeft(6, '0')}',
                            style: TextStyle(
                              fontSize: 14,
                              fontFamily: 'monospace',
                              color: Color(currentColor | 0xFF000000),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Color grid with gradient background
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.black26 : Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    alignment: WrapAlignment.center,
                    children: presetColors.map((color) {
                      final isSelected = currentColor == color;
                      return GestureDetector(
                        onTap: () {
                          setModalState(() {
                            currentColor = color;
                          });
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          width: isSelected ? 48 : 42,
                          height: isSelected ? 48 : 42,
                          decoration: BoxDecoration(
                            gradient: RadialGradient(
                              colors: [
                                Color(color | 0xFF000000),
                                Color(color | 0xFF000000).withOpacity(0.8),
                              ],
                            ),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: isSelected
                                  ? Colors.white
                                  : Colors.transparent,
                              width: isSelected ? 3 : 0,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Color(color | 0xFF000000)
                                    .withOpacity(isSelected ? 0.8 : 0.3),
                                blurRadius: isSelected ? 16 : 6,
                                spreadRadius: isSelected ? 2 : 0,
                              ),
                            ],
                          ),
                          child: isSelected
                              ? const Icon(Icons.check,
                                  color: Colors.white, size: 22)
                              : null,
                        ),
                      );
                    }).toList(),
                  ),
                ),

                const SizedBox(height: 24),

                // Brightness slider
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.black26 : Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.brightness_6,
                                color: Color(currentColor | 0xFF000000),
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Brightness',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color:
                                      isDark ? Colors.white70 : Colors.black54,
                                ),
                              ),
                            ],
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 4),
                            decoration: BoxDecoration(
                              color: Color(currentColor | 0xFF000000)
                                  .withOpacity(0.2),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              '$currentBrightness%',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: Color(currentColor | 0xFF000000),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      SliderTheme(
                        data: SliderThemeData(
                          activeTrackColor: Color(currentColor | 0xFF000000),
                          inactiveTrackColor:
                              Color(currentColor | 0xFF000000).withOpacity(0.2),
                          thumbColor: Colors.white,
                          overlayColor:
                              Color(currentColor | 0xFF000000).withOpacity(0.2),
                          trackHeight: 8,
                          thumbShape: const RoundSliderThumbShape(
                              enabledThumbRadius: 12),
                        ),
                        child: Slider(
                          value: currentBrightness.toDouble(),
                          min: 0,
                          max: 100,
                          onChanged: (value) {
                            setModalState(() {
                              currentBrightness = value.toInt();
                            });
                          },
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // Action buttons
                Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: () => Navigator.pop(context),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: BorderSide(color: Colors.grey.shade400),
                          ),
                        ),
                        child: Text(
                          'Cancel',
                          style: TextStyle(
                            fontSize: 16,
                            color: isDark ? Colors.white60 : Colors.black54,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: ElevatedButton(
                        onPressed: () {
                          provider.setRgbLightColor(currentColor);
                          provider.setRgbBrightness(currentBrightness);
                          Navigator.pop(context);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Color(currentColor | 0xFF000000),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 4,
                          shadowColor:
                              Color(currentColor | 0xFF000000).withOpacity(0.5),
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.check_circle, size: 20),
                            SizedBox(width: 8),
                            Text(
                              'Apply',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  String _formatName(String id) {
    // Handle special cases like 'rgb' -> 'RGB'
    final specialCases = {'rgb': 'RGB'};
    if (specialCases.containsKey(id.toLowerCase())) {
      return specialCases[id.toLowerCase()]!;
    }
    return id
        .split('_')
        .map((word) => word.isNotEmpty
            ? '${word[0].toUpperCase()}${word.substring(1)}'
            : '')
        .join(' ');
  }

  Widget _buildSectionHeader(
      BuildContext context, String title, IconData icon, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, top: 8),
      child: Row(
        children: [
          Icon(
            icon,
            size: 16,
            color: AppTheme.primaryColor,
          ),
          const SizedBox(width: 8),
          Text(
            title,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white70 : Colors.black54,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDeviceListItem(
    BuildContext context, {
    required IconData icon,
    required String name,
    required String deviceId,
    required String mqttTopic,
    required bool isActive,
    required Color activeColor,
    required Color inactiveColor,
    required String activeLabel,
    required String inactiveLabel,
    required VoidCallback onTap,
    required bool isDark,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: GlassmorphicContainer(
        width: double.infinity,
        height: 72,
        borderRadius: 12,
        blur: 15,
        alignment: Alignment.center,
        border: 1.5,
        linearGradient: LinearGradient(
          colors: isActive
              ? [
                  activeColor.withOpacity(0.2),
                  activeColor.withOpacity(0.1),
                ]
              : isDark
                  ? [
                      Colors.white.withOpacity(0.08),
                      Colors.white.withOpacity(0.04),
                    ]
                  : [
                      Colors.white.withOpacity(0.9),
                      Colors.white.withOpacity(0.7),
                    ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderGradient: LinearGradient(
          colors: isActive
              ? [
                  activeColor.withOpacity(0.5),
                  activeColor.withOpacity(0.2),
                ]
              : [
                  Colors.white.withOpacity(0.15),
                  Colors.white.withOpacity(0.05),
                ],
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            children: [
              // Icon
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: isActive
                        ? [activeColor.shade400, activeColor.shade600]
                        : [inactiveColor.shade400, inactiveColor.shade600],
                  ),
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [
                    BoxShadow(
                      color: (isActive ? activeColor : inactiveColor)
                          .withOpacity(0.3),
                      blurRadius: 6,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Icon(icon, color: Colors.white, size: 20),
              ),
              const SizedBox(width: 12),

              // Name and ID
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      name,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'ID: $deviceId',
                      style: TextStyle(
                        fontSize: 10,
                        fontFamily: 'monospace',
                        color: AppTheme.mutedText,
                      ),
                    ),
                    Text(
                      mqttTopic,
                      style: TextStyle(
                        fontSize: 9,
                        fontFamily: 'monospace',
                        color: AppTheme.mutedText.withOpacity(0.7),
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),

              // Status Badge
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: isActive
                        ? [activeColor.shade400, activeColor.shade600]
                        : [inactiveColor.shade400, inactiveColor.shade600],
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: (isActive ? activeColor : inactiveColor)
                          .withOpacity(0.3),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Text(
                  isActive ? activeLabel : inactiveLabel,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

extension _ColorShadeExtension on Color {
  Color get shade300 => HSLColor.fromColor(this).withLightness(0.6).toColor();
  Color get shade400 => HSLColor.fromColor(this).withLightness(0.5).toColor();
  Color get shade500 => HSLColor.fromColor(this).withLightness(0.45).toColor();
  Color get shade600 => HSLColor.fromColor(this).withLightness(0.4).toColor();
  Color get shade800 => HSLColor.fromColor(this).withLightness(0.25).toColor();
}
