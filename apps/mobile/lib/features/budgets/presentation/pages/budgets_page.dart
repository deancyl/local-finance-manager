import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:database/database.dart';

import '../../data/budget_provider.dart';
import '../../data/budget_notification_service.dart';
import '../widgets/budget_card.dart';
import '../widgets/add_budget_dialog.dart';
import '../widgets/budget_alert_settings.dart';

class BudgetsPage extends ConsumerWidget {
  const BudgetsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final budgetsAsync = ref.watch(budgetsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('预算管理'),
      ),
      body: budgetsAsync.when(
        data: (budgets) {
          if (budgets.isEmpty) {
            return _buildEmptyState(context);
          }
          return _buildBudgetList(context, ref, budgets);
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('错误: $error')),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddDialog(context),
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
            Icons.account_balance_wallet_outlined,
            size: 64,
            color: Theme.of(context).colorScheme.outline,
          ),
          const SizedBox(height: 16),
          Text(
            '暂无预算',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: Theme.of(context).colorScheme.outline,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            '点击右下角按钮添加预算',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.outline,
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildBudgetList(BuildContext context, WidgetRef ref, List<Budget> budgets) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: budgets.length,
      itemBuilder: (context, index) {
        final budget = budgets[index];
        return _buildBudgetItem(context, ref, budget);
      },
    );
  }

  Widget _buildBudgetItem(BuildContext context, WidgetRef ref, Budget budget) {
    final spendingAsync = ref.watch(budgetWithSpendingProvider(budget.id));
    
    return spendingAsync.when(
      data: (spending) => BudgetCard(
        budget: budget,
        spentAmount: spending.spentAmount,
        progress: spending.progress,
        onTap: () => _showEditDialog(context, budget),
        onDelete: () => _deleteBudget(context, ref, budget),
        onAlertSettings: () => _showAlertSettings(context, ref, budget),
      ),
      loading: () => const Card(
        margin: EdgeInsets.only(bottom: 8),
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Center(child: CircularProgressIndicator()),
        ),
      ),
      error: (_, __) => const SizedBox(),
    );
  }

  void _showAddDialog(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => const AddBudgetDialog(),
    );
  }

  void _showEditDialog(BuildContext context, Budget budget) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => AddBudgetDialog(budget: budget),
    );
  }

  void _deleteBudget(BuildContext context, WidgetRef ref, Budget budget) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除预算'),
        content: Text('确定要删除预算 "${budget.name}" 吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () {
              ref.read(budgetNotifierProvider.notifier).deleteBudget(budget.id);
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('预算已删除')),
              );
            },
            child: const Text('删除'),
          ),
        ],
      ),
    );
  }

  void _showAlertSettings(BuildContext context, WidgetRef ref, Budget budget) {
    showBudgetAlertSettingsDialog(
      context,
      budget: budget,
      onSaved: (updatedBudget) {
        ref.read(budgetNotifierProvider.notifier).updateBudget(updatedBudget);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('提醒设置已更新')),
        );
      },
    );
  }
}