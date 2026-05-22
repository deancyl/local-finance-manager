import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:database/database.dart';
import 'package:finance_app/features/accounts/data/account_provider.dart';

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

/// Provider for dashboard summary
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

  final transactions = await (db.select(db.transactions)
    ..where((t) =>
        t.postDate.isBiggerOrEqualValue(monthStart.millisecondsSinceEpoch) &
        t.postDate.isSmallerOrEqualValue(monthEnd.millisecondsSinceEpoch)))
      .get();

  // Calculate income and expense
  double monthIncome = 0;
  double monthExpense = 0;

  for (final txn in transactions) {
    final splits = await (db.select(db.splits)
      ..where((s) => s.transactionId.equals(txn.id)))
      .get();

    for (final split in splits) {
      final account = accounts.firstWhere(
        (a) => a.id == split.accountId,
        orElse: () => accounts.first,
      );

      final value = split.valueNum / 100.0;
      if (account.accountType == 'INCOME') {
        monthIncome += value.abs();
      } else if (account.accountType == 'EXPENSE') {
        monthExpense += value.abs();
      }
    }
  }

  return DashboardSummary(
    totalAssets: totalAssets,
    totalLiabilities: totalLiabilities,
    netWorth: totalAssets - totalLiabilities,
    monthIncome: monthIncome,
    monthExpense: monthExpense,
    monthNet: monthIncome - monthExpense,
    transactionCount: transactions.length,
    accountCount: accounts.length,
  );
});

/// Provider for monthly summaries (last 12 months)
final monthlySummariesProvider = FutureProvider<List<MonthlySummary>>((ref) async {
  final db = ref.watch(databaseProvider);
  final summaries = <MonthlySummary>[];

  final now = DateTime.now();

  for (var i = 0; i < 12; i++) {
    final month = DateTime(now.year, now.month - i, 1);
    final monthStart = DateTime(month.year, month.month, 1);
    final monthEnd = DateTime(month.year, month.month + 1, 0);

    final transactions = await (db.select(db.transactions)
      ..where((t) =>
          t.postDate.isBiggerOrEqualValue(monthStart.millisecondsSinceEpoch) &
          t.postDate.isSmallerOrEqualValue(monthEnd.millisecondsSinceEpoch)))
      .get();

    // Calculate income/expense for month
    double income = 0;
    double expense = 0;

    for (final txn in transactions) {
      final splits = await (db.select(db.splits)
        ..where((s) => s.transactionId.equals(txn.id)))
        .get();

      for (final split in splits) {
        final account = await (db.select(db.accounts)
          ..where((a) => a.id.equals(split.accountId)))
          .getSingleOrNull();

        if (account == null) continue;

        final value = split.valueNum / 100.0;
        if (account.accountType == 'INCOME') {
          income += value.abs();
        } else if (account.accountType == 'EXPENSE') {
          expense += value.abs();
        }
      }
    }

    summaries.add(MonthlySummary(
      month: month,
      income: income,
      expense: expense,
    ));
  }

  return summaries;
});
