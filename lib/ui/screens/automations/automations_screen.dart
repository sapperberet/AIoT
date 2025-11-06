import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:iconsax/iconsax.dart';
import 'package:animate_do/animate_do.dart';
import 'package:intl/intl.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/providers/automation_provider.dart';
import '../../../core/models/automation_model.dart';
import '../../../core/theme/app_theme.dart';
import '../../widgets/floating_chat_button.dart';

class AutomationsScreen extends StatefulWidget {
  const AutomationsScreen({super.key});

  @override
  State<AutomationsScreen> createState() => _AutomationsScreenState();
}

class _AutomationsScreenState extends State<AutomationsScreen> {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final textColor = theme.colorScheme.onBackground;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: FadeInLeft(
          child: IconButton(
            icon: Icon(Iconsax.arrow_left, color: textColor),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        title: FadeInDown(
          child: ShaderMask(
            shaderCallback: (bounds) =>
                AppTheme.primaryGradient.createShader(bounds),
            child: Text(
              AppLocalizations.of(context).t('automations'),
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
        ),
      ),
      body: Stack(
        children: [
          FadeIn(
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
          // Floating chat button
          const FloatingChatButton(),
        ],
      ),
      floatingActionButton: FadeInUp(
        delay: const Duration(milliseconds: 300),
        child: FloatingActionButton.extended(
          onPressed: () => _showCreateAutomationDialog(context),
          backgroundColor: AppTheme.primaryColor,
          icon: const Icon(Iconsax.add),
          label: Text(AppLocalizations.of(context).t('create_automation')),
        ),
      ),
    );
  }

  Widget _buildAutomationCard(BuildContext context, Automation automation) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final textColor = theme.colorScheme.onBackground;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: isDark
            ? AppTheme.cardGradient
            : LinearGradient(
                colors: [
                  AppTheme.lightSurface,
                  AppTheme.lightSurface.withOpacity(0.8),
                ],
              ),
        borderRadius: AppTheme.largeRadius,
        border: Border.all(
          color: automation.isEnabled
              ? AppTheme.primaryColor.withOpacity(0.3)
              : textColor.withOpacity(0.1),
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
                            textColor.withOpacity(0.3),
                            textColor.withOpacity(0.1),
                          ],
                        ),
                  borderRadius: AppTheme.smallRadius,
                ),
                child: Icon(
                  Iconsax.timer,
                  size: 24,
                  color: automation.isEnabled
                      ? Colors.white
                      : textColor.withOpacity(0.5),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      automation.name,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: textColor,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      automation.description,
                      style: TextStyle(
                        fontSize: 14,
                        color: textColor.withOpacity(0.6),
                      ),
                    ),
                  ],
                ),
              ),
              Switch(
                value: automation.isEnabled,
                onChanged: (value) {
                  context
                      .read<AutomationProvider>()
                      .toggleAutomation(automation.id);
                },
                activeColor: AppTheme.primaryColor,
              ),
            ],
          ),

          const SizedBox(height: 16),
          Divider(color: textColor.withOpacity(0.1), height: 1),
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
              automation.conditions
                  .map((c) => _getConditionDescription(c))
                  .toList(),
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
                  color: textColor.withOpacity(0.5),
                ),
                const SizedBox(width: 6),
                Text(
                  'Last triggered: ${DateFormat('MMM d, HH:mm').format(automation.lastTriggered!)}',
                  style: TextStyle(
                    fontSize: 12,
                    color: textColor.withOpacity(0.5),
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
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: AppTheme.mediumRadius,
                    border: Border.all(
                      color: AppTheme.primaryColor.withOpacity(0.5),
                      width: 1.5,
                    ),
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () =>
                          _showEditAutomationDialog(context, automation),
                      borderRadius: AppTheme.mediumRadius,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Iconsax.edit,
                              size: 18,
                              color: AppTheme.primaryColor,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Edit',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.primaryColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: AppTheme.primaryGradient,
                    borderRadius: AppTheme.mediumRadius,
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.primaryColor.withOpacity(0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () => _runAutomation(context, automation),
                      borderRadius: AppTheme.mediumRadius,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: const [
                            Icon(
                              Iconsax.play_circle5,
                              size: 20,
                              color: Colors.white,
                            ),
                            SizedBox(width: 8),
                            Text(
                              'Run Now',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Container(
                decoration: BoxDecoration(
                  color: AppTheme.errorColor.withOpacity(0.1),
                  borderRadius: AppTheme.smallRadius,
                  border: Border.all(
                    color: AppTheme.errorColor.withOpacity(0.3),
                    width: 1,
                  ),
                ),
                child: IconButton(
                  onPressed: () => _deleteAutomation(context, automation),
                  icon: const Icon(Iconsax.trash),
                  color: AppTheme.errorColor,
                  iconSize: 20,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInfoSection(String title, IconData icon, List<String> items) {
    final theme = Theme.of(context);
    final textColor = theme.colorScheme.onBackground;

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
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: textColor,
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
                      color: textColor.withOpacity(0.5),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      item,
                      style: TextStyle(
                        fontSize: 13,
                        color: textColor.withOpacity(0.7),
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
    final theme = Theme.of(context);
    final textColor = theme.colorScheme.onBackground;

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
            Text(
              'No automations',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: textColor,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Create your first automation to get started',
              style: TextStyle(
                fontSize: 14,
                color: textColor.withOpacity(0.6),
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
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Automation creation coming soon!'),
        backgroundColor: isDark ? AppTheme.darkCard : AppTheme.lightSurface,
      ),
    );
  }

  void _showEditAutomationDialog(BuildContext context, Automation automation) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Edit automation: ${automation.name}'),
        backgroundColor: isDark ? AppTheme.darkCard : AppTheme.lightSurface,
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
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final textColor = theme.colorScheme.onBackground;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDark ? AppTheme.darkCard : AppTheme.lightSurface,
        title: const Text('Delete Automation',
            style: TextStyle(color: AppTheme.errorColor)),
        content: Text(
          'Are you sure you want to delete "${automation.name}"?',
          style: TextStyle(color: textColor),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: TextStyle(color: textColor)),
          ),
          TextButton(
            onPressed: () {
              context
                  .read<AutomationProvider>()
                  .deleteAutomation(automation.id);
              Navigator.pop(context);
            },
            child: const Text('Delete',
                style: TextStyle(color: AppTheme.errorColor)),
          ),
        ],
      ),
    );
  }
}
