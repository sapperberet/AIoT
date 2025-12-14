import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../models/automation_model.dart';
import '../models/sensor_data_model.dart';
import '../models/device_model.dart';
import 'automation_service.dart';
import 'sensor_service.dart';
import 'mqtt_service.dart';
import 'notification_service.dart';
import 'event_log_service.dart';

/// Engine that monitors sensors and executes automations
class AutomationEngine {
  final AutomationService _automationService;
  final SensorService _sensorService;
  final MqttService _mqttService;
  final NotificationService? _notificationService;
  final EventLogService? _eventLogService;

  // Track last sensor values to detect changes
  final Map<String, double> _lastSensorValues = {};

  // Stream subscriptions
  final List<StreamSubscription> _subscriptions = [];

  // Timer for time-based triggers
  Timer? _timeCheckTimer;

  bool _isRunning = false;
  bool get isRunning => _isRunning;

  AutomationEngine({
    required AutomationService automationService,
    required SensorService sensorService,
    required MqttService mqttService,
    NotificationService? notificationService,
    EventLogService? eventLogService,
  })  : _automationService = automationService,
        _sensorService = sensorService,
        _mqttService = mqttService,
        _notificationService = notificationService,
        _eventLogService = eventLogService;

  /// Start the automation engine
  Future<void> start() async {
    if (_isRunning) return;

    debugPrint('🤖 Starting AutomationEngine...');

    // Start monitoring all sensor types
    for (var sensorType in SensorType.values) {
      _subscriptions.add(
        _sensorService.getSensorStream(sensorType).listen(
              (sensorData) => _handleSensorData(sensorData),
            ),
      );
    }

    // Start time-based trigger checking (every minute)
    _timeCheckTimer = Timer.periodic(
      const Duration(minutes: 1),
      (_) => _checkTimeBasedTriggers(),
    );

    _isRunning = true;
    debugPrint('✅ AutomationEngine started successfully');
  }

  /// Stop the automation engine
  void stop() {
    if (!_isRunning) return;

    debugPrint('🛑 Stopping AutomationEngine...');

    for (var subscription in _subscriptions) {
      subscription.cancel();
    }
    _subscriptions.clear();

    _timeCheckTimer?.cancel();
    _timeCheckTimer = null;

    _isRunning = false;
    debugPrint('✅ AutomationEngine stopped');
  }

  /// Handle incoming sensor data
  Future<void> _handleSensorData(SensorData data) async {
    final automations = _automationService.getEnabledAutomations();

    for (final automation in automations) {
      for (final trigger in automation.triggers) {
        bool shouldTrigger = false;

        switch (trigger.type) {
          case TriggerType.sensorValue:
            shouldTrigger = _checkSensorValueTrigger(trigger, data);
            break;

          case TriggerType.sensorChange:
            shouldTrigger = _checkSensorChangeTrigger(trigger, data);
            break;

          case TriggerType.temperature:
            if (data.type == SensorType.temperature) {
              shouldTrigger = _checkThresholdTrigger(trigger, data.value);
            }
            break;

          case TriggerType.humidity:
            if (data.type == SensorType.humidity) {
              shouldTrigger = _checkThresholdTrigger(trigger, data.value);
            }
            break;

          case TriggerType.energy:
            if (data.type == SensorType.energy) {
              shouldTrigger = _checkThresholdTrigger(trigger, data.value);
            }
            break;

          case TriggerType.motion:
            if (data.type == SensorType.motion) {
              shouldTrigger = data.value > 0;
            }
            break;

          default:
            break;
        }

        if (shouldTrigger) {
          await _executeAutomation(automation, {
            'trigger': trigger.type.name,
            'sensorData': {
              'type': data.type.name,
              'value': data.value,
              'unit': data.unit,
              'timestamp': data.timestamp.toIso8601String(),
            },
          });
        }
      }
    }

    // Update last sensor value for change detection
    _lastSensorValues[data.sensorId] = data.value;
  }

  /// Check sensor value trigger
  bool _checkSensorValueTrigger(AutomationTrigger trigger, SensorData data) {
    final sensorType = trigger.parameters['sensorType'] as String?;
    if (sensorType != null && sensorType != data.type.name) {
      return false;
    }

    return _checkThresholdTrigger(trigger, data.value);
  }

  /// Check sensor change trigger
  bool _checkSensorChangeTrigger(AutomationTrigger trigger, SensorData data) {
    final lastValue = _lastSensorValues[data.sensorId];
    if (lastValue == null) return false;

    final minChange = trigger.parameters['minChange'] as double? ?? 1.0;
    return (data.value - lastValue).abs() >= minChange;
  }

