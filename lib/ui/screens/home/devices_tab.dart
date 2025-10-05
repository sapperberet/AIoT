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
    return Consumer<DeviceProvider>(
      builder: (context, deviceProvider, child) {
        final devices = deviceProvider.devices;
        final alarms = deviceProvider.activeAlarms;

        return Container(
          decoration: const BoxDecoration(
            gradient: AppTheme.backgroundGradient,
          ),
          child: Column(
            children: [
              // Active Alarms Section
              if (alarms.isNotEmpty)
                FadeInDown(
                  child: Container(
                    margin: const EdgeInsets.all(16),
                    child: GlassmorphicContainer(
                      width: double.infinity,
                      height: alarms.length > 2 ? 180 : alarms.length * 70 + 50,
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
                                  child: const Icon(Iconsax.warning_2, color: Colors.white, size: 20),
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
                                children: alarms.take(2).map((alarm) => Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 4),
                                  child: Row(
                                    children: [
                                      Icon(Iconsax.danger, color: AppTheme.errorColor, size: 16),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          '${alarm.type} in ${alarm.location}',
                                          style: const TextStyle(color: AppTheme.lightText),
                                        ),
                                      ),
                                      TextButton(
                                        onPressed: () => deviceProvider.acknowledgeAlarm(alarm.id),
                                        child: Text(AppLocalizations.of(context).t('clear')),
                                      ),
                                    ],
                                  ),
                                )).toList(),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              
              // Devices List
              Expanded(
                child: devices.isEmpty
                    ? Center(
                        child: FadeIn(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                width: 120,
                                height: 120,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  gradient: AppTheme.primaryGradient.scale(0.3),
                                ),
                                child: const Icon(Iconsax.devices_1, size: 50, color: AppTheme.primaryColor),
                              ),
                              const SizedBox(height: 24),
                              Text(
                                AppLocalizations.of(context).t('no_devices'),
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.lightText,
                                ),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                AppLocalizations.of(context).t('add_devices_desc'),
                                style: TextStyle(
                                  fontSize: 14,
                                  color: AppTheme.mutedText,
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    : AnimationLimiter(
                        child: ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: devices.length,
                          itemBuilder: (context, index) {
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
                          },
                        ),
                      ),
              ),
            ],
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
    return const LinearGradient(colors: [Colors.transparent, Colors.transparent]);
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
            colors: [
              Colors.white.withOpacity(0.1),
              Colors.white.withOpacity(0.05),
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
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.lightText,
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
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: device.status == DeviceStatus.online
                                  ? AppTheme.successColor.withOpacity(0.2)
                                  : AppTheme.mutedText.withOpacity(0.2),
                              borderRadius: AppTheme.smallRadius,
                            ),
                            child: Text(
                              device.status == DeviceStatus.online ? 'Online' : 'Offline',
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

                // Device Control
                if (device.type == DeviceType.light)
                  _buildLightControl(deviceProvider, device)
                else if (device.type == DeviceType.lock)
                  _buildLockIcon(device)
                else
                  const Icon(Iconsax.arrow_right_3, color: AppTheme.mutedText, size: 20),
              ],
            ),
          ),
        ),
      ),
    );
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
            ? LinearGradient(colors: [Colors.green.shade400, Colors.green.shade600])
            : LinearGradient(colors: [Colors.orange.shade400, Colors.orange.shade600]),
        borderRadius: AppTheme.smallRadius,
      ),
      child: Icon(
        isLocked ? Iconsax.lock_15 : Iconsax.unlock,
        color: Colors.white,
        size: 24,
      ),
    );
  }

  LinearGradient _getDeviceGradient(DeviceType type) {
    switch (type) {
      case DeviceType.light:
        return AppTheme.accentGradient;
      case DeviceType.alarm:
        return LinearGradient(colors: [Colors.red.shade400, Colors.red.shade600]);
      case DeviceType.sensor:
        return LinearGradient(colors: [Colors.blue.shade400, Colors.blue.shade600]);
      case DeviceType.camera:
        return LinearGradient(colors: [Colors.purple.shade400, Colors.purple.shade600]);
      case DeviceType.thermostat:
        return LinearGradient(colors: [Colors.orange.shade400, Colors.orange.shade600]);
      case DeviceType.lock:
        return LinearGradient(colors: [Colors.green.shade400, Colors.green.shade600]);
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

