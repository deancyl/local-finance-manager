import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart' as drift;
import 'package:database/database.dart';
import 'package:finance_app/features/accounts/data/account_provider.dart';
import 'package:finance_app/features/analytics/data/optimized_analytics_queries.dart';

// ============================================================
// DASHBOARD MODELS
// ============================================================

/// Dashboard summary data
class DashboardSummary {
  final double totalAssets;
  final double totalLiabilities;
  final double netWorth;
  final double monthIncome;
  final double monthExpense;
  final double monthNet;
  final int transactionCount;
  final int accountCount;

  const DashboardSummary({
    required this.totalAssets,
    required this.totalLiabilities,
    required this.netWorth,
    required this.monthIncome,
    required this.monthExpense,
    required this.monthNet,
    required this.transactionCount,
    required this.accountCount,
  });
}

/// Monthly summary
class MonthlySummary {
  final DateTime month;
  final double income;
  final double expense;

  const MonthlySummary({
    required this.month,
    required this.income,
    required this.expense,
  });

  double get net => income - expense;
}

// ============================================================
// DASHBOARD PROVIDERS
// ============================================================

/// Provider for dashboard summary - OPTIMIZED with single JOIN query + background isolate
/// Performance improvement: 1 query instead of nested transaction→split→account loops
final dashboardSummaryProvider = FutureProvider<DashboardSummary>((ref) async {
  final db = ref.watch(databaseProvider);

  // Get all accounts
  final accounts = await (db.select(db.accounts)).get();
  final balances = ref.read(accountBalancesProvider);

  // Calculate totals
  double totalAssets = 0;
  double totalLiabilities = 0;

  await balances.when(
    data: (balanceMap) {
      for (final account in accounts) {
        final balance = balanceMap[account.id] ?? 0.0;
        if (account.accountType == 'ASSET') {
          totalAssets += balance;
        } else if (account.accountType == 'LIABILITY') {
          totalLiabilities += balance.abs();
        }
      }
    },
    loading: () {},
    error: (_, __) {},
  );

  // Get this month's transactions
  final now = DateTime.now();
  final monthStart = DateTime(now.year, now.month, 1);
  final monthEnd = DateTime(now.year, now.month + 1, 0);

  // Optimized: Single JOIN query + background compute
  // Replaces: transaction query → loop → splits query → loop → account query
  final results = await getIncomeExpenseOptimized(
    db,
    monthStart.millisecondsSinceEpoch,
    monthEnd.millisecondsSinceEpoch,
  );

  final monthIncome = results['income'] ?? 0.0;
  final monthExpense = results['expense'] ?? 0.0;

  return DashboardSummary(
    totalAssets: totalAssets,
    totalLiabilities: totalLiabilities,
    netWorth: totalAssets - totalLiabilities,
    monthIncome: monthIncome,
    monthExpense: monthExpense,
    monthNet: monthIncome - monthExpense,
    transactionCount: results['expenseCount']?.toInt() ?? 0,
    accountCount: accounts.length,
  );
});

/// Provider for monthly summaries (last 12 months) - OPTIMIZED with single JOIN query
/// Performance improvement: 1 query instead of 12 sequential nested loops (36+ queries)
final monthlySummariesProvider = FutureProvider<List<MonthlySummary>>((ref) async {
  final db = ref.watch(databaseProvider);

  final now = DateTime.now();
  
  // Build month ranges for last 12 months
  final monthStarts = <DateTime>[];
  final monthEnds = <DateTime>[];
  
  for (var i = 0; i < 12; i++) {
    final month = DateTime(now.year, now.month - i, 1);
    final monthStart = DateTime(month.year, month.month, 1);
    final monthEnd = DateTime(month.year, month.month + 1, 0);
    monthStarts.add(monthStart);
    monthEnds.add(monthEnd);
  }

  // Optimized: Single query for all 12 months
  // Replaces: 12 sequential loops with nested transaction→split→account queries
  final results = await getMonthlySpendingData(db, monthStarts, monthEnds);

  // Convert to MonthlySummary objects
  final summaries = results.map((item) {
    final monthIndex = item['monthIndex'] as int;
    final month = DateTime(now.year, now.month - monthIndex, 1);
    
    return MonthlySummary(
      month: month,
      income: item['income'] as double,
      expense: item['expense'] as double,
    );
  }).toList();

  return summaries;
});
