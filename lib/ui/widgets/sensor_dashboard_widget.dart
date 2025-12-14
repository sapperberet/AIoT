import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:iconsax/iconsax.dart';
import '../../core/providers/device_provider.dart';
import '../../core/theme/app_theme.dart';

/// Widget to display real-time sensor readings
class SensorDashboardWidget extends StatelessWidget {
  const SensorDashboardWidget({super.key});

  @override
  Widget build(BuildContext context) {
    final deviceProvider = Provider.of<DeviceProvider>(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      children: [
        // Temperature & Humidity Row
        Row(
          children: [
            Expanded(
              child: _buildSensorCard(
                context,
                icon: Iconsax.cloud,
                label: 'Temperature',
                value: '${deviceProvider.temperature.toStringAsFixed(1)}°C',
                color: Colors.orange,
                isDark: isDark,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildSensorCard(
                context,
                icon: Iconsax.drop,
                label: 'Humidity',
                value: '${deviceProvider.humidity.toStringAsFixed(0)}%',
                color: Colors.blue,
                isDark: isDark,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Energy & Light Row
        Row(
          children: [
            Expanded(
              child: _buildSensorCard(
                context,
                icon: Iconsax.flash_1,
                label: 'Energy',
                value:
                    '${deviceProvider.energyConsumption.toStringAsFixed(2)} kWh',
                color: Colors.amber,
                isDark: isDark,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildSensorCard(
                context,
                icon: Iconsax.sun_1,
                label: 'Light Level',
                value: '${deviceProvider.lightLevel.toStringAsFixed(0)} lux',
                color: Colors.yellow,
                isDark: isDark,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Gas & Air Quality Row
        Row(
          children: [
            Expanded(
              child: _buildSensorCard(
                context,
                icon: Iconsax.danger,
                label: 'Gas Level',
                value: '${deviceProvider.gasLevel.toStringAsFixed(0)} ppm',
                color:
                    deviceProvider.gasLevel > 300 ? Colors.red : Colors.green,
                isDark: isDark,
                isWarning: deviceProvider.gasLevel > 300,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildSensorCard(
                context,
                icon: Iconsax.wind_2,
                label: 'Air Quality',
                value: _getAirQualityLabel(deviceProvider.airQuality),
                color: _getAirQualityColor(deviceProvider.airQuality),
                isDark: isDark,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSensorCard(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String value,
    required Color color,
    required bool isDark,
    bool isWarning = false,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? [
                  color.withOpacity(0.15),
                  color.withOpacity(0.05),
                ]
              : [
                  color.withOpacity(0.1),
                  color.withOpacity(0.05),
                ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isWarning ? Colors.red : color.withOpacity(0.3),
          width: isWarning ? 2 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  icon,
                  color: color,
                  size: 20,
                ),
              ),
              if (isWarning) ...[
                const SizedBox(width: 8),
                Icon(
                  Iconsax.warning_2,
                  color: Colors.red,
                  size: 16,
                ),
              ],
            ],
          ),
          const SizedBox(height: 12),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: isDark ? Colors.white70 : Colors.black54,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: isWarning ? Colors.red : color,
            ),
          ),
        ],
      ),
    );
  }

  String _getAirQualityLabel(double aqi) {
    if (aqi == 0) return 'N/A';
    if (aqi <= 50) return 'Good';
    if (aqi <= 100) return 'Moderate';
    if (aqi <= 150) return 'Unhealthy';
    if (aqi <= 200) return 'Very Unhealthy';
    return 'Hazardous';
  }

  Color _getAirQualityColor(double aqi) {
    if (aqi == 0) return Colors.grey;
    if (aqi <= 50) return Colors.green;
    if (aqi <= 100) return Colors.yellow;
    if (aqi <= 150) return Colors.orange;
    if (aqi <= 200) return Colors.red;
    return Colors.purple;
  }
}
