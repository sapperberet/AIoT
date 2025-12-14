import 'package:logger/logger.dart';
import 'package:uuid/uuid.dart';
import '../models/automation_model.dart';
import '../services/automation_service.dart';
import '../services/mqtt_service.dart';
import '../services/firestore_service.dart';
import '../config/mqtt_config.dart';

/// Service for handling AI chat automation actions
/// Allows the AI to control devices, create automations, and update settings
class AIChatActionsService {
  final Logger _logger = Logger();
  final Uuid _uuid = const Uuid();

  final AutomationService _automationService;
  final MqttService _mqttService;
  final FirestoreService _firestoreService;

  AIChatActionsService({
    required AutomationService automationService,
    required MqttService mqttService,
    required FirestoreService firestoreService,
  })  : _automationService = automationService,
        _mqttService = mqttService,
        _firestoreService = firestoreService;

  /// Parse AI response for action commands
  /// Returns a map of executed actions and their results
  Future<Map<String, dynamic>> parseAndExecuteActions(
    String aiResponse, {
    String? userId,
  }) async {
    final results = <String, dynamic>{};
    final executedActions = <String>[];

    try {
      // Look for action commands in the AI response
      // Format: [ACTION:type:parameters]
      final actionRegex = RegExp(r'\[ACTION:([^\]]+)\]');
      final matches = actionRegex.allMatches(aiResponse);

      for (final match in matches) {
        final actionData = match.group(1);
        if (actionData == null) continue;

        final parts = actionData.split(':');
        if (parts.isEmpty) continue;

        final actionType = parts[0].toLowerCase();
        final actionResult = await _executeAction(
          actionType,
          parts.sublist(1),
          userId: userId,
        );

        executedActions.add(actionType);
        results[actionType] = actionResult;

        _logger.i('✅ Executed action: $actionType - $actionResult');
      }

      results['success'] = executedActions.isNotEmpty;
      results['executedActions'] = executedActions;
      results['message'] = executedActions.isEmpty
          ? 'No actions detected'
          : 'Executed ${executedActions.length} action(s)';
    } catch (e) {
      _logger.e('Error parsing and executing actions: $e');
      results['success'] = false;
      results['error'] = e.toString();
    }

    return results;
  }

  /// Execute a specific action based on type
  Future<Map<String, dynamic>> _executeAction(
    String actionType,
    List<String> parameters, {
    String? userId,
  }) async {
    switch (actionType) {
      case 'device_control':
      case 'control':
        return await _executeDeviceControl(parameters);

      case 'create_automation':
      case 'automation':
        return await _createAutomation(parameters, userId: userId);

      case 'open_door':
      case 'close_door':
        return await _controlDoor(
          parameters.isNotEmpty ? parameters[0] : 'main_door',
          actionType == 'open_door',
        );

      case 'open_window':
      case 'close_window':
        return await _controlWindow(
          parameters.isNotEmpty ? parameters[0] : 'front',
          actionType == 'open_window',
        );

      case 'turn_light':
        return await _controlLight(
          parameters.isNotEmpty ? parameters[0] : 'living_room',
          parameters.length > 1 ? parameters[1] == 'on' : true,
        );

      case 'set_fan':
        return await _controlFan(
          parameters.isNotEmpty ? parameters[0] : 'living_room',
          parameters.length > 1 ? int.tryParse(parameters[1]) ?? 0 : 0,
        );

      case 'trigger_alarm':
        return await _triggerAlarm(parameters.isNotEmpty ? parameters[0] : '');

      default:
        return {
          'success': false,
          'error': 'Unknown action type: $actionType',
        };
    }
  }

  /// Control a device via MQTT
  Future<Map<String, dynamic>> _executeDeviceControl(
      List<String> parameters) async {
    if (parameters.length < 3) {
      return {
        'success': false,
        'error': 'Invalid device control parameters',
      };
    }

    final deviceType = parameters[0];
    final deviceId = parameters[1];
    final command = parameters[2];
    final topic = '${MqttConfig.topicPrefix}/$deviceId/$deviceType/command';

    _mqttService.publish(topic, command);

    return {
      'success': true,
      'device': deviceId,
      'command': command,
      'topic': topic,
    };
  }

  /// Control door (main_door, garage_door)
  Future<Map<String, dynamic>> _controlDoor(String doorId, bool open) async {
    final topic = '${MqttConfig.topicPrefix}/${doorId}/command';
    final command = open ? 'OPEN' : 'CLOSE';

    _mqttService.publish(topic, command);

    return {
      'success': true,
      'device': doorId,
      'action': open ? 'opened' : 'closed',
      'topic': topic,
    };
  }

  /// Control window
  Future<Map<String, dynamic>> _controlWindow(
      String windowId, bool open) async {
    final topic = '${MqttConfig.topicPrefix}/${windowId}/window/command';
    final command = open ? 'OPEN' : 'CLOSE';

    _mqttService.publish(topic, command);

    return {
      'success': true,
      'device': '${windowId}_window',
      'action': open ? 'opened' : 'closed',
      'topic': topic,
    };
  }

