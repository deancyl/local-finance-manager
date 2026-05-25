import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:database/database.dart';

/// Card widget for displaying a recurring transaction.
class RecurringCard extends StatelessWidget {
  final RecurringTransaction recurring;
  final double amount;
  final DateTime nextDate;
  final VoidCallback? onTap;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final VoidCallback? onToggleActive;
  final VoidCallback? onGenerateNow;

  const RecurringCard({
    super.key,
    required this.recurring,
    required this.amount,
    required this.nextDate,
    this.onTap,
    this.onEdit,
    this.onDelete,
    this.onToggleActive,
    this.onGenerateNow,
  });

  @override
  Widget build(BuildContext context) {
    final isActive = recurring.isActive;
    final isOverdue = nextDate.isBefore(DateTime.now());
    final frequencyText = _getFrequencyText(recurring);
    final daysUntilNext = nextDate.difference(DateTime.now()).inDays;

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
                  // Frequency icon
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: isActive
                          ? Theme.of(context).colorScheme.primaryContainer
                          : Theme.of(context).colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      _getFrequencyIcon(recurring.frequency),
                      color: isActive
                          ? Theme.of(context).colorScheme.onPrimaryContainer
                          : Theme.of(context).colorScheme.outline,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Name and description
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          recurring.name,
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                                color: isActive ? null : Theme.of(context).colorScheme.outline,
                              ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          frequencyText,
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: Theme.of(context).colorScheme.outline,
                              ),
                        ),
                      ],
                    ),
                  ),
                  // Amount
                  Text(
                    '¥${amount.abs().toStringAsFixed(2)}',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: isActive
                              ? (amount < 0 ? Colors.red : Colors.green)
                              : Theme.of(context).colorScheme.outline,
                        ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Next date and status row
              Row(
                children: [
                  // Next date
                  Expanded(
                    child: Row(
                      children: [
                        Icon(
                          Icons.event,
                          size: 16,
                          color: isOverdue && isActive
                              ? Colors.red
                              : Theme.of(context).colorScheme.outline,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '下次: ${DateFormat.yMMMd().format(nextDate)}',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: isOverdue && isActive
                                    ? Colors.red
                                    : Theme.of(context).colorScheme.onSurface,
                              ),
                        ),
                      ],
                    ),
                  ),
                  // Days until next or overdue badge
                  if (isActive) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: isOverdue
                            ? Colors.red.withOpacity(0.1)
                            : daysUntilNext <= 3
                                ? Colors.orange.withOpacity(0.1)
                                : Theme.of(context).colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        isOverdue
                            ? '已逾期'
                            : daysUntilNext == 0
                                ? '今天'
                                : '$daysUntilNext 天后',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              color: isOverdue
                                  ? Colors.red
                                  : daysUntilNext <= 3
                                      ? Colors.orange
                                      : Theme.of(context).colorScheme.onSurface,
                            ),
                      ),
                    ),
                  ],
                ],
              ),

              // Occurrence info (if applicable)
              if (recurring.maxOccurrences != null || recurring.occurrenceCount > 0) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(
                      Icons.repeat,
                      size: 16,
                      color: Theme.of(context).colorScheme.outline,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      recurring.maxOccurrences != null
                          ? '已执行 ${recurring.occurrenceCount}/${recurring.maxOccurrences} 次'
                          : '已执行 ${recurring.occurrenceCount} 次',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context).colorScheme.outline,
                          ),
                    ),
                  ],
                ),
              ],

              // End date (if set)
              if (recurring.endDate != null) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(
                      Icons.event_busy,
                      size: 16,
                      color: Theme.of(context).colorScheme.outline,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '结束: ${DateFormat.yMMMd().format(DateTime.fromMillisecondsSinceEpoch(recurring.endDate!))}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context).colorScheme.outline,
                          ),
                    ),
                  ],
                ),
              ],

              const SizedBox(height: 12),

              // Action buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  // Generate now button
                  if (isActive && onGenerateNow != null)
                    TextButton.icon(
                      onPressed: onGenerateNow,
                      icon: const Icon(Icons.play_arrow, size: 18),
                      label: const Text('立即执行'),
                      style: TextButton.styleFrom(
                        foregroundColor: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  const Spacer(),
                  // Active toggle
                  if (onToggleActive != null)
                    Switch(
                      value: isActive,
                      onChanged: (_) => onToggleActive?.call(),
                    ),
                  // Edit button
                  if (onEdit != null)
                    IconButton(
                      icon: const Icon(Icons.edit_outlined),
                      onPressed: onEdit,
                      iconSize: 20,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  // Delete button
                  if (onDelete != null)
                    IconButton(
                      icon: const Icon(Icons.delete_outline),
                      onPressed: onDelete,
                      iconSize: 20,
                      color: Theme.of(context).colorScheme.error,
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _getFrequencyText(RecurringTransaction recurring) {
    final interval = recurring.interval > 1 ? '每${recurring.interval}' : '每';

    switch (recurring.frequency) {
      case 'daily':
        return '${interval}天';
      case 'weekly':
        if (recurring.dayOfWeek != null) {
          final days = ['周日', '周一', '周二', '周三', '周四', '周五', '周六'];
          return '${interval}周 (${days[recurring.dayOfWeek!]})';
        }
        return '${interval}周';
      case 'monthly':
        if (recurring.dayOfMonth != null) {
          if (recurring.dayOfMonth == -1) {
            return '${interval}月 (最后一天)';
          }
          return '${interval}月 (${recurring.dayOfMonth}日)';
        }
        return '${interval}月';
      case 'yearly':
        if (recurring.monthOfYear != null && recurring.dayOfMonth != null) {
          final months = [
            '1月', '2月', '3月', '4月', '5月', '6月',
            '7月', '8月', '9月', '10月', '11月', '12月'
          ];
          return '${interval}年 (${months[recurring.monthOfYear! - 1]}${recurring.dayOfMonth}日)';
        }
        return '${interval}年';
      case 'custom':
        return '自定义间隔';
      default:
        return recurring.frequency;
    }
  }

  IconData _getFrequencyIcon(String frequency) {
    switch (frequency) {
      case 'daily':
        return Icons.today;
      case 'weekly':
        return Icons.date_range;
      case 'monthly':
        return Icons.calendar_month;
      case 'yearly':
        return Icons.event;
      case 'custom':
        return Icons.schedule;
      default:
        return Icons.replay;
    }
  }
}
