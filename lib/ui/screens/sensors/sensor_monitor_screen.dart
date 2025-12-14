import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:iconsax/iconsax.dart';
import 'package:animate_do/animate_do.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/providers/device_provider.dart';
import '../../../core/services/mqtt_service.dart';
import '../../widgets/floating_chat_button.dart';

class SensorMonitorScreen extends StatefulWidget {
  const SensorMonitorScreen({super.key});

  @override
  State<SensorMonitorScreen> createState() => _SensorMonitorScreenState();
}

class _SensorMonitorScreenState extends State<SensorMonitorScreen> {
  String _selectedSensor = 'all';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textColor = theme.colorScheme.onBackground;
    final deviceProvider = context.watch<DeviceProvider>();
    final mqttService = context.watch<MqttService>();
    final loc = AppLocalizations.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: FadeInLeft(
          child: IconButton(
            icon: Icon(Iconsax.arrow_left, color: textColor),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        title: FadeInDown(
          child: ShaderMask(
            shaderCallback: (bounds) =>
                AppTheme.primaryGradient.createShader(bounds),
            child: Text(
              loc.translate('sensor_monitor'),
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
        ),
      ),
      body: Stack(
        children: [
          FadeIn(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Connection status banner
                  _buildConnectionStatus(mqttService),
                  const SizedBox(height: 16),

                  // Sensor type selector
                  _buildSensorSelector(),
                  const SizedBox(height: 24),

                  // Sensor Cards Grid
                  _buildSensorGrid(deviceProvider),
                  const SizedBox(height: 24),

                  // Detailed Sensor Charts
                  _buildSensorCharts(deviceProvider),
                  const SizedBox(height: 100),
                ],
              ),
            ),
          ),
          const FloatingChatButton(),
        ],
      ),
    );
  }

  Widget _buildConnectionStatus(MqttService mqttService) {
    final isConnected = mqttService.currentStatus == ConnectionStatus.connected;

    return FadeInDown(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: (isConnected ? Colors.green : Colors.orange).withOpacity(0.1),
          borderRadius: AppTheme.mediumRadius,
          border: Border.all(
            color:
                (isConnected ? Colors.green : Colors.orange).withOpacity(0.3),
          ),
        ),
        child: Row(
          children: [
            Icon(
              isConnected ? Iconsax.tick_circle : Iconsax.warning_2,
              color: isConnected ? Colors.green : Colors.orange,
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                isConnected
                    ? 'Connected - receiving live sensor data'
                    : 'Not connected - showing cached data',
                style: TextStyle(
                  color: isConnected ? Colors.green : Colors.orange,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSensorSelector() {
    final sensors = [
      {'id': 'all', 'name': 'All', 'icon': Iconsax.category},
      {'id': 'temperature', 'name': 'Temperature', 'icon': Iconsax.sun_1},
      {'id': 'humidity', 'name': 'Humidity', 'icon': Iconsax.drop},
      {'id': 'gas', 'name': 'Gas', 'icon': Iconsax.cloud},
      {'id': 'smoke', 'name': 'Smoke', 'icon': Iconsax.cloud_fog},
      {'id': 'motion', 'name': 'Motion', 'icon': Iconsax.radar},
      {'id': 'light', 'name': 'Light', 'icon': Iconsax.lamp_charge},
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: sensors.map((sensor) {
          final isSelected = _selectedSensor == sensor['id'];
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: _buildSelectorChip(
              sensor['name'] as String,
              sensor['icon'] as IconData,
              isSelected,
              () => setState(() => _selectedSensor = sensor['id'] as String),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildSelectorChip(
    String label,
    IconData icon,
    bool isSelected,
    VoidCallback onTap,
  ) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final textColor = theme.colorScheme.onBackground;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          gradient: isSelected ? AppTheme.primaryGradient : null,
          color: isSelected
              ? null
              : (isDark ? AppTheme.darkCard : AppTheme.lightSurface),
          borderRadius: AppTheme.mediumRadius,
          border: Border.all(
            color:
                isSelected ? AppTheme.primaryColor : textColor.withOpacity(0.1),
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 18,
              color: isSelected ? Colors.white : textColor.withOpacity(0.6),
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                color: isSelected ? Colors.white : textColor.withOpacity(0.6),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSensorGrid(DeviceProvider deviceProvider) {
    final allSensors = [
      _SensorData(
        id: 'temperature',
        name: 'Temperature',
        value: deviceProvider.temperature,
        unit: '°C',
        icon: Iconsax.sun_1,
        color: Colors.orange,
        minValue: 0,
        maxValue: 50,
        warningThreshold: 35,
        dangerThreshold: 40,
      ),
      _SensorData(
        id: 'humidity',
        name: 'Humidity',
        value: deviceProvider.humidity,
        unit: '%',
        icon: Iconsax.drop,
        color: Colors.blue,
        minValue: 0,
        maxValue: 100,
        warningThreshold: 70,
        dangerThreshold: 85,
      ),
      _SensorData(
        id: 'gas',
        name: 'Gas Level',
        value: deviceProvider.gasLevel,
        unit: 'ppm',
        icon: Iconsax.cloud,
        color: Colors.purple,
        minValue: 0,
        maxValue: 1000,
        warningThreshold: 500,
        dangerThreshold: 800,
      ),
      _SensorData(
        id: 'smoke',
        name: 'Smoke Level',
        value: deviceProvider.smokeLevel,
        unit: 'ppm',
        icon: Iconsax.cloud_fog,
        color: Colors.red,
        minValue: 0,
        maxValue: 500,
        warningThreshold: 100,
        dangerThreshold: 200,
      ),
      _SensorData(
        id: 'motion',
        name: 'Motion',
        value: deviceProvider.motionDetected ? 1.0 : 0.0,
        unit: '',
        icon: Iconsax.radar,
        color: Colors.teal,
        minValue: 0,
        maxValue: 1,
        isBoolean: true,
        booleanLabels: ['No Motion', 'Motion Detected'],
      ),
      _SensorData(
        id: 'light',
        name: 'Light Level',
        value: deviceProvider.lightLevel,
        unit: 'lux',
        icon: Iconsax.lamp_charge,
        color: Colors.amber,
        minValue: 0,
        maxValue: 1000,
        warningThreshold: 800,
        dangerThreshold: 950,
      ),
    ];

    final filteredSensors = _selectedSensor == 'all'
        ? allSensors
        : allSensors.where((s) => s.id == _selectedSensor).toList();

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 0.9,
      ),
      itemCount: filteredSensors.length,
      itemBuilder: (context, index) {
        final sensor = filteredSensors[index];
        return FadeInUp(
          delay: Duration(milliseconds: 50 * index),
          child: _buildSensorCard(sensor),
        );
      },
    );
  }

  Widget _buildSensorCard(_SensorData sensor) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final textColor = theme.colorScheme.onBackground;

    // Determine status color
    Color statusColor = Colors.green;
    String statusText = 'Normal';
    if (!sensor.isBoolean) {
      if (sensor.value >= sensor.dangerThreshold) {
        statusColor = Colors.red;
        statusText = 'Danger';
      } else if (sensor.value >= sensor.warningThreshold) {
        statusColor = Colors.orange;
        statusText = 'Warning';
      }
    } else {
      if (sensor.value > 0) {
        statusColor = Colors.teal;
        statusText = sensor.booleanLabels?[1] ?? 'Active';
      } else {
        statusText = sensor.booleanLabels?[0] ?? 'Inactive';
      }
    }

    // Calculate percentage for progress
    final percentage = sensor.isBoolean
        ? sensor.value
        : ((sensor.value - sensor.minValue) /
                (sensor.maxValue - sensor.minValue))
            .clamp(0.0, 1.0);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: isDark ? AppTheme.cardGradient : null,
        color: isDark ? null : theme.cardTheme.color,
        borderRadius: AppTheme.largeRadius,
        border: Border.all(
          color: sensor.color.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: sensor.color.withOpacity(0.2),
                  borderRadius: AppTheme.smallRadius,
                ),
                child: Icon(
                  sensor.icon,
                  color: sensor.color,
                  size: 20,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  statusText,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: statusColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            sensor.name,
            style: TextStyle(
              fontSize: 14,
              color: textColor.withOpacity(0.7),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            sensor.isBoolean
                ? (sensor.value > 0 ? 'Detected' : 'Clear')
                : '${sensor.value.toStringAsFixed(1)}${sensor.unit}',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: textColor,
            ),
          ),
          const Spacer(),
          // Progress indicator
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: percentage,
              backgroundColor: sensor.color.withOpacity(0.2),
              valueColor: AlwaysStoppedAnimation<Color>(sensor.color),
              minHeight: 6,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSensorCharts(DeviceProvider deviceProvider) {
    final theme = Theme.of(context);
    final textColor = theme.colorScheme.onBackground;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Sensor History',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: textColor,
          ),
        ),
        const SizedBox(height: 16),
        // Temperature Chart
        _buildChartCard(
          'Temperature Trend',
          Iconsax.sun_1,
          Colors.orange,
          deviceProvider.temperature,
          '°C',
        ),
        const SizedBox(height: 12),
        // Humidity Chart
        _buildChartCard(
          'Humidity Trend',
          Iconsax.drop,
          Colors.blue,
          deviceProvider.humidity,
          '%',
        ),
        const SizedBox(height: 12),
        // Gas Level Chart
        _buildChartCard(
          'Gas Level Trend',
          Iconsax.cloud,
          Colors.purple,
          deviceProvider.gasLevel,
          'ppm',
        ),
      ],
    );
  }

  Widget _buildChartCard(
    String title,
    IconData icon,
    Color color,
    double currentValue,
    String unit,
  ) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final textColor = theme.colorScheme.onBackground;

    // Simulated chart data points
    final dataPoints = List.generate(
      12,
      (i) =>
          (currentValue * (0.8 + (i % 3) * 0.1)).clamp(0.0, currentValue * 1.2),
    );

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: isDark ? AppTheme.cardGradient : null,
        color: isDark ? null : theme.cardTheme.color,
        borderRadius: AppTheme.largeRadius,
        border: Border.all(
          color: color.withOpacity(0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: textColor,
                ),
              ),
              const Spacer(),
              Text(
                '${currentValue.toStringAsFixed(1)}$unit',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 80,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: dataPoints.asMap().entries.map((entry) {
                final index = entry.key;
                final value = entry.value;
                final maxValue = dataPoints.reduce((a, b) => a > b ? a : b);
                final height = maxValue > 0 ? (value / maxValue) * 60 : 0.0;

                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2),
                    child: Container(
                      height: height,
                      decoration: BoxDecoration(
                        color: color.withOpacity(
                            0.3 + (index / dataPoints.length) * 0.7),
                        borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(4)),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '12h ago',
                style:
                    TextStyle(fontSize: 10, color: textColor.withOpacity(0.5)),
              ),
              Text(
                'Now',
                style:
                    TextStyle(fontSize: 10, color: textColor.withOpacity(0.5)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SensorData {
  final String id;
  final String name;
  final double value;
  final String unit;
  final IconData icon;
  final Color color;
  final double minValue;
  final double maxValue;
  final double warningThreshold;
  final double dangerThreshold;
  final bool isBoolean;
  final List<String>? booleanLabels;

  _SensorData({
    required this.id,
    required this.name,
    required this.value,
    required this.unit,
    required this.icon,
    required this.color,
    this.minValue = 0,
    this.maxValue = 100,
    this.warningThreshold = 70,
    this.dangerThreshold = 90,
    this.isBoolean = false,
    this.booleanLabels,
  });
}
