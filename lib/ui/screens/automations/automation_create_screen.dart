import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/services/automation_service.dart';
import '../../../core/models/automation_model.dart';
import '../../../core/models/sensor_data_model.dart';
import '../../../core/localization/app_localizations.dart';

class AutomationCreateScreen extends StatefulWidget {
  const AutomationCreateScreen({super.key});

  @override
  State<AutomationCreateScreen> createState() => _AutomationCreateScreenState();
}

class _AutomationCreateScreenState extends State<AutomationCreateScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();

  final List<AutomationTrigger> _triggers = [];
  final List<AutomationCondition> _conditions = [];
  final List<AutomationAction> _actions = [];

  bool _isCreating = false;

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(loc.translate('create_automation')),
        actions: [
          if (!_isCreating)
            TextButton(
              onPressed: _createAutomation,
              child: const Text('SAVE', style: TextStyle(color: Colors.white)),
            ),
        ],
      ),
      body: _isCreating
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Name
                    TextFormField(
                      controller: _nameController,
                      decoration: const InputDecoration(
                        labelText: 'Name',
                        hintText: 'e.g., Turn on lights at sunset',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter a name';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    // Description
                    TextFormField(
                      controller: _descriptionController,
                      decoration: const InputDecoration(
                        labelText: 'Description',
                        hintText: 'Describe what this automation does',
                        border: OutlineInputBorder(),
                      ),
                      maxLines: 3,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter a description';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 24),
                    // Triggers
                    _buildSection(
                      'Triggers',
                      Icons.flash_on,
                      Colors.blue,
                      _triggers,
                      () => _addTrigger(),
                      (index) => _removeTrigger(index),
                    ),
                    const SizedBox(height: 24),
                    // Conditions (optional)
                    _buildSection(
                      'Conditions (Optional)',
                      Icons.filter_list,
                      Colors.orange,
                      _conditions,
                      () => _addCondition(),
                      (index) => _removeCondition(index),
                    ),
                    const SizedBox(height: 24),
                    // Actions
                    _buildSection(
                      'Actions',
                      Icons.play_arrow,
                      Colors.green,
                      _actions,
                      () => _addAction(),
                      (index) => _removeAction(index),
                    ),
                    const SizedBox(height: 24),
                    // Quick templates
                    _buildQuickTemplates(),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildSection<T>(
    String title,
    IconData icon,
    Color color,
    List<T> items,
    VoidCallback onAdd,
    Function(int) onRemove,
  ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.add_circle),
                  color: color,
                  onPressed: onAdd,
                ),
              ],
            ),
            if (items.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Center(
                  child: Text(
                    'No ${title.toLowerCase()} added yet',
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                ),
              )
            else
              ...List.generate(items.length, (index) {
                return ListTile(
                  leading: Icon(icon, color: color),
                  title: Text(_getItemSummary(items[index])),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete, color: Colors.red),
                    onPressed: () => onRemove(index),
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickTemplates() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Quick Templates',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _buildTemplateChip(
                  'High Temperature Alert',
                  () => _applyTemperatureTemplate(),
                ),
                _buildTemplateChip(
                  'Motion Detection',
                  () => _applyMotionTemplate(),
                ),
                _buildTemplateChip(
                  'Energy Saver',
                  () => _applyEnergySaverTemplate(),
                ),
                _buildTemplateChip(
                  'Sunset Lights',
                  () => _applySunsetTemplate(),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTemplateChip(String label, VoidCallback onTap) {
    return ActionChip(
      label: Text(label),
      onPressed: onTap,
      avatar: const Icon(Icons.lightbulb_outline, size: 18),
    );
  }

  String _getItemSummary(dynamic item) {
    if (item is AutomationTrigger) {
      return item.type.name.replaceAll('_', ' ');
    } else if (item is AutomationCondition) {
      return item.type.name.replaceAll('_', ' ');
    } else if (item is AutomationAction) {
      return '${item.type.name.replaceAll('_', ' ')} ${item.deviceId ?? ''}';
    }
    return 'Unknown';
  }

  void _addTrigger() {
    showDialog(
      context: context,
      builder: (context) => _TriggerPickerDialog(
        onTriggerSelected: (trigger) {
          setState(() => _triggers.add(trigger));
        },
      ),
    );
  }

  void _removeTrigger(int index) {
    setState(() => _triggers.removeAt(index));
  }

  void _addCondition() {
    showDialog(
      context: context,
      builder: (context) => _ConditionPickerDialog(
        onConditionSelected: (condition) {
          setState(() => _conditions.add(condition));
        },
      ),
    );
  }

  void _removeCondition(int index) {
    setState(() => _conditions.removeAt(index));
  }

  void _addAction() {
    showDialog(
      context: context,
      builder: (context) => _ActionPickerDialog(
        onActionSelected: (action) {
          setState(() => _actions.add(action));
        },
      ),
    );
  }

  void _removeAction(int index) {
    setState(() => _actions.removeAt(index));
  }

  // Quick templates
  void _applyTemperatureTemplate() {
    setState(() {
      _nameController.text = 'High Temperature Alert';
      _descriptionController.text =
          'Send notification when temperature exceeds 30°C';
      _triggers.clear();
      _triggers.add(AutomationTrigger(
        type: TriggerType.temperature,
        parameters: {'threshold': 30.0, 'operator': 'greater'},
      ));
      _actions.clear();
      _actions.add(AutomationAction(
        type: ActionType.sendNotification,
        parameters: {
          'title': 'High Temperature',
          'message': 'Temperature exceeded 30°C',
        },
      ));
    });
  }

  void _applyMotionTemplate() {
    setState(() {
      _nameController.text = 'Motion Detection Alert';
      _descriptionController.text = 'Turn on lights when motion is detected';
      _triggers.clear();
      _triggers.add(AutomationTrigger(
        type: TriggerType.motion,
        parameters: {},
      ));
      _actions.clear();
      _actions.add(AutomationAction(
        type: ActionType.turnOn,
        deviceId: 'living_room_light',
        parameters: {},
      ));
    });
  }

  void _applyEnergySaverTemplate() {
    setState(() {
      _nameController.text = 'Energy Saver Mode';
      _descriptionController.text =
          'Turn off devices when energy consumption is high';
      _triggers.clear();
      _triggers.add(AutomationTrigger(
        type: TriggerType.energy,
        parameters: {'threshold': 1000.0, 'operator': 'greater'},
      ));
      _actions.clear();
      _actions.add(AutomationAction(
        type: ActionType.sendNotification,
        parameters: {
          'title': 'High Energy Usage',
          'message': 'Energy consumption exceeded 1000W',
        },
      ));
    });
  }

  void _applySunsetTemplate() {
    setState(() {
      _nameController.text = 'Sunset Lights';
      _descriptionController.text = 'Turn on lights at sunset';
      _triggers.clear();
      _triggers.add(AutomationTrigger(
        type: TriggerType.sunset,
        parameters: {'offset': 0},
      ));
      _actions.clear();
      _actions.add(AutomationAction(
        type: ActionType.turnOn,
        deviceId: 'living_room_light',
        parameters: {},
      ));
    });
  }

  Future<void> _createAutomation() async {
    if (!_formKey.currentState!.validate()) return;

    if (_triggers.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please add at least one trigger'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    if (_actions.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please add at least one action'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isCreating = true);

    final automation = Automation(
      id: '',
      name: _nameController.text,
      description: _descriptionController.text,
      triggers: _triggers,
      conditions: _conditions,
      actions: _actions,
    );

    final service = context.read<AutomationService>();
    final id = await service.createAutomation(automation);

    if (mounted) {
      setState(() => _isCreating = false);

      if (id != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Automation created successfully'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to create automation'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}

// Trigger Picker Dialog
class _TriggerPickerDialog extends StatelessWidget {
  final Function(AutomationTrigger) onTriggerSelected;

  const _TriggerPickerDialog({required this.onTriggerSelected});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Select Trigger Type'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: TriggerType.values.map((type) {
            return ListTile(
              leading: const Icon(Icons.flash_on),
              title: Text(type.name.replaceAll('_', ' ')),
              onTap: () {
                Navigator.pop(context);
                _showTriggerParametersDialog(context, type);
              },
            );
          }).toList(),
        ),
      ),
    );
  }

  void _showTriggerParametersDialog(BuildContext context, TriggerType type) {
    // Simplified parameter input
    final parameters = <String, dynamic>{};

    switch (type) {
      case TriggerType.temperature:
      case TriggerType.humidity:
      case TriggerType.energy:
        parameters['threshold'] = 30.0;
        parameters['operator'] = 'greater';
        break;
      case TriggerType.time:
        parameters['hour'] = 18;
        parameters['minute'] = 0;
        break;
      case TriggerType.schedule:
        parameters['hour'] = 18;
        parameters['minute'] = 0;
        parameters['daysOfWeek'] = [1, 2, 3, 4, 5];
        break;
      default:
        break;
    }

    onTriggerSelected(AutomationTrigger(type: type, parameters: parameters));
  }
}

