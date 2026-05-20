import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:database/database.dart';
import 'package:finance_app/features/transactions/data/transaction_provider.dart';
import 'package:finance_app/features/accounts/data/account_provider.dart';

/// Date range filter for reports.
class DateRangeFilter {
  final DateTime startDate;
  final DateTime endDate;
  final String label; // "本月", "本年", "自定义"
  
  const DateRangeFilter({
    required this.startDate,
    required this.endDate,
    required this.label,
  });
  
  /// Create filter for current month.
  factory DateRangeFilter.currentMonth() {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, 1);
    final end = DateTime(now.year, now.month + 1, 0, 23, 59, 59, 999);
    return DateRangeFilter(
      startDate: start,
      endDate: end,
      label: '本月',
    );
  }
  
  /// Create filter for current year.
  factory DateRangeFilter.currentYear() {
    final now = DateTime.now();
    final start = DateTime(now.year, 1, 1);
    final end = DateTime(now.year, 12, 31, 23, 59, 59, 999);
    return DateRangeFilter(
      startDate: start,
      endDate: end,
      label: '本年',
    );
  }
  
  /// Create custom date range filter.
  factory DateRangeFilter.custom(DateTime start, DateTime end) {
    return DateRangeFilter(
      startDate: start,
      endDate: end,
      label: '自定义',
    );
  }
}

/// Provider for date range filter state.
final dateRangeFilterProvider = StateProvider<DateRangeFilter>((ref) {
  return DateRangeFilter.currentMonth();
});

/// Provider that returns all splits with their associated account and transaction info.
/// Used for calculating income/expense totals filtered by date range.
final allSplitsWithAccountsAndTransactionsProvider = FutureProvider<List<(Split, Account, Transaction)>>((ref) async {
  final db = ref.watch(databaseProvider);
  
  // Get all splits
  final allSplits = await (db.select(db.splits)).get();
  
  // Get all accounts and create a map
  final allAccounts = await (db.select(db.accounts)).get();
  final accountMap = {for (var a in allAccounts) a.id: a};
  
  // Get all transactions and create a map
  final allTransactions = await (db.select(db.transactions)
    ..where((t) => t.deletedAt.isNull()))
    .get();
  final transactionMap = {for (var t in allTransactions) t.id: t};
  
  // Pair splits with their accounts and transactions
  return allSplits
      .where((s) => accountMap.containsKey(s.accountId) && transactionMap.containsKey(s.transactionId))
      .map((s) => (s, accountMap[s.accountId]!, transactionMap[s.transactionId]!))
      .toList();
});

/// Monthly data model for trend chart.
class MonthlyData {
  final String monthLabel; // e.g., "2026-05"
  final double income;
  final double expense;
  
  const MonthlyData({
    required this.monthLabel,
    required this.income,
    required this.expense,
  });
  
  double get balance => income - expense;
}

/// Category breakdown data model for pie chart.
class CategoryBreakdown {
  final String categoryId;
  final String categoryName;
  final double amount;
  final String? color; // Hex color string
  
  const CategoryBreakdown({
    required this.categoryId,
    required this.categoryName,
    required this.amount,
    this.color,
  });
}

/// Provider for monthly trend data based on selected date range.
final monthlyTrendProvider = FutureProvider<List<MonthlyData>>((ref) async {
  final splitsWithAccounts = await ref.watch(allSplitsWithAccountsProvider.future);
  final db = ref.watch(databaseProvider);
  final dateRange = ref.watch(dateRangeFilterProvider);
  
  // Get all categories for name lookup
  final categories = await (db.select(db.categories)
    ..where((c) => c.deletedAt.isNull()))
    .get();
  final categoryMap = {for (var c in categories) c.id: c};
  
  // Calculate months within the date range
  final startMonth = DateTime(dateRange.startDate.year, dateRange.startDate.month, 1);
  final endMonth = DateTime(dateRange.endDate.year, dateRange.endDate.month, 1);
  
  final months = <MonthlyData>[];
  var currentMonth = startMonth;
  
  while (currentMonth.isBefore(endMonth) || currentMonth.isAtSameMomentAs(endMonth)) {
    final monthStart = currentMonth.millisecondsSinceEpoch;
    final monthEnd = DateTime(currentMonth.year, currentMonth.month + 1, 0, 23, 59, 59, 999).millisecondsSinceEpoch;
    
    double monthIncome = 0;
    double monthExpense = 0;
    
    for (final (split, account) in splitsWithAccounts) {
      // Check if split is within this month
      if (split.valueNum != 0) {
        // Get transaction date
        final transaction = await (db.select(db.transactions)
          ..where((t) => t.id.equals(split.transactionId)))
          .getSingleOrNull();
        
        if (transaction != null && 
            transaction.postDate >= monthStart && 
            transaction.postDate <= monthEnd) {
          final amount = split.valueNum.abs() / 100.0;
          
          if (account.accountType == 'INCOME') {
            monthIncome += amount;
          } else if (account.accountType == 'EXPENSE') {
            monthExpense += amount;
          }
        }
      }
    }
    
    months.add(MonthlyData(
      monthLabel: '${currentMonth.year}-${currentMonth.month.toString().padLeft(2, '0')}',
      income: monthIncome,
      expense: monthExpense,
    ));
    
    currentMonth = DateTime(currentMonth.year, currentMonth.month + 1, 1);
  }
  
  return months;
});

/// Provider for category breakdown based on selected date range.
final categoryBreakdownProvider = FutureProvider<List<CategoryBreakdown>>((ref) async {
  final splitsWithAccounts = await ref.watch(allSplitsWithAccountsProvider.future);
  final db = ref.watch(databaseProvider);
  final dateRange = ref.watch(dateRangeFilterProvider);
  
  // Get all categories
  final categories = await (db.select(db.categories)
    ..where((c) => c.deletedAt.isNull()))
    .get();
  final categoryMap = {for (var c in categories) c.id: c};
  
  // Date range in milliseconds
  final startMs = dateRange.startDate.millisecondsSinceEpoch;
  final endMs = dateRange.endDate.millisecondsSinceEpoch;
  
  // Aggregate expenses by category
  final categoryTotals = <String, double>{};
  
  for (final (split, account) in splitsWithAccounts) {
    // Only count expenses
    if (account.accountType == 'EXPENSE' && split.valueNum != 0) {
      final categoryId = split.categoryId;
      if (categoryId != null && categoryMap.containsKey(categoryId)) {
        // Get transaction date
        final transaction = await (db.select(db.transactions)
          ..where((t) => t.id.equals(split.transactionId)))
          .getSingleOrNull();
        
        if (transaction != null && 
            transaction.postDate >= startMs && 
            transaction.postDate <= endMs) {
          final amount = split.valueNum.abs() / 100.0;
          categoryTotals[categoryId] = (categoryTotals[categoryId] ?? 0) + amount;
        }
      }
    }
  }
  
  // Convert to CategoryBreakdown list, sorted by amount descending
  final breakdowns = categoryTotals.entries
      .map((e) => CategoryBreakdown(
        categoryId: e.key,
        categoryName: categoryMap[e.key]?.name ?? '未知分类',
        amount: e.value,
        color: categoryMap[e.key]?.color,
      ))
      .toList();
  
  breakdowns.sort((a, b) => b.amount.compareTo(a.amount));
  
  return breakdowns;
});