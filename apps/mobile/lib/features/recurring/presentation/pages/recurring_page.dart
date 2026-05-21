import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:database/database.dart';
import '../../data/recurring_provider.dart';
import '../widgets/add_recurring_dialog.dart';

class RecurringPage extends ConsumerWidget {
  const RecurringPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recurringAsync = ref.watch(recurringTransactionsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('定期交易'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _showAddDialog(context, ref),
          ),
        ],
      ),
      body: recurringAsync.when(
        data: (recurringList) {
          if (recurringList.isEmpty) {
            return const Center(
              child: Text('暂无定期交易，点击右上角添加'),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: recurringList.length,
            itemBuilder: (context, index) {
              final recurring = recurringList[index];
              return _buildRecurringItem(context, ref, recurring);
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('错误: $error')),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddDialog(context, ref),
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildRecurringItem(BuildContext context, WidgetRef ref, RecurringTransaction recurring) {
    final amount = recurring.valueNum / recurring.valueDenom.toDouble();
    final nextDate = DateTime.fromMillisecondsSinceEpoch(recurring.nextDate);
    final frequencyText = _getFrequencyText(recurring);
    final isActive = recurring.isActive;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: isActive ? Theme.of(context).colorScheme.primaryContainer : Colors.grey,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            _getFrequencyIcon(recurring.frequency),
            color: isActive 
                ? Theme.of(context).colorScheme.onPrimaryContainer 
                : Colors.white,
            size: 20,
          ),
        ),
        title: Text(
          recurring.name,
          style: TextStyle(
            color: isActive ? null : Colors.grey,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(frequencyText),
            Text(
              '下次: ${DateFormat.yMMMd().format(nextDate)}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '¥${amount.toStringAsFixed(2)}',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: isActive ? null : Colors.grey,
              ),
            ),
            const SizedBox(width: 8),
            Switch(
              value: isActive,
              onChanged: (value) {
                ref.read(recurringNotifierProvider.notifier).toggleActive(recurring.id, value);
              },
            ),
          ],
        ),
        onTap: () => _showEditDialog(context, ref, recurring),
        onLongPress: () => _showDeleteConfirmation(context, ref, recurring),
      ),
    );
  }

  String _getFrequencyText(RecurringTransaction recurring) {
    final interval = recurring.interval > 1 ? '每${recurring.interval}' : '';
    
    switch (recurring.frequency) {
      case 'daily':
        return '${interval}天';
      case 'weekly':
        return '${interval}周';
      case 'monthly':
        return '${interval}月';
      case 'yearly':
        return '${interval}年';
      case 'custom':
        return '自定义';
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

  void _showAddDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => const AddRecurringDialog(),
    );
  }

  void _showEditDialog(BuildContext context, WidgetRef ref, RecurringTransaction recurring) {
    showDialog(
      context: context,
      builder: (context) => AddRecurringDialog(recurring: recurring),
    );
  }

  void _showDeleteConfirmation(BuildContext context, WidgetRef ref, RecurringTransaction recurring) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除定期交易'),
        content: Text('确定要删除 "${recurring.name}" 吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () {
              ref.read(recurringNotifierProvider.notifier).deleteRecurring(recurring.id);
              Navigator.pop(context);
            },
            child: const Text('删除'),
          ),
        ],
      ),
    );
  }
}
