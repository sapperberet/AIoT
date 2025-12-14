import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/services/automation_service.dart';
import '../../../core/services/automation_engine.dart';
import '../../../core/models/automation_model.dart';
import '../../../core/localization/app_localizations.dart';
import 'automation_detail_screen.dart';
import 'automation_create_screen.dart';

class AutomationManagementScreen extends StatelessWidget {
  const AutomationManagementScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final automationService = context.watch<AutomationService>();
    final automationEngine = context.read<AutomationEngine>();
    final loc = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(loc.translate('automations')),
        actions: [
          // Engine status indicator
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: Center(
              child: Row(
                children: [
                  Icon(
                    automationEngine.isRunning
                        ? Icons.play_circle
                        : Icons.pause_circle,
                    color: automationEngine.isRunning
                        ? Colors.green
                        : Colors.orange,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    automationEngine.isRunning ? 'Active' : 'Paused',
                    style: TextStyle(
                      fontSize: 14,
                      color: automationEngine.isRunning
                          ? Colors.green
                          : Colors.orange,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      body: automationService.isInitialized
          ? _buildAutomationsList(context, automationService, loc)
          : const Center(child: CircularProgressIndicator()),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const AutomationCreateScreen(),
            ),
          );
        },
        icon: const Icon(Icons.add),
        label: Text(loc.translate('create_automation')),
      ),
    );
  }

  Widget _buildAutomationsList(
    BuildContext context,
    AutomationService service,
    AppLocalizations loc,
  ) {
    final automations = service.automations;

    if (automations.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.smart_toy_outlined,
              size: 80,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              loc.translate('no_automations'),
              style: TextStyle(
                fontSize: 18,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              loc.translate('create_first_automation'),
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[500],
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: automations.length,
      itemBuilder: (context, index) {
        final automation = automations[index];
        return _buildAutomationCard(context, automation, service, loc);
      },
    );
  }

  Widget _buildAutomationCard(
    BuildContext context,
    Automation automation,
    AutomationService service,
    AppLocalizations loc,
  ) {
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => AutomationDetailScreen(
                automationId: automation.id,
              ),
            ),
          );
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  // Status indicator
                  Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: automation.isEnabled ? Colors.green : Colors.grey,
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Automation name
                  Expanded(
                    child: Text(
                      automation.name,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  // Toggle switch
                  Switch(
                    value: automation.isEnabled,
                    onChanged: (value) {
                      service.toggleAutomation(automation.id, value);
                    },
                  ),
                ],
              ),
              const SizedBox(height: 8),
              // Description
              Text(
                automation.description,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 12),
              // Triggers
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _buildChip(
                    context,
                    Icons.flash_on,
                    '${automation.triggers.length} trigger(s)',
                    Colors.blue,
                  ),
                  if (automation.conditions.isNotEmpty)
                    _buildChip(
                      context,
                      Icons.filter_list,
                      '${automation.conditions.length} condition(s)',
                      Colors.orange,
                    ),
                  _buildChip(
                    context,
                    Icons.play_arrow,
                    '${automation.actions.length} action(s)',
                    Colors.green,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Execution stats
              Row(
                children: [
                  Icon(Icons.history, size: 16, color: Colors.grey[600]),
                  const SizedBox(width: 4),
                  Text(
                    'Executed ${automation.executionCount} times',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                  if (automation.lastTriggered != null) ...[
                    const SizedBox(width: 16),
                    Icon(Icons.access_time, size: 16, color: Colors.grey[600]),
                    const SizedBox(width: 4),
                    Text(
                      _formatLastTriggered(automation.lastTriggered!),
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildChip(
      BuildContext context, IconData icon, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: color,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  String _formatLastTriggered(DateTime dateTime) {
    final now = DateTime.now();
    final diff = now.difference(dateTime);

    if (diff.inMinutes < 1) {
      return 'Just now';
    } else if (diff.inMinutes < 60) {
      return '${diff.inMinutes}m ago';
    } else if (diff.inHours < 24) {
      return '${diff.inHours}h ago';
    } else {
      return '${diff.inDays}d ago';
    }
  }
}
