import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:database/database.dart';
import '../../data/recurring_provider.dart';
import '../widgets/recurring_card.dart';
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
            icon: const Icon(Icons.play_circle_outline),
            tooltip: '执行所有到期交易',
            onPressed: () => _processAllDue(context, ref),
          ),
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _showAddDialog(context, ref),
          ),
        ],
      ),
      body: recurringAsync.when(
        data: (recurringList) {
          if (recurringList.isEmpty) {
            return _buildEmptyState(context);
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

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.replay,
            size: 64,
            color: Theme.of(context).colorScheme.outline,
          ),
          const SizedBox(height: 16),
          Text(
            '暂无定期交易',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: Theme.of(context).colorScheme.outline,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            '点击右下角按钮添加定期交易',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.outline,
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecurringItem(BuildContext context, WidgetRef ref, RecurringTransaction recurring) {
    final amount = recurring.valueNum / recurring.valueDenom.toDouble();
    final nextDate = DateTime.fromMillisecondsSinceEpoch(recurring.nextDate);

    return RecurringCard(
      recurring: recurring,
      amount: amount,
      nextDate: nextDate,
      onTap: () => _showEditDialog(context, ref, recurring),
      onEdit: () => _showEditDialog(context, ref, recurring),
      onDelete: () => _showDeleteConfirmation(context, ref, recurring),
      onToggleActive: () => _toggleActive(context, ref, recurring),
      onGenerateNow: () => _generateNow(context, ref, recurring),
    );
  }

  Future<void> _toggleActive(BuildContext context, WidgetRef ref, RecurringTransaction recurring) async {
    final newState = !recurring.isActive;
    await ref.read(recurringNotifierProvider.notifier).toggleActive(recurring.id, newState);
    
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(newState ? '已启用定期交易' : '已暂停定期交易')),
      );
    }
  }

  Future<void> _generateNow(BuildContext context, WidgetRef ref, RecurringTransaction recurring) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('立即执行'),
        content: Text('确定要立即生成 "${recurring.name}" 的交易吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('确定'),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      try {
        await ref.read(recurringNotifierProvider.notifier).generateNow(recurring.id);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('交易已生成')),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('生成失败: $e'),
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
          );
        }
      }
    }
  }

  Future<void> _processAllDue(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('执行所有到期交易'),
        content: const Text('确定要执行所有到期的定期交易吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('确定'),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      try {
        final ids = await ref.read(recurringGenerationNotifierProvider.notifier).processAll();
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('已生成 ${ids.length} 个交易')),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('执行失败: $e'),
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
          );
        }
      }
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
        content: Text('确定要删除 "${recurring.name}" 吗？\n已生成的交易不会被删除。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () {
              ref.read(recurringNotifierProvider.notifier).deleteRecurring(recurring.id);
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('定期交易已删除')),
              );
            },
            child: const Text('删除'),
          ),
        ],
      ),
    );
  }
}
