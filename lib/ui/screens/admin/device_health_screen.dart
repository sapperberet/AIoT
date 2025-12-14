import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:animate_do/animate_do.dart';
import 'package:iconsax/iconsax.dart';
import 'dart:async';

import '../../../core/services/mqtt_service.dart';
import '../../../core/config/mqtt_config.dart';
import '../../../core/localization/app_localizations.dart';

/// Device health status
enum DeviceHealthStatus {
  online,
  offline,
  checking,
  warning,
}

/// Device health info model
class DeviceHealthInfo {
  final String id;
  final String name;
  final String type;
  final String topic;
  final DeviceHealthStatus status;
  final DateTime? lastSeen;
  final String? errorMessage;
  final Map<String, dynamic>? lastData;

  DeviceHealthInfo({
    required this.id,
    required this.name,
    required this.type,
    required this.topic,
    this.status = DeviceHealthStatus.checking,
    this.lastSeen,
    this.errorMessage,
    this.lastData,
  });

  DeviceHealthInfo copyWith({
    DeviceHealthStatus? status,
    DateTime? lastSeen,
    String? errorMessage,
    Map<String, dynamic>? lastData,
  }) {
    return DeviceHealthInfo(
      id: id,
      name: name,
      type: type,
      topic: topic,
      status: status ?? this.status,
      lastSeen: lastSeen ?? this.lastSeen,
      errorMessage: errorMessage ?? this.errorMessage,
      lastData: lastData ?? this.lastData,
    );
  }
}

/// Screen to check device health and MQTT broker connection status
class DeviceHealthScreen extends StatefulWidget {
  const DeviceHealthScreen({super.key});

  @override
  State<DeviceHealthScreen> createState() => _DeviceHealthScreenState();
}

class _DeviceHealthScreenState extends State<DeviceHealthScreen> {
  final List<DeviceHealthInfo> _devices = [];
  bool _isCheckingBroker = false;
  ConnectionStatus _brokerStatus = ConnectionStatus.disconnected;
  String? _brokerError;
  StreamSubscription<ConnectionStatus>? _statusSubscription;
  StreamSubscription<MqttMessage>? _messageSubscription;
  Timer? _checkTimer;

  // Define device types to check
  final List<Map<String, String>> _deviceDefinitions = [
    {
      'id': 'temp_sensor',
      'name': 'Temperature Sensor',
      'type': 'sensor',
      'topic': 'home/sensors/temperature'
    },
    {
      'id': 'humidity_sensor',
      'name': 'Humidity Sensor',
      'type': 'sensor',
      'topic': 'home/sensors/humidity'
    },
    {
      'id': 'motion_sensor',
      'name': 'Motion Sensor',
      'type': 'sensor',
      'topic': 'home/sensors/motion'
    },
    {
      'id': 'light_sensor',
      'name': 'Light Sensor',
      'type': 'sensor',
      'topic': 'home/sensors/light'
    },
    {
      'id': 'door_sensor',
      'name': 'Door Sensor',
      'type': 'sensor',
      'topic': 'home/sensors/door'
    },
    {
      'id': 'voltmeter',
      'name': 'Voltmeter',
      'type': 'meter',
      'topic': 'home/energy/voltage'
    },
    {
      'id': 'ammeter',
      'name': 'Current Meter',
      'type': 'meter',
      'topic': 'home/energy/current'
    },
    {
      'id': 'power_meter',
      'name': 'Power Meter',
      'type': 'meter',
      'topic': 'home/energy/power'
    },
    {
      'id': 'esp32_main',
      'name': 'ESP32 Main Controller',
      'type': 'controller',
      'topic': 'home/esp32/status'
    },
    {
      'id': 'heat_sensor',
      'name': 'Heat Sensor',
      'type': 'sensor',
      'topic': 'home/sensors/heat'
    },
    {
      'id': 'smoke_detector',
      'name': 'Smoke Detector',
      'type': 'safety',
      'topic': 'home/safety/smoke'
    },
    {
      'id': 'gas_detector',
      'name': 'Gas Detector',
      'type': 'safety',
      'topic': 'home/safety/gas'
    },
  ];