  /// Check threshold-based trigger
  bool _checkThresholdTrigger(AutomationTrigger trigger, double value) {
    final threshold = trigger.parameters['threshold'] as double?;
    final operator = trigger.parameters['operator'] as String? ?? 'greater';

    if (threshold == null) return false;

    switch (operator) {
      case 'greater':
        return value > threshold;
      case 'less':
        return value < threshold;
      case 'equals':
        return value == threshold;
      case 'greater_equals':
        return value >= threshold;
      case 'less_equals':
        return value <= threshold;
      default:
        return false;
    }
  }

  /// Check time-based triggers
  Future<void> _checkTimeBasedTriggers() async {
    final now = DateTime.now();
    final automations = _automationService.getEnabledAutomations();

    for (final automation in automations) {
      for (final trigger in automation.triggers) {
        bool shouldTrigger = false;

        switch (trigger.type) {
          case TriggerType.time:
            shouldTrigger = _checkTimeTrigger(trigger, now);
            break;

          case TriggerType.schedule:
            shouldTrigger = _checkScheduleTrigger(trigger, now);
            break;

          case TriggerType.sunrise:
          case TriggerType.sunset:
            shouldTrigger = _checkSunTrigger(trigger, now);
            break;

          default:
            break;
        }

        if (shouldTrigger) {
          await _executeAutomation(automation, {
            'trigger': trigger.type.name,
            'time': now.toIso8601String(),
          });
        }
      }
    }
  }

  /// Check specific time trigger
  bool _checkTimeTrigger(AutomationTrigger trigger, DateTime now) {
    final hour = trigger.parameters['hour'] as int?;
    final minute = trigger.parameters['minute'] as int?;

    if (hour == null || minute == null) return false;

    return now.hour == hour && now.minute == minute;
  }

  /// Check schedule trigger (daily, weekly, etc.)
  bool _checkScheduleTrigger(AutomationTrigger trigger, DateTime now) {
    final hour = trigger.parameters['hour'] as int?;
    final minute = trigger.parameters['minute'] as int?;
    final daysOfWeek = trigger.parameters['daysOfWeek'] as List<dynamic>?;

    if (hour == null || minute == null) return false;
    if (now.hour != hour || now.minute != minute) return false;

    if (daysOfWeek != null && daysOfWeek.isNotEmpty) {
      return daysOfWeek.contains(now.weekday);
    }

    return true;
  }

  /// Check sunrise/sunset trigger
  bool _checkSunTrigger(AutomationTrigger trigger, DateTime now) {
    // Simplified - in production, use actual sunrise/sunset calculation
    final offset = trigger.parameters['offset'] as int? ?? 0;

    if (trigger.type == TriggerType.sunrise) {
      // Approximate sunrise at 6:00 AM + offset
      return now.hour == 6 && now.minute == offset;
    } else {
      // Approximate sunset at 6:00 PM + offset
      return now.hour == 18 && now.minute == offset;
    }
  }

  /// Execute automation
  Future<void> _executeAutomation(
    Automation automation,
    Map<String, dynamic> triggerData,
  ) async {
    debugPrint('🤖 Executing automation: ${automation.name}');

    // Check conditions
    if (!await _checkConditions(automation.conditions)) {
      debugPrint('⚠️ Conditions not met for: ${automation.name}');
      return;
    }

    final actionsExecuted = <String>[];
    bool success = true;
    String? errorMessage;

    try {
      // Execute all actions
      for (final action in automation.actions) {
        final actionSuccess = await _executeAction(action);
        if (actionSuccess) {
          actionsExecuted.add(action.type.name);
        } else {
          success = false;
          errorMessage = 'Failed to execute action: ${action.type.name}';
          break;
        }
      }

      debugPrint('✅ Automation executed: ${automation.name}');
    } catch (e) {
      success = false;
      errorMessage = e.toString();
      debugPrint('❌ Automation execution failed: $e');
    }

    // Log execution
    final log = AutomationExecutionLog(
      id: '${automation.id}_${DateTime.now().millisecondsSinceEpoch}',
      automationId: automation.id,
      automationName: automation.name,
      executedAt: DateTime.now(),
      success: success,
      errorMessage: errorMessage,
      triggerData: triggerData,
      actionsExecuted: actionsExecuted,
    );

    await _automationService.logExecution(log);

    // Log to event log
    _eventLogService?.logEvent(
      'Automation',
      success
          ? 'Automation executed: ${automation.name}'
          : 'Automation failed: ${automation.name}',
      metadata: {
        'automationId': automation.id,
        'success': success,
        'error': errorMessage,
      },
    );
  }

