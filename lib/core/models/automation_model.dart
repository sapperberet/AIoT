import 'package:cloud_firestore/cloud_firestore.dart';

/// Comprehensive automation model
class Automation {
  final String id;
  final String name;
  final String description;
  final bool isEnabled;
  final List<AutomationTrigger> triggers;
  final List<AutomationCondition> conditions;
  final List<AutomationAction> actions;
  final DateTime createdAt;
  final DateTime? lastTriggered;
  final int executionCount;

  Automation({
    required this.id,
    required this.name,
    required this.description,
    this.isEnabled = true,
    required this.triggers,
    this.conditions = const [],
    required this.actions,
    DateTime? createdAt,
    this.lastTriggered,
    this.executionCount = 0,
  }) : createdAt = createdAt ?? DateTime.now();

  factory Automation.fromJson(Map<String, dynamic> json) {
    return Automation(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String,
      isEnabled: json['isEnabled'] as bool? ?? true,
      triggers: (json['triggers'] as List<dynamic>?)
              ?.map(
                  (t) => AutomationTrigger.fromJson(t as Map<String, dynamic>))
              .toList() ??
          [],
      conditions: (json['conditions'] as List<dynamic>?)
              ?.map((c) =>
                  AutomationCondition.fromJson(c as Map<String, dynamic>))
              .toList() ??
          [],
      actions: (json['actions'] as List<dynamic>?)
              ?.map((a) => AutomationAction.fromJson(a as Map<String, dynamic>))
              .toList() ??
          [],
      createdAt: (json['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      lastTriggered: (json['lastTriggered'] as Timestamp?)?.toDate(),
      executionCount: json['executionCount'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'isEnabled': isEnabled,
      'triggers': triggers.map((t) => t.toJson()).toList(),
      'conditions': conditions.map((c) => c.toJson()).toList(),
      'actions': actions.map((a) => a.toJson()).toList(),
      'createdAt': Timestamp.fromDate(createdAt),
      'lastTriggered':
          lastTriggered != null ? Timestamp.fromDate(lastTriggered!) : null,
      'executionCount': executionCount,
    };
  }

  Automation copyWith({
    String? id,
    String? name,
    String? description,
    bool? isEnabled,
    List<AutomationTrigger>? triggers,
    List<AutomationCondition>? conditions,
    List<AutomationAction>? actions,
    DateTime? createdAt,
    DateTime? lastTriggered,
    int? executionCount,
  }) {
    return Automation(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      isEnabled: isEnabled ?? this.isEnabled,
      triggers: triggers ?? this.triggers,
      conditions: conditions ?? this.conditions,
      actions: actions ?? this.actions,
      createdAt: createdAt ?? this.createdAt,
      lastTriggered: lastTriggered ?? this.lastTriggered,
      executionCount: executionCount ?? this.executionCount,
    );
  }
}

/// Trigger types that can initiate an automation
enum TriggerType {
  time, // Specific time of day
  schedule, // Recurring schedule (daily, weekly)
  sensorValue, // Sensor crosses threshold
  sensorChange, // Sensor value changes
  deviceState, // Device changes state
  energy, // Energy consumption threshold
  temperature, // Temperature threshold
  humidity, // Humidity threshold
  motion, // Motion detected
  sunrise, // Sunrise time
  sunset, // Sunset time
  manual, // Manual trigger via app
}

extension TriggerTypeExtension on TriggerType {
  String get name {
    switch (this) {
      case TriggerType.time:
        return 'time';
      case TriggerType.schedule:
        return 'schedule';
      case TriggerType.sensorValue:
        return 'sensor_value';
      case TriggerType.sensorChange:
        return 'sensor_change';
      case TriggerType.deviceState:
        return 'device_state';
      case TriggerType.energy:
        return 'energy';
      case TriggerType.temperature:
        return 'temperature';
      case TriggerType.humidity:
        return 'humidity';
      case TriggerType.motion:
        return 'motion';
      case TriggerType.sunrise:
        return 'sunrise';
      case TriggerType.sunset:
        return 'sunset';
      case TriggerType.manual:
        return 'manual';
    }
  }

  static TriggerType fromString(String value) {
    switch (value.toLowerCase()) {
      case 'time':
        return TriggerType.time;
      case 'schedule':
        return TriggerType.schedule;
      case 'sensor_value':
        return TriggerType.sensorValue;
      case 'sensor_change':
        return TriggerType.sensorChange;
      case 'device_state':
        return TriggerType.deviceState;
      case 'energy':
        return TriggerType.energy;
      case 'temperature':
        return TriggerType.temperature;
      case 'humidity':
        return TriggerType.humidity;
      case 'motion':
        return TriggerType.motion;
      case 'sunrise':
        return TriggerType.sunrise;
      case 'sunset':
        return TriggerType.sunset;
      case 'manual':
        return TriggerType.manual;
      default:
        return TriggerType.manual;
    }
  }
}

class AutomationTrigger {
  final TriggerType type;
  final Map<String, dynamic> parameters;

  AutomationTrigger({
    required this.type,
    required this.parameters,
  });

  factory AutomationTrigger.fromJson(Map<String, dynamic> json) {
    return AutomationTrigger(
      type: TriggerTypeExtension.fromString(json['type'] as String),
      parameters: json['parameters'] as Map<String, dynamic>? ?? {},
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'type': type.name,
      'parameters': parameters,
    };
  }
}

/// Condition types for additional checks before executing
enum ConditionType {
  time, // Time range check
  dayOfWeek, // Specific days
  deviceState, // Device must be in specific state
  sensorValue, // Sensor must meet condition
  energy, // Energy level condition
  temperature, // Temperature condition
  humidity, // Humidity condition
  userPresence, // User must be home/away
}

extension ConditionTypeExtension on ConditionType {
  String get name {
    switch (this) {
      case ConditionType.time:
        return 'time';
      case ConditionType.dayOfWeek:
        return 'day_of_week';
      case ConditionType.deviceState:
        return 'device_state';
      case ConditionType.sensorValue:
        return 'sensor_value';
      case ConditionType.energy:
        return 'energy';
      case ConditionType.temperature:
        return 'temperature';
      case ConditionType.humidity:
        return 'humidity';
      case ConditionType.userPresence:
        return 'user_presence';
    }
  }

  static ConditionType fromString(String value) {
    switch (value.toLowerCase()) {
      case 'time':
        return ConditionType.time;
      case 'day_of_week':
        return ConditionType.dayOfWeek;
      case 'device_state':
        return ConditionType.deviceState;
      case 'sensor_value':
        return ConditionType.sensorValue;
      case 'energy':
        return ConditionType.energy;
      case 'temperature':
        return ConditionType.temperature;
      case 'humidity':
        return ConditionType.humidity;
      case 'user_presence':
        return ConditionType.userPresence;
      default:
        return ConditionType.time;
    }
  }
}

class AutomationCondition {
  final ConditionType type;
  final Map<String, dynamic> parameters;

  AutomationCondition({
    required this.type,
    required this.parameters,
  });

  factory AutomationCondition.fromJson(Map<String, dynamic> json) {
    return AutomationCondition(
      type: ConditionTypeExtension.fromString(json['type'] as String),
      parameters: json['parameters'] as Map<String, dynamic>? ?? {},
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'type': type.name,
      'parameters': parameters,
    };
  }
}

/// Action types that can be executed
enum ActionType {
  deviceControl, // Control any device
  turnOn, // Turn device on
  turnOff, // Turn device off
  toggle, // Toggle device state
  setBrightness, // Set light brightness
  setTemperature, // Set thermostat temperature
  openClose, // Open/close doors, windows
  sendNotification, // Send notification to user
  sendMqttMessage, // Send custom MQTT message
  triggerAlarm, // Trigger alarm
  playSound, // Play buzzer/sound
  adjustEnergy, // Adjust energy settings
  logEvent, // Log event to Firestore
}

extension ActionTypeExtension on ActionType {
  String get name {
    switch (this) {
      case ActionType.deviceControl:
        return 'device_control';
      case ActionType.turnOn:
        return 'turn_on';
      case ActionType.turnOff:
        return 'turn_off';
      case ActionType.toggle:
        return 'toggle';
      case ActionType.setBrightness:
        return 'set_brightness';
      case ActionType.setTemperature:
        return 'set_temperature';
      case ActionType.openClose:
        return 'open_close';
      case ActionType.sendNotification:
        return 'send_notification';
      case ActionType.sendMqttMessage:
        return 'send_mqtt_message';
      case ActionType.triggerAlarm:
        return 'trigger_alarm';
      case ActionType.playSound:
        return 'play_sound';
      case ActionType.adjustEnergy:
        return 'adjust_energy';
      case ActionType.logEvent:
        return 'log_event';
    }
  }

  static ActionType fromString(String value) {
    switch (value.toLowerCase()) {
      case 'device_control':
        return ActionType.deviceControl;
      case 'turn_on':
        return ActionType.turnOn;
      case 'turn_off':
        return ActionType.turnOff;
      case 'toggle':
        return ActionType.toggle;
      case 'set_brightness':
        return ActionType.setBrightness;
      case 'set_temperature':
        return ActionType.setTemperature;
      case 'open_close':
        return ActionType.openClose;
      case 'send_notification':
        return ActionType.sendNotification;
      case 'send_mqtt_message':
        return ActionType.sendMqttMessage;
      case 'trigger_alarm':
        return ActionType.triggerAlarm;
      case 'play_sound':
        return ActionType.playSound;
      case 'adjust_energy':
        return ActionType.adjustEnergy;
      case 'log_event':
        return ActionType.logEvent;
      default:
        return ActionType.deviceControl;
    }
  }
}

class AutomationAction {
  final ActionType type;
  final String? deviceId;
  final Map<String, dynamic> parameters;

  AutomationAction({
    required this.type,
    this.deviceId,
    required this.parameters,
  });

  factory AutomationAction.fromJson(Map<String, dynamic> json) {
    return AutomationAction(
      type: ActionTypeExtension.fromString(json['type'] as String),
      deviceId: json['deviceId'] as String?,
      parameters: json['parameters'] as Map<String, dynamic>? ?? {},
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'type': type.name,
      'deviceId': deviceId,
      'parameters': parameters,
    };
  }
}

/// History record of automation execution
class AutomationExecutionLog {
  final String id;
  final String automationId;
  final String automationName;
  final DateTime executedAt;
  final bool success;
  final String? errorMessage;
  final Map<String, dynamic> triggerData;
  final List<String> actionsExecuted;

  AutomationExecutionLog({
    required this.id,
    required this.automationId,
    required this.automationName,
    required this.executedAt,
    required this.success,
    this.errorMessage,
    required this.triggerData,
    required this.actionsExecuted,
  });

  factory AutomationExecutionLog.fromJson(Map<String, dynamic> json) {
    return AutomationExecutionLog(
      id: json['id'] as String,
      automationId: json['automationId'] as String,
      automationName: json['automationName'] as String,
      executedAt:
          (json['executedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      success: json['success'] as bool,
      errorMessage: json['errorMessage'] as String?,
      triggerData: json['triggerData'] as Map<String, dynamic>? ?? {},
      actionsExecuted: (json['actionsExecuted'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'automationId': automationId,
      'automationName': automationName,
      'executedAt': Timestamp.fromDate(executedAt),
      'success': success,
      'errorMessage': errorMessage,
      'triggerData': triggerData,
      'actionsExecuted': actionsExecuted,
    };
  }
}
