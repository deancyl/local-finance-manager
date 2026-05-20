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