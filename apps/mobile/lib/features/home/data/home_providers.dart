import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:database/database.dart';
import 'package:core/core.dart' hide Transaction, Split, Account;

import 'package:finance_app/features/accounts/data/account_provider.dart';
import 'package:finance_app/features/import/providers/import_providers.dart' show TransactionRepositoryImpl;

/// Provider for AccountRepository implementation.
final accountRepositoryProvider = Provider<AccountRepository>((ref) {
  final db = ref.watch(databaseProvider);
  return AccountRepositoryImpl(db);
});

/// Provider for TransactionRepository implementation.
final transactionRepositoryProvider = Provider<TransactionRepository>((ref) {
  final db = ref.watch(databaseProvider);
  return TransactionRepositoryImpl(db);
});

/// Provider for GetBalance use case.
final getBalanceProvider = Provider<GetBalance>((ref) {
  final accountRepo = ref.watch(accountRepositoryProvider);
  final transactionRepo = ref.watch(transactionRepositoryProvider);
  return GetBalance(accountRepo, transactionRepo);
});

/// Provider for net worth calculation.
final netWorthProvider = FutureProvider<double>((ref) async {
  final getBalance = ref.watch(getBalanceProvider);
  return getBalance.getNetWorth();
});

/// Provider for total assets.
final assetTotalProvider = FutureProvider<double>((ref) async {
  final getBalance = ref.watch(getBalanceProvider);
  return getBalance.getTotalBalanceByType('ASSET');
});

/// Provider for total liabilities.
final liabilityTotalProvider = FutureProvider<double>((ref) async {
  final getBalance = ref.watch(getBalanceProvider);
  return getBalance.getTotalBalanceByType('LIABILITY');
});

/// Provider for recent transactions (last 10).
final recentTransactionsProvider = FutureProvider<List<Transaction>>((ref) async {
  final db = ref.watch(databaseProvider);
  final transactions = await db.transactionsDao.getAll();
  
  // Sort by date descending and take last 10
  transactions.sort((a, b) => b.postDate.compareTo(a.postDate));
  return transactions.take(10).toList();
});

/// Quick stats model for home page.
class QuickStats {
  final int todayCount;
  final double monthIncome;
  final double monthExpense;
  
  const QuickStats({
    required this.todayCount,
    required this.monthIncome,
    required this.monthExpense,
  });
  
  double get monthBalance => monthIncome - monthExpense;
}

/// Provider for quick stats (today's count, this month's income/expense).
final quickStatsProvider = FutureProvider<QuickStats>((ref) async {
  final db = ref.watch(databaseProvider);
  final now = DateTime.now();
  
  // Today's date range
  final todayStart = DateTime(now.year, now.month, now.day);
  final todayEnd = DateTime(now.year, now.month, now.day, 23, 59, 59, 999);
  
  // This month's date range
  final monthStart = DateTime(now.year, now.month, 1);
  final monthEnd = DateTime(now.year, now.month + 1, 0, 23, 59, 59, 999);
  
  // Get today's transactions
  final todayTransactions = await db.transactionsDao.getByDateRange(todayStart, todayEnd);
  final todayCount = todayTransactions.length;
  
  // Get this month's splits with accounts for income/expense calculation
  final monthTransactions = await db.transactionsDao.getByDateRange(monthStart, monthEnd);
  
  double monthIncome = 0;
  double monthExpense = 0;
  
  for (final transaction in monthTransactions) {
    final splits = await db.transactionsDao.getSplits(transaction.id);
    for (final split in splits) {
      // Get account to determine type
      final account = await db.accountsDao.getById(split.accountId);
      if (account != null) {
        final amount = split.valueNum / 100.0;
        if (account.accountType == 'INCOME') {
          monthIncome += amount.abs();
        } else if (account.accountType == 'EXPENSE') {
          monthExpense += amount.abs();
        }
      }
    }
  }
  
  return QuickStats(
    todayCount: todayCount,
    monthIncome: monthIncome,
    monthExpense: monthExpense,
  );
});

/// Monthly spending data for trend chart.
class MonthlySpending {
  final String monthLabel;
  final double expense;
  final double income;
  final DateTime date;
  
