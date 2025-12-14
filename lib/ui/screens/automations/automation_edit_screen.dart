import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/services/automation_service.dart';
import '../../../core/models/automation_model.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/app_theme.dart';

class AutomationEditScreen extends StatefulWidget {
  final Automation automation;

  const AutomationEditScreen({super.key, required this.automation});

  @override
  State<AutomationEditScreen> createState() => _AutomationEditScreenState();
}

class _AutomationEditScreenState extends State<AutomationEditScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _descriptionController;

  late List<AutomationTrigger> _triggers;
  late List<AutomationCondition> _conditions;
  late List<AutomationAction> _actions;
  late bool _isEnabled;

  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.automation.name);
    _descriptionController =
        TextEditingController(text: widget.automation.description);
    _triggers = List.from(widget.automation.triggers);
    _conditions = List.from(widget.automation.conditions);
    _actions = List.from(widget.automation.actions);
    _isEnabled = widget.automation.isEnabled;
  }

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
        title: Text(loc.translate('edit_automation')),
        actions: [
          if (!_isSaving)
            TextButton(
              onPressed: _saveAutomation,
              child: const Text('SAVE', style: TextStyle(color: Colors.white)),
            ),
        ],
      ),
      body: _isSaving
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Enable/Disable Toggle
                    Card(
                      child: SwitchListTile(
                        title: const Text('Automation Enabled'),
                        subtitle: Text(_isEnabled ? 'Active' : 'Disabled'),
                        value: _isEnabled,
                        activeColor: AppTheme.primaryColor,
                        onChanged: (value) {
                          setState(() => _isEnabled = value);
                        },
                      ),
                    ),
                    const SizedBox(height: 16),

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

                    // Execution Info
                    _buildExecutionInfo(),
                    const SizedBox(height: 100),
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

  Widget _buildExecutionInfo() {
    final automation = widget.automation;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Execution Info',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            _buildInfoRow(
                'Times Executed', automation.executionCount.toString()),
            if (automation.lastTriggered != null)
              _buildInfoRow(
                'Last Triggered',
                _formatDateTime(automation.lastTriggered!),
              ),
            _buildInfoRow(
              'Created',
              _formatDateTime(automation.createdAt),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: Colors.grey[600])),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  String _formatDateTime(DateTime dt) {
    return '${dt.day}/${dt.month}/${dt.year} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
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

  Future<void> _saveAutomation() async {
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

    setState(() => _isSaving = true);

    final updatedAutomation = widget.automation.copyWith(
      name: _nameController.text,
      description: _descriptionController.text,
      isEnabled: _isEnabled,
      triggers: _triggers,
      conditions: _conditions,
      actions: _actions,
    );

    final service = context.read<AutomationService>();
    final success = await service.updateAutomation(updatedAutomation);

    if (mounted) {
      setState(() => _isSaving = false);

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Automation updated successfully'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to update automation'),
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
class _ActionPickerDialog extends StatelessWidget {
  final Function(AutomationAction) onActionSelected;

  const _ActionPickerDialog({required this.onActionSelected});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Select Action Type'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: ActionType.values.map((type) {
            return ListTile(
              leading: const Icon(Icons.play_arrow),
              title: Text(type.name.replaceAll('_', ' ')),
              onTap: () {
                Navigator.pop(context);
                onActionSelected(
                  AutomationAction(type: type, parameters: {}),
                );
              },
            );
          }).toList(),
        ),
      ),
    );
  }
}