  @override
  void initState() {
    super.initState();
    _initializeDevices();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkBrokerConnection();
    });
  }

  @override
  void dispose() {
    _statusSubscription?.cancel();
    _messageSubscription?.cancel();
    _checkTimer?.cancel();
    super.dispose();
  }

  void _initializeDevices() {
    _devices.clear();
    for (final def in _deviceDefinitions) {
      _devices.add(DeviceHealthInfo(
        id: def['id']!,
        name: def['name']!,
        type: def['type']!,
        topic: def['topic']!,
      ));
    }
  }

  Future<void> _checkBrokerConnection() async {
    setState(() {
      _isCheckingBroker = true;
      _brokerError = null;
    });

    try {
      final mqttService = context.read<MqttService>();

      // Listen for status changes
      _statusSubscription?.cancel();
      _statusSubscription = mqttService.statusStream.listen((status) {
        if (mounted) {
          setState(() {
            _brokerStatus = status;
            if (status == ConnectionStatus.connected) {
              _isCheckingBroker = false;
              _subscribeToDeviceTopics(mqttService);
            } else if (status == ConnectionStatus.error) {
              _isCheckingBroker = false;
              _brokerError = 'Failed to connect to broker';
            }
          });
        }
      });

      // Check current status
      _brokerStatus = mqttService.currentStatus;

      if (_brokerStatus == ConnectionStatus.connected) {
        _isCheckingBroker = false;
        _subscribeToDeviceTopics(mqttService);
      } else if (_brokerStatus == ConnectionStatus.disconnected) {
        // Try to connect
        await mqttService.connect();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isCheckingBroker = false;
          _brokerStatus = ConnectionStatus.error;
          _brokerError = e.toString();
        });
      }
    }
  }

  void _subscribeToDeviceTopics(MqttService mqttService) {
    // Subscribe to all device topics
    for (final device in _devices) {
      mqttService.subscribe(device.topic);
    }

    // Listen for messages
    _messageSubscription?.cancel();
    _messageSubscription = mqttService.messageStream.listen((message) {
      _handleDeviceMessage(message);
    });

    // Set up a timer to mark devices as offline if no message received
    _checkTimer?.cancel();
    _checkTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      _checkDeviceTimeouts();
    });

    // After 5 seconds, mark devices that haven't responded as offline
    Future.delayed(const Duration(seconds: 5), () {
      if (mounted) {
        _checkDeviceTimeouts();
      }
    });
  }

  void _handleDeviceMessage(MqttMessage message) {
    final index = _devices.indexWhere((d) => d.topic == message.topic);
    if (index != -1 && mounted) {
      setState(() {
        _devices[index] = _devices[index].copyWith(
          status: DeviceHealthStatus.online,
          lastSeen: message.timestamp,
          lastData: {'payload': message.payload},
        );
      });
    }
  }

  void _checkDeviceTimeouts() {
    final now = DateTime.now();
    final timeout = const Duration(minutes: 2);

    if (mounted) {
      setState(() {
        for (int i = 0; i < _devices.length; i++) {
          final device = _devices[i];
          if (device.status == DeviceHealthStatus.checking) {
            // No response yet
            _devices[i] = device.copyWith(
              status: DeviceHealthStatus.offline,
              errorMessage: 'No response from device',
            );
          } else if (device.lastSeen != null &&
              now.difference(device.lastSeen!) > timeout) {
            // Timeout
            _devices[i] = device.copyWith(
              status: DeviceHealthStatus.warning,
              errorMessage: 'No recent data',
            );
          }
        }
      });
    }
  }

  Future<void> _refreshAll() async {
    _initializeDevices();
    await _checkBrokerConnection();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final loc = AppLocalizations.of(context);

    final onlineCount =
        _devices.where((d) => d.status == DeviceHealthStatus.online).length;
    final offlineCount =
        _devices.where((d) => d.status == DeviceHealthStatus.offline).length;
    final warningCount =
        _devices.where((d) => d.status == DeviceHealthStatus.warning).length;

    return Scaffold(
      appBar: AppBar(
        title: Text(loc.translate('device_health')),
        actions: [
          IconButton(
            icon: const Icon(Iconsax.refresh),
            onPressed: _refreshAll,
            tooltip: loc.translate('refresh'),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refreshAll,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Broker Status Card
            FadeInDown(
              child: _buildBrokerStatusCard(theme, loc),
            ),
            const SizedBox(height: 16),

            // Device Summary
            FadeInDown(
              delay: const Duration(milliseconds: 100),
              child: _buildSummaryRow(
                  theme, onlineCount, offlineCount, warningCount),
            ),
            const SizedBox(height: 16),

            // Section: Sensors
            _buildDeviceSection(
                theme, loc, 'Sensors', 'sensor', Iconsax.cpu_setting),

            // Section: Meters
            _buildDeviceSection(
                theme, loc, 'Energy Meters', 'meter', Iconsax.electricity),

            // Section: Controllers
            _buildDeviceSection(
                theme, loc, 'Controllers', 'controller', Iconsax.cpu),

            // Section: Safety
            _buildDeviceSection(
                theme, loc, 'Safety Devices', 'safety', Iconsax.shield_tick),
          ],
        ),
      ),
    );
  }

  Widget _buildBrokerStatusCard(ThemeData theme, AppLocalizations loc) {
    Color statusColor;
    IconData statusIcon;
    String statusText;

    switch (_brokerStatus) {
      case ConnectionStatus.connected:
        statusColor = Colors.green;
        statusIcon = Iconsax.tick_circle;
        statusText = 'Connected';
        break;
      case ConnectionStatus.connecting:
        statusColor = Colors.orange;
        statusIcon = Iconsax.refresh;
        statusText = 'Connecting...';
        break;
      case ConnectionStatus.error:
        statusColor = Colors.red;
        statusIcon = Iconsax.close_circle;
        statusText = 'Error';
        break;
      case ConnectionStatus.disconnected:
        statusColor = Colors.grey;
        statusIcon = Iconsax.minus_cirlce;
        statusText = 'Disconnected';
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Iconsax.global, color: theme.colorScheme.primary),
                const SizedBox(width: 12),
                Text(
                  'MQTT Broker',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                if (_isCheckingBroker)
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                else
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: statusColor),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(statusIcon, size: 16, color: statusColor),
                        const SizedBox(width: 6),
                        Text(
                          statusText,
                          style: TextStyle(
                            color: statusColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'Address: ${MqttConfig.localBrokerAddress}:${MqttConfig.localBrokerPort}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: Colors.grey[600],
              ),
            ),
            if (_brokerError != null) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Iconsax.warning_2, size: 16, color: Colors.red),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _brokerError!,
                        style: const TextStyle(color: Colors.red, fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryRow(
      ThemeData theme, int online, int offline, int warning) {
    return Row(
      children: [
        Expanded(
          child: _buildSummaryCard(
              theme, 'Online', online, Colors.green, Iconsax.tick_circle),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _buildSummaryCard(
              theme, 'Offline', offline, Colors.red, Iconsax.close_circle),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _buildSummaryCard(
              theme, 'Warning', warning, Colors.orange, Iconsax.warning_2),
        ),
      ],
    );
  }

  Widget _buildSummaryCard(
      ThemeData theme, String label, int count, Color color, IconData icon) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Icon(icon, color: color),
            const SizedBox(height: 4),
            Text(
              '$count',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDeviceSection(ThemeData theme, AppLocalizations loc,
      String title, String type, IconData icon) {
    final devices = _devices.where((d) => d.type == type).toList();
    if (devices.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Row(
            children: [
              Icon(icon, size: 20, color: theme.colorScheme.primary),
              const SizedBox(width: 8),
              Text(
                title,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
        ...devices.map((device) => _buildDeviceCard(theme, device)).toList(),
      ],
    );
  }

  Widget _buildDeviceCard(ThemeData theme, DeviceHealthInfo device) {
    Color statusColor;
    IconData statusIcon;

    switch (device.status) {
      case DeviceHealthStatus.online:
        statusColor = Colors.green;
        statusIcon = Iconsax.tick_circle;
        break;
      case DeviceHealthStatus.offline:
        statusColor = Colors.red;
        statusIcon = Iconsax.close_circle;
        break;
      case DeviceHealthStatus.warning:
        statusColor = Colors.orange;
        statusIcon = Iconsax.warning_2;
        break;
      case DeviceHealthStatus.checking:
        statusColor = Colors.grey;
        statusIcon = Iconsax.refresh;
    }

    return FadeInLeft(
      child: Card(
        margin: const EdgeInsets.only(bottom: 8),
        child: ListTile(
          leading: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(statusIcon, color: statusColor, size: 20),
          ),
          title: Text(device.name),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                device.topic,
                style: TextStyle(fontSize: 11, color: Colors.grey[500]),
              ),
              if (device.lastSeen != null)
                Text(
                  'Last seen: ${_formatTime(device.lastSeen!)}',
                  style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                ),
              if (device.errorMessage != null)
                Text(
                  device.errorMessage!,
                  style: TextStyle(fontSize: 11, color: statusColor),
                ),
            ],
          ),
          trailing: device.status == DeviceHealthStatus.checking
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : null,
        ),
      ),
    );
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final diff = now.difference(time);

    if (diff.inSeconds < 60) {
      return '${diff.inSeconds}s ago';
    } else if (diff.inMinutes < 60) {
      return '${diff.inMinutes}m ago';
    } else if (diff.inHours < 24) {
      return '${diff.inHours}h ago';
    } else {
      return '${diff.inDays}d ago';
    }
  }
}
