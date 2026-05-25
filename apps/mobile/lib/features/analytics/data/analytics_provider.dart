import 'package:flutter/material.dart';
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
      changePercent: changePercent.toDouble(),
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

// ============================================================
// ADDITIONAL ANALYTICS MODELS FOR v0.3.110
// ============================================================

/// Monthly savings rate data
class MonthlySavingsRate {
  final DateTime month;
  final double income;
  final double expense;
  final double savings;
  final double savingsRate; // percentage

  const MonthlySavingsRate({
    required this.month,
    required this.income,
    required this.expense,
    required this.savings,
    required this.savingsRate,
  });
}

/// Expense ratio breakdown
class ExpenseRatio {
  final String categoryName;
  final double amount;
  final double percentage;
  final Color color;

  const ExpenseRatio({
    required this.categoryName,
    required this.amount,
    required this.percentage,
    required this.color,
  });
}

/// Period comparison data
class PeriodComparison {
  final double currentAmount;
  final double previousAmount;
  final double change;
  final double changePercent;
  final String periodLabel;

  const PeriodComparison({
    required this.currentAmount,
    required this.previousAmount,
    required this.change,
    required this.changePercent,
    required this.periodLabel,
  });
}

/// Financial goal progress
class GoalProgress {
  final String goalId;
  final String goalName;
  final double targetAmount;
  final double currentAmount;
  final double progress;
  final DateTime targetDate;
  final bool isOnTrack;

  const GoalProgress({
    required this.goalId,
    required this.goalName,
    required this.targetAmount,
    required this.currentAmount,
    required this.progress,
    required this.targetDate,
    required this.isOnTrack,
  });
}

/// Spending anomaly
class SpendingAnomaly {
  final String type;
  final String category;
  final double expectedAmount;
  final double actualAmount;
  final double deviationPercent;
  final String description;
  final DateTime detectedAt;

  const SpendingAnomaly({
    required this.type,
    required this.category,
    required this.expectedAmount,
    required this.actualAmount,
    required this.deviationPercent,
    required this.description,
    required this.detectedAt,
  });
}

/// Income source breakdown
class IncomeSource {
  final String source;
  final double amount;
  final double percentage;
  final int transactionCount;

  const IncomeSource({
    required this.source,
    required this.amount,
    required this.percentage,
    required this.transactionCount,
  });
}

// ============================================================
// ADDITIONAL ANALYTICS PROVIDERS FOR v0.3.110
// ============================================================

/// Provider for monthly savings rate
final monthlySavingsRateProvider = FutureProvider<MonthlySavingsRate>((ref) async {
  final db = ref.watch(databaseProvider);
  final now = DateTime.now();
  final monthStart = DateTime(now.year, now.month, 1);
  final monthEnd = DateTime(now.year, now.month + 1, 0);

  final transactions = await (db.select(db.transactions)
    ..where((t) =>
        t.postDate.isBiggerOrEqualValue(monthStart.millisecondsSinceEpoch) &
        t.postDate.isSmallerOrEqualValue(monthEnd.millisecondsSinceEpoch)))
      .get();

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

      if (account?.accountType == 'INCOME') {
        income += split.valueNum.abs() / 100.0;
      } else if (account?.accountType == 'EXPENSE') {
        expense += split.valueNum.abs() / 100.0;
      }
    }
  }

  final savings = income - expense;
  final savingsRate = income > 0 ? (savings / income) * 100 : 0;

  return MonthlySavingsRate(
    month: monthStart,
    income: income,
    expense: expense,
    savings: savings,
    savingsRate: savingsRate.toDouble(),
  );
});

/// Provider for expense ratio breakdown
final expenseRatioProvider = FutureProvider<List<ExpenseRatio>>((ref) async {
  final now = DateTime.now();
  final monthStart = DateTime(now.year, now.month, 1);
  final range = DateTimeRange(start: monthStart, end: now);

  final categorySpending = await ref.watch(spendingByCategoryProvider(range).future);

  final colors = [
    const Color(0xFF4CAF50),
    const Color(0xFF2196F3),
    const Color(0xFFFF9800),
    const Color(0xFF9C27B0),
    const Color(0xFFF44336),
    const Color(0xFF00BCD4),
    const Color(0xFFFFEB3B),
    const Color(0xFF795548),
  ];

  return categorySpending.asMap().entries.map((entry) {
    final index = entry.key;
    final spending = entry.value;
    return ExpenseRatio(
      categoryName: spending.categoryName,
      amount: spending.amount,
      percentage: spending.percentage,
      color: colors[index % colors.length],
    );
  }).toList();
});

