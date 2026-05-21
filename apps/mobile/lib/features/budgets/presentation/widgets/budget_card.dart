import 'package:flutter/material.dart';
import 'package:database/database.dart';

/// Budget card widget showing progress and spending.
class BudgetCard extends StatelessWidget {
  final Budget budget;
  final double spentAmount;
  final double progress;
  final VoidCallback onTap;
  final VoidCallback onDelete;
  final VoidCallback? onAlertSettings;

  const BudgetCard({
    super.key,
    required this.budget,
    required this.spentAmount,
    required this.progress,
    required this.onTap,
    required this.onDelete,
    this.onAlertSettings,
  });

  @override
  Widget build(BuildContext context) {
    final isOverBudget = progress > 1.0;
    final progressColor = isOverBudget 
        ? Colors.red 
        : progress > 0.8 
            ? Colors.orange 
            : Colors.green;
    
    final percentage = (progress * 100).clamp(0, 999).toStringAsFixed(0);
    final budgetAmount = budget.amountNum / budget.amountDenom;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header row
              Row(
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        Text(
                          budget.name,
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                        ),
                        if (budget.alertEnabled) ...[
                          const SizedBox(width: 8),
                          Icon(
                            Icons.notifications_active_outlined,
                            size: 16,
                            color: Theme.of(context).colorScheme.primary.withOpacity(0.7),
                          ),
                        ],
                      ],
                    ),
                  ),
                  // Period badge
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      _getPeriodLabel(budget.period),
                      style: Theme.of(context).textTheme.labelSmall,
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (onAlertSettings != null)
                    IconButton(
                      icon: const Icon(Icons.notifications_outlined),
                      onPressed: onAlertSettings,
                      color: Theme.of(context).colorScheme.primary,
                      iconSize: 20,
                    ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline),
                    onPressed: onDelete,
                    color: Theme.of(context).colorScheme.error,
                    iconSize: 20,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              
              // Progress bar
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: progress.clamp(0.0, 1.0),
                  backgroundColor: progressColor.withOpacity(0.2),
                  valueColor: AlwaysStoppedAnimation(progressColor),
                  minHeight: 8,
                ),
              ),
              const SizedBox(height: 8),
              
              // Amount row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '¥${spentAmount.toStringAsFixed(2)} / ¥${budgetAmount.toStringAsFixed(2)}',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  Text(
                    '$percentage%',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: progressColor,
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                ],
              ),
              
              // Over budget warning
              if (isOverBudget) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(Icons.warning, size: 16, color: Colors.red),
                    const SizedBox(width: 4),
                    Text(
                      '已超出预算 ¥${(spentAmount - budgetAmount).toStringAsFixed(2)}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Colors.red,
                          ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
  
  String _getPeriodLabel(String period) {
    switch (period) {
      case 'MONTHLY':
        return '每月';
      case 'YEARLY':
        return '每年';
      case 'CUSTOM':
        return '自定义';
      default:
        return period;
    }
  }
}