  const MonthlySpending({
    required this.monthLabel,
    required this.expense,
    required this.income,
    required this.date,
  });
}

/// Provider for last 6 months spending trend.
final monthlySpendingTrendProvider = FutureProvider<List<MonthlySpending>>((ref) async {
  final db = ref.watch(databaseProvider);
  final now = DateTime.now();
  
  final List<MonthlySpending> result = [];
  
  for (int i = 5; i >= 0; i--) {
    final monthDate = DateTime(now.year, now.month - i, 1);
    final monthEnd = DateTime(now.year, now.month - i + 1, 0, 23, 59, 59, 999);
    
    final transactions = await db.transactionsDao.getByDateRange(monthDate, monthEnd);
    
    double monthIncome = 0;
    double monthExpense = 0;
    
    for (final transaction in transactions) {
      final splits = await db.transactionsDao.getSplits(transaction.id);
      for (final split in splits) {
        final account = await db.accountsDao.getById(split.accountId);
        if (account != null) {
          final amount = split.valueNum / 100.0;
          if (account.accountType == 'INCOME') {
            monthIncome += amount.abs();
          } else if (account.accountType == 'EXPENSE') {
            monthExpense += amount.abs();
          }
        }
      }
    }
    
    final monthLabel = '${monthDate.year}-${monthDate.month.toString().padLeft(2, '0')}';
    
    result.add(MonthlySpending(
      monthLabel: monthLabel,
      expense: monthExpense,
      income: monthIncome,
      date: monthDate,
    ));
  }
  
  return result;
});

/// Category spending data for pie chart.
class CategorySpending {
  final String categoryId;
  final String categoryName;
  final double amount;
  final Color color;
  
  const CategorySpending({
    required this.categoryId,
    required this.categoryName,
    required this.amount,
    required this.color,
  });
}

/// Provider for current month category breakdown.
final categoryBreakdownProvider = FutureProvider<List<CategorySpending>>((ref) async {
  final db = ref.watch(databaseProvider);
  final now = DateTime.now();
  
  final monthStart = DateTime(now.year, now.month, 1);
  final monthEnd = DateTime(now.year, now.month + 1, 0, 23, 59, 59, 999);
  
  final transactions = await db.transactionsDao.getByDateRange(monthStart, monthEnd);
  
  // Aggregate by category
  final Map<String, double> categoryTotals = {};
  final Map<String, String> categoryNames = {};
  
  for (final transaction in transactions) {
    final splits = await db.transactionsDao.getSplits(transaction.id);
    for (final split in splits) {
      final account = await db.accountsDao.getById(split.accountId);
      if (account != null && account.accountType == 'EXPENSE') {
        final amount = split.valueNum / 100.0;
        final catId = split.categoryId ?? 'other';
        
        categoryTotals[catId] = (categoryTotals[catId] ?? 0) + amount.abs();
        
        // Get category name
        if (split.categoryId != null && !categoryNames.containsKey(split.categoryId)) {
          final category = await db.categoriesDao.getById(split.categoryId!);
          categoryNames[split.categoryId!] = category?.name ?? '其他';
        }
      }
    }
  }
  
  // Add "其他" name if needed
  categoryNames['other'] = '其他';
  
  // Convert to list and assign colors
  final colors = [
    const Color(0xFF4CAF50),  // Green
    const Color(0xFF2196F3),  // Blue
    const Color(0xFFFF9800),  // Orange
    const Color(0xFF9C27B0),  // Purple
    const Color(0xFFF44336),  // Red
    const Color(0xFF00BCD4),  // Cyan
    const Color(0xFF795548),  // Brown
    const Color(0xFF607D8B),  // Grey
  ];
  
  final result = categoryTotals.entries.map((entry) {
    final index = categoryTotals.keys.toList().indexOf(entry.key);
    return CategorySpending(
      categoryId: entry.key,
      categoryName: categoryNames[entry.key] ?? '其他',
      amount: entry.value,
      color: colors[index % colors.length],
    );
  }).toList();
  
  // Sort by amount descending
  result.sort((a, b) => b.amount.compareTo(a.amount));
  
  return result;
});