/// Provider for period comparison (this month vs last month)
final monthComparisonProvider = FutureProvider<PeriodComparison>((ref) async {
  final db = ref.watch(databaseProvider);
  final now = DateTime.now();

  // This month
  final thisMonthStart = DateTime(now.year, now.month, 1);
  final thisMonthEnd = DateTime(now.year, now.month + 1, 0);

  // Last month
  final lastMonthStart = DateTime(now.year, now.month - 1, 1);
  final lastMonthEnd = DateTime(now.year, now.month, 0);

  double thisMonthExpense = 0;
  double lastMonthExpense = 0;

  // Calculate this month expense
  final thisMonthTxns = await (db.select(db.transactions)
    ..where((t) =>
        t.postDate.isBiggerOrEqualValue(thisMonthStart.millisecondsSinceEpoch) &
        t.postDate.isSmallerOrEqualValue(thisMonthEnd.millisecondsSinceEpoch)))
      .get();

  for (final txn in thisMonthTxns) {
    final splits = await (db.select(db.splits)
      ..where((s) => s.transactionId.equals(txn.id)))
      .get();

    for (final split in splits) {
      final account = await (db.select(db.accounts)
        ..where((a) => a.id.equals(split.accountId)))
        .getSingleOrNull();

      if (account?.accountType == 'EXPENSE') {
        thisMonthExpense += split.valueNum.abs() / 100.0;
      }
    }
  }

  // Calculate last month expense
  final lastMonthTxns = await (db.select(db.transactions)
    ..where((t) =>
        t.postDate.isBiggerOrEqualValue(lastMonthStart.millisecondsSinceEpoch) &
        t.postDate.isSmallerOrEqualValue(lastMonthEnd.millisecondsSinceEpoch)))
      .get();

  for (final txn in lastMonthTxns) {
    final splits = await (db.select(db.splits)
      ..where((s) => s.transactionId.equals(txn.id)))
      .get();

    for (final split in splits) {
      final account = await (db.select(db.accounts)
        ..where((a) => a.id.equals(split.accountId)))
        .getSingleOrNull();

      if (account?.accountType == 'EXPENSE') {
        lastMonthExpense += split.valueNum.abs() / 100.0;
      }
    }
  }

  final change = thisMonthExpense - lastMonthExpense;
  final changePercent = lastMonthExpense > 0 ? (change / lastMonthExpense) * 100 : 0;

  return PeriodComparison(
    currentAmount: thisMonthExpense,
    previousAmount: lastMonthExpense,
    change: change,
    changePercent: changePercent.toDouble(),
    periodLabel: '本月 vs 上月',
  );
});

/// Provider for year comparison (this year vs last year)
final yearComparisonProvider = FutureProvider<PeriodComparison>((ref) async {
  final db = ref.watch(databaseProvider);
  final now = DateTime.now();

  // This year
  final thisYearStart = DateTime(now.year, 1, 1);
  final thisYearEnd = DateTime(now.year, 12, 31);

  // Last year
  final lastYearStart = DateTime(now.year - 1, 1, 1);
  final lastYearEnd = DateTime(now.year - 1, 12, 31);

  double thisYearExpense = 0;
  double lastYearExpense = 0;

  // Calculate this year expense
  final thisYearTxns = await (db.select(db.transactions)
    ..where((t) =>
        t.postDate.isBiggerOrEqualValue(thisYearStart.millisecondsSinceEpoch) &
        t.postDate.isSmallerOrEqualValue(thisYearEnd.millisecondsSinceEpoch)))
      .get();

  for (final txn in thisYearTxns) {
    final splits = await (db.select(db.splits)
      ..where((s) => s.transactionId.equals(txn.id)))
      .get();

    for (final split in splits) {
      final account = await (db.select(db.accounts)
        ..where((a) => a.id.equals(split.accountId)))
        .getSingleOrNull();

      if (account?.accountType == 'EXPENSE') {
        thisYearExpense += split.valueNum.abs() / 100.0;
      }
    }
  }

  // Calculate last year expense
  final lastYearTxns = await (db.select(db.transactions)
    ..where((t) =>
        t.postDate.isBiggerOrEqualValue(lastYearStart.millisecondsSinceEpoch) &
        t.postDate.isSmallerOrEqualValue(lastYearEnd.millisecondsSinceEpoch)))
      .get();

  for (final txn in lastYearTxns) {
    final splits = await (db.select(db.splits)
      ..where((s) => s.transactionId.equals(txn.id)))
      .get();

    for (final split in splits) {
      final account = await (db.select(db.accounts)
        ..where((a) => a.id.equals(split.accountId)))
        .getSingleOrNull();

      if (account?.accountType == 'EXPENSE') {
        lastYearExpense += split.valueNum.abs() / 100.0;
      }
    }
  }

  final change = thisYearExpense - lastYearExpense;
  final changePercent = lastYearExpense > 0 ? (change / lastYearExpense) * 100 : 0;

  return PeriodComparison(
    currentAmount: thisYearExpense,
    previousAmount: lastYearExpense,
    change: change,
    changePercent: changePercent.toDouble(),
    periodLabel: '今年 vs 去年',
  );
});

