import 'package:flutter/material.dart';
import 'package:database/database.dart';

/// Widget for configuring budget alert settings.
class BudgetAlertSettings extends StatelessWidget {
  final Budget budget;
  final ValueChanged<Budget> onUpdated;

  const BudgetAlertSettings({
    super.key,
    required this.budget,
    required this.onUpdated,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Master toggle
        _buildMasterToggle(context),
        const SizedBox(height: 16),
        
        // Threshold toggles (only show if alerts enabled)
        if (budget.alertEnabled) ...[
          Text(
            '提醒阈值',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
          const SizedBox(height: 8),
          _buildThresholdToggle(
            context,
            label: '50% - 预算使用一半时',
            subtitle: '温和提醒，帮助你关注支出',
            value: budget.alertAt50,
            icon: Icons.notifications_outlined,
            color: Colors.blue,
            onChanged: (value) => _updateThreshold(alertAt50: value),
          ),
          _buildThresholdToggle(
            context,
            label: '75% - 预算使用四分之三时',
            subtitle: '警告提醒，建议控制支出',
            value: budget.alertAt75,
            icon: Icons.warning_amber_outlined,
            color: Colors.orange,
            onChanged: (value) => _updateThreshold(alertAt75: value),
          ),
          _buildThresholdToggle(
            context,
            label: '90% - 预算即将用完时',
            subtitle: '紧急提醒，严格控制支出',
            value: budget.alertAt90,
            icon: Icons.error_outline,
            color: Colors.deepOrange,
            onChanged: (value) => _updateThreshold(alertAt90: value),
          ),
          _buildThresholdToggle(
            context,
            label: '100% - 预算用完时',
            subtitle: '超支提醒，已超出预算',
            value: budget.alertAt100,
            icon: Icons.block_outlined,
            color: Colors.red,
            onChanged: (value) => _updateThreshold(alertAt100: value),
          ),
        ],
      ],
    );
  }

  Widget _buildMasterToggle(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: budget.alertEnabled
            ? Theme.of(context).colorScheme.primaryContainer.withOpacity(0.3)
            : Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: SwitchListTile(
        title: Text(
          '启用预算提醒',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
        ),
        subtitle: Text(
          budget.alertEnabled 
              ? '将在达到设定阈值时发送通知' 
              : '不会发送预算提醒通知',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        secondary: Icon(
          budget.alertEnabled ? Icons.notifications_active : Icons.notifications_off,
          color: budget.alertEnabled
              ? Theme.of(context).colorScheme.primary
              : Theme.of(context).colorScheme.outline,
        ),
        value: budget.alertEnabled,
        onChanged: (value) {
          onUpdated(budget.copyWith(alertEnabled: value));
        },
      ),
    );
  }

  Widget _buildThresholdToggle(
    BuildContext context, {
    required String label,
    required String subtitle,
    required bool value,
    required IconData icon,
    required Color color,
    required ValueChanged<bool> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: () => onChanged(!value),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: value
                ? color.withOpacity(0.1)
                : Theme.of(context).colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(12),
            border: value
                ? Border.all(color: color.withOpacity(0.3))
                : null,
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: value
                      ? color.withOpacity(0.2)
                      : Theme.of(context).colorScheme.surfaceContainerHighest,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  icon,
                  size: 20,
                  color: value ? color : Theme.of(context).colorScheme.outline,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w500,
                            color: value
                                ? Theme.of(context).colorScheme.onSurface
                                : Theme.of(context).colorScheme.outline,
                          ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                    ),
                  ],
                ),
              ),
              Switch(
                value: value,
                onChanged: onChanged,
                activeColor: color,
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _updateThreshold({
    bool? alertAt50,
    bool? alertAt75,
    bool? alertAt90,
    bool? alertAt100,
  }) {
    onUpdated(budget.copyWith(
      alertAt50: alertAt50,
      alertAt75: alertAt75,
      alertAt90: alertAt90,
      alertAt100: alertAt100,
    ));
  }
}

/// Dialog for editing budget alert settings.
class BudgetAlertSettingsDialog extends StatefulWidget {
  final Budget budget;
  final ValueChanged<Budget> onSaved;

  const BudgetAlertSettingsDialog({
    super.key,
    required this.budget,
    required this.onSaved,
  });

  @override
  State<BudgetAlertSettingsDialog> createState() => _BudgetAlertSettingsDialogState();
}

class _BudgetAlertSettingsDialogState extends State<BudgetAlertSettingsDialog> {
  late Budget _editedBudget;

  @override
  void initState() {
    super.initState();
    _editedBudget = widget.budget;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('提醒设置'),
      content: SingleChildScrollView(
        child: BudgetAlertSettings(
          budget: _editedBudget,
          onUpdated: (budget) {
            setState(() {
              _editedBudget = budget;
            });
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: () {
            widget.onSaved(_editedBudget);
            Navigator.pop(context);
          },
          child: const Text('保存'),
        ),
      ],
    );
  }
}

/// Helper function to show alert settings dialog.
Future<void> showBudgetAlertSettingsDialog(
  BuildContext context, {
  required Budget budget,
  required ValueChanged<Budget> onSaved,
}) {
  return showDialog(
    context: context,
    builder: (context) => BudgetAlertSettingsDialog(
      budget: budget,
      onSaved: onSaved,
    ),
  );
}
