import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:database/database.dart';
import 'package:finance_app/features/transactions/data/transaction_provider.dart';
import 'package:finance_app/features/accounts/data/account_provider.dart';

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

/// Provider for monthly trend data (last 6 months).
final monthlyTrendProvider = FutureProvider<List<MonthlyData>>((ref) async {
  final splitsWithAccounts = await ref.watch(allSplitsWithAccountsProvider.future);
  final db = ref.watch(databaseProvider);
  
  // Get all categories for name lookup
  final categories = await (db.select(db.categories)
    ..where((c) => c.deletedAt.isNull()))
    .get();
  final categoryMap = {for (var c in categories) c.id: c};
  
  // Calculate last 6 months boundaries
  final now = DateTime.now();
  final months = <MonthlyData>[];
  
  for (int i = 5; i >= 0; i--) {
    final monthDate = DateTime(now.year, now.month - i, 1);
    final monthStart = monthDate.millisecondsSinceEpoch;
    final monthEnd = DateTime(now.year, now.month - i + 1, 0, 23, 59, 59, 999).millisecondsSinceEpoch;
    
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
      monthLabel: '${monthDate.year}-${monthDate.month.toString().padLeft(2, '0')}',
      income: monthIncome,
      expense: monthExpense,
    ));
  }
  
  return months;
});

/// Provider for category breakdown (expense only).
final categoryBreakdownProvider = FutureProvider<List<CategoryBreakdown>>((ref) async {
  final splitsWithAccounts = await ref.watch(allSplitsWithAccountsProvider.future);
  final db = ref.watch(databaseProvider);
  
  // Get all categories
  final categories = await (db.select(db.categories)
    ..where((c) => c.deletedAt.isNull()))
    .get();
  final categoryMap = {for (var c in categories) c.id: c};
  
  // Aggregate expenses by category
  final categoryTotals = <String, double>{};
  
  for (final (split, account) in splitsWithAccounts) {
    // Only count expenses
    if (account.accountType == 'EXPENSE' && split.valueNum != 0) {
      final categoryId = split.categoryId;
      if (categoryId != null && categoryMap.containsKey(categoryId)) {
        final amount = split.valueNum.abs() / 100.0;
        categoryTotals[categoryId] = (categoryTotals[categoryId] ?? 0) + amount;
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