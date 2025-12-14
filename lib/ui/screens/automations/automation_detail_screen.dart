import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/services/automation_service.dart';
import '../../../core/services/automation_engine.dart';
import '../../../core/models/automation_model.dart';
import '../../../core/localization/app_localizations.dart';

class AutomationDetailScreen extends StatelessWidget {
  final String automationId;

  const AutomationDetailScreen({
    super.key,
    required this.automationId,
  });

  @override
  Widget build(BuildContext context) {
    final automationService = context.watch<AutomationService>();
    final automationEngine = context.read<AutomationEngine>();
    final automation = automationService.getAutomation(automationId);
    final loc = AppLocalizations.of(context);

    if (automation == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Automation')),
        body: const Center(child: Text('Automation not found')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(automation.name),
        actions: [
          // Manual trigger button
          IconButton(
            icon: const Icon(Icons.play_arrow),
            onPressed: () async {
              await automationEngine.triggerManually(automationId);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Triggered: ${automation.name}'),
                    backgroundColor: Colors.green,
                  ),
                );
              }
            },
            tooltip: 'Trigger Manually',
          ),
          // Delete button
          IconButton(
            icon: const Icon(Icons.delete),
            onPressed: () => _confirmDelete(context, automationService),
            tooltip: 'Delete',
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Status card
            _buildStatusCard(context, automation),
            const SizedBox(height: 16),
            // Description
            _buildSection(
              context,
              'Description',
              Icons.description,
              [Text(automation.description)],
            ),
            const SizedBox(height: 16),
            // Triggers
            _buildSection(
              context,
              'Triggers',
              Icons.flash_on,
              automation.triggers
                  .map((t) => _buildTriggerTile(context, t))
                  .toList(),
            ),
            const SizedBox(height: 16),
            // Conditions
            if (automation.conditions.isNotEmpty)
              _buildSection(
                context,
                'Conditions',
                Icons.filter_list,
                automation.conditions
                    .map((c) => _buildConditionTile(context, c))
                    .toList(),
              ),
            if (automation.conditions.isNotEmpty) const SizedBox(height: 16),
            // Actions
            _buildSection(
              context,
              'Actions',
              Icons.play_arrow,
              automation.actions
                  .map((a) => _buildActionTile(context, a))
                  .toList(),
            ),
            const SizedBox(height: 16),
            // Execution logs
            _buildExecutionLogs(context, automationService),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusCard(BuildContext context, Automation automation) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStatItem(
                  context,
                  Icons.check_circle,
                  'Status',
                  automation.isEnabled ? 'Enabled' : 'Disabled',
                  automation.isEnabled ? Colors.green : Colors.grey,
                ),
                _buildStatItem(
                  context,
                  Icons.repeat,
                  'Executions',
                  '${automation.executionCount}',
                  Colors.blue,
                ),
              ],
            ),
            if (automation.lastTriggered != null) ...[
              const Divider(height: 32),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.access_time, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'Last triggered: ${_formatDateTime(automation.lastTriggered!)}',
                    style: const TextStyle(fontSize: 14),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(
    BuildContext context,
    IconData icon,
    String label,
    String value,
    Color color,
  ) {
    return Column(
      children: [
        Icon(icon, color: color, size: 32),
        const SizedBox(height: 8),
        Text(
          value,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }

  Widget _buildSection(
    BuildContext context,
    String title,
    IconData icon,
    List<Widget> children,
  ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 20),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const Divider(height: 24),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _buildTriggerTile(BuildContext context, AutomationTrigger trigger) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.blue.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.blue.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _getTriggerTypeName(trigger.type),
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.blue,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _formatTriggerParameters(trigger),
            style: TextStyle(fontSize: 12, color: Colors.grey[700]),
          ),
        ],
      ),
    );
  }

  Widget _buildConditionTile(
      BuildContext context, AutomationCondition condition) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.orange.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.orange.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _getConditionTypeName(condition.type),
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.orange,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _formatConditionParameters(condition),
            style: TextStyle(fontSize: 12, color: Colors.grey[700]),
          ),
        ],
      ),
    );
  }

  Widget _buildActionTile(BuildContext context, AutomationAction action) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.green.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.green.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _getActionTypeName(action.type),
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.green,
            ),
          ),
          if (action.deviceId != null) ...[
            const SizedBox(height: 4),
            Text(
              'Device: ${action.deviceId}',
              style: TextStyle(fontSize: 12, color: Colors.grey[700]),
            ),
          ],
          if (action.parameters.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              _formatActionParameters(action),
              style: TextStyle(fontSize: 12, color: Colors.grey[700]),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildExecutionLogs(BuildContext context, AutomationService service) {
    final logs = service.getLogsForAutomation(automationId);

    if (logs.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              const Icon(Icons.history),
              const SizedBox(width: 8),
              const Text(
                'Execution History',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              Text(
                'No executions yet',
                style: TextStyle(color: Colors.grey[600]),
              ),
            ],
          ),
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.history),
                SizedBox(width: 8),
                Text(
                  'Execution History',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const Divider(height: 24),
            ...logs.take(5).map((log) => _buildLogTile(context, log)),
          ],
        ),
      ),
    );
  }

  Widget _buildLogTile(BuildContext context, AutomationExecutionLog log) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: log.success
            ? Colors.green.withOpacity(0.1)
            : Colors.red.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(
            log.success ? Icons.check_circle : Icons.error,
            color: log.success ? Colors.green : Colors.red,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _formatDateTime(log.executedAt),
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (!log.success && log.errorMessage != null)
                  Text(
                    log.errorMessage!,
                    style: const TextStyle(fontSize: 11, color: Colors.red),
                  ),
              ],
            ),
          ),
          Text(
            '${log.actionsExecuted.length} actions',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  String _getTriggerTypeName(TriggerType type) {
    return type.name.replaceAll('_', ' ').toUpperCase();
  }

  String _getConditionTypeName(ConditionType type) {
    return type.name.replaceAll('_', ' ').toUpperCase();
  }

  String _getActionTypeName(ActionType type) {
    return type.name.replaceAll('_', ' ').toUpperCase();
  }

  String _formatTriggerParameters(AutomationTrigger trigger) {
    final params = trigger.parameters;
    if (params.isEmpty) return 'No parameters';

    return params.entries.map((e) => '${e.key}: ${e.value}').join(', ');
  }

  String _formatConditionParameters(AutomationCondition condition) {
    final params = condition.parameters;
    if (params.isEmpty) return 'No parameters';

    return params.entries.map((e) => '${e.key}: ${e.value}').join(', ');
  }

  String _formatActionParameters(AutomationAction action) {
    final params = action.parameters;
    if (params.isEmpty) return 'No parameters';

    return params.entries.map((e) => '${e.key}: ${e.value}').join(', ');
  }

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.year}-${dateTime.month.toString().padLeft(2, '0')}-${dateTime.day.toString().padLeft(2, '0')} '
        '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  }

  Future<void> _confirmDelete(
      BuildContext context, AutomationService service) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Automation'),
        content: const Text(
          'Are you sure you want to delete this automation? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      await service.deleteAutomation(automationId);
      if (context.mounted) {
        Navigator.pop(context);
      }
    }
  }
}
