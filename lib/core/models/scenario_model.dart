/// Data models for the n8n scenario/automation system.
///
/// These match the JSON format expected by the n8n webhook endpoints
/// documented in the scenario system API.

class Scenario {
  final String? id;
  final String name;
  final ScenarioTrigger trigger;
  final List<ScenarioAction> actions;
  final bool isActive;

  Scenario({
    this.id,
    required this.name,
    required this.trigger,
    required this.actions,
    this.isActive = true,
  });

  factory Scenario.fromJson(Map<String, dynamic> json) {
    return Scenario(
      id: json['id'] as String?,
      name: json['name'] as String,
      trigger:
          ScenarioTrigger.fromJson(json['trigger'] as Map<String, dynamic>),
      actions: (json['actions'] as List<dynamic>)
          .map((a) => ScenarioAction.fromJson(a as Map<String, dynamic>))
          .toList(),
      isActive: json['active'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'trigger': trigger.toJson(),
      'actions': actions.map((a) => a.toJson()).toList(),
    };
  }

  Scenario copyWith({
    String? id,
    String? name,
    ScenarioTrigger? trigger,
    List<ScenarioAction>? actions,
    bool? isActive,
  }) {
    return Scenario(
      id: id ?? this.id,
      name: name ?? this.name,
      trigger: trigger ?? this.trigger,
      actions: actions ?? this.actions,
      isActive: isActive ?? this.isActive,
    );
  }
}

// ─── Trigger ────────────────────────────────────────────────

enum ScenarioTriggerType { schedule, sensor }

enum ScheduleMode { interval, daily, weekly, monthly, cron }

class ScenarioTrigger {
  final ScenarioTriggerType type;

  // Schedule fields
  final ScheduleMode? mode;
  final int? every;
  final String? unit; // seconds | minutes | hours
  final String? at; // HH:MM
  final List<String>? days; // mon, tue, ...
  final int? day; // 1-31
  final String? expression; // cron

  // Sensor fields
  final String? sensor;
  final String? condition; // greater_than | less_than | equals | changes
  final num? value;

  ScenarioTrigger({
    required this.type,
    this.mode,
    this.every,
    this.unit,
    this.at,
    this.days,
    this.day,
    this.expression,
    this.sensor,
    this.condition,
    this.value,
  });

  factory ScenarioTrigger.fromJson(Map<String, dynamic> json) {
    final type = json['type'] == 'schedule'
        ? ScenarioTriggerType.schedule
        : ScenarioTriggerType.sensor;

    ScheduleMode? mode;
    if (json['mode'] != null) {
      mode = ScheduleMode.values.firstWhere(
        (m) => m.name == json['mode'],
        orElse: () => ScheduleMode.daily,
      );
    }

    return ScenarioTrigger(
      type: type,
      mode: mode,
      every: json['every'] as int?,
      unit: json['unit'] as String?,
      at: json['at'] as String?,
      days: (json['days'] as List<dynamic>?)?.map((d) => d as String).toList(),
      day: json['day'] as int?,
      expression: json['expression'] as String?,
      sensor: json['sensor'] as String?,
      condition: json['condition'] as String?,
      value: json['value'] as num?,
    );
  }

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{
      'type': type == ScenarioTriggerType.schedule ? 'schedule' : 'sensor',
    };

    if (type == ScenarioTriggerType.schedule && mode != null) {
      map['mode'] = mode!.name;
      switch (mode!) {
        case ScheduleMode.interval:
          map['every'] = every;
          map['unit'] = unit;
          break;
        case ScheduleMode.daily:
          map['at'] = at;
          break;
        case ScheduleMode.weekly:
          map['at'] = at;
          map['days'] = days;
          break;
        case ScheduleMode.monthly:
          map['at'] = at;
          map['day'] = day;
          break;
        case ScheduleMode.cron:
          map['expression'] = expression;
          break;
      }
    } else if (type == ScenarioTriggerType.sensor) {
      map['sensor'] = sensor;
      map['condition'] = condition;
      if (condition != 'changes') map['value'] = value;
    }