  /// Check all conditions
  Future<bool> _checkConditions(List<AutomationCondition> conditions) async {
    if (conditions.isEmpty) return true;

    for (final condition in conditions) {
      if (!await _checkCondition(condition)) {
        return false;
      }
    }

    return true;
  }

  /// Check individual condition
  Future<bool> _checkCondition(AutomationCondition condition) async {
    switch (condition.type) {
      case ConditionType.time:
        return _checkTimeCondition(condition);

      case ConditionType.dayOfWeek:
        return _checkDayOfWeekCondition(condition);

      case ConditionType.sensorValue:
        return _checkSensorValueCondition(condition);

      case ConditionType.temperature:
        return _checkTemperatureCondition(condition);

      case ConditionType.humidity:
        return _checkHumidityCondition(condition);

      case ConditionType.energy:
        return _checkEnergyCondition(condition);

      default:
        return true;
    }
  }

  bool _checkTimeCondition(AutomationCondition condition) {
    final now = DateTime.now();
    final startHour = condition.parameters['startHour'] as int?;
    final endHour = condition.parameters['endHour'] as int?;

    if (startHour == null || endHour == null) return true;

    final currentMinutes = now.hour * 60 + now.minute;
    final startMinutes = startHour * 60;
    final endMinutes = endHour * 60;

    if (startMinutes <= endMinutes) {
      return currentMinutes >= startMinutes && currentMinutes <= endMinutes;
    } else {
      // Crosses midnight
      return currentMinutes >= startMinutes || currentMinutes <= endMinutes;
    }
  }

  bool _checkDayOfWeekCondition(AutomationCondition condition) {
    final now = DateTime.now();
    final allowedDays = condition.parameters['days'] as List<dynamic>?;

    if (allowedDays == null || allowedDays.isEmpty) return true;

    return allowedDays.contains(now.weekday);
  }

  bool _checkSensorValueCondition(AutomationCondition condition) {
    final sensorType = condition.parameters['sensorType'] as String?;
    if (sensorType == null) return true;

    final sensorData = _sensorService.getLatestReadingByType(
      SensorTypeExtension.fromString(sensorType),
    );

    if (sensorData == null || sensorData.id.isEmpty) return false;

    final threshold = condition.parameters['threshold'] as double?;
    final operator = condition.parameters['operator'] as String? ?? 'greater';

    if (threshold == null) return true;

    switch (operator) {
      case 'greater':
        return sensorData.value > threshold;
      case 'less':
        return sensorData.value < threshold;
      case 'equals':
        return sensorData.value == threshold;
      default:
        return false;
    }
  }

  bool _checkTemperatureCondition(AutomationCondition condition) {
    return _checkSensorValueCondition(
      AutomationCondition(
        type: ConditionType.sensorValue,
        parameters: {
          ...condition.parameters,
          'sensorType': 'temperature',
        },
      ),
    );
  }

  bool _checkHumidityCondition(AutomationCondition condition) {
    return _checkSensorValueCondition(
      AutomationCondition(
        type: ConditionType.sensorValue,
        parameters: {
          ...condition.parameters,
          'sensorType': 'humidity',
        },
      ),
    );
  }

  bool _checkEnergyCondition(AutomationCondition condition) {
    return _checkSensorValueCondition(
      AutomationCondition(
        type: ConditionType.sensorValue,
        parameters: {
          ...condition.parameters,
          'sensorType': 'energy',
        },
      ),
    );
  }

  /// Execute individual action
  Future<bool> _executeAction(AutomationAction action) async {
    try {
      debugPrint('🤖 Executing action: ${action.type.name}');

      switch (action.type) {
        case ActionType.deviceControl:
        case ActionType.turnOn:
        case ActionType.turnOff:
        case ActionType.toggle:
        case ActionType.openClose:
          return await _executeDeviceControl(action);

        case ActionType.setBrightness:
          return await _executeSetBrightness(action);

        case ActionType.setTemperature:
          return await _executeSetTemperature(action);

        case ActionType.sendNotification:
          return await _executeSendNotification(action);

        case ActionType.sendMqttMessage:
          return await _executeSendMqttMessage(action);

        case ActionType.triggerAlarm:
          return await _executeTriggerAlarm(action);

        case ActionType.playSound:
          return await _executePlaySound(action);

        case ActionType.logEvent:
          return await _executeLogEvent(action);

        default:
          debugPrint('⚠️ Unknown action type: ${action.type}');
          return false;
      }
    } catch (e) {
      debugPrint('❌ Action execution failed: $e');
      return false;
    }
  }

