import 'package:flutter/foundation.dart';
import 'package:drift/drift.dart' as drift;
import 'package:database/database.dart';

// ============================================================
// OPTIMIZED QUERY DATA STRUCTURES
// ============================================================

/// Raw data for spending calculation (from JOIN query)
class SpendingRawData {
  final String? categoryId;
  final String accountType;
  final int valueNum;

  const SpendingRawData({
    required this.categoryId,
    required this.accountType,
    required this.valueNum,
  });
}

/// Raw data for period spending (from JOIN query)
class PeriodSpendingRawData {
  final String accountType;
  final int valueNum;

  const PeriodSpendingRawData({
    required this.accountType,
    required this.valueNum,
  });
}

/// Raw data for category spending with category name (from JOIN query)
class CategorySpendingRawData {
  final String? categoryId;
  final String? categoryName;
  final String accountType;
  final int valueNum;

  const CategorySpendingRawData({
    required this.categoryId,
    required this.categoryName,
    required this.accountType,
    required this.valueNum,
  });
}

// ============================================================
// OPTIMIZED JOIN QUERIES
// ============================================================

/// Optimized query: Get all expense splits with account type in date range
/// Replaces: transaction query → loop → splits query → loop → account query
/// Performance: O(n) instead of O(n * m * k)
Future<List<SpendingRawData>> getExpenseSplitsInRange(
  LocalFinanceDatabase db,
  int startDateMs,
  int endDateMs,
) async {
  // Single JOIN query instead of nested loops
  final query = db.selectOnly(db.splits).join([
    drift.innerJoin(
      db.transactions,
      db.transactions.id.equalsExp(db.splits.transactionId),
    ),
    drift.innerJoin(
      db.accounts,
      db.accounts.id.equalsExp(db.splits.accountId),
    ),
  ])
    ..where(
      db.transactions.postDate.isBiggerOrEqualValue(startDateMs) &
          db.transactions.postDate.isSmallerOrEqualValue(endDateMs) &
          db.accounts.accountType.equals('EXPENSE'),
    );

  final results = await query.get();

  return results.map((row) {
    return SpendingRawData(
      categoryId: row.read(db.splits.categoryId),
      accountType: row.read(db.accounts.accountType)!,
      valueNum: row.read(db.splits.valueNum)!,
    );
  }).toList();
}

/// Optimized query: Get all splits with account type in date range (for income/expense)
Future<List<SpendingRawData>> getAllSplitsInRange(
  LocalFinanceDatabase db,
  int startDateMs,
  int endDateMs,
) async {
  final query = db.selectOnly(db.splits).join([
    drift.innerJoin(
      db.transactions,
      db.transactions.id.equalsExp(db.splits.transactionId),
    ),
    drift.innerJoin(
      db.accounts,
      db.accounts.id.equalsExp(db.splits.accountId),
    ),
  ])
    ..where(
      db.transactions.postDate.isBiggerOrEqualValue(startDateMs) &
          db.transactions.postDate.isSmallerOrEqualValue(endDateMs),
    );

  final results = await query.get();

  return results.map((row) {
    return SpendingRawData(
      categoryId: row.read(db.splits.categoryId),
      accountType: row.read(db.accounts.accountType)!,
      valueNum: row.read(db.splits.valueNum)!,
    );
  }).toList();
}

