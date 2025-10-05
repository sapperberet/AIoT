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
  }) : createdAt = createdAt ?? DateTime.now();

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
    );
  }
}

enum TriggerType {
  time,
  deviceState,
  temperature,
  sunrise,
  sunset,
}

class AutomationTrigger {
  final TriggerType type;
  final Map<String, dynamic> parameters;

  AutomationTrigger({
    required this.type,
    required this.parameters,
  });
}

enum ConditionType {
  time,
  deviceState,
  temperature,
  day,
}

class AutomationCondition {
  final ConditionType type;
  final Map<String, dynamic> parameters;

  AutomationCondition({
    required this.type,
    required this.parameters,
  });
}

enum ActionType {
  turnOn,
  turnOff,
  setBrightness,
  setTemperature,
  sendNotification,
}

class AutomationAction {
  final ActionType type;
  final String deviceId;
  final Map<String, dynamic> parameters;

  AutomationAction({
    required this.type,
    required this.deviceId,
    required this.parameters,
  });
}
