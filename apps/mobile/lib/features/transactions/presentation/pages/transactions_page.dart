import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:database/database.dart';
import '../../data/transaction_provider.dart';
import '../../data/transaction_filter.dart';
import '../widgets/transaction_card.dart';
import '../widgets/add_transaction_dialog.dart';
import '../widgets/transaction_filter_dialog.dart';

class TransactionsPage extends ConsumerWidget {
  const TransactionsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final transactionsAsync = ref.watch(filteredTransactionsWithSplitsProvider);
    final filter = ref.watch(transactionFilterProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('交易记录'),
        actions: [
          _buildFilterButton(context, ref, filter),
        ],
      ),
      body: transactionsAsync.when(
        data: (transactionsWithSplits) {
          final transactions = transactionsWithSplits.map((t) => t.$1).toList();
          if (transactions.isEmpty) {
            if (filter.isNotEmpty) {
              return _buildNoResultsState(context, ref);
            }
            return _buildEmptyState(context);
          }
          return _buildTransactionList(context, ref, transactions);
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('错误: $error')),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddDialog(context),
        icon: const Icon(Icons.add),
        label: const Text('记一笔'),
      ),
    );
  }

  Widget _buildFilterButton(BuildContext context, WidgetRef ref, TransactionFilter filter) {
    return Stack(
      children: [
        IconButton(
          icon: const Icon(Icons.filter_list),
          onPressed: () => _showFilterDialog(context),
        ),
        if (filter.isNotEmpty)
          Positioned(
            right: 8,
            top: 8,
            child: Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary,
                shape: BoxShape.circle,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.receipt_long_outlined,
            size: 64,
            color: Theme.of(context).colorScheme.outline,
          ),
          const SizedBox(height: 16),
          Text(
            '暂无交易记录',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: Theme.of(context).colorScheme.outline,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            '点击下方按钮开始记账',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.outline,
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoResultsState(BuildContext context, WidgetRef ref) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.search_off,
            size: 64,
            color: Theme.of(context).colorScheme.outline,
          ),
          const SizedBox(height: 16),
          Text(
            '未找到符合条件的交易',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: Theme.of(context).colorScheme.outline,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            '尝试调整筛选条件',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.outline,
                ),
          ),
          const SizedBox(height: 16),
          FilledButton.tonal(
            onPressed: () {
              ref.read(transactionFilterProvider.notifier).state = const TransactionFilter();
            },
            child: const Text('清除筛选'),
          ),
        ],
      ),
    );
  }

  void _showFilterDialog(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => const TransactionFilterDialog(),
    );
  }

  Widget _buildTransactionList(BuildContext context, WidgetRef ref, List<Transaction> transactions) {
    final grouped = _groupByDate(transactions);

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: grouped.length,
      itemBuilder: (context, index) {
        final entry = grouped.entries.elementAt(index);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                _formatDateHeader(entry.key),
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ),
            ...entry.value.map((transaction) => TransactionCard(
                  transaction: transaction,
                  onTap: () => _showEditDialog(context, transaction),
                  onDelete: () => _deleteTransaction(context, ref, transaction),
                )),
            const SizedBox(height: 8),
          ],
        );
      },
    );
  }

  Map<DateTime, List<Transaction>> _groupByDate(List<Transaction> transactions) {
    final grouped = <DateTime, List<Transaction>>{};
    for (final transaction in transactions) {
      final date = DateTime.fromMillisecondsSinceEpoch(transaction.postDate);
      final dateKey = DateTime(date.year, date.month, date.day);
      grouped.putIfAbsent(dateKey, () => []).add(transaction);
    }
    return grouped;
  }

  String _formatDateHeader(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));

    if (date == today) return '今天';
    if (date == yesterday) return '昨天';
    return DateFormat('MM月dd日', 'zh_CN').format(date);
  }

  void _showAddDialog(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => const AddTransactionDialog(),
    );
  }

  void _showEditDialog(BuildContext context, Transaction transaction) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => AddTransactionDialog(transaction: transaction),
    );
  }

  void _deleteTransaction(BuildContext context, WidgetRef ref, Transaction transaction) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除交易'),
        content: const Text('确定要删除这条交易记录吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () {
              ref.read(transactionNotifierProvider.notifier).deleteTransaction(transaction.id);
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('交易已删除')),
              );
            },
            child: const Text('删除'),
          ),
        ],
      ),
    );
  }
}