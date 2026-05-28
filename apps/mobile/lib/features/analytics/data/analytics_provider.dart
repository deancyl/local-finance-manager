import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart' as drift;
import 'package:database/database.dart';
import 'package:finance_app/features/accounts/data/account_provider.dart';
import 'optimized_analytics_queries.dart';

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

/// Provider for spending by category (OPTIMIZED with JOIN + background isolate)
/// Performance improvement: O(n) single query instead of O(n*m*k) nested loops
final spendingByCategoryProvider =
    FutureProvider.family<List<CategorySpending>, DateTimeRange>((ref, range) async {
  final db = ref.watch(databaseProvider);

  // Optimized: Single JOIN query + background compute
  // Replaces: transaction query → loop → splits query → loop → account query (50+ queries)
  final results = await getSpendingByCategoryOptimized(
    db,
    range.start.millisecondsSinceEpoch,
    range.end.millisecondsSinceEpoch,
  );

  return results.map((item) => CategorySpending(
    categoryId: item['categoryId'] as String,
    categoryName: item['categoryName'] as String,
    amount: item['amount'] as double,
    percentage: item['percentage'] as double,
    transactionCount: item['transactionCount'] as int,
  )).toList();
});

/// Provider for spending trends (by week) - OPTIMIZED with parallel queries + background isolate
/// Performance improvement: 12 parallel queries + background compute instead of 12 sequential nested loops
final spendingTrendsProvider = FutureProvider<List<SpendingTrend>>((ref) async {
  final db = ref.watch(databaseProvider);
  final now = DateTime.now();

  // Optimized: 12 parallel queries + background compute
  // Replaces: 12 sequential loops with nested queries (36+ queries)
  final results = await getSpendingTrendsOptimized(db, now);

  // Convert results to SpendingTrend objects
  final trends = results.reversed.map((item) {
    final index = item['index'] as int;
    final period = now.subtract(Duration(days: index * 7)).subtract(const Duration(days: 7));
    
    return SpendingTrend(
      period: period,
      amount: item['amount'] as double,
      change: item['change'] as double,
      changePercent: item['changePercent'] as double,
    );
  }).toList();

  return trends;
});

