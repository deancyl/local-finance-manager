import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:database/database.dart' as db;
import 'package:finance_app/features/transactions/data/transaction_provider.dart';
import 'package:finance_app/features/reports/data/chart_providers.dart';
import 'package:finance_app/features/reports/presentation/widgets/monthly_trend_chart.dart';
import 'package:finance_app/features/reports/presentation/widgets/category_breakdown_chart.dart';

class ReportsPage extends ConsumerWidget {
  const ReportsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final splitsWithAccountsAsync = ref.watch(allSplitsWithAccountsProvider);
    final monthlyTrendAsync = ref.watch(monthlyTrendProvider);
    final categoryBreakdownAsync = ref.watch(categoryBreakdownProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('报表分析'),
      ),
      body: splitsWithAccountsAsync.when(
        data: (splitsWithAccounts) {
          final summary = _calculateSummary(splitsWithAccounts);
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSummaryCard(context, summary['income'] ?? 0, summary['expense'] ?? 0, summary['balance'] ?? 0),
                const SizedBox(height: 24),
                _buildMonthlyTrendSection(context, monthlyTrendAsync),
                const SizedBox(height: 24),
                _buildCategoryBreakdownSection(context, categoryBreakdownAsync),
              ],
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('错误: $error')),
      ),
    );
  }

  Map<String, double> _calculateSummary(List<(db.Split, db.Account)> splitsWithAccounts) {
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

  Widget _buildMonthlyTrendSection(BuildContext context, AsyncValue<List<MonthlyData>> monthlyTrendAsync) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '月度趋势',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
            Row(
              children: [
                Container(width: 12, height: 12, decoration: const BoxDecoration(color: Colors.green, shape: BoxShape.circle)),
                const SizedBox(width: 4),
                const Text('收入', style: TextStyle(fontSize: 12)),
                const SizedBox(width: 12),
                Container(width: 12, height: 12, decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle)),
                const SizedBox(width: 4),
                const Text('支出', style: TextStyle(fontSize: 12)),
              ],
            ),
          ],
        ),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: monthlyTrendAsync.when(
              data: (data) => MonthlyTrendChart(data: data),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => Center(child: Text('加载失败: $error')),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCategoryBreakdownSection(BuildContext context, AsyncValue<List<CategoryBreakdown>> categoryBreakdownAsync) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '支出分类',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
        ),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: categoryBreakdownAsync.when(
              data: (data) => SizedBox(
                height: 300,
                child: CategoryBreakdownChart(data: data),
              ),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => Center(child: Text('加载失败: $error')),
            ),
          ),
        ),
      ],
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
}