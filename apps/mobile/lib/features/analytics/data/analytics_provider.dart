import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart' as drift;
import 'package:database/database.dart';
import 'package:finance_app/features/accounts/data/account_provider.dart';

// ============================================================
// ANALYTICS MODELS
// ============================================================

/// Spending by category
class CategorySpending {
  final String categoryId;
  final String categoryName;
  final double amount;
  final double percentage;
  final int transactionCount;

  const CategorySpending({
    required this.categoryId,
    required this.categoryName,
    required this.amount,
    required this.percentage,
    required this.transactionCount,
  });
}

/// Spending trend
class SpendingTrend {
  final DateTime period;
  final double amount;
  final double change;
  final double changePercent;

  const SpendingTrend({
    required this.period,
    required this.amount,
    required this.change,
    required this.changePercent,
  });
}

/// Financial insights
class FinancialInsight {
  final String type;
  final String title;
  final String description;
  final double? value;
  final String? recommendation;

  const FinancialInsight({
    required this.type,
    required this.title,
    required this.description,
    this.value,
    this.recommendation,
  });
}

// ============================================================
// ANALYTICS PROVIDERS
// ============================================================

/// Provider for spending by category
final spendingByCategoryProvider =
    FutureProvider.family<List<CategorySpending>, DateTimeRange>((ref, range) async {
  final db = ref.watch(databaseProvider);

  // Get all expense splits in range
  final transactions = await (db.select(db.transactions)
    ..where((t) =>
        t.postDate.isBiggerOrEqualValue(range.start.millisecondsSinceEpoch) &
        t.postDate.isSmallerOrEqualValue(range.end.millisecondsSinceEpoch)))
      .get();

  final categoryTotals = <String?, double>{};
  final categoryCounts = <String?, int>{};
  double totalSpending = 0;

  for (final txn in transactions) {
    final splits = await (db.select(db.splits)
      ..where((s) => s.transactionId.equals(txn.id)))
      .get();

    for (final split in splits) {
      final account = await (db.select(db.accounts)
        ..where((a) => a.id.equals(split.accountId)))
        .getSingleOrNull();

      if (account?.accountType == 'EXPENSE') {
        final amount = split.valueNum.abs() / 100.0;
        categoryTotals[split.categoryId] = (categoryTotals[split.categoryId] ?? 0) + amount;
        categoryCounts[split.categoryId] = (categoryCounts[split.categoryId] ?? 0) + 1;
        totalSpending += amount;
      }
    }
  }

  final result = <CategorySpending>[];

  for (final entry in categoryTotals.entries) {
    final categoryId = entry.key;
    final amount = entry.value;

    String categoryName = '未分类';
    if (categoryId != null) {
      final category = await (db.select(db.categories)
        ..where((c) => c.id.equals(categoryId)))
        .getSingleOrNull();
      categoryName = category?.name ?? '未分类';
    }

    result.add(CategorySpending(
      categoryId: categoryId ?? 'uncategorized',
      categoryName: categoryName,
      amount: amount,
      percentage: totalSpending > 0 ? (amount / totalSpending) * 100 : 0,
      transactionCount: categoryCounts[categoryId] ?? 0,
    ));
  }

  result.sort((a, b) => b.amount.compareTo(a.amount));
  return result;
});

/// Provider for spending trends (by week)
final spendingTrendsProvider = FutureProvider<List<SpendingTrend>>((ref) async {
  final db = ref.watch(databaseProvider);
  final now = DateTime.now();
  final trends = <SpendingTrend>[];

  for (var i = 0; i < 12; i++) {
    final weekEnd = now.subtract(Duration(days: i * 7));
    final weekStart = weekEnd.subtract(const Duration(days: 7));

    // Calculate spending for this week
    final transactions = await (db.select(db.transactions)
      ..where((t) =>
          t.postDate.isBiggerOrEqualValue(weekStart.millisecondsSinceEpoch) &
          t.postDate.isSmallerOrEqualValue(weekEnd.millisecondsSinceEpoch)))
        .get();

    double weekSpending = 0;

    for (final txn in transactions) {
      final splits = await (db.select(db.splits)
        ..where((s) => s.transactionId.equals(txn.id)))
        .get();

      for (final split in splits) {
        final account = await (db.select(db.accounts)
          ..where((a) => a.id.equals(split.accountId)))
          .getSingleOrNull();

        if (account?.accountType == 'EXPENSE') {
          weekSpending += split.valueNum.abs() / 100.0;
        }
      }
    }

    trends.add(SpendingTrend(
      period: weekStart,
      amount: weekSpending,
      change: 0,
      changePercent: 0,
    ));
  }

  // Calculate changes
  for (var i = 0; i < trends.length - 1; i++) {
    final current = trends[i];
    final previous = trends[i + 1];
    final change = current.amount - previous.amount;
    final changePercent = previous.amount > 0
        ? (change / previous.amount) * 100
        : 0;

    trends[i] = SpendingTrend(
      period: current.period,
      amount: current.amount,
      change: change,
      changePercent: changePercent,
    );
  }

  return trends.reversed.toList();
});

/// Provider for financial insights
final financialInsightsProvider = FutureProvider<List<FinancialInsight>>((ref) async {
  final db = ref.watch(databaseProvider);
  final insights = <FinancialInsight>[];

  // Get recent spending
  final now = DateTime.now();
  final monthStart = DateTime(now.year, now.month, 1);

  final transactions = await (db.select(db.transactions)
    ..where((t) =>
        t.postDate.isBiggerOrEqualValue(monthStart.millisecondsSinceEpoch)))
      .get();

  // Analyze spending patterns
  int expenseCount = 0;
  double totalExpense = 0;

  for (final txn in transactions) {
    final splits = await (db.select(db.splits)
      ..where((s) => s.transactionId.equals(txn.id)))
      .get();

    for (final split in splits) {
      final account = await (db.select(db.accounts)
        ..where((a) => a.id.equals(split.accountId)))
        .getSingleOrNull();

      if (account?.accountType == 'EXPENSE') {
        expenseCount++;
        totalExpense += split.valueNum.abs() / 100.0;
      }
    }
  }

  // Add insights based on patterns
  if (expenseCount > 0) {
    final avgExpense = totalExpense / expenseCount;
    insights.add(FinancialInsight(
      type: 'spending_average',
      title: '平均支出',
      description: '本月平均每笔支出 ¥${avgExpense.toStringAsFixed(2)}',
      value: avgExpense,
    ));
  }

  if (totalExpense > 10000) {
    insights.add(FinancialInsight(
      type: 'high_spending',
      title: '支出较高',
      description: '本月支出已超过 ¥10,000',
      value: totalExpense,
      recommendation: '建议检查大额支出项目',
    ));
  }

  return insights;
});

/// DateTime range helper
class DateTimeRange {
  final DateTime start;
  final DateTime end;

  const DateTimeRange({required this.start, required this.end});
}
