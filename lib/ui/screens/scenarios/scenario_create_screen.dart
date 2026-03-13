import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:iconsax/iconsax.dart';
import 'package:animate_do/animate_do.dart';
import '../../../core/models/scenario_model.dart';
import '../../../core/providers/scenario_provider.dart';
import '../../../core/theme/app_theme.dart';

/// Shared create / edit form for an n8n scenario.
class ScenarioCreateScreen extends StatefulWidget {
  final Scenario? editScenario;
  const ScenarioCreateScreen({super.key, this.editScenario});

  @override
  State<ScenarioCreateScreen> createState() => _ScenarioCreateScreenState();
}

class _ScenarioCreateScreenState extends State<ScenarioCreateScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  bool _saving = false;

  // ── Trigger state ─────────────────────────────────────────
  ScenarioTriggerType _triggerType = ScenarioTriggerType.sensor;

  // Sensor trigger
  String _sensor = 'gas';
  String _condition = 'greater_than';
  final _valueCtrl = TextEditingController(text: '400');

  // Schedule trigger - mode
  ScheduleMode _scheduleMode = ScheduleMode.daily;
  // interval
  final _everyCtrl = TextEditingController(text: '15');
  String _intervalUnit = 'minutes';
  // daily / weekly / monthly
  final _atCtrl = TextEditingController(text: '07:00');
  List<String> _selectedDays = ['mon', 'tue', 'wed', 'thu', 'fri'];
  final _dayOfMonthCtrl = TextEditingController(text: '1');
  // cron
  final _cronCtrl = TextEditingController(text: '0 0 7 * * 1-5');

  // ── Actions state ─────────────────────────────────────────
  final List<ScenarioAction> _actions = [];

  // ── Editing an existing scenario ──────────────────────────
  @override
  void initState() {
    super.initState();
    if (widget.editScenario != null) {
      _loadFromScenario(widget.editScenario!);
    }
  }

  void _loadFromScenario(Scenario s) {
    _nameCtrl.text = s.name;
    _triggerType = s.trigger.type;

    final t = s.trigger;
    if (t.type == ScenarioTriggerType.sensor) {
      _sensor = t.sensor ?? 'gas';
      _condition = t.condition ?? 'greater_than';
      _valueCtrl.text = '${t.value ?? 0}';
    } else {
      _scheduleMode = t.mode ?? ScheduleMode.daily;
      _everyCtrl.text = '${t.every ?? 15}';
      _intervalUnit = t.unit ?? 'minutes';
      _atCtrl.text = t.at ?? '07:00';
      _selectedDays = List<String>.from(t.days ?? ['mon']);
      _dayOfMonthCtrl.text = '${t.day ?? 1}';
      _cronCtrl.text = t.expression ?? '0 0 7 * * 1-5';
    }

    _actions.addAll(s.actions);
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _valueCtrl.dispose();
    _everyCtrl.dispose();
    _atCtrl.dispose();
    _dayOfMonthCtrl.dispose();
    _cronCtrl.dispose();
    super.dispose();
  }

  // ── Build ─────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textColor = theme.colorScheme.onBackground;
    final isEdit = widget.editScenario != null;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Iconsax.arrow_left, color: textColor),
          onPressed: () => Navigator.pop(context, false),
        ),
        title: ShaderMask(
          shaderCallback: (b) => AppTheme.primaryGradient.createShader(b),
          child: Text(
            isEdit ? 'Edit Scenario' : 'New Scenario',
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 120),
          children: [
            FadeInUp(child: _card(_buildNameField(textColor))),
            const SizedBox(height: 16),
            FadeInUp(
              delay: const Duration(milliseconds: 60),
              child: _card(_buildTriggerSection(textColor)),
            ),
            const SizedBox(height: 16),
            FadeInUp(
              delay: const Duration(milliseconds: 120),
              child: _card(_buildActionsSection(textColor)),
            ),
          ],
        ),
      ),
      bottomNavigationBar: _buildBottomBar(isEdit),
    );
  }

  // ── Section card wrapper ──────────────────────────────────

  Widget _card(Widget child) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: isDark
            ? AppTheme.cardGradient
            : LinearGradient(colors: [
                AppTheme.lightSurface,
                AppTheme.lightSurface.withOpacity(0.9),
              ]),
        borderRadius: AppTheme.largeRadius,
        border: Border.all(
          color: AppTheme.primaryColor.withOpacity(0.15),
        ),
      ),
      child: child,
    );
  }

  Widget _sectionTitle(String text, IconData icon) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            gradient: AppTheme.primaryGradient,
            borderRadius: AppTheme.smallRadius,
          ),
          child: Icon(icon, size: 18, color: Colors.white),
        ),
        const SizedBox(width: 12),
        Text(
          text,
          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  // ── Name ──────────────────────────────────────────────────

  Widget _buildNameField(Color textColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle('Name', Iconsax.text),
        const SizedBox(height: 16),
        TextFormField(
          controller: _nameCtrl,
          decoration: InputDecoration(
            hintText: 'e.g. Gas Leak Alert',
            prefixIcon: const Icon(Iconsax.edit),
            border: OutlineInputBorder(borderRadius: AppTheme.mediumRadius),
          ),
          validator: (v) =>
              (v == null || v.trim().isEmpty) ? 'Name is required' : null,
        ),
      ],
    );
  }

  // ── Trigger ───────────────────────────────────────────────

  Widget _buildTriggerSection(Color textColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle('Trigger', Iconsax.flash_1),
        const SizedBox(height: 16),

        // Type selector
        Row(
          children: [
            Expanded(
              child: _typeButton(
                label: 'Sensor',
                icon: Iconsax.activity,
                selected: _triggerType == ScenarioTriggerType.sensor,
                onTap: () =>
                    setState(() => _triggerType = ScenarioTriggerType.sensor),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _typeButton(
                label: 'Schedule',
                icon: Iconsax.clock,
                selected: _triggerType == ScenarioTriggerType.schedule,
                onTap: () =>
                    setState(() => _triggerType = ScenarioTriggerType.schedule),
              ),
            ),
          ],
        ),

        const SizedBox(height: 16),

        if (_triggerType == ScenarioTriggerType.sensor)
          _buildSensorTriggerFields(textColor)
        else
          _buildScheduleTriggerFields(textColor),
      ],
    );
  }

  Widget _typeButton({
    required String label,
    required IconData icon,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          gradient: selected ? AppTheme.primaryGradient : null,
          color: selected ? null : Colors.transparent,
          borderRadius: AppTheme.mediumRadius,
          border: Border.all(
            color: selected
                ? AppTheme.primaryColor
                : AppTheme.primaryColor.withOpacity(0.3),
            width: selected ? 2 : 1,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon,
                size: 18,
                color: selected ? Colors.white : AppTheme.primaryColor),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: selected ? Colors.white : AppTheme.primaryColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSensorTriggerFields(Color textColor) {
    return Column(
      children: [
        _dropdownRow(
          label: 'Sensor',
          value: _sensor,
          items: ScenarioRef.sensors.keys.toList(),
          labelMap: ScenarioRef.sensors,
          onChanged: (v) => setState(() => _sensor = v!),
        ),
        const SizedBox(height: 12),
        _dropdownRow(
          label: 'Condition',
          value: _condition,
          items: ScenarioRef.conditions.keys.toList(),
          labelMap: ScenarioRef.conditions,
          onChanged: (v) => setState(() => _condition = v!),
        ),
        if (_condition != 'changes') ...[
          const SizedBox(height: 12),
          TextFormField(
            controller: _valueCtrl,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: InputDecoration(
              labelText: 'Threshold Value',
              prefixIcon: const Icon(Iconsax.hashnode),
              border: OutlineInputBorder(borderRadius: AppTheme.mediumRadius),
            ),
            validator: (v) => (v == null || v.isEmpty) ? 'Enter a value' : null,
          ),
        ],
      ],
    );
  }

  Widget _buildScheduleTriggerFields(Color textColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Mode selector
        Text('Mode',
            style: TextStyle(
                fontWeight: FontWeight.w600,
                color: textColor.withOpacity(0.8))),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: ScheduleMode.values.map((m) {
            final label = m.name[0].toUpperCase() + m.name.substring(1);
            return ChoiceChip(
              label: Text(label),
              selected: _scheduleMode == m,
              onSelected: (_) => setState(() => _scheduleMode = m),
              selectedColor: AppTheme.primaryColor,
              labelStyle: TextStyle(
                color: _scheduleMode == m ? Colors.white : null,
              ),
            );
          }).toList(),
        ),

        const SizedBox(height: 16),

        // Mode-specific fields
        if (_scheduleMode == ScheduleMode.interval) ...[
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _everyCtrl,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: InputDecoration(
                    labelText: 'Every',
                    border:
                        OutlineInputBorder(borderRadius: AppTheme.mediumRadius),
                  ),
                  validator: (v) =>
                      (v == null || v.isEmpty) ? 'Required' : null,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _dropdownRow(
                  label: 'Unit',
                  value: _intervalUnit,
                  items: ['seconds', 'minutes', 'hours'],
                  onChanged: (v) => setState(() => _intervalUnit = v!),
                ),
              ),
            ],
          ),
        ],

        if (_scheduleMode == ScheduleMode.daily) ...[
          _timeField('Time (HH:MM)'),
        ],

        if (_scheduleMode == ScheduleMode.weekly) ...[
          _timeField('Time (HH:MM)'),
          const SizedBox(height: 12),
          Text('Days',
              style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: textColor.withOpacity(0.8))),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: ScenarioRef.weekDays.map((d) {
              final label = d[0].toUpperCase() + d.substring(1);
              final selected = _selectedDays.contains(d);
              return FilterChip(
                label: Text(label),
                selected: selected,
                onSelected: (v) {
                  setState(() {
                    if (v) {
                      _selectedDays.add(d);
                    } else {
                      _selectedDays.remove(d);
                    }
                  });
                },
                selectedColor: AppTheme.primaryColor,
                labelStyle: TextStyle(color: selected ? Colors.white : null),
              );
            }).toList(),
          ),
        ],

        if (_scheduleMode == ScheduleMode.monthly) ...[
          _timeField('Time (HH:MM)'),
          const SizedBox(height: 12),
          TextFormField(
            controller: _dayOfMonthCtrl,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: InputDecoration(
              labelText: 'Day of month (1-31)',
              border: OutlineInputBorder(borderRadius: AppTheme.mediumRadius),
            ),
            validator: (v) {
              final n = int.tryParse(v ?? '');
              if (n == null || n < 1 || n > 31) return '1-31';
              return null;
            },
          ),
        ],

        if (_scheduleMode == ScheduleMode.cron) ...[
          TextFormField(
            controller: _cronCtrl,
            decoration: InputDecoration(
              labelText: 'Cron expression (s m h dom mon dow)',
              hintText: '0 30 7 * * 1-5',
              border: OutlineInputBorder(borderRadius: AppTheme.mediumRadius),
            ),
            validator: (v) => (v == null || v.trim().isEmpty)
                ? 'Enter cron expression'
                : null,
          ),
        ],
      ],
    );
  }

  Widget _timeField(String label) {
    return TextFormField(
      controller: _atCtrl,
      decoration: InputDecoration(
        labelText: label,
        hintText: '07:00',
        prefixIcon: const Icon(Iconsax.clock),
        border: OutlineInputBorder(borderRadius: AppTheme.mediumRadius),
      ),
      validator: (v) {
        if (v == null || v.isEmpty) return 'Required';
        final parts = v.split(':');
        if (parts.length != 2) return 'Use HH:MM';
        final h = int.tryParse(parts[0]);
        final m = int.tryParse(parts[1]);
        if (h == null || m == null || h > 23 || m > 59) {
          return 'Invalid time';
        }
        return null;
      },
    );
  }

  // ── Actions ───────────────────────────────────────────────

  Widget _buildActionsSection(Color textColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: _sectionTitle('Actions', Iconsax.command)),
            TextButton.icon(
              onPressed: () => _addAction(textColor),
              icon: const Icon(Iconsax.add_circle, size: 18),
              label: const Text('Add'),
              style:
                  TextButton.styleFrom(foregroundColor: AppTheme.primaryColor),
            ),
          ],
        ),
        if (_actions.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Text(
              'No actions yet. Tap Add to insert a device action or delay.',
              style: TextStyle(color: textColor.withOpacity(0.5), fontSize: 13),
            ),
          ),
        ReorderableListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _actions.length,
          onReorder: (oldIndex, newIndex) {
            setState(() {
              if (newIndex > oldIndex) newIndex--;
              final item = _actions.removeAt(oldIndex);
              _actions.insert(newIndex, item);
            });
          },
          itemBuilder: (context, index) {
            final action = _actions[index];
            return _actionTile(action, index, textColor,
                key: ValueKey('action_$index'));
          },
        ),
      ],
    );
  }

  Widget _actionTile(ScenarioAction action, int index, Color textColor,
      {required Key key}) {
    return Container(
      key: key,
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.primaryColor.withOpacity(0.07),
        borderRadius: AppTheme.mediumRadius,
        border: Border.all(
          color: AppTheme.primaryColor.withOpacity(0.2),
        ),
      ),
      child: Row(
        children: [
          Icon(
            action.isDelay ? Iconsax.clock : Iconsax.cpu,
            size: 18,
            color: AppTheme.primaryColor,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              action.description,
              style: TextStyle(
                fontSize: 14,
                color: textColor,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Iconsax.edit, size: 18),
            onPressed: () => _editAction(index, textColor),
            color: AppTheme.accentColor,
            constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
          ),
          IconButton(
            icon: const Icon(Iconsax.trash, size: 18),
            onPressed: () => setState(() => _actions.removeAt(index)),
            color: AppTheme.errorColor,
            constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
          ),
          const Icon(Icons.drag_handle, size: 20, color: Colors.grey),
        ],
      ),
    );
  }

  // ── Add / edit action dialog ──────────────────────────────

  void _addAction(Color textColor) {
    _showActionDialog(null, textColor);
  }

  void _editAction(int index, Color textColor) {
    _showActionDialog(index, textColor);
  }

  void _showActionDialog(int? editIndex, Color textColor) {
    final isEdit = editIndex != null;
    final existing = isEdit ? _actions[editIndex] : null;

    bool isDelay = existing?.isDelay ?? false;

    // Device action state
    String device = existing?.device ?? 'door';
    String deviceAction = '';
    final actionCtrl = TextEditingController(text: existing?.action ?? '');

    // Delay state
    final delayCtrl = TextEditingController(text: '${existing?.delay ?? 10}');
    String delayUnit = existing?.unit ?? 'seconds';

    // Set a valid initial action for device
    if (!isDelay) {
      final validActions = ScenarioRef.deviceActions[device] ?? ['on', 'off'];
      deviceAction = existing?.action ?? validActions.first;
    }

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) {
          final theme = Theme.of(ctx);

          return AlertDialog(
            backgroundColor: theme.cardColor,
            title: Text(isEdit ? 'Edit Action' : 'Add Action'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Type toggle
                  Row(
                    children: [
                      Expanded(
                        child: _typeButton(
                          label: 'Device',
                          icon: Iconsax.cpu,
                          selected: !isDelay,
                          onTap: () => setLocal(() => isDelay = false),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _typeButton(
                          label: 'Delay',
                          icon: Iconsax.clock,
                          selected: isDelay,
                          onTap: () => setLocal(() => isDelay = true),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  if (!isDelay) ...[
                    // Device selector
                    DropdownButtonFormField<String>(
                      value: device,
                      decoration: InputDecoration(
                        labelText: 'Device',
                        border: OutlineInputBorder(
                            borderRadius: AppTheme.mediumRadius),
                      ),
                      items: ScenarioRef.devices.keys
                          .map((d) => DropdownMenuItem(
                                value: d,
                                child: Text(ScenarioRef.devices[d]!),
                              ))
                          .toList(),
                      onChanged: (v) {
                        setLocal(() {
                          device = v!;
                          final valid = ScenarioRef.deviceActions[device] ??
                              ['on', 'off'];
                          deviceAction = valid.first;
                          actionCtrl.text = deviceAction;
                        });
                      },
                    ),
                    const SizedBox(height: 12),

                    // Action — dropdown for simple devices, text for rgb
                    if (device == 'lights_rgb') ...[
                      TextFormField(
                        controller: actionCtrl,
                        decoration: InputDecoration(
                          labelText: 'Action',
                          hintText: 'b 75  or  c #FF0000',
                          helperText:
                              'b <0-100> for brightness, c #HEX for color',
                          border: OutlineInputBorder(
                              borderRadius: AppTheme.mediumRadius),
                        ),
                        onChanged: (v) => deviceAction = v,
                      ),
                    ] else ...[
                      DropdownButtonFormField<String>(
                        value:
                            (ScenarioRef.deviceActions[device] ?? ['on', 'off'])
                                    .contains(deviceAction)
                                ? deviceAction
                                : (ScenarioRef.deviceActions[device] ??
                                    ['on', 'off'])[0],
                        decoration: InputDecoration(
                          labelText: 'Action',
                          border: OutlineInputBorder(
                              borderRadius: AppTheme.mediumRadius),
                        ),
                        items:
                            (ScenarioRef.deviceActions[device] ?? ['on', 'off'])
                                .map((a) => DropdownMenuItem(
                                      value: a,
                                      child: Text(a),
                                    ))
                                .toList(),
                        onChanged: (v) => setLocal(() => deviceAction = v!),
                      ),
                    ],
                  ] else ...[
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: delayCtrl,
                            keyboardType: TextInputType.number,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly
                            ],
                            decoration: InputDecoration(
                              labelText: 'Delay',
                              border: OutlineInputBorder(
                                  borderRadius: AppTheme.mediumRadius),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value: delayUnit,
                            decoration: InputDecoration(
                              labelText: 'Unit',
                              border: OutlineInputBorder(
                                  borderRadius: AppTheme.mediumRadius),
                            ),
                            items: ['seconds', 'minutes']
                                .map((u) =>
                                    DropdownMenuItem(value: u, child: Text(u)))
                                .toList(),
                            onChanged: (v) => setLocal(() => delayUnit = v!),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () {
                  ScenarioAction action;

                  if (isDelay) {
                    final d = int.tryParse(delayCtrl.text) ?? 10;
                    action = ScenarioAction(
                        delay: d,
                        unit: delayUnit == 'seconds' ? null : delayUnit);
                  } else {
                    final act = device == 'lights_rgb'
                        ? actionCtrl.text.trim()
                        : deviceAction;
                    if (act.isEmpty) return;
                    action = ScenarioAction(device: device, action: act);
                  }

                  setState(() {
                    if (isEdit) {
                      _actions[editIndex!] = action;
                    } else {
                      _actions.add(action);
                    }
                  });
                  Navigator.pop(ctx);
                },
                style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor),
                child: Text(isEdit ? 'Update' : 'Add'),
              ),
            ],
          );
        },
      ),
    );
  }

  // ── Shared dropdown helper ────────────────────────────────

  Widget _dropdownRow({
    required String label,
    required String value,
    required List<String> items,
    Map<String, String>? labelMap,
    required ValueChanged<String?> onChanged,
  }) {
    return DropdownButtonFormField<String>(
      value: value,
      decoration: InputDecoration(
        labelText: label,
        border: OutlineInputBorder(borderRadius: AppTheme.mediumRadius),
      ),
      items: items
          .map((i) => DropdownMenuItem(
                value: i,
                child: Text(labelMap?[i] ?? i),
              ))
          .toList(),
      onChanged: onChanged,
    );
  }

  // ── Bottom save bar ───────────────────────────────────────

  Widget _buildBottomBar(bool isEdit) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        boxShadow: AppTheme.cardShadow,
      ),
      child: SafeArea(
        child: Consumer<ScenarioProvider>(
          builder: (context, provider, child) {
            return SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: _saving ? null : () => _save(isEdit),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  shape: RoundedRectangleBorder(
                      borderRadius: AppTheme.mediumRadius),
                  padding: EdgeInsets.zero,
                ),
                child: Ink(
                  decoration: BoxDecoration(
                    gradient: AppTheme.primaryGradient,
                    borderRadius: AppTheme.mediumRadius,
                    boxShadow: AppTheme.glowShadow,
                  ),
                  child: Center(
                    child: _saving
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Iconsax.tick_circle,
                                  color: Colors.white),
                              const SizedBox(width: 10),
                              Text(
                                isEdit ? 'Save Changes' : 'Create Scenario',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  // ── Save ──────────────────────────────────────────────────

  Future<void> _save(bool isEdit) async {
    if (!_formKey.currentState!.validate()) return;

    if (_actions.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add at least one action')),
      );
      return;
    }

    if (_triggerType == ScenarioTriggerType.schedule &&
        _scheduleMode == ScheduleMode.weekly &&
        _selectedDays.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select at least one day')),
      );
      return;
    }

    setState(() => _saving = true);

    final trigger = _buildTrigger();
    final scenario = Scenario(
      name: _nameCtrl.text.trim(),
      trigger: trigger,
      actions: List.from(_actions),
    );

    final provider = context.read<ScenarioProvider>();
    bool ok;
    if (isEdit && widget.editScenario?.id != null) {
      ok = await provider.updateScenario(widget.editScenario!.id!, scenario);
    } else {
      ok = await provider.createScenario(scenario);
    }

    if (!mounted) return;
    setState(() => _saving = false);

    if (ok) {
      Navigator.pop(context, true);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(provider.error ?? 'Failed to save scenario'),
          backgroundColor: AppTheme.errorColor,
        ),
      );
    }
  }

  ScenarioTrigger _buildTrigger() {
    if (_triggerType == ScenarioTriggerType.sensor) {
      return ScenarioTrigger(
        type: ScenarioTriggerType.sensor,
        sensor: _sensor,
        condition: _condition,
        value: _condition == 'changes' ? null : num.tryParse(_valueCtrl.text),
      );
    }

    switch (_scheduleMode) {
      case ScheduleMode.interval:
        return ScenarioTrigger(
          type: ScenarioTriggerType.schedule,
          mode: ScheduleMode.interval,
          every: int.tryParse(_everyCtrl.text) ?? 15,
          unit: _intervalUnit,
        );
      case ScheduleMode.daily:
        return ScenarioTrigger(
          type: ScenarioTriggerType.schedule,
          mode: ScheduleMode.daily,
          at: _atCtrl.text.trim(),
        );
      case ScheduleMode.weekly:
        return ScenarioTrigger(
          type: ScenarioTriggerType.schedule,
          mode: ScheduleMode.weekly,
          at: _atCtrl.text.trim(),
          days: List.from(_selectedDays),
        );
      case ScheduleMode.monthly:
        return ScenarioTrigger(
          type: ScenarioTriggerType.schedule,
          mode: ScheduleMode.monthly,
          at: _atCtrl.text.trim(),
          day: int.tryParse(_dayOfMonthCtrl.text) ?? 1,
        );
      case ScheduleMode.cron:
        return ScenarioTrigger(
          type: ScenarioTriggerType.schedule,
          mode: ScheduleMode.cron,
          expression: _cronCtrl.text.trim(),
        );
    }
  }
}