/// Provider for spending anomalies
final spendingAnomaliesProvider = FutureProvider<List<SpendingAnomaly>>((ref) async {
  final db = ref.watch(databaseProvider);
  final anomalies = <SpendingAnomaly>[];
  final now = DateTime.now();

  // Get this month and last 3 months data for comparison
  final thisMonthStart = DateTime(now.year, now.month, 1);
  final threeMonthsAgo = DateTime(now.year, now.month - 3, 1);

  // Get all categories
  final categories = await (db.select(db.categories)).get();

  for (final category in categories) {
    // Calculate average monthly spending for this category (last 3 months)
    double totalSpending = 0;
    int monthCount = 0;

    for (var i = 1; i <= 3; i++) {
      final monthStart = DateTime(now.year, now.month - i, 1);
      final monthEnd = DateTime(now.year, now.month - i + 1, 0);

      final transactions = await (db.select(db.transactions)
        ..where((t) =>
            t.postDate.isBiggerOrEqualValue(monthStart.millisecondsSinceEpoch) &
            t.postDate.isSmallerOrEqualValue(monthEnd.millisecondsSinceEpoch)))
          .get();

      double monthSpending = 0;

      for (final txn in transactions) {
        final splits = await (db.select(db.splits)
          ..where((s) =>
              s.transactionId.equals(txn.id) &
              s.categoryId.equals(category.id)))
          .get();

        for (final split in splits) {
          final account = await (db.select(db.accounts)
            ..where((a) => a.id.equals(split.accountId)))
            .getSingleOrNull();

          if (account?.accountType == 'EXPENSE') {
            monthSpending += split.valueNum.abs() / 100.0;
          }
        }
      }

      if (monthSpending > 0) {
        totalSpending += monthSpending;
        monthCount++;
      }
    }

    final avgMonthlySpending = monthCount > 0 ? totalSpending / monthCount : 0;

    // Get this month's spending for this category
    final thisMonthTxns = await (db.select(db.transactions)
      ..where((t) =>
          t.postDate.isBiggerOrEqualValue(thisMonthStart.millisecondsSinceEpoch)))
        .get();

    double thisMonthSpending = 0;

    for (final txn in thisMonthTxns) {
      final splits = await (db.select(db.splits)
        ..where((s) =>
            s.transactionId.equals(txn.id) &
            s.categoryId.equals(category.id)))
        .get();

      for (final split in splits) {
        final account = await (db.select(db.accounts)
          ..where((a) => a.id.equals(split.accountId)))
          .getSingleOrNull();

        if (account?.accountType == 'EXPENSE') {
          thisMonthSpending += split.valueNum.abs() / 100.0;
        }
      }
    }

    // Detect anomaly: spending is 50% higher than average
    if (avgMonthlySpending > 0 && thisMonthSpending > avgMonthlySpending * 1.5) {
      final deviation = ((thisMonthSpending - avgMonthlySpending) / avgMonthlySpending) * 100;

      anomalies.add(SpendingAnomaly(
        type: 'high_spending',
        category: category.name,
        expectedAmount: avgMonthlySpending.toDouble(),
        actualAmount: thisMonthSpending.toDouble(),
        deviationPercent: deviation.toDouble(),
        description: '${category.name}支出比月均高出${deviation.toStringAsFixed(0)}%',
        detectedAt: now,
      ));
    }
  }

  anomalies.sort((a, b) => b.deviationPercent.compareTo(a.deviationPercent));
  return anomalies;
});

/// Provider for income sources
final incomeSourcesProvider = FutureProvider<List<IncomeSource>>((ref) async {
  final db = ref.watch(databaseProvider);
  final now = DateTime.now();
  final monthStart = DateTime(now.year, now.month, 1);

  final transactions = await (db.select(db.transactions)
    ..where((t) =>
        t.postDate.isBiggerOrEqualValue(monthStart.millisecondsSinceEpoch)))
      .get();

  final sourceTotals = <String, double>{};
  final sourceCounts = <String, int>{};
  double totalIncome = 0;

  for (final txn in transactions) {
    final splits = await (db.select(db.splits)
      ..where((s) => s.transactionId.equals(txn.id)))
      .get();

    for (final split in splits) {
      final account = await (db.select(db.accounts)
        ..where((a) => a.id.equals(split.accountId)))
        .getSingleOrNull();

      if (account?.accountType == 'INCOME') {
        final source = account!.name;
        final amount = split.valueNum.abs() / 100.0;
        sourceTotals[source] = (sourceTotals[source] ?? 0) + amount;
        sourceCounts[source] = (sourceCounts[source] ?? 0) + 1;
        totalIncome += amount;
      }
    }
  }

  final result = sourceTotals.entries.map((entry) {
    return IncomeSource(
      source: entry.key,
      amount: entry.value,
      percentage: totalIncome > 0 ? (entry.value / totalIncome) * 100 : 0,
      transactionCount: sourceCounts[entry.key] ?? 0,
    );
  }).toList();

  result.sort((a, b) => b.amount.compareTo(a.amount));
  return result;
});

/// Provider for financial goals progress (placeholder - would need goals table)
final goalProgressProvider = FutureProvider<List<GoalProgress>>((ref) async {
  // This is a placeholder implementation
  // In a real app, you would have a goals table and track progress
  // For now, return empty list
  return [];
});
