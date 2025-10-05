import 'package:flutter/foundation.dart';
import '../models/automation_model.dart';

class AutomationProvider with ChangeNotifier {
  final List<Automation> _automations = [
    // Sample automations
    Automation(
      id: '1',
      name: 'Good Morning',
      description: 'Turn on lights and adjust temperature at 7 AM',
      triggers: [
        AutomationTrigger(
          type: TriggerType.time,
          parameters: {'time': '07:00'},
        ),
      ],
      actions: [
        AutomationAction(
          type: ActionType.turnOn,
          deviceId: 'light_1',
          parameters: {'brightness': 80},
        ),
        AutomationAction(
          type: ActionType.setTemperature,
          deviceId: 'thermostat_1',
          parameters: {'temperature': 22},
        ),
      ],
    ),
    Automation(
      id: '2',
      name: 'Away Mode',
      description: 'Turn off all devices when leaving home',
      isEnabled: false,
      triggers: [
        AutomationTrigger(
          type: TriggerType.deviceState,
          parameters: {'deviceId': 'door_sensor', 'state': 'closed'},
        ),
      ],
      conditions: [
        AutomationCondition(
          type: ConditionType.time,
          parameters: {'after': '08:00', 'before': '18:00'},
        ),
      ],
      actions: [
        AutomationAction(
          type: ActionType.turnOff,
          deviceId: 'all',
          parameters: {},
        ),
        AutomationAction(
          type: ActionType.sendNotification,
          deviceId: '',
          parameters: {'message': 'All devices turned off'},
        ),
      ],
    ),
    Automation(
      id: '3',
      name: 'Night Security',
      description: 'Enable security features at night',
      triggers: [
        AutomationTrigger(
          type: TriggerType.sunset,
          parameters: {'offset': 0},
        ),
      ],
      actions: [
        AutomationAction(
          type: ActionType.turnOn,
          deviceId: 'outdoor_lights',
          parameters: {},
        ),
        AutomationAction(
          type: ActionType.turnOn,
          deviceId: 'security_camera',
          parameters: {},
        ),
      ],
    ),
  ];

  List<Automation> get automations => List.unmodifiable(_automations);
  List<Automation> get enabledAutomations =>
      _automations.where((a) => a.isEnabled).toList();

  // Add automation
  void addAutomation(Automation automation) {
    _automations.add(automation);
    notifyListeners();
  }

  // Update automation
  void updateAutomation(String id, Automation automation) {
    final index = _automations.indexWhere((a) => a.id == id);
    if (index != -1) {
      _automations[index] = automation;
      notifyListeners();
    }
  }

  // Delete automation
  void deleteAutomation(String id) {
    _automations.removeWhere((a) => a.id == id);
    notifyListeners();
  }

  // Toggle automation
  void toggleAutomation(String id) {
    final index = _automations.indexWhere((a) => a.id == id);
    if (index != -1) {
      _automations[index] = _automations[index].copyWith(
        isEnabled: !_automations[index].isEnabled,
      );
      notifyListeners();
    }
  }

  // Execute automation
  Future<void> executeAutomation(String id) async {
    final automation = _automations.firstWhere((a) => a.id == id);

    // TODO: Implement automation execution logic
    debugPrint('Executing automation: ${automation.name}');

    // Update last triggered time
    final index = _automations.indexWhere((a) => a.id == id);
    if (index != -1) {
      _automations[index] = _automations[index].copyWith(
        lastTriggered: DateTime.now(),
      );
      notifyListeners();
    }
  }

  // Check if automation should trigger
  bool shouldTrigger(Automation automation) {
    // TODO: Implement trigger checking logic
    return false;
  }

  // Evaluate conditions
  bool evaluateConditions(Automation automation) {
    // TODO: Implement condition evaluation logic
    return true;
  }
}
