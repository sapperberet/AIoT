import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:iconsax/iconsax.dart';
import 'package:animate_do/animate_do.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/providers/scenario_provider.dart';
import '../../../core/models/scenario_model.dart';
import '../../../core/theme/app_theme.dart';
import '../../widgets/floating_chat_button.dart';
import 'scenario_create_screen.dart';

class ScenariosScreen extends StatefulWidget {
  const ScenariosScreen({super.key});

  @override
  State<ScenariosScreen> createState() => _ScenariosScreenState();
}

class _ScenariosScreenState extends State<ScenariosScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ScenarioProvider>().loadScenarios();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textColor = theme.colorScheme.onBackground;
    final loc = AppLocalizations.of(context);

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
              loc.t('scenarios'),
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
        ),
        actions: [
          FadeInRight(
            child: IconButton(
              icon: Icon(Iconsax.refresh, color: textColor),
              onPressed: () => context.read<ScenarioProvider>().loadScenarios(),
            ),
          ),
        ],
      ),
      body: Stack(
        children: [
          Consumer<ScenarioProvider>(
            builder: (context, provider, child) {
              if (provider.isLoading && provider.scenarios.isEmpty) {
                return const Center(child: CircularProgressIndicator());
              }

              if (provider.error != null && provider.scenarios.isEmpty) {
                return _buildErrorState(provider.error!);
              }

              if (provider.scenarios.isEmpty) {
                return _buildEmptyState();
              }

              return RefreshIndicator(
                onRefresh: () => provider.loadScenarios(),
                child: ListView.builder(
                  padding: const EdgeInsets.fromLTRB(20, 10, 20, 100),
                  itemCount: provider.scenarios.length,
                  itemBuilder: (context, index) {
                    final scenario = provider.scenarios[index];
                    return FadeInUp(
                      delay: Duration(milliseconds: 50 * index),
                      child: _buildScenarioCard(context, scenario),
                    );
                  },
                ),
              );
            },
          ),
          const FloatingChatButton(),
        ],
      ),
      floatingActionButton: FadeInUp(
        delay: const Duration(milliseconds: 300),
        child: FloatingActionButton.extended(
          onPressed: () => _openCreate(context),
          backgroundColor: AppTheme.primaryColor,
          icon: const Icon(Iconsax.add),
          label: Text(loc.t('create_scenario')),
        ),
      ),
    );
  }

  // ── Card ──────────────────────────────────────────────────

  Widget _buildScenarioCard(BuildContext context, Scenario scenario) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final textColor = theme.colorScheme.onBackground;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: isDark
            ? AppTheme.cardGradient
            : LinearGradient(colors: [
                AppTheme.lightSurface,
                AppTheme.lightSurface.withOpacity(0.8),
              ]),
        borderRadius: AppTheme.largeRadius,
        border: Border.all(
          color: scenario.isActive
              ? AppTheme.primaryColor.withOpacity(0.3)
              : textColor.withOpacity(0.1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header ───────────────────────────────────────
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  gradient: scenario.isActive
                      ? AppTheme.primaryGradient
                      : LinearGradient(colors: [
                          textColor.withOpacity(0.3),
                          textColor.withOpacity(0.1),
                        ]),
                  borderRadius: AppTheme.smallRadius,
                ),
                child: Icon(
                  _triggerIcon(scenario.trigger),
                  size: 24,
                  color: scenario.isActive
                      ? Colors.white
                      : textColor.withOpacity(0.5),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            scenario.name,
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: textColor,
                            ),
                          ),
                        ),
                        _statusChip(scenario.isActive, textColor),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      scenario.trigger.description,
                      style: TextStyle(
                        fontSize: 13,
                        color: textColor.withOpacity(0.6),
                      ),
                    ),
                  ],
                ),
              ),
              if (scenario.id != null)
                Switch(
                  value: scenario.isActive,
                  onChanged: (val) => _toggle(context, scenario, val),
                  activeColor: AppTheme.primaryColor,
                ),
            ],
          ),
          const SizedBox(height: 16),
          Divider(color: textColor.withOpacity(0.1), height: 1),
          const SizedBox(height: 12),

          // ── Trigger ──────────────────────────────────────
          _infoRow(
            Iconsax.flash_1,
            'Trigger',
            scenario.trigger.description,
            textColor,
          ),
          const SizedBox(height: 8),

          // ── Actions list ─────────────────────────────────
          _infoRow(
            Iconsax.command,
            'Actions (${scenario.actions.length})',
            scenario.actions.map((a) => a.description).join(' → '),
            textColor,
          ),

          const SizedBox(height: 16),

          // ── Buttons ──────────────────────────────────────
          Row(
            children: [
              Expanded(
                child: _outlinedButton(
                  icon: Iconsax.edit,
                  label: 'Edit',
                  color: AppTheme.primaryColor,
                  onTap: () => _openEdit(context, scenario),
                ),
              ),
              const SizedBox(width: 8),
              _iconButton(
                icon: Iconsax.document_code,
                color: AppTheme.accentColor,
                onTap: () => _showJson(context, scenario),
              ),
              const SizedBox(width: 8),
              _iconButton(
                icon: Iconsax.trash,
                color: AppTheme.errorColor,
                onTap: () => _confirmDelete(context, scenario),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Helpers ───────────────────────────────────────────────

  Widget _statusChip(bool active, Color textColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: active
            ? AppTheme.successColor.withOpacity(0.15)
            : textColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color:
                  active ? AppTheme.successColor : textColor.withOpacity(0.4),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            active ? 'Active' : 'Inactive',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color:
                  active ? AppTheme.successColor : textColor.withOpacity(0.6),
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value, Color textColor) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: AppTheme.primaryColor),
        const SizedBox(width: 8),
        Text(
          '$label: ',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: textColor.withOpacity(0.7),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              fontSize: 12,
              color: textColor.withOpacity(0.5),
            ),
          ),
        ),
      ],
    );
  }

  Widget _outlinedButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: AppTheme.mediumRadius,
        border: Border.all(color: color.withOpacity(0.5), width: 1.5),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: AppTheme.mediumRadius,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 18, color: color),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: color,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _iconButton({
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: AppTheme.smallRadius,
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: IconButton(
        onPressed: onTap,
        icon: Icon(icon),
        color: color,
        iconSize: 20,
      ),
    );
  }

  IconData _triggerIcon(ScenarioTrigger trigger) {
    if (trigger.type == ScenarioTriggerType.sensor) {
      switch (trigger.sensor) {
        case 'temp':
          return Iconsax.sun_1;
        case 'humidity':
          return Iconsax.drop;
        case 'gas':
          return Iconsax.cloud;
        case 'flame':
          return Iconsax.danger;
        case 'rain':
          return Iconsax.cloud_drizzle;
        case 'ldr':
          return Iconsax.lamp_on;
        case 'voltage':
        case 'current':
          return Iconsax.flash_1;
        default:
          return Iconsax.activity;
      }
    }
    return Iconsax.clock;
  }

  // ── Empty / error states ──────────────────────────────────

  Widget _buildEmptyState() {
    final theme = Theme.of(context);
    final textColor = theme.colorScheme.onBackground;
    return Center(
      child: FadeIn(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Iconsax.cpu_setting,
                size: 80, color: textColor.withOpacity(0.2)),
            const SizedBox(height: 20),
            Text(
              'No scenarios yet',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: textColor,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Create your first n8n scenario\nto automate your smart home.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: textColor.withOpacity(0.5),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState(String error) {
    final theme = Theme.of(context);
    final textColor = theme.colorScheme.onBackground;
    return Center(
      child: FadeIn(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Iconsax.warning_2, size: 60, color: AppTheme.errorColor),
            const SizedBox(height: 16),
            Text(
              'Could not load scenarios',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: textColor,
              ),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: Text(
                error,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  color: textColor.withOpacity(0.5),
                ),
                maxLines: 4,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: () => context.read<ScenarioProvider>().loadScenarios(),
              icon: const Icon(Iconsax.refresh),
              label: const Text('Retry'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Actions ───────────────────────────────────────────────

  void _openCreate(BuildContext context) async {
    final created = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const ScenarioCreateScreen()),
    );
    if (created == true && mounted) {
      context.read<ScenarioProvider>().loadScenarios();
    }
  }

  void _openEdit(BuildContext context, Scenario scenario) async {
    final updated = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => ScenarioCreateScreen(editScenario: scenario),
      ),
    );
    if (updated == true && mounted) {
      context.read<ScenarioProvider>().loadScenarios();
    }
  }

  void _toggle(BuildContext context, Scenario scenario, bool active) {
    if (scenario.id == null) return;
    context.read<ScenarioProvider>().toggleScenario(scenario.id!, active);
  }

  void _confirmDelete(BuildContext context, Scenario scenario) {
    if (scenario.id == null) return;
    final theme = Theme.of(context);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: theme.cardColor,
        title: const Text('Delete Scenario'),
        content: Text('Delete "${scenario.name}"? This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              context.read<ScenarioProvider>().deleteScenario(scenario.id!);
            },
            child: Text('Delete', style: TextStyle(color: AppTheme.errorColor)),
          ),
        ],
      ),
    );
  }

  void _showJson(BuildContext context, Scenario scenario) {
    final pretty =
        const JsonEncoder.withIndent('  ').convert(scenario.toJson());
    final theme = Theme.of(context);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: theme.cardColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.5,
        maxChildSize: 0.9,
        builder: (_, controller) => Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Iconsax.document_code,
                      color: AppTheme.accentColor),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Scenario JSON',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Iconsax.copy),
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: pretty));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Copied to clipboard')),
                      );
                    },
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Expanded(
                child: SingleChildScrollView(
                  controller: controller,
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: theme.scaffoldBackgroundColor,
                      borderRadius: AppTheme.mediumRadius,
                    ),
                    child: SelectableText(
                      pretty,
                      style: TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 13,
                        color: theme.colorScheme.onBackground.withOpacity(0.8),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
