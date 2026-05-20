import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:database/database.dart';
import 'package:finance_app/features/transactions/data/transaction_provider.dart';

class ReportsPage extends ConsumerWidget {
  const ReportsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final splitsWithAccountsAsync = ref.watch(allSplitsWithAccountsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('报表分析'),
      ),
      body: splitsWithAccountsAsync.when(
        data: (splitsWithAccounts) {
          final summary = _calculateSummary(splitsWithAccounts);
          return _buildReportContent(context, summary);
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('错误: $error')),
      ),
    );
  }

  Map<String, double> _calculateSummary(List<(Split, Account)> splitsWithAccounts) {
    double totalIncome = 0;
    double totalExpense = 0;

    for (final (split, account) in splitsWithAccounts) {
      // Convert from cents to yuan (valueNum is stored in cents)
      final amount = split.valueNum / 100.0;
      
      // In double-entry bookkeeping:
      // - INCOME accounts: credit (negative) represents income
      // - EXPENSE accounts: debit (positive) represents expense
      // 
      // For simplicity in single-entry view:
      // - If account is INCOME type, positive value = income
      // - If account is EXPENSE type, positive value = expense
      // - ASSET/LIABILITY/EQUITY are balance sheet items, not income/expense
      
      switch (account.accountType) {
        case 'INCOME':
          // Income: positive value means money coming in
          totalIncome += amount.abs();
          break;
        case 'EXPENSE':
          // Expense: positive value means money going out
          totalExpense += amount.abs();
          break;
        // ASSET, LIABILITY, EQUITY are not income/expense
        default:
          break;
      }
    }

    return {
      'income': totalIncome,
      'expense': totalExpense,
      'balance': totalIncome - totalExpense,
    };
  }

  Widget _buildReportContent(BuildContext context, Map<String, double> summary) {
    final income = summary['income'] ?? 0;
    final expense = summary['expense'] ?? 0;
    final balance = summary['balance'] ?? 0;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSummaryCard(context, income, expense, balance),
          const SizedBox(height: 24),
          _buildMonthlySection(context),
        ],
      ),
    );
  }

  Widget _buildSummaryCard(BuildContext context, double income, double expense, double balance) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Text(
              '本月收支概览',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: _buildSummaryItem(
                    context,
                    '收入',
                    income,
                    Colors.green,
                    Icons.arrow_upward,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildSummaryItem(
                    context,
                    '支出',
                    expense,
                    Colors.red,
                    Icons.arrow_downward,
                  ),
                ),
              ],
            ),
            const Divider(height: 32),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '结余: ',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                Text(
                  '¥ ${balance.toStringAsFixed(2)}',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: balance >= 0 ? Colors.green : Colors.red,
                      ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryItem(
    BuildContext context,
    String label,
    double amount,
    Color color,
    IconData icon,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: color,
                ),
          ),
          const SizedBox(height: 4),
          Text(
            '¥ ${amount.toStringAsFixed(2)}',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildMonthlySection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '月度趋势',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
        ),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Center(
              child: Column(
                children: [
                  Icon(
                    Icons.bar_chart_outlined,
                    size: 48,
                    color: Theme.of(context).colorScheme.outline,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    '暂无足够数据',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: Theme.of(context).colorScheme.outline,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '记录更多交易后查看趋势分析',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.outline,
                        ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}