/// Optimized query: Get category spending with category names in date range
Future<List<CategorySpendingRawData>> getCategorySpendingInRange(
  LocalFinanceDatabase db,
  int startDateMs,
  int endDateMs,
) async {
  final query = db.selectOnly(db.splits).join([
    drift.innerJoin(
      db.transactions,
      db.transactions.id.equalsExp(db.splits.transactionId),
    ),
    drift.innerJoin(
      db.accounts,
      db.accounts.id.equalsExp(db.splits.accountId),
    ),
    drift.leftJoin(
      db.categories,
      db.categories.id.equalsExp(db.splits.categoryId),
    ),
  ])
    ..where(
      db.transactions.postDate.isBiggerOrEqualValue(startDateMs) &
          db.transactions.postDate.isSmallerOrEqualValue(endDateMs) &
          db.accounts.accountType.equals('EXPENSE'),
    );

  final results = await query.get();

  return results.map((row) {
    return CategorySpendingRawData(
      categoryId: row.read(db.splits.categoryId),
      categoryName: row.read(db.categories.name),
      accountType: row.read(db.accounts.accountType)!,
      valueNum: row.read(db.splits.valueNum)!,
    );
  }).toList();
}

/// Optimized query: Get splits for specific category in date range
Future<List<PeriodSpendingRawData>> getCategorySplitsInRange(
  LocalFinanceDatabase db,
  String categoryId,
  int startDateMs,
  int endDateMs,
) async {
  final query = db.selectOnly(db.splits).join([
    drift.innerJoin(
      db.transactions,
      db.transactions.id.equalsExp(db.splits.transactionId),
    ),
    drift.innerJoin(
      db.accounts,
      db.accounts.id.equalsExp(db.splits.accountId),
    ),
  ])
    ..where(
      db.transactions.postDate.isBiggerOrEqualValue(startDateMs) &
          db.transactions.postDate.isSmallerOrEqualValue(endDateMs) &
          db.splits.categoryId.equals(categoryId) &
          db.accounts.accountType.equals('EXPENSE'),
    );

  final results = await query.get();

  return results.map((row) {
    return PeriodSpendingRawData(
      accountType: row.read(db.accounts.accountType)!,
      valueNum: row.read(db.splits.valueNum)!,
    );
  }).toList();
}

/// Optimized query: Get income source splits with account names
Future<List<CategorySpendingRawData>> getIncomeSplitsInRange(
  LocalFinanceDatabase db,
  int startDateMs,
  int endDateMs,
) async {
  final query = db.selectOnly(db.splits).join([
    drift.innerJoin(
      db.transactions,
      db.transactions.id.equalsExp(db.splits.transactionId),
    ),
    drift.innerJoin(
      db.accounts,
      db.accounts.id.equalsExp(db.splits.accountId),
    ),
  ])
    ..where(
      db.transactions.postDate.isBiggerOrEqualValue(startDateMs) &
          db.transactions.postDate.isSmallerOrEqualValue(endDateMs) &
          db.accounts.accountType.equals('INCOME'),
    );

  final results = await query.get();

  return results.map((row) {
    return CategorySpendingRawData(
      categoryId: row.read(db.splits.accountId),
      categoryName: row.read(db.accounts.name),
      accountType: row.read(db.accounts.accountType)!,
      valueNum: row.read(db.splits.valueNum)!,
    );
  }).toList();
}

// ============================================================
// BACKGROUND ISOLATE COMPUTATION FUNCTIONS
// ============================================================

/// Input for spending by category calculation
class SpendingByCategoryInput {
  final List<CategorySpendingRawData> rawData;

  const SpendingByCategoryInput(this.rawData);
}

/// Calculate spending by category in background isolate
/// This runs in a separate isolate to avoid UI jank
List<Map<String, dynamic>> calculateSpendingByCategory(SpendingByCategoryInput input) {
  final categoryTotals = <String?, double>{};
  final categoryCounts = <String?, int>{};
  final categoryNames = <String?, String>{};
  double totalSpending = 0;

  for (final item in input.rawData) {
    final amount = item.valueNum.abs() / 100.0;
    categoryTotals[item.categoryId] = (categoryTotals[item.categoryId] ?? 0) + amount;
    categoryCounts[item.categoryId] = (categoryCounts[item.categoryId] ?? 0) + 1;
    
    if (item.categoryName != null) {
      categoryNames[item.categoryId] = item.categoryName!;
    }
    
    totalSpending += amount;
  }

  final result = <Map<String, dynamic>>[];
  
  for (final entry in categoryTotals.entries) {
    final categoryId = entry.key;
    final amount = entry.value;
    
    result.add({
      'categoryId': categoryId ?? 'uncategorized',
      'categoryName': categoryNames[categoryId] ?? '未分类',
      'amount': amount,
      'percentage': totalSpending > 0 ? (amount / totalSpending) * 100 : 0,
      'transactionCount': categoryCounts[categoryId] ?? 0,
    });
  }

  result.sort((a, b) => (b['amount'] as double).compareTo(a['amount'] as double));
  
  return result;
}

/// Input for spending trends calculation
class SpendingTrendsInput {
  final List<List<SpendingRawData>> weeklyData;

  const SpendingTrendsInput(this.weeklyData);
}

/// Calculate spending trends in background isolate
List<Map<String, dynamic>> calculateSpendingTrends(SpendingTrendsInput input) {
  final trends = <Map<String, dynamic>>[];

  for (var i = 0; i < input.weeklyData.length; i++) {
    double weekSpending = 0;
    
    for (final item in input.weeklyData[i]) {
      weekSpending += item.valueNum.abs() / 100.0;
    }

    trends.add({
      'index': i,
      'amount': weekSpending,
      'change': 0.0,
      'changePercent': 0.0,
    });
  }

  // Calculate changes
  for (var i = 0; i < trends.length - 1; i++) {
    final current = trends[i];
    final previous = trends[i + 1];
    final change = (current['amount'] as double) - (previous['amount'] as double);
    final previousAmount = previous['amount'] as double;
    final changePercent = previousAmount > 0 ? (change / previousAmount) * 100 : 0.0;

    trends[i] = {
      ...current,
      'change': change,
      'changePercent': changePercent,
    };
  }

  return trends;
}

/// Input for income/expense calculation
class IncomeExpenseInput {
  final List<SpendingRawData> rawData;

  const IncomeExpenseInput(this.rawData);
}

/// Calculate income and expense totals in background isolate
Map<String, double> calculateIncomeExpense(IncomeExpenseInput input) {
  double income = 0;
  double expense = 0;
  int expenseCount = 0;

  for (final item in input.rawData) {
    final amount = item.valueNum.abs() / 100.0;
    
    if (item.accountType == 'INCOME') {
      income += amount;
    } else if (item.accountType == 'EXPENSE') {
      expense += amount;
      expenseCount++;
    }
  }

  return {
    'income': income,
    'expense': expense,
    'expenseCount': expenseCount.toDouble(),
  };
}

/// Input for income sources calculation
class IncomeSourcesInput {
  final List<CategorySpendingRawData> rawData;

  const IncomeSourcesInput(this.rawData);
}

/// Calculate income sources in background isolate
List<Map<String, dynamic>> calculateIncomeSources(IncomeSourcesInput input) {
  final sourceTotals = <String, double>{};
  final sourceCounts = <String, int>{};
  final sourceNames = <String, String>{};
  double totalIncome = 0;

  for (final item in input.rawData) {
    final source = item.categoryId!;
    final amount = item.valueNum.abs() / 100.0;
    
    sourceTotals[source] = (sourceTotals[source] ?? 0) + amount;
    sourceCounts[source] = (sourceCounts[source] ?? 0) + 1;
    sourceNames[source] = item.categoryName ?? 'Unknown';
    totalIncome += amount;
  }

  final result = <Map<String, dynamic>>[];
  
  for (final entry in sourceTotals.entries) {
    final source = entry.key;
    
    result.add({
      'source': sourceNames[source]!,
      'amount': entry.value,
      'percentage': totalIncome > 0 ? (entry.value / totalIncome) * 100 : 0,
      'transactionCount': sourceCounts[source] ?? 0,
    });
  }

  result.sort((a, b) => (b['amount'] as double).compareTo(a['amount'] as double));
  
  return result;
}

// ============================================================
// HELPER FUNCTIONS FOR PROVIDERS
// ============================================================

/// Get spending by category using optimized query and background calculation
Future<List<Map<String, dynamic>>> getSpendingByCategoryOptimized(
  LocalFinanceDatabase db,
  int startDateMs,
  int endDateMs,
) async {
  // Step 1: Single JOIN query to get all data
  final rawData = await getCategorySpendingInRange(db, startDateMs, endDateMs);

  // Step 2: Calculate in background isolate
  return compute(calculateSpendingByCategory, SpendingByCategoryInput(rawData));
}

/// Get spending trends using optimized queries and background calculation
Future<List<Map<String, dynamic>>> getSpendingTrendsOptimized(
  LocalFinanceDatabase db,
  DateTime now,
) async {
  // Step 1: Fetch all 12 weeks data in parallel
  final weeklyFutures = <Future<List<SpendingRawData>>>[];
  
  for (var i = 0; i < 12; i++) {
    final weekEnd = now.subtract(Duration(days: i * 7));
    final weekStart = weekEnd.subtract(const Duration(days: 7));
    
    weeklyFutures.add(
      getExpenseSplitsInRange(
        db,
        weekStart.millisecondsSinceEpoch,
        weekEnd.millisecondsSinceEpoch,
      ),
    );
  }

  final weeklyData = await Future.wait(weeklyFutures);

  // Step 2: Calculate trends in background isolate
  return compute(calculateSpendingTrends, SpendingTrendsInput(weeklyData));
}

/// Get income/expense totals using optimized query and background calculation
Future<Map<String, double>> getIncomeExpenseOptimized(
  LocalFinanceDatabase db,
  int startDateMs,
  int endDateMs,
) async {
  // Step 1: Single JOIN query
  final rawData = await getAllSplitsInRange(db, startDateMs, endDateMs);

  // Step 2: Calculate in background isolate
  return compute(calculateIncomeExpense, IncomeExpenseInput(rawData));
}

/// Get income sources using optimized query and background calculation
Future<List<Map<String, dynamic>>> getIncomeSourcesOptimized(
  LocalFinanceDatabase db,
  int startDateMs,
  int endDateMs,
) async {
  // Step 1: Single JOIN query
  final rawData = await getIncomeSplitsInRange(db, startDateMs, endDateMs);

  // Step 2: Calculate in background isolate
  return compute(calculateIncomeSources, IncomeSourcesInput(rawData));
}

/// Optimized query: Get spending data grouped by month for multiple months
/// Used for monthly summaries and trend analysis
Future<List<Map<String, dynamic>>> getMonthlySpendingData(
  LocalFinanceDatabase db,
  List<DateTime> monthStarts,
  List<DateTime> monthEnds,
) async {
  // Single query for all months
  final query = db.selectOnly(db.splits).join([
    drift.innerJoin(
      db.transactions,
      db.transactions.id.equalsExp(db.splits.transactionId),
    ),
    drift.innerJoin(
      db.accounts,
      db.accounts.id.equalsExp(db.splits.accountId),
    ),
  ]);

  // Build WHERE clause for all months
  final whereClauses = <drift.Expression<bool>>[];
  for (var i = 0; i < monthStarts.length; i++) {
    whereClauses.add(
      db.transactions.postDate.isBiggerOrEqualValue(monthStarts[i].millisecondsSinceEpoch) &
      db.transactions.postDate.isSmallerOrEqualValue(monthEnds[i].millisecondsSinceEpoch),
    );
  }
  
  // Combine with OR
  final combinedWhere = whereClauses.reduce((a, b) => a | b);
  query.where(combinedWhere);

  final results = await query.get();

  // Group by month and account type
  final monthlyData = <int, Map<String, double>>{};
  
  for (final row in results) {
    final postDate = row.read(db.transactions.postDate)!;
    final accountType = row.read(db.accounts.accountType)!;
    final valueNum = row.read(db.splits.valueNum)!;
    
    // Find which month this belongs to
    for (var i = 0; i < monthStarts.length; i++) {
      if (postDate >= monthStarts[i].millisecondsSinceEpoch &&
          postDate <= monthEnds[i].millisecondsSinceEpoch) {
        monthlyData[i] ??= {'income': 0.0, 'expense': 0.0};
        
        if (accountType == 'INCOME') {
          monthlyData[i]!['income'] = monthlyData[i]!['income']! + valueNum.abs() / 100.0;
        } else if (accountType == 'EXPENSE') {
          monthlyData[i]!['expense'] = monthlyData[i]!['expense']! + valueNum.abs() / 100.0;
        }
        break;
      }
    }
  }

  // Convert to result format
  return monthlyData.entries.map((entry) {
    return {
      'monthIndex': entry.key,
      'income': entry.value['income'] ?? 0.0,
      'expense': entry.value['expense'] ?? 0.0,
    };
  }).toList();
}

/// Optimized query: Get all categories with spending data for anomaly detection
/// Returns category-spending pairs for multiple months in single query
Future<List<Map<String, dynamic>>> getCategorySpendingForMonths(
  LocalFinanceDatabase db,
  List<DateTime> monthStarts,
  List<DateTime> monthEnds,
) async {
  // Build a single query that gets all category spending across all months
  // This is more efficient than looping through each category and month
  final query = db.selectOnly(db.splits).join([
    drift.innerJoin(
      db.transactions,
      db.transactions.id.equalsExp(db.splits.transactionId),
    ),
    drift.innerJoin(
      db.accounts,
      db.accounts.id.equalsExp(db.splits.accountId),
    ),
    drift.innerJoin(
      db.categories,
      db.categories.id.equalsExp(db.splits.categoryId),
    ),
  ]);

  // Build WHERE clause for all months
  final whereClauses = < drift.Expression<bool>>[];
  for (var i = 0; i < monthStarts.length; i++) {
    whereClauses.add(
      db.transactions.postDate.isBiggerOrEqualValue(monthStarts[i].millisecondsSinceEpoch) &
      db.transactions.postDate.isSmallerOrEqualValue(monthEnds[i].millisecondsSinceEpoch),
    );
  }
  
  // Combine with OR
  final combinedWhere = whereClauses.reduce((a, b) => a | b);
  query.where(combinedWhere & db.accounts.accountType.equals('EXPENSE'));

  final results = await query.get();

  // Group by category and month
  final categoryMonthSpending = <String, Map<int, double>>{};
  
  for (final row in results) {
    final categoryId = row.read(db.splits.categoryId);
    final postDate = row.read(db.transactions.postDate)!;
    final valueNum = row.read(db.splits.valueNum)!;
    
    if (categoryId == null) continue;
    
    // Find which month this belongs to
    for (var i = 0; i < monthStarts.length; i++) {
      if (postDate >= monthStarts[i].millisecondsSinceEpoch &&
          postDate <= monthEnds[i].millisecondsSinceEpoch) {
        categoryMonthSpending[categoryId] ??= {};
        categoryMonthSpending[categoryId]![i] = 
          (categoryMonthSpending[categoryId]![i] ?? 0) + valueNum.abs() / 100.0;
        break;
      }
    }
  }

  // Get category names
  final categories = await db.select(db.categories).get();
  final categoryNames = {for (var c in categories) c.id: c.name};

  // Convert to result format
  final result = <Map<String, dynamic>>[];
  
  for (final entry in categoryMonthSpending.entries) {
    final categoryId = entry.key;
    final monthlyData = entry.value;
    
    result.add({
      'categoryId': categoryId,
      'categoryName': categoryNames[categoryId] ?? 'Unknown',
      'monthlySpending': monthlyData.map((k, v) => MapEntry(k.toString(), v)),
    });
  }

  return result;
}