  /// Execute device control action
  Future<bool> _executeDeviceControl(AutomationAction action) async {
    if (action.deviceId == null) return false;

    String? state;
    switch (action.type) {
      case ActionType.turnOn:
        state = 'on';
        break;
      case ActionType.turnOff:
        state = 'off';
        break;
      case ActionType.toggle:
        state = 'toggle';
        break;
      case ActionType.openClose:
        state = action.parameters['state'] as String? ?? 'toggle';
        break;
      default:
        state = action.parameters['state'] as String?;
    }

    if (state == null) return false;

    // Create simple JSON message for MQTT
    final message = {
      'action': state == 'toggle' ? 'toggle' : 'set',
      'state': state,
      'deviceId': action.deviceId,
      'timestamp': DateTime.now().toIso8601String(),
      'source': 'automation',
    };

    final topic = 'home/${action.deviceId}/command';
    _mqttService.publish(topic, jsonEncode(message));

    debugPrint('📤 Sent device control: $topic -> $message');
    return true;
  }

  /// Execute set brightness action
  Future<bool> _executeSetBrightness(AutomationAction action) async {
    if (action.deviceId == null) return false;

    final brightness = action.parameters['brightness'] as int? ?? 100;

    final message = {
      'action': 'set_brightness',
      'brightness': brightness,
      'deviceId': action.deviceId,
      'timestamp': DateTime.now().toIso8601String(),
      'source': 'automation',
    };

    final topic = 'home/${action.deviceId}/command';
    _mqttService.publish(topic, jsonEncode(message));

    return true;
  }

  /// Execute set temperature action
  Future<bool> _executeSetTemperature(AutomationAction action) async {
    if (action.deviceId == null) return false;

    final temperature = action.parameters['temperature'] as double? ?? 22.0;

    final message = {
      'action': 'set_temperature',
      'temperature': temperature,
      'deviceId': action.deviceId,
      'timestamp': DateTime.now().toIso8601String(),
      'source': 'automation',
    };

    final topic = 'home/${action.deviceId}/command';
    _mqttService.publish(topic, jsonEncode(message));

    return true;
  }

  /// Execute send notification action
  Future<bool> _executeSendNotification(AutomationAction action) async {
    final title = action.parameters['title'] as String? ?? 'Automation';
    final message = action.parameters['message'] as String? ?? '';

    _notificationService?.showNotification(title, message);

    return true;
  }

  /// Execute send MQTT message action
  Future<bool> _executeSendMqttMessage(AutomationAction action) async {
    final topic = action.parameters['topic'] as String?;
    final payload = action.parameters['payload'] as Map<String, dynamic>?;

    if (topic == null || payload == null) return false;

    // Add automation metadata
    final message = {
      ...payload,
      'timestamp': DateTime.now().toIso8601String(),
      'source': 'automation',
    };

    _mqttService.publish(topic, jsonEncode(message));
    debugPrint('📤 Sent custom MQTT: $topic -> $message');

    return true;
  }

  /// Execute trigger alarm action
  Future<bool> _executeTriggerAlarm(AutomationAction action) async {
    final alarmType = action.parameters['alarmType'] as String? ?? 'general';

    final message = {
      'action': 'trigger_alarm',
      'alarmType': alarmType,
      'timestamp': DateTime.now().toIso8601String(),
      'source': 'automation',
    };

    _mqttService.publish('home/alarm/command', jsonEncode(message));

    return true;
  }

  /// Execute play sound action
  Future<bool> _executePlaySound(AutomationAction action) async {
    final duration = action.parameters['duration'] as int? ?? 1000;
    final pattern = action.parameters['pattern'] as String? ?? 'single';

    final message = {
      'action': 'play_sound',
      'duration': duration,
      'pattern': pattern,
      'timestamp': DateTime.now().toIso8601String(),
      'source': 'automation',
    };

    _mqttService.publish('home/buzzer/command', jsonEncode(message));

    return true;
  }

  /// Execute log event action
  Future<bool> _executeLogEvent(AutomationAction action) async {
    final eventType = action.parameters['eventType'] as String? ?? 'Automation';
    final message = action.parameters['message'] as String? ?? '';

    _eventLogService?.logEvent(eventType, message);

    return true;
  }

  /// Manually trigger an automation
  Future<void> triggerManually(String automationId) async {
    final automation = _automationService.getAutomation(automationId);
    if (automation == null) {
      debugPrint('⚠️ Automation not found: $automationId');
      return;
    }

    if (!automation.isEnabled) {
      debugPrint('⚠️ Automation is disabled: ${automation.name}');
      return;
    }

    await _executeAutomation(automation, {
      'trigger': 'manual',
      'time': DateTime.now().toIso8601String(),
    });
  }

  void dispose() {
    stop();
  }
}