    return map;
  }

  String get description {
    if (type == ScenarioTriggerType.sensor) {
      final condLabel = {
            'greater_than': '>',
            'less_than': '<',
            'equals': '=',
            'changes': 'changes',
          }[condition] ??
          condition ??
          '';
      if (condition == 'changes') return '${sensor ?? ''} changes';
      return '${sensor ?? ''} $condLabel ${value ?? ''}';
    }
    switch (mode) {
      case ScheduleMode.interval:
        return 'Every $every ${unit ?? 'minutes'}';
      case ScheduleMode.daily:
        return 'Daily at $at';
      case ScheduleMode.weekly:
        return '${days?.join(', ') ?? ''} at $at';
      case ScheduleMode.monthly:
        return 'Day $day at $at';
      case ScheduleMode.cron:
        return 'Cron: $expression';
      default:
        return 'Schedule';
    }
  }
}

// ─── Actions ────────────────────────────────────────────────

class ScenarioAction {
  // Device action fields
  final String? device;
  final String? action;

  // Delay fields
  final int? delay;
  final String? unit; // seconds | minutes

  bool get isDelay => delay != null;

  ScenarioAction({
    this.device,
    this.action,
    this.delay,
    this.unit,
  });

  factory ScenarioAction.fromJson(Map<String, dynamic> json) {
    if (json.containsKey('delay')) {
      return ScenarioAction(
        delay: json['delay'] as int,
        unit: json['unit'] as String? ?? 'seconds',
      );
    }
    return ScenarioAction(
      device: json['device'] as String,
      action: json['action'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    if (isDelay) {
      final map = <String, dynamic>{'delay': delay};
      if (unit != null && unit != 'seconds') map['unit'] = unit;
      return map;
    }
    return {'device': device, 'action': action};
  }

  String get description {
    if (isDelay) return 'Wait $delay ${unit ?? 'seconds'}';
    return '${device ?? ''} → ${action ?? ''}';
  }
}

// ─── Reference data ─────────────────────────────────────────

class ScenarioRef {
  static const sensors = {
    'gas': 'Gas Level',
    'ldr': 'Light Intensity',
    'rain': 'Rain',
    'temp': 'Temperature',
    'humidity': 'Humidity',
    'flame': 'Flame Detection',
    'voltage': 'Voltage',
    'current': 'Current',
  };

  static const conditions = {
    'greater_than': 'Greater than',
    'less_than': 'Less than',
    'equals': 'Equals',
    'changes': 'Changes',
  };

  static const devices = {
    'door': 'Front Door',
    'gate': 'Gate',
    'garage': 'Garage',
    'front_window': 'Front Window',
    'lights_floor1': 'Floor 1 Lights',
    'lights_floor2': 'Floor 2 Lights',
    'lights_rgb': 'RGB Lights',
    'fan': 'Fan',
    'buzzer': 'Buzzer',
  };

  static const deviceActions = <String, List<String>>{
    'door': ['open', 'close'],
    'gate': ['open', 'close'],
    'garage': ['open', 'close'],
    'front_window': ['open', 'close'],
    'lights_floor1': ['on', 'off'],
    'lights_floor2': ['on', 'off'],
    'lights_rgb': ['on', 'off'], // simplified; UI adds brightness/color
    'fan': ['in', 'out', 'off'],
    'buzzer': ['on', 'off'],
  };

  static const weekDays = ['mon', 'tue', 'wed', 'thu', 'fri', 'sat', 'sun'];

  static const weekDayLabels = {
    'mon': 'Monday',
    'tue': 'Tuesday',
    'wed': 'Wednesday',
    'thu': 'Thursday',
    'fri': 'Friday',
    'sat': 'Saturday',
    'sun': 'Sunday',
  };
}