  /// Control light
  Future<Map<String, dynamic>> _controlLight(String room, bool turnOn) async {
    final topic = '${MqttConfig.topicPrefix}/$room/light/set';
    final command = turnOn ? 'ON' : 'OFF';

    _mqttService.publish(topic, command);

    return {
      'success': true,
      'device': '${room}_light',
      'action': turnOn ? 'turned on' : 'turned off',
      'topic': topic,
    };
  }

  /// Control fan with speed
  Future<Map<String, dynamic>> _controlFan(String room, int speed) async {
    final topic = '${MqttConfig.topicPrefix}/$room/fan/command';
    final command = speed.toString();

    _mqttService.publish(topic, command);

    return {
      'success': true,
      'device': '${room}_fan',
      'speed': speed,
      'topic': topic,
    };
  }

  /// Trigger alarm
  Future<Map<String, dynamic>> _triggerAlarm(String alarmType) async {
    final topic = '${MqttConfig.topicPrefix}/buzzer/command';
    final command = 'ALARM';

    _mqttService.publish(topic, command);

    return {
      'success': true,
      'alarm': alarmType.isEmpty ? 'general' : alarmType,
      'topic': topic,
    };
  }

  /// Create an automation from AI suggestion
  Future<Map<String, dynamic>> _createAutomation(
    List<String> parameters, {
    String? userId,
  }) async {
    if (parameters.length < 2) {
      return {
        'success': false,
        'error': 'Invalid automation parameters',
      };
    }

    try {
      // Parse parameters
      // Expected format: name:description:trigger:action
      final name = parameters[0];
      final description =
          parameters.length > 1 ? parameters[1] : 'AI created automation';

      // Create a basic automation
      final automation = Automation(
        id: _uuid.v4(),
        name: name,
        description: description,
        isEnabled: true,
        triggers: [
          AutomationTrigger(
            type: TriggerType.manual,
            parameters: {'createdBy': 'ai_chat'},
          ),
        ],
        actions: [
          AutomationAction(
            type: ActionType.logEvent,
            parameters: {
              'message': 'Automation created by AI chat',
              'timestamp': DateTime.now().toIso8601String(),
            },
          ),
        ],
      );

      final automationId =
          await _automationService.createAutomation(automation);

      return {
        'success': automationId != null,
        'automationId': automationId,
        'name': name,
      };
    } catch (e) {
      _logger.e('Error creating automation: $e');
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }

  /// Execute an automation by ID
  Future<Map<String, dynamic>> executeAutomation(
    String automationId, {
    String? userId,
  }) async {
    try {
      final automation = _automationService.getAutomation(automationId);
      if (automation == null) {
        return {
          'success': false,
          'error': 'Automation not found',
        };
      }

      if (!automation.isEnabled) {
        return {
          'success': false,
          'error': 'Automation is disabled',
        };
      }

      final actionsExecuted = <String>[];

      // Execute each action
      for (final action in automation.actions) {
        final result = await _executeAutomationAction(action, userId: userId);
        if (result['success'] == true) {
          actionsExecuted.add(action.type.name);
        }
      }

      // Log execution
      final log = AutomationExecutionLog(
        id: _uuid.v4(),
        automationId: automation.id,
        automationName: automation.name,
        executedAt: DateTime.now(),
        success: actionsExecuted.length == automation.actions.length,
        triggerData: {'source': 'ai_chat'},
        actionsExecuted: actionsExecuted,
      );

      await _automationService.logExecution(log);

      return {
        'success': true,
        'automationId': automationId,
        'actionsExecuted': actionsExecuted,
      };
    } catch (e) {
      _logger.e('Error executing automation: $e');
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }

  /// Execute a single automation action
  Future<Map<String, dynamic>> _executeAutomationAction(
    AutomationAction action, {
    String? userId,
  }) async {
    switch (action.type) {
      case ActionType.deviceControl:
      case ActionType.turnOn:
      case ActionType.turnOff:
      case ActionType.toggle:
        return await _executeDeviceControlAction(action);

      case ActionType.openClose:
        return await _executeOpenCloseAction(action);

      case ActionType.setBrightness:
        return await _executeBrightnessAction(action);

      case ActionType.sendMqttMessage:
        return await _executeMqttAction(action);

      case ActionType.playSound:
      case ActionType.triggerAlarm:
        return await _executeAlarmAction(action);

      case ActionType.sendNotification:
        return await _executeNotificationAction(action, userId: userId);

      case ActionType.logEvent:
        return await _executeLogAction(action, userId: userId);

      default:
        return {
          'success': false,
          'error': 'Unsupported action type: ${action.type}',
        };
    }
  }

  Future<Map<String, dynamic>> _executeDeviceControlAction(
      AutomationAction action) async {
    final deviceId =
        action.deviceId ?? action.parameters['deviceId'] as String?;
    if (deviceId == null) {
      return {'success': false, 'error': 'Device ID not specified'};
    }

    final deviceType = action.parameters['deviceType'] as String? ?? 'command';
    final topic = '${MqttConfig.topicPrefix}/$deviceId/$deviceType';

    String command;
    switch (action.type) {
      case ActionType.turnOn:
        command = 'ON';
        break;
      case ActionType.turnOff:
        command = 'OFF';
        break;
      case ActionType.toggle:
        command = 'TOGGLE';
        break;
      default:
        command = action.parameters['command'] as String? ?? 'ON';
    }

    _mqttService.publish(topic, command);
    return {'success': true, 'device': deviceId, 'command': command};
  }

  Future<Map<String, dynamic>> _executeOpenCloseAction(
      AutomationAction action) async {
    final deviceId =
        action.deviceId ?? action.parameters['deviceId'] as String?;
    final isOpen = action.parameters['open'] as bool? ?? true;

    if (deviceId == null) {
      return {'success': false, 'error': 'Device ID not specified'};
    }

    final topic = '${MqttConfig.topicPrefix}/$deviceId/command';
    final command = isOpen ? 'OPEN' : 'CLOSE';

    _mqttService.publish(topic, command);
    return {'success': true, 'device': deviceId, 'action': command};
  }

  Future<Map<String, dynamic>> _executeBrightnessAction(
      AutomationAction action) async {
    final deviceId =
        action.deviceId ?? action.parameters['deviceId'] as String?;
    final brightness = action.parameters['brightness'] as int? ?? 100;

    if (deviceId == null) {
      return {'success': false, 'error': 'Device ID not specified'};
    }

    final topic = '${MqttConfig.topicPrefix}/$deviceId/light/set';
    final command = brightness.toString();

    _mqttService.publish(topic, command);
    return {'success': true, 'device': deviceId, 'brightness': brightness};
  }

  Future<Map<String, dynamic>> _executeMqttAction(
      AutomationAction action) async {
    final topic = action.parameters['topic'] as String?;
    final message = action.parameters['message'] as String?;

    if (topic == null || message == null) {
      return {'success': false, 'error': 'Topic or message not specified'};
    }

    _mqttService.publish(topic, message);
    return {'success': true, 'topic': topic};
  }

  Future<Map<String, dynamic>> _executeAlarmAction(
      AutomationAction action) async {
    final topic = '${MqttConfig.topicPrefix}/buzzer/command';
    final command = 'ALARM';

    _mqttService.publish(topic, command);
    return {'success': true};
  }

  Future<Map<String, dynamic>> _executeNotificationAction(
    AutomationAction action, {
    String? userId,
  }) async {
    // This would integrate with your notification system
    _logger.i('Notification action: ${action.parameters['message']}');
    return {'success': true, 'message': 'Notification sent'};
  }

  Future<Map<String, dynamic>> _executeLogAction(
    AutomationAction action, {
    String? userId,
  }) async {
    try {
      if (userId == null) {
        return {'success': false, 'error': 'User ID required for logging'};
      }

      final message =
          action.parameters['message'] as String? ?? 'Automation executed';

      // Log to Firestore using logEvent method
      await _firestoreService.logEvent(
        userId,
        'automation',
        {
          'message': message,
          ...action.parameters,
        },
      );

      return {'success': true};
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  /// Get list of available actions
  List<Map<String, dynamic>> getAvailableActions() {
    return [
      {
        'type': 'device_control',
        'description': 'Control any device',
        'parameters': ['deviceType', 'deviceId', 'command'],
      },
      {
        'type': 'open_door',
        'description': 'Open a door',
        'parameters': ['doorId'],
      },
      {
        'type': 'close_door',
        'description': 'Close a door',
        'parameters': ['doorId'],
      },
      {
        'type': 'open_window',
        'description': 'Open a window',
        'parameters': ['windowId'],
      },
      {
        'type': 'close_window',
        'description': 'Close a window',
        'parameters': ['windowId'],
      },
      {
        'type': 'turn_light',
        'description': 'Turn light on/off',
        'parameters': ['room', 'state'],
      },
      {
        'type': 'set_fan',
        'description': 'Set fan speed',
        'parameters': ['room', 'speed'],
      },
      {
        'type': 'trigger_alarm',
        'description': 'Trigger alarm/buzzer',
        'parameters': ['alarmType'],
      },
      {
        'type': 'create_automation',
        'description': 'Create new automation',
        'parameters': ['name', 'description'],
      },
    ];
  }

  /// Direct action methods for easy access

  Future<bool> openDoor(String doorId) async {
    final result = await _controlDoor(doorId, true);
    return result['success'] == true;
  }

  Future<bool> closeDoor(String doorId) async {
    final result = await _controlDoor(doorId, false);
    return result['success'] == true;
  }

  Future<bool> openWindow(String windowId) async {
    final result = await _controlWindow(windowId, true);
    return result['success'] == true;
  }

  Future<bool> closeWindow(String windowId) async {
    final result = await _controlWindow(windowId, false);
    return result['success'] == true;
  }

  Future<bool> turnLightOn(String room) async {
    final result = await _controlLight(room, true);
    return result['success'] == true;
  }

  Future<bool> turnLightOff(String room) async {
    final result = await _controlLight(room, false);
    return result['success'] == true;
  }

  Future<bool> setFanSpeed(String room, int speed) async {
    final result = await _controlFan(room, speed);
    return result['success'] == true;
  }
}