// Condition Picker Dialog
class _ConditionPickerDialog extends StatelessWidget {
  final Function(AutomationCondition) onConditionSelected;

  const _ConditionPickerDialog({required this.onConditionSelected});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Select Condition Type'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: ConditionType.values.map((type) {
            return ListTile(
              leading: const Icon(Icons.filter_list),
              title: Text(type.name.replaceAll('_', ' ')),
              onTap: () {
                Navigator.pop(context);
                onConditionSelected(
                  AutomationCondition(type: type, parameters: {}),
                );
              },
            );
          }).toList(),
        ),
      ),
    );
  }
}

// Action Picker Dialog
class _ActionPickerDialog extends StatefulWidget {
  final Function(AutomationAction) onActionSelected;

  const _ActionPickerDialog({required this.onActionSelected});

  @override
  State<_ActionPickerDialog> createState() => _ActionPickerDialogState();
}

class _ActionPickerDialogState extends State<_ActionPickerDialog> {
  ActionType? _selectedType;
  final _deviceIdController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Select Action'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<ActionType>(
              decoration: const InputDecoration(labelText: 'Action Type'),
              value: _selectedType,
              items: ActionType.values.map((type) {
                return DropdownMenuItem(
                  value: type,
                  child: Text(type.name.replaceAll('_', ' ')),
                );
              }).toList(),
              onChanged: (value) {
                setState(() => _selectedType = value);
              },
            ),
            const SizedBox(height: 16),
            if (_selectedType != null &&
                _selectedType != ActionType.sendNotification)
              TextField(
                controller: _deviceIdController,
                decoration: const InputDecoration(
                  labelText: 'Device ID',
                  hintText: 'e.g., living_room_light',
                ),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () {
            if (_selectedType != null) {
              widget.onActionSelected(
                AutomationAction(
                  type: _selectedType!,
                  deviceId: _deviceIdController.text.isNotEmpty
                      ? _deviceIdController.text
                      : null,
                  parameters: {},
                ),
              );
              Navigator.pop(context);
            }
          },
          child: const Text('Add'),
        ),
      ],
    );
  }
}