/// Provider for financial insights - OPTIMIZED with single JOIN query + background isolate
/// Performance improvement: 1 query instead of nested transaction→split→account loops
final financialInsightsProvider = FutureProvider<List<FinancialInsight>>((ref) async {
  final db = ref.watch(databaseProvider);
  final insights = <FinancialInsight>[];

  // Get recent spending
  final now = DateTime.now();
  final monthStart = DateTime(now.year, now.month, 1);

  // Optimized: Single JOIN query + background compute
  final results = await getIncomeExpenseOptimized(
    db,
    monthStart.millisecondsSinceEpoch,
    now.millisecondsSinceEpoch,
  );

  final expenseCount = results['expenseCount']?.toInt() ?? 0;
  final totalExpense = results['expense'] ?? 0.0;

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

/// Provider for monthly savings rate - OPTIMIZED with single JOIN query + background isolate
/// Performance improvement: 1 query instead of nested transaction→split→account loops
final monthlySavingsRateProvider = FutureProvider<MonthlySavingsRate>((ref) async {
  final db = ref.watch(databaseProvider);
  final now = DateTime.now();
  final monthStart = DateTime(now.year, now.month, 1);
  final monthEnd = DateTime(now.year, now.month + 1, 0);

  // Optimized: Single JOIN query + background compute
  final results = await getIncomeExpenseOptimized(
    db,
    monthStart.millisecondsSinceEpoch,
    monthEnd.millisecondsSinceEpoch,
  );

  final income = results['income'] ?? 0.0;
  final expense = results['expense'] ?? 0.0;
  final savings = income - expense;
  final savingsRate = income > 0 ? (savings / income) * 100 : 0.0;

  return MonthlySavingsRate(
    month: monthStart,
    income: income,
    expense: expense,
    savings: savings,
    savingsRate: savingsRate,
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

/// Provider for period comparison (this month vs last month) - OPTIMIZED with parallel JOIN queries
/// Performance improvement: 2 parallel queries instead of nested loops
final monthComparisonProvider = FutureProvider<PeriodComparison>((ref) async {
  final db = ref.watch(databaseProvider);
  final now = DateTime.now();

  // This month
  final thisMonthStart = DateTime(now.year, now.month, 1);
  final thisMonthEnd = DateTime(now.year, now.month + 1, 0);

  // Last month
  final lastMonthStart = DateTime(now.year, now.month - 1, 1);
  final lastMonthEnd = DateTime(now.year, now.month, 0);

  // Optimized: 2 parallel queries instead of nested loops
  final results = await Future.wait([
    getIncomeExpenseOptimized(
      db,
      thisMonthStart.millisecondsSinceEpoch,
      thisMonthEnd.millisecondsSinceEpoch,
    ),
    getIncomeExpenseOptimized(
      db,
      lastMonthStart.millisecondsSinceEpoch,
      lastMonthEnd.millisecondsSinceEpoch,
    ),
  ]);

  final thisMonthExpense = results[0]['expense'] ?? 0.0;
  final lastMonthExpense = results[1]['expense'] ?? 0.0;
  final change = thisMonthExpense - lastMonthExpense;
  final changePercent = lastMonthExpense > 0 ? (change / lastMonthExpense) * 100 : 0.0;

  return PeriodComparison(
    currentAmount: thisMonthExpense,
    previousAmount: lastMonthExpense,
    change: change,
    changePercent: changePercent,
    periodLabel: '本月 vs 上月',
  );
});

/// Provider for year comparison (this year vs last year) - OPTIMIZED with parallel JOIN queries
/// Performance improvement: 2 parallel queries instead of nested loops
final yearComparisonProvider = FutureProvider<PeriodComparison>((ref) async {
  final db = ref.watch(databaseProvider);
  final now = DateTime.now();

  // This year
  final thisYearStart = DateTime(now.year, 1, 1);
  final thisYearEnd = DateTime(now.year, 12, 31);

  // Last year
  final lastYearStart = DateTime(now.year - 1, 1, 1);
  final lastYearEnd = DateTime(now.year - 1, 12, 31);

  // Optimized: 2 parallel queries instead of nested loops
  final results = await Future.wait([
    getIncomeExpenseOptimized(
      db,
      thisYearStart.millisecondsSinceEpoch,
      thisYearEnd.millisecondsSinceEpoch,
    ),
    getIncomeExpenseOptimized(
      db,
      lastYearStart.millisecondsSinceEpoch,
      lastYearEnd.millisecondsSinceEpoch,
    ),
  ]);

  final thisYearExpense = results[0]['expense'] ?? 0.0;
  final lastYearExpense = results[1]['expense'] ?? 0.0;
  final change = thisYearExpense - lastYearExpense;
  final changePercent = lastYearExpense > 0 ? (change / lastYearExpense) * 100 : 0.0;

  return PeriodComparison(
    currentAmount: thisYearExpense,
    previousAmount: lastYearExpense,
    change: change,
    changePercent: changePercent,
    periodLabel: '今年 vs 去年',
  );
});

/// Provider for spending anomalies - OPTIMIZED with single JOIN query for all categories/months
/// Performance improvement: 1 query instead of categories→months→transactions→splits→accounts loops (100+ queries)
final spendingAnomaliesProvider = FutureProvider<List<SpendingAnomaly>>((ref) async {
  final db = ref.watch(databaseProvider);
  final anomalies = <SpendingAnomaly>[];
  final now = DateTime.now();

  // Build month ranges: this month + last 3 months
  final thisMonthStart = DateTime(now.year, now.month, 1);
  final monthRanges = <DateTime>[];
  final monthEnds = <DateTime>[];
  
  for (var i = 0; i <= 3; i++) {
    final monthStart = DateTime(now.year, now.month - i, 1);
    final monthEnd = DateTime(now.year, now.month - i + 1, 0);
    monthRanges.add(monthStart);
    monthEnds.add(monthEnd);
  }

  // Optimized: Single query gets all category spending across all months
  // Replaces: nested loops through categories → months → transactions → splits → accounts
  final categoryData = await getCategorySpendingForMonths(db, monthRanges, monthEnds);

  for (final categoryEntry in categoryData) {
    final categoryId = categoryEntry['categoryId'] as String;
    final categoryName = categoryEntry['categoryName'] as String;
    final monthlySpending = categoryEntry['monthlySpending'] as Map<String, dynamic>;

    // Calculate average monthly spending (last 3 months, index 1-3)
    double totalSpending = 0;
    int monthCount = 0;
    
    for (var i = 1; i <= 3; i++) {
      final spending = monthlySpending[i.toString()] as double?;
      if (spending != null && spending > 0) {
        totalSpending += spending;
        monthCount++;
      }
    }

    final avgMonthlySpending = monthCount > 0 ? totalSpending / monthCount : 0.0;
    
    // Get this month's spending (index 0)
    final thisMonthSpending = monthlySpending['0'] as double? ?? 0.0;

    // Detect anomaly: spending is 50% higher than average
    if (avgMonthlySpending > 0 && thisMonthSpending > avgMonthlySpending * 1.5) {
      final deviation = ((thisMonthSpending - avgMonthlySpending) / avgMonthlySpending) * 100;

      anomalies.add(SpendingAnomaly(
        type: 'high_spending',
        category: categoryName,
        expectedAmount: avgMonthlySpending,
        actualAmount: thisMonthSpending,
        deviationPercent: deviation,
        description: '$categoryName支出比月均高出${deviation.toStringAsFixed(0)}%',
        detectedAt: now,
      ));
    }
  }

  anomalies.sort((a, b) => b.deviationPercent.compareTo(a.deviationPercent));
  return anomalies;
});

/// Provider for income sources - OPTIMIZED with single JOIN query + background isolate
/// Performance improvement: 1 query instead of nested transaction→split→account loops
final incomeSourcesProvider = FutureProvider<List<IncomeSource>>((ref) async {
  final db = ref.watch(databaseProvider);
  final now = DateTime.now();
  final monthStart = DateTime(now.year, now.month, 1);

  // Optimized: Single JOIN query + background compute
  final results = await getIncomeSourcesOptimized(
    db,
    monthStart.millisecondsSinceEpoch,
    now.millisecondsSinceEpoch,
  );

  return results.map((item) => IncomeSource(
    source: item['source'] as String,
    amount: item['amount'] as double,
    percentage: item['percentage'] as double,
    transactionCount: item['transactionCount'] as int,
  )).toList();
});

/// Provider for financial goals progress (placeholder - would need goals table)
final goalProgressProvider = FutureProvider<List<GoalProgress>>((ref) async {
  // This is a placeholder implementation
  // In a real app, you would have a goals table and track progress
  // For now, return empty list
  return [];
});
