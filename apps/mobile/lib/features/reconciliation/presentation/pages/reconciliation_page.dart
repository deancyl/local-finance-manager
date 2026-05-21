import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';

import 'package:core/core.dart';
import '../data/reconciliation_provider.dart';
import '../widgets/reconciliation_dialog.dart';

/// Page for reconciling account transactions against a bank statement.
/// 
/// Shows:
/// - Statement balance and calculated cleared balance
/// - Difference indicator
/// - List of splits to mark as cleared/reconciled
class ReconciliationPage extends ConsumerWidget {
  const ReconciliationPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(reconciliationNotifierProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('账户对账'),
        actions: [
          if (state.hasSession)
            IconButton(
              icon: const Icon(Icons.close),
              tooltip: '取消对账',
              onPressed: () => _confirmCancel(context, ref),
            ),
        ],
      ),
      body: state.hasSession
          ? _buildReconciliationView(context, ref, state)
          : _buildEmptyState(context, ref),
    );
  }

  Widget _buildEmptyState(BuildContext context, WidgetRef ref) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.receipt_long_outlined,
            size: 80,
            color: Theme.of(context).colorScheme.outline,
          ),
          const SizedBox(height: 24),
          Text(
            '开始对账',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          Text(
            '将您的账户余额与银行对账单进行核对',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 32),
          FilledButton.icon(
            onPressed: () => _showStartDialog(context),
            icon: const Icon(Icons.add),
            label: const Text('开始新对账'),
          ),
        ],
      ),
    );
  }

  Widget _buildReconciliationView(
    BuildContext context,
    WidgetRef ref,
    ReconciliationState state,
  ) {
    if (state.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (state.error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 48,
              color: Theme.of(context).colorScheme.error,
            ),
            const SizedBox(height: 16),
            Text('错误: ${state.error}'),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () => ref.read(reconciliationNotifierProvider.notifier).refresh(),
              child: const Text('重试'),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        // Balance summary card
        _buildBalanceCard(context, state),
        
        // Splits list
        Expanded(
          child: state.result == null || state.result!.splits.isEmpty
              ? _buildNoTransactions(context)
              : _buildSplitsList(context, ref, state),
        ),
        
        // Action buttons
        if (state.isBalanced)
          _buildFinalizeButton(context, ref),
      ],
    );
  }

  Widget _buildBalanceCard(BuildContext context, ReconciliationState state) {
    final difference = state.difference;
    final isBalanced = state.isBalanced;
    final dateFormat = DateFormat('yyyy-MM-dd');

    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        state.accountName ?? '',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '对账单日期: ${dateFormat.format(state.statementDate!)}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.edit_outlined),
                  tooltip: '修改对账信息',
                  onPressed: () => _showStartDialog(context),
                ),
              ],
            ),
            const Divider(height: 24),
            Row(
              children: [
                Expanded(
                  child: _buildBalanceItem(
                    context,
                    '对账单余额',
                    state.statementBalance,
                  ),
                ),
                Expanded(
                  child: _buildBalanceItem(
                    context,
                    '已核对余额',
                    state.result?.clearedBalance ?? 0,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isBalanced
                    ? Colors.green.withOpacity(0.1)
                    : Colors.orange.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    isBalanced ? Icons.check_circle : Icons.warning_amber,
                    color: isBalanced ? Colors.green : Colors.orange,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    isBalanced
                        ? '已平衡 - 差额为 0'
                        : '差额: ${_formatCurrency(difference)}',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: isBalanced ? Colors.green : Colors.orange,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBalanceItem(
    BuildContext context,
    String label,
    double amount,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          _formatCurrency(amount),
          style: Theme.of(context).textTheme.titleLarge,
        ),
      ],
    );
  }

  Widget _buildNoTransactions(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.receipt_long_outlined,
            size: 48,
            color: Theme.of(context).colorScheme.outline,
          ),
          const SizedBox(height: 16),
          Text(
            '该账户在此日期前没有交易记录',
            style: Theme.of(context).textTheme.bodyLarge,
          ),
        ],
      ),
    );
  }

  Widget _buildSplitsList(
    BuildContext context,
    WidgetRef ref,
    ReconciliationState state,
  ) {
    final splits = state.result!.splits;
    final dateFormat = DateFormat('MM-dd');

    return ListView.builder(
      itemCount: splits.length,
      itemBuilder: (context, index) {
        final split = splits[index];
        final isSelected = split.isClearedOrReconciled;

        return ListTile(
          leading: Checkbox(
            value: isSelected,
            onChanged: (value) {
              final notifier = ref.read(reconciliationNotifierProvider.notifier);
              if (value == true) {
                notifier.markCleared(split.splitId);
              } else {
                notifier.markNotReconciled(split.splitId);
              }
            },
          ),
          title: Text(split.description ?? '无描述'),
          subtitle: Text(
            '${dateFormat.format(split.postDate)} ${split.memo ?? ''}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          trailing: Text(
            _formatCurrency(split.value),
            style: TextStyle(
              color: split.valueNum >= 0
                  ? Colors.green
                  : Theme.of(context).colorScheme.error,
              fontWeight: FontWeight.bold,
            ),
          ),
          onTap: () {
            final notifier = ref.read(reconciliationNotifierProvider.notifier);
            if (isSelected) {
              notifier.markNotReconciled(split.splitId);
            } else {
              notifier.markCleared(split.splitId);
            }
          },
        );
      },
    );
  }

  Widget _buildFinalizeButton(BuildContext context, WidgetRef ref) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: FilledButton.icon(
          onPressed: () => _finalizeReconciliation(context, ref),
          icon: const Icon(Icons.check),
          label: const Text('完成对账'),
          style: FilledButton.styleFrom(
            minimumSize: const Size(double.infinity, 48),
          ),
        ),
      ),
    );
  }

  void _showStartDialog(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => const ReconciliationDialog(),
    ).then((result) {
      if (result == true) {
        // Reconciliation started successfully, navigate to page if needed
      }
    });
  }

  Future<void> _confirmCancel(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('取消对账'),
        content: const Text('确定要取消当前对账吗？已核对的项目将保留。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('继续对账'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('取消对账'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      ref.read(reconciliationNotifierProvider.notifier).cancelSession();
    }
  }

  Future<void> _finalizeReconciliation(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('完成对账'),
        content: const Text('确定要完成对账吗？所有已核对的项目将被标记为已对账。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('完成'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await ref.read(reconciliationNotifierProvider.notifier).finalize();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('对账已完成')),
        );
        context.pop();
      }
    }
  }

  String _formatCurrency(double amount) {
    final format = NumberFormat.currency(symbol: '¥', decimalDigits: 2);
    return format.format(amount);
  }
}
