import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:iconsax/iconsax.dart';
import 'package:animate_do/animate_do.dart';
import 'package:intl/intl.dart';
import '../../../core/providers/automation_provider.dart';
import '../../../core/models/automation_model.dart';
import '../../../core/theme/app_theme.dart';

class AutomationsScreen extends StatefulWidget {
  const AutomationsScreen({super.key});

  @override
  State<AutomationsScreen> createState() => _AutomationsScreenState();
}

class _AutomationsScreenState extends State<AutomationsScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.darkBackground,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: FadeInLeft(
          child: IconButton(
            icon: const Icon(Iconsax.arrow_left, color: AppTheme.lightText),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        title: FadeInDown(
          child: ShaderMask(
            shaderCallback: (bounds) => AppTheme.primaryGradient.createShader(bounds),
            child: const Text(
              'Automations',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
        ),
      ),
      body: FadeIn(
        child: Consumer<AutomationProvider>(
          builder: (context, automationProvider, child) {
            final automations = automationProvider.automations;

            if (automations.isEmpty) {
              return _buildEmptyState();
            }

            return ListView.builder(
              padding: const EdgeInsets.all(20),
              itemCount: automations.length,
              itemBuilder: (context, index) {
                final automation = automations[index];
                return FadeInUp(
                  delay: Duration(milliseconds: 50 * index),
                  child: _buildAutomationCard(context, automation),
                );
              },
            );
          },
        ),
      ),
      floatingActionButton: FadeInUp(
        delay: const Duration(milliseconds: 300),
        child: FloatingActionButton.extended(
          onPressed: () => _showCreateAutomationDialog(context),
          backgroundColor: AppTheme.primaryColor,
          icon: const Icon(Iconsax.add),
          label: const Text('New Automation'),
        ),
      ),
    );
  }

  Widget _buildAutomationCard(BuildContext context, Automation automation) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: AppTheme.cardGradient,
        borderRadius: AppTheme.largeRadius,
        border: Border.all(
          color: automation.isEnabled
              ? AppTheme.primaryColor.withOpacity(0.3)
              : AppTheme.lightText.withOpacity(0.1),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  gradient: automation.isEnabled
                      ? AppTheme.primaryGradient
                      : LinearGradient(
                          colors: [
                            AppTheme.lightText.withOpacity(0.3),
                            AppTheme.lightText.withOpacity(0.1),
                          ],
                        ),
                  borderRadius: AppTheme.smallRadius,
                ),
                child: Icon(
                  Iconsax.timer,
                  size: 24,
                  color: automation.isEnabled ? Colors.white : AppTheme.lightText.withOpacity(0.5),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      automation.name,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.lightText,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      automation.description,
                      style: TextStyle(
                        fontSize: 14,
                        color: AppTheme.lightText.withOpacity(0.6),
                      ),
                    ),
                  ],
                ),
              ),
              Switch(
                value: automation.isEnabled,
                onChanged: (value) {
                  context.read<AutomationProvider>().toggleAutomation(automation.id);
                },
                activeColor: AppTheme.primaryColor,
              ),
            ],
          ),

          const SizedBox(height: 16),
          const Divider(color: AppTheme.lightText, height: 1),
          const SizedBox(height: 16),

          // Triggers
          _buildInfoSection(
            'Triggers',
            Iconsax.flash_1,
            automation.triggers.map((t) => _getTriggerDescription(t)).toList(),
          ),

          if (automation.conditions.isNotEmpty) ...[
            const SizedBox(height: 12),
            _buildInfoSection(
              'Conditions',
              Iconsax.setting_2,
              automation.conditions.map((c) => _getConditionDescription(c)).toList(),
            ),
          ],

          const SizedBox(height: 12),
          _buildInfoSection(
            'Actions',
            Iconsax.command,
            automation.actions.map((a) => _getActionDescription(a)).toList(),
          ),

          if (automation.lastTriggered != null) ...[
            const SizedBox(height: 16),
            Row(
              children: [
                Icon(
                  Iconsax.clock,
                  size: 14,
                  color: AppTheme.lightText.withOpacity(0.5),
                ),
                const SizedBox(width: 6),
                Text(
                  'Last triggered: ${DateFormat('MMM d, HH:mm').format(automation.lastTriggered!)}',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppTheme.lightText.withOpacity(0.5),
                  ),
                ),
              ],
            ),
          ],

          const SizedBox(height: 16),

          // Actions
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _showEditAutomationDialog(context, automation),
                  icon: const Icon(Iconsax.edit, size: 18),
                  label: const Text('Edit'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.primaryColor,
                    side: const BorderSide(color: AppTheme.primaryColor),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: AppTheme.mediumRadius,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _runAutomation(context, automation),
                  icon: const Icon(Iconsax.play, size: 18),
                  label: const Text('Run Now'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: AppTheme.mediumRadius,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              IconButton(
                onPressed: () => _deleteAutomation(context, automation),
                icon: const Icon(Iconsax.trash),
                color: AppTheme.errorColor,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInfoSection(String title, IconData icon, List<String> items) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              icon,
              size: 16,
              color: AppTheme.primaryColor,
            ),
            const SizedBox(width: 8),
            Text(
              title,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppTheme.lightText,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ...items.map((item) => Padding(
              padding: const EdgeInsets.only(left: 24, bottom: 4),
              child: Row(
                children: [
                  Container(
                    width: 4,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppTheme.lightText.withOpacity(0.5),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      item,
                      style: TextStyle(
                        fontSize: 13,
                        color: AppTheme.lightText.withOpacity(0.7),
                      ),
                    ),
                  ),
                ],
              ),
            )),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: FadeIn(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                gradient: AppTheme.primaryGradient.scale(0.3),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Iconsax.timer,
                size: 80,
                color: AppTheme.primaryColor,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'No automations',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppTheme.lightText,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Create your first automation to get started',
              style: TextStyle(
                fontSize: 14,
                color: AppTheme.lightText.withOpacity(0.6),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getTriggerDescription(AutomationTrigger trigger) {
    switch (trigger.type) {
      case TriggerType.time:
        return 'At ${trigger.parameters['time']}';
      case TriggerType.deviceState:
        return 'When device changes state';
      case TriggerType.temperature:
        return 'When temperature is ${trigger.parameters['temperature']}°C';
      case TriggerType.sunrise:
        return 'At sunrise';
      case TriggerType.sunset:
        return 'At sunset';
    }
  }

  String _getConditionDescription(AutomationCondition condition) {
    switch (condition.type) {
      case ConditionType.time:
        return 'Between ${condition.parameters['after']} and ${condition.parameters['before']}';
      case ConditionType.deviceState:
        return 'If device is ${condition.parameters['state']}';
      case ConditionType.temperature:
        return 'If temperature is ${condition.parameters['temperature']}°C';
      case ConditionType.day:
        return 'On ${condition.parameters['days'].join(', ')}';
    }
  }

  String _getActionDescription(AutomationAction action) {
    switch (action.type) {
      case ActionType.turnOn:
        return 'Turn on ${action.deviceId}';
      case ActionType.turnOff:
        return 'Turn off ${action.deviceId}';
      case ActionType.setBrightness:
        return 'Set brightness to ${action.parameters['brightness']}%';
      case ActionType.setTemperature:
        return 'Set temperature to ${action.parameters['temperature']}°C';
      case ActionType.sendNotification:
        return 'Send notification: ${action.parameters['message']}';
    }
  }

  void _showCreateAutomationDialog(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Automation creation coming soon!'),
        backgroundColor: AppTheme.darkCard,
      ),
    );
  }

  void _showEditAutomationDialog(BuildContext context, Automation automation) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Edit automation: ${automation.name}'),
        backgroundColor: AppTheme.darkCard,
      ),
    );
  }

  void _runAutomation(BuildContext context, Automation automation) {
    context.read<AutomationProvider>().executeAutomation(automation.id);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Running automation: ${automation.name}'),
        backgroundColor: AppTheme.successColor,
      ),
    );
  }

  void _deleteAutomation(BuildContext context, Automation automation) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.darkCard,
        title: const Text('Delete Automation', style: TextStyle(color: AppTheme.errorColor)),
        content: Text(
          'Are you sure you want to delete "${automation.name}"?',
          style: const TextStyle(color: AppTheme.lightText),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              context.read<AutomationProvider>().deleteAutomation(automation.id);
              Navigator.pop(context);
            },
            child: const Text('Delete', style: TextStyle(color: AppTheme.errorColor)),
          ),
        ],
      ),
    );
  }
}
