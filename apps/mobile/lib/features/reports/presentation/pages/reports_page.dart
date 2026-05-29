import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';

import 'package:database/database.dart' as db;
import 'package:finance_app/features/reports/data/chart_providers.dart';
import 'package:finance_app/features/reports/presentation/widgets/monthly_trend_chart.dart';
import 'package:finance_app/features/reports/presentation/widgets/category_breakdown_chart.dart';
import 'package:finance_app/features/reports/presentation/widgets/asset_trend_chart.dart';
import 'package:finance_app/features/transactions/data/transaction_filter.dart';

class ReportsPage extends ConsumerWidget {
  const ReportsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final splitsWithTransactionsAsync = ref.watch(allSplitsWithAccountsAndTransactionsProvider);
    final monthlyTrendAsync = ref.watch(monthlyTrendProvider);
    final categoryBreakdownAsync = ref.watch(categoryBreakdownProvider);
    final dateRange = ref.watch(dateRangeFilterProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('报表分析'),
        actions: [
          IconButton(
            icon: const Icon(Icons.book_outlined),
            onPressed: () => context.push('/journal-entries'),
            tooltip: '凭证列表',
          ),
          IconButton(
            icon: const Icon(Icons.account_balance),
            onPressed: () => context.push('/reports/trial-balance'),
            tooltip: '试算平衡表',
          ),
          IconButton(
            icon: const Icon(Icons.balance),
            onPressed: () => context.push('/reports/balance-sheet'),
            tooltip: '资产负债表',
          ),
          IconButton(
            icon: const Icon(Icons.show_chart),
            onPressed: () => context.push('/reports/income-statement'),
            tooltip: '利润表',
          ),
          IconButton(
            icon: const Icon(Icons.account_balance_wallet),
            onPressed: () => context.push('/reports/cash-flow'),
            tooltip: '现金流量表',
          ),
          IconButton(
            icon: const Icon(Icons.receipt_long),
            onPressed: () => context.push('/reports/general-ledger'),
            tooltip: '总账',
          ),
        ],
      ),
      body: splitsWithTransactionsAsync.when(
        data: (splitsWithTransactions) {
          final summary = _calculateSummary(splitsWithTransactions, dateRange);
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildDateRangeSelector(context, ref, dateRange),
                const SizedBox(height: 16),
                _buildSummaryCard(context, summary['income'] ?? 0, summary['expense'] ?? 0, summary['balance'] ?? 0, dateRange),
                const SizedBox(height: 24),
                _buildMonthlyTrendSection(context, monthlyTrendAsync),
                const SizedBox(height: 24),
                _buildCategoryBreakdownSection(context, categoryBreakdownAsync),
                const SizedBox(height: 24),
                _buildAssetTrendSection(context),
              ],
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('错误: $error')),
      ),
    );
  }

  Widget _buildDateRangeSelector(BuildContext context, WidgetRef ref, DateRangeFilter dateRange) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.date_range,
                  size: 20,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  '时间范围',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _buildQuickSelector(
                  context,
                  ref,
                  label: '本月',
                  isSelected: dateRange.label == '本月',
                  onTap: () {
                    ref.read(dateRangeFilterProvider.notifier).state = DateRangeFilter.currentMonth();
                  },
                ),
                const SizedBox(width: 8),
                _buildQuickSelector(
                  context,
                  ref,
                  label: '本年',
                  isSelected: dateRange.label == '本年',
                  onTap: () {
                    ref.read(dateRangeFilterProvider.notifier).state = DateRangeFilter.currentYear();
                  },
                ),
                const SizedBox(width: 8),
                _buildQuickSelector(
                  context,
                  ref,
                  label: '自定义',
                  isSelected: dateRange.label == '自定义',
                  onTap: () => _showDateRangePicker(context, ref, dateRange),
                ),
              ],
            ),
            if (dateRange.label == '自定义') ...[
              const SizedBox(height: 12),
              Text(
                '${DateFormat('yyyy-MM-dd').format(dateRange.startDate)} 至 ${DateFormat('yyyy-MM-dd').format(dateRange.endDate)}',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.outline,
                    ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildQuickSelector(
    BuildContext context,
    WidgetRef ref, {
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected
                ? Theme.of(context).colorScheme.primaryContainer
                : Theme.of(context).colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(8),
            border: isSelected
                ? Border.all(
                    color: Theme.of(context).colorScheme.primary,
                    width: 1.5,
                  )
                : null,
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              color: isSelected
                  ? Theme.of(context).colorScheme.onPrimaryContainer
                  : Theme.of(context).colorScheme.onSurface,
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _showDateRangePicker(BuildContext context, WidgetRef ref, DateRangeFilter currentRange) async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
      initialDateRange: DateTimeRange(
        start: currentRange.startDate,
        end: currentRange.endDate,
      ),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme,
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      final start = DateTime(picked.start.year, picked.start.month, picked.start.day);
      final end = DateTime(picked.end.year, picked.end.month, picked.end.day, 23, 59, 59, 999);
      ref.read(dateRangeFilterProvider.notifier).state = DateRangeFilter.custom(start, end);
    }
  }

  Map<String, double> _calculateSummary(List<(db.Split, db.Account, db.Transaction)> splitsWithTransactions, DateRangeFilter dateRange) {
    double totalIncome = 0;
    double totalExpense = 0;

    final startMs = dateRange.startDate.millisecondsSinceEpoch;
    final endMs = dateRange.endDate.millisecondsSinceEpoch;

    for (final (split, account, transaction) in splitsWithTransactions) {
      // Check if transaction is within date range
      if (transaction.postDate >= startMs && transaction.postDate <= endMs && split.valueNum != 0) {
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
              data: (data) => MonthlyTrendChart(
                data: data,
                onBarTap: (filter) => _navigateToTransactions(context, filter),
              ),
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
                child: CategoryBreakdownChart(
                  data: data,
                  onCategoryTap: (filter) => _navigateToTransactions(context, filter),
                ),
              ),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => Center(child: Text('加载失败: $error')),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAssetTrendSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '资产负债趋势',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: SizedBox(
              height: 400,
              child: const AssetTrendChart(),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryCard(BuildContext context, double income, double expense, double balance, DateRangeFilter dateRange) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Text(
              '${dateRange.label}收支概览',
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
  
  void _navigateToTransactions(BuildContext context, TransactionFilter filter) {
    context.push('/transactions', extra: filter);
  }
}