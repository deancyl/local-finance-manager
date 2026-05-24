import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:drift/drift.dart' as drift;
import 'package:database/database.dart' as db;
import '../../data/cost_center_provider.dart';
import 'package:finance_app/features/accounts/data/account_provider.dart';

/// Provider for cost center report date range
final costCenterReportStartDateProvider = StateProvider<DateTime>((ref) {
  final now = DateTime.now();
  return DateTime(now.year, now.month, 1); // First day of current month
});

final costCenterReportEndDateProvider = StateProvider<DateTime>((ref) {
  return DateTime.now();
});

/// Model for cost center expense summary
class CostCenterExpense {
  final String costCenterId;
  final String costCenterName;
  final double totalDebit;
  final double totalCredit;
  final int transactionCount;

  const CostCenterExpense({
    required this.costCenterId,
    required this.costCenterName,
    this.totalDebit = 0,
    this.totalCredit = 0,
    this.transactionCount = 0,
  });

  double get netExpense => totalDebit - totalCredit;
}

/// Provider for cost center expense report
final costCenterExpenseReportProvider = FutureProvider<List<CostCenterExpense>>((ref) async {
  final db = ref.watch(databaseProvider);
  final startDate = ref.watch(costCenterReportStartDateProvider);
  final endDate = ref.watch(costCenterReportEndDateProvider);
  final costCenters = ref.watch(activeCostCentersProvider);

  final startTs = startDate.millisecondsSinceEpoch;
  final endTs = endDate.millisecondsSinceEpoch;

  // Query splits with cost center, grouped by cost center
  // Join with transactions to filter by date
  final query = db.select(db.splits).join([
    drift.innerJoin(db.transactions, db.transactions.id.equalsExp(db.splits.transactionId)),
  ])
    ..where(db.splits.costCenterId.isNotNull() &
            db.transactions.postDate.isBiggerOrEqualValue(startTs) &
            db.transactions.postDate.isSmallerOrEqualValue(endTs));

  final results = await query.get();

  // Group by cost center
  final Map<String, List<db.Split>> groupedSplits = {};
  for (final row in results) {
    final split = row.readTable(database.splits);
    final costCenterId = split.costCenterId;
    if (costCenterId != null) {
      groupedSplits.putIfAbsent(costCenterId, () => []).add(split);
    }
  }

  // Build expense list
  final expenses = <CostCenterExpense>[];
  for (final cc in costCenters) {
    final splits = groupedSplits[cc.id] ?? [];
    double totalDebit = 0;
    double totalCredit = 0;
    
    for (final split in splits) {
      final value = split.valueNum / split.valueDenom.toDouble();
      if (value < 0) {
        totalDebit += value.abs();
      } else {
        totalCredit += value;
      }
    }

    expenses.add(CostCenterExpense(
      costCenterId: cc.id,
      costCenterName: cc.name,
      totalDebit: totalDebit,
      totalCredit: totalCredit,
      transactionCount: splits.length,
    ));
  }

  // Sort by net expense (descending)
  expenses.sort((a, b) => b.netExpense.compareTo(a.netExpense));

  return expenses;
});

/// Cost Center Report Page
class CostCenterReportPage extends ConsumerWidget {
  const CostCenterReportPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reportAsync = ref.watch(costCenterExpenseReportProvider);
    final startDate = ref.watch(costCenterReportStartDateProvider);
    final endDate = ref.watch(costCenterReportEndDateProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('成本中心报表'),
        actions: [
          IconButton(
            icon: const Icon(Icons.date_range),
            onPressed: () => _showDateRangeDialog(context, ref),
            tooltip: '选择日期范围',
          ),
        ],
      ),
      body: Column(
        children: [
          // Date range header
          _buildDateRangeHeader(context, startDate, endDate),
          
          // Report content
          Expanded(
            child: reportAsync.when(
              data: (expenses) {
                if (expenses.isEmpty) {
                  return _buildEmptyState(context);
                }
                return _buildReportList(context, ref, expenses);
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, stack) => Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline, size: 64, color: Colors.red),
                    const SizedBox(height: 16),
                    Text('加载失败: $error'),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDateRangeHeader(BuildContext context, DateTime startDate, DateTime endDate) {
    final dateFormat = DateFormat('yyyy-MM-dd');
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer,
        border: Border(
          bottom: BorderSide(
            color: Theme.of(context).colorScheme.outlineVariant,
          ),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.date_range,
            color: Theme.of(context).colorScheme.onPrimaryContainer,
          ),
          const SizedBox(width: 8),
          Text(
            '${dateFormat.format(startDate)} 至 ${dateFormat.format(endDate)}',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: Theme.of(context).colorScheme.onPrimaryContainer,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.pie_chart_outline,
            size: 64,
            color: Theme.of(context).colorScheme.outline,
          ),
          const SizedBox(height: 16),
          Text(
            '暂无成本中心数据',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Text(
            '请先在交易分录中分配成本中心',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.outline,
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildReportList(
    BuildContext context,
    WidgetRef ref,
    List<CostCenterExpense> expenses,
  ) {
    final currencyFormat = NumberFormat.currency(symbol: '¥', decimalDigits: 2);
    
    // Calculate total
    final totalExpense = expenses.fold<double>(0, (sum, e) => sum + e.netExpense);

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: expenses.length + 1, // +1 for summary card
      itemBuilder: (context, index) {
        if (index == 0) {
          // Summary card
          return Card(
            color: Theme.of(context).colorScheme.primaryContainer,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '总费用汇总',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onPrimaryContainer,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    currencyFormat.format(totalExpense),
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onPrimaryContainer,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '共 ${expenses.length} 个成本中心',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onPrimaryContainer,
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        final expense = expenses[index - 1];
        final percentage = totalExpense > 0 ? (expense.netExpense / totalExpense * 100) : 0.0;

        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: Theme.of(context).colorScheme.secondaryContainer,
              child: Text(
                expense.costCenterName.substring(0, 1),
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSecondaryContainer,
                ),
              ),
            ),
            title: Text(expense.costCenterName),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 4),
                Row(
                  children: [
                    Expanded(
                      child: LinearProgressIndicator(
                        value: percentage / 100,
                        backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${percentage.toStringAsFixed(1)}%',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  '${expense.transactionCount} 笔交易',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.outline,
                  ),
                ),
              ],
            ),
            trailing: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  currencyFormat.format(expense.netExpense),
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (expense.totalCredit > 0)
                  Text(
                    '贷: ${currencyFormat.format(expense.totalCredit)}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.outline,
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showDateRangeDialog(BuildContext context, WidgetRef ref) async {
    final startDate = ref.read(costCenterReportStartDateProvider);
    final endDate = ref.read(costCenterReportEndDateProvider);

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('选择日期范围'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: const Text('开始日期'),
              subtitle: Text(DateFormat('yyyy-MM-dd').format(startDate)),
              trailing: const Icon(Icons.calendar_today),
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: startDate,
                  firstDate: DateTime(2000),
                  lastDate: DateTime.now(),
                );
                if (picked != null) {
                  ref.read(costCenterReportStartDateProvider.notifier).state = picked;
                }
              },
            ),
            ListTile(
              title: const Text('结束日期'),
              subtitle: Text(DateFormat('yyyy-MM-dd').format(endDate)),
              trailing: const Icon(Icons.calendar_today),
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: endDate,
                  firstDate: DateTime(2000),
                  lastDate: DateTime.now(),
                );
                if (picked != null) {
                  ref.read(costCenterReportEndDateProvider.notifier).state = picked;
                }
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () {
              ref.invalidate(costCenterExpenseReportProvider);
              Navigator.pop(context);
            },
            child: const Text('应用'),
          ),
        ],
      ),
    );
  }
}
