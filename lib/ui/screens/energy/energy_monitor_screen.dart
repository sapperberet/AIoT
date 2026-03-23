import 'dart:math';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:iconsax/iconsax.dart';
import 'package:animate_do/animate_do.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/providers/energy_provider.dart';
import '../../../core/services/energy_service.dart';
import '../../../core/services/mqtt_service.dart';
import '../../widgets/floating_chat_button.dart';

class EnergyMonitorScreen extends StatefulWidget {
  const EnergyMonitorScreen({super.key});

  @override
  State<EnergyMonitorScreen> createState() => _EnergyMonitorScreenState();
}

class _EnergyMonitorScreenState extends State<EnergyMonitorScreen> {
  String _selectedPeriod = 'today';

  @override
  void initState() {
    super.initState();
    // Refresh energy data when screen opens
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<EnergyProvider>().refresh();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textColor = theme.colorScheme.onBackground;
    final energyProvider = context.watch<EnergyProvider>();
    final mqttService = context.watch<MqttService>();

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
              AppLocalizations.of(context).t('energy_monitor'),
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
                  _buildConnectionStatusBanner(energyProvider, mqttService),
                  const SizedBox(height: 16),

                  // Period selector
                  _buildPeriodSelector(),
                  const SizedBox(height: 24),

                  // Real-time readings (always visible)
                  _buildRealTimeReadingsCard(energyProvider),
                  const SizedBox(height: 24),

                  // Total consumption card
                  _buildTotalConsumptionCard(energyProvider),
                  const SizedBox(height: 24),

                  // Consumption chart (placeholder)
                  _buildConsumptionChart(energyProvider),
                  const SizedBox(height: 24),

                  // Stored history list
                  _buildHistoryCard(energyProvider),
                  const SizedBox(height: 24),

                  // Device breakdown
                  _buildSectionTitle('Device Breakdown'),
                  const SizedBox(height: 16),
                  _buildDeviceBreakdownList(energyProvider),
                  const SizedBox(height: 24),

                  // Cost estimate
                  _buildCostEstimateCard(energyProvider),
                  const SizedBox(height: 24),

                  // Tips
                  _buildSectionTitle('Energy Saving Tips'),
                  const SizedBox(height: 16),
                  _buildEnergyTips(),
                  const SizedBox(height: 100),
                ],
              ),
            ),
          ),
          // Floating chat button
          const FloatingChatButton(),
        ],
      ),
    );
  }

  Widget _buildConnectionStatusBanner(
      EnergyProvider energyProvider, MqttService mqttService) {
    final isConnected = mqttService.currentStatus == ConnectionStatus.connected;
    final hasData = energyProvider.currentEnergy != null;

    Color bgColor;
    IconData icon;
    String message;

    if (!isConnected) {
      bgColor = Colors.orange;
      icon = Iconsax.warning_2;
      message = 'MQTT broker not connected - showing cached data';
    } else if (!hasData) {
      bgColor = Colors.blue;
      icon = Iconsax.search_normal;
      message = 'Connected - searching for energy meters...';
    } else {
      bgColor = Colors.green;
      icon = Iconsax.tick_circle;
      message =
          'Live data from ${energyProvider.detectedDevices.length} meter(s)';
    }

    return FadeInDown(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: bgColor.withOpacity(0.1),
          borderRadius: AppTheme.mediumRadius,
          border: Border.all(color: bgColor.withOpacity(0.3)),
        ),
        child: Row(
          children: [
            Icon(icon, color: bgColor, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: TextStyle(
                  color: bgColor,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            if (energyProvider.isLoading)
              SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: bgColor,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildRealTimeReadingsCard(EnergyProvider energyProvider) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final textColor = theme.colorScheme.onBackground;
    final energy = energyProvider.currentEnergy;

    return FadeInUp(
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: isDark ? AppTheme.cardGradient : null,
          color: isDark ? null : theme.cardTheme.color,
          borderRadius: AppTheme.largeRadius,
          border: Border.all(
            color: AppTheme.primaryColor.withOpacity(0.3),
            width: 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Iconsax.activity, color: Colors.green, size: 20),
                const SizedBox(width: 8),
                Text(
                  'Live Readings',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: textColor,
                  ),
                ),
                const Spacer(),
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: energyProvider.isConnected
                        ? Colors.green
                        : Colors.orange,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  energyProvider.isConnected ? 'LIVE' : 'WAITING',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: energyProvider.isConnected
                        ? Colors.green
                        : Colors.orange,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: _buildReadingTile(
                    'Voltage',
                    '${(energy?.voltage ?? 0).toStringAsFixed(1)} V',
                    Iconsax.flash_1,
                    Colors.amber,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildReadingTile(
                    'Current',
                    '${(energy?.current ?? 0).toStringAsFixed(2)} A',
                    Iconsax.electricity,
                    Colors.blue,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildReadingTile(
                    'Power',
                    '${(energy?.power ?? 0).toStringAsFixed(0)} W',
                    Iconsax.cpu_charge,
                    Colors.orange,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildReadingTile(
                    'Power Factor',
                    energyProvider.powerFactor.toStringAsFixed(2),
                    Iconsax.chart_21,
                    Colors.purple,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReadingTile(
      String label, String value, IconData icon, Color color) {
    final theme = Theme.of(context);
    final textColor = theme.colorScheme.onBackground;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: AppTheme.smallRadius,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 16),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: textColor.withOpacity(0.6),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: textColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPeriodSelector() {
    final loc = AppLocalizations.of(context);
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _buildPeriodChip('today', loc.t('today')),
          const SizedBox(width: 8),
          _buildPeriodChip('week', loc.t('week')),
          const SizedBox(width: 8),
          _buildPeriodChip('month', loc.t('month')),
          const SizedBox(width: 8),
          _buildPeriodChip('year', loc.t('year')),
        ],
      ),
    );
  }

  Widget _buildPeriodChip(String key, String label) {
    final isSelected = _selectedPeriod == key;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final textColor = theme.colorScheme.onBackground;

    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedPeriod = key;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          gradient: isSelected ? AppTheme.primaryGradient : null,
          color: isSelected
              ? null
              : (isDark ? AppTheme.darkCard : AppTheme.lightSurface),
          borderRadius: AppTheme.mediumRadius,
          border: Border.all(
            color:
                isSelected ? AppTheme.primaryColor : textColor.withOpacity(0.1),
            width: 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
            color: isSelected ? Colors.white : textColor.withOpacity(0.6),
          ),
        ),
      ),
    );
  }

  Widget _buildTotalConsumptionCard(EnergyProvider energyProvider) {
    final totalEnergy =
        energyProvider.getEnergyForPeriod(_durationForPeriod(_selectedPeriod));
    final trend = energyProvider.usageTrend;
    final trendPositive = trend >= 0;

    return FadeInUp(
      delay: const Duration(milliseconds: 100),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          gradient: AppTheme.primaryGradient,
          borderRadius: AppTheme.largeRadius,
          boxShadow: [
            BoxShadow(
              color: AppTheme.primaryColor.withOpacity(0.3),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: AppTheme.smallRadius,
                  ),
                  child: const Icon(
                    Iconsax.flash_1,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                const Text(
                  'Total Consumption',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.white,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  totalEnergy.toStringAsFixed(3),
                  style: TextStyle(
                    fontSize: 48,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: 8),
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(
                    'kWh',
                    style: TextStyle(
                      fontSize: 20,
                      color: Colors.white.withOpacity(0.8),
                    ),
                  ),
                ),
                const Spacer(),
                if (trend.abs() > 0.1)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: trendPositive
                          ? Colors.red.withOpacity(0.8)
                          : AppTheme.successColor,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          trendPositive ? Iconsax.arrow_up : Iconsax.arrow_down,
                          size: 14,
                          color: Colors.white,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${trend.abs().toStringAsFixed(0)}%',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              energyProvider.isConnected
                  ? 'Live accumulated ${_selectedPeriodLabel()}'
                  : 'Connect energy meters to see data',
              style: TextStyle(
                fontSize: 14,
                color: Colors.white.withOpacity(0.7),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildConsumptionChart(EnergyProvider energyProvider) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final textColor = theme.colorScheme.onBackground;
    final periodDuration = _durationForPeriod(_selectedPeriod);
    final readings = energyProvider.getReadingsForPeriod(periodDuration);

    return FadeInUp(
      delay: const Duration(milliseconds: 200),
      child: Container(
        height: 200,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: isDark
              ? AppTheme.cardGradient
              : LinearGradient(
                  colors: [
                    AppTheme.lightSurface,
                    AppTheme.lightSurface.withOpacity(0.8),
                  ],
                ),
          borderRadius: AppTheme.largeRadius,
          border: Border.all(
            color: AppTheme.primaryColor.withOpacity(0.3),
            width: 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Live Consumption Chart',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: textColor,
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: readings.length < 2
                  ? Center(
                      child: Text(
                        'Waiting for more live samples...',
                        style: TextStyle(
                          fontSize: 14,
                          color: textColor.withOpacity(0.5),
                        ),
                      ),
                    )
                  : CustomPaint(
                      painter: _EnergyLineChartPainter(
                        readings: readings,
                        lineColor: AppTheme.primaryColor,
                        gridColor: textColor.withOpacity(0.1),
                      ),
                      child: const SizedBox.expand(),
                    ),
            ),
            if (readings.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(
                  'Samples: ${readings.length} | Last: ${_formatTime(readings.last.timestamp)}',
                  style: TextStyle(
                    fontSize: 12,
                    color: textColor.withOpacity(0.6),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildHistoryCard(EnergyProvider energyProvider) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final textColor = theme.colorScheme.onBackground;
    final readings = energyProvider
        .getReadingsForPeriod(_durationForPeriod(_selectedPeriod))
        .reversed
        .take(8)
        .toList();

    return FadeInUp(
      delay: const Duration(milliseconds: 260),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: isDark
              ? AppTheme.cardGradient
              : LinearGradient(
                  colors: [
                    AppTheme.lightSurface,
                    AppTheme.lightSurface.withOpacity(0.8),
                  ],
                ),
          borderRadius: AppTheme.largeRadius,
          border: Border.all(
            color: AppTheme.primaryColor.withOpacity(0.2),
            width: 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Recent History',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: textColor,
              ),
            ),
            const SizedBox(height: 12),
            if (readings.isEmpty)
              Text(
                'No stored samples yet.',
                style: TextStyle(
                  fontSize: 13,
                  color: textColor.withOpacity(0.5),
                ),
              )
            else
              ...readings.map(
                (reading) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          _formatTime(reading.timestamp),
                          style: TextStyle(
                            fontSize: 13,
                            color: textColor.withOpacity(0.7),
                          ),
                        ),
                      ),
                      Text(
                        '${reading.power.toStringAsFixed(0)} W',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: textColor,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        '${reading.energy.toStringAsFixed(3)} kWh',
                        style: TextStyle(
                          fontSize: 12,
                          color: textColor.withOpacity(0.7),
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

  Widget _buildSectionTitle(String title) {
    final theme = Theme.of(context);
    final textColor = theme.colorScheme.onBackground;

    return Text(
      title,
      style: TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.bold,
        color: textColor,
      ),
    );
  }

  Widget _buildDeviceBreakdownList(EnergyProvider energyProvider) {
    final breakdown = energyProvider.deviceBreakdown;

    // If we have real data, use it
    if (breakdown.isNotEmpty) {
      final total = breakdown.values.fold(0.0, (a, b) => a + b);
      final entries = breakdown.entries.toList();

      return Column(
        children: entries.asMap().entries.map((entry) {
          final index = entry.key;
          final device = entry.value;
          final percentage =
              total > 0 ? (device.value / total * 100).round() : 0;

          return FadeInUp(
            delay: Duration(milliseconds: 300 + (index * 50)),
            child: _buildDeviceConsumptionCard(
              device.key,
              percentage,
              _getDeviceIcon(device.key),
            ),
          );
        }).toList(),
      );
    }

    // Fallback: show placeholder when no real data
    if (!energyProvider.isConnected) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Theme.of(context).cardTheme.color,
          borderRadius: AppTheme.mediumRadius,
          border: Border.all(color: Colors.grey.withOpacity(0.2)),
        ),
        child: Column(
          children: [
            Icon(Iconsax.chart_21, size: 48, color: Colors.grey),
            const SizedBox(height: 12),
            Text(
              'Connect energy meters to see device breakdown',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      );
    }

    // Show sample data for demo purposes when connected but no device-level data
    final devices = [
      {'name': 'Living Room Lights', 'percentage': 21, 'icon': Iconsax.lamp},
      {'name': 'Air Conditioner', 'percentage': 52, 'icon': Iconsax.wind},
      {'name': 'Refrigerator', 'percentage': 17, 'icon': Iconsax.box},
      {'name': 'TV', 'percentage': 10, 'icon': Iconsax.monitor},
    ];

    return Column(
      children: devices.asMap().entries.map((entry) {
        final index = entry.key;
        final device = entry.value;
        return FadeInUp(
          delay: Duration(milliseconds: 300 + (index * 50)),
          child: _buildDeviceConsumptionCard(
            device['name'] as String,
            device['percentage'] as int,
            device['icon'] as IconData,
          ),
        );
      }).toList(),
    );
  }

  IconData _getDeviceIcon(String deviceName) {
    final name = deviceName.toLowerCase();
    if (name.contains('light') || name.contains('lamp')) return Iconsax.lamp;
    if (name.contains('ac') || name.contains('air') || name.contains('hvac'))
      return Iconsax.wind;
    if (name.contains('fridge') || name.contains('refrigerator'))
      return Iconsax.box;
    if (name.contains('tv') ||
        name.contains('monitor') ||
        name.contains('display')) return Iconsax.monitor;
    if (name.contains('heater') || name.contains('heat')) return Iconsax.sun_1;
    if (name.contains('washer') || name.contains('dryer'))
      return Iconsax.cloud_drizzle;
    return Iconsax.electricity;
  }

  Widget _buildDeviceConsumptionCard(
    String name,
    int percentage,
    IconData icon,
  ) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final textColor = theme.colorScheme.onBackground;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: isDark ? AppTheme.cardGradient : null,
        color: isDark ? null : theme.cardTheme.color,
        borderRadius: AppTheme.largeRadius,
        border: Border.all(
          color: textColor.withOpacity(0.1),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              gradient: AppTheme.primaryGradient.scale(0.3),
              borderRadius: AppTheme.smallRadius,
            ),
            child: Icon(
              icon,
              size: 24,
              color: AppTheme.primaryColor,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: textColor,
                  ),
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: LinearProgressIndicator(
                    value: percentage / 100,
                    backgroundColor:
                        isDark ? AppTheme.darkCard : AppTheme.lightCard,
                    valueColor: const AlwaysStoppedAnimation<Color>(
                        AppTheme.primaryColor),
                    minHeight: 6,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Duration _durationForPeriod(String period) {
    switch (period) {
      case 'week':
        return const Duration(days: 7);
      case 'month':
        return const Duration(days: 30);
      case 'year':
        return const Duration(days: 365);
      case 'today':
      default:
        return const Duration(days: 1);
    }
  }

  String _selectedPeriodLabel() {
    switch (_selectedPeriod) {
      case 'week':
        return 'this week';
      case 'month':
        return 'this month';
      case 'year':
        return 'this year';
      case 'today':
      default:
        return 'today';
    }
  }

  String _formatTime(DateTime timestamp) {
    final hour = timestamp.hour.toString().padLeft(2, '0');
    final minute = timestamp.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  Widget _buildCostEstimateCard(EnergyProvider energyProvider) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final textColor = theme.colorScheme.onBackground;

    // Get estimated cost from provider (using Egyptian electricity rate ~1.45 EGP per kWh)
    final estimatedCost = energyProvider.getEstimatedCost(ratePerKwh: 1.45);

    return FadeInUp(
      delay: const Duration(milliseconds: 500),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              AppTheme.successColor.withOpacity(0.2),
              isDark ? AppTheme.darkCard : AppTheme.lightSurface,
            ],
          ),
          borderRadius: AppTheme.largeRadius,
          border: Border.all(
            color: AppTheme.successColor.withOpacity(0.3),
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.successColor.withOpacity(0.3),
                borderRadius: AppTheme.smallRadius,
              ),
              child: const Icon(
                Iconsax.money,
                size: 28,
                color: AppTheme.successColor,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Estimated Cost Today',
                    style: TextStyle(
                      fontSize: 14,
                      color: textColor.withOpacity(0.7),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    estimatedCost > 0
                        ? '${estimatedCost.toStringAsFixed(2)} EGP'
                        : '--',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: textColor,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Iconsax.arrow_right_3,
              color: textColor.withOpacity(0.4),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEnergyTips() {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final textColor = theme.colorScheme.onBackground;

    final tips = [
      {
        'title': 'Peak Hours',
        'description': 'Reduce usage between 6 PM - 10 PM to save costs',
        'icon': Iconsax.clock,
      },
      {
        'title': 'Standby Power',
        'description': 'Turn off devices when not in use',
        'icon': Iconsax.electricity,
      },
      {
        'title': 'Smart Scheduling',
        'description': 'Use automations to optimize energy usage',
        'icon': Iconsax.timer,
      },
    ];

    return Column(
      children: tips.asMap().entries.map((entry) {
        final index = entry.key;
        final tip = entry.value;
        return FadeInUp(
          delay: Duration(milliseconds: 600 + (index * 50)),
          child: Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: isDark
                  ? AppTheme.cardGradient
                  : LinearGradient(
                      colors: [
                        AppTheme.lightSurface,
                        AppTheme.lightSurface.withOpacity(0.8),
                      ],
                    ),
              borderRadius: AppTheme.largeRadius,
              border: Border.all(
                color: textColor.withOpacity(0.1),
                width: 1,
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppTheme.warningColor.withOpacity(0.2),
                    borderRadius: AppTheme.smallRadius,
                  ),
                  child: Icon(
                    tip['icon'] as IconData,
                    size: 20,
                    color: AppTheme.warningColor,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        tip['title'] as String,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: textColor,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        tip['description'] as String,
                        style: TextStyle(
                          fontSize: 13,
                          color: textColor.withOpacity(0.6),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _EnergyLineChartPainter extends CustomPainter {
  final List<EnergyReading> readings;
  final Color lineColor;
  final Color gridColor;

  _EnergyLineChartPainter({
    required this.readings,
    required this.lineColor,
    required this.gridColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (readings.length < 2) return;

    final gridPaint = Paint()
      ..color = gridColor
      ..strokeWidth = 1;

    const horizontalLines = 4;
    for (var i = 0; i <= horizontalLines; i++) {
      final y = (size.height / horizontalLines) * i;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    final powers = readings.map((r) => r.power).toList();
    final minPower = powers.reduce(min);
    final maxPower = powers.reduce(max);
    final range = max(1.0, maxPower - minPower);

    final path = Path();
    for (var i = 0; i < readings.length; i++) {
      final x = (i / (readings.length - 1)) * size.width;
      final normalized = (readings[i].power - minPower) / range;
      final y = size.height - (normalized * size.height);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }

    final linePaint = Paint()
      ..color = lineColor
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(path, linePaint);

    final fillPath = Path.from(path)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();

    final fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          lineColor.withOpacity(0.25),
          lineColor.withOpacity(0.02),
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    canvas.drawPath(fillPath, fillPaint);
  }

  @override
  bool shouldRepaint(covariant _EnergyLineChartPainter oldDelegate) {
    return oldDelegate.readings != readings ||
        oldDelegate.lineColor != lineColor ||
        oldDelegate.gridColor != gridColor;
  }
}
