import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart' as drift;
import 'package:uuid/uuid.dart';

import 'package:database/database.dart';
import 'package:finance_app/features/accounts/data/account_provider.dart';
import 'transaction_filter.dart';

final transactionsProvider = StreamProvider<List<Transaction>>((ref) {
  final db = ref.watch(databaseProvider);
  return (db.select(db.transactions)
    ..where((t) => t.deletedAt.isNull())
    ..orderBy([(t) => drift.OrderingTerm.desc(t.postDate)]))
    .watch();
});

final transactionsByDateRangeProvider = Provider.family<List<Transaction>, (DateTime, DateTime)>((ref, range) {
  final transactions = ref.watch(transactionsProvider);
  return transactions.when(
    data: (list) => list.where((t) {
      final date = DateTime.fromMillisecondsSinceEpoch(t.postDate);
      return date.isAfter(range.$1) && date.isBefore(range.$2);
    }).toList(),
    loading: () => [],
    error: (_, __) => [],
  );
});

final splitsForTransactionProvider = FutureProvider.family<List<Split>, String>((ref, transactionId) async {
  final db = ref.watch(databaseProvider);
  return (db.select(db.splits)..where((s) => s.transactionId.equals(transactionId))).get();
});

/// Provider that returns all splits with their associated account info.
/// Used for calculating income/expense totals in reports.
final allSplitsWithAccountsProvider = FutureProvider<List<(Split, Account)>>((ref) async {
  final db = ref.watch(databaseProvider);
  
  // Get all splits
  final allSplits = await (db.select(db.splits)).get();
  
  // Get all accounts and create a map
  final allAccounts = await (db.select(db.accounts)).get();
  final accountMap = {for (var a in allAccounts) a.id: a};
  
  // Pair splits with their accounts
  return allSplits
      .where((s) => accountMap.containsKey(s.accountId))
      .map((s) => (s, accountMap[s.accountId]!))
      .toList();
});

// ============================================================
// FILTER PROVIDERS - Transaction search and filtering
// ============================================================

/// Provider for transaction filter state.
final transactionFilterProvider = StateProvider<TransactionFilter>((ref) {
  return const TransactionFilter();
});

/// Provider for filtered transactions based on current filter state.
final filteredTransactionsProvider = Provider<List<Transaction>>((ref) {
  final transactionsAsync = ref.watch(transactionsProvider);
  final filter = ref.watch(transactionFilterProvider);
  
  return transactionsAsync.when(
    data: (transactions) {
      if (filter.isEmpty) {
        return transactions;
      }
      return _applyFilter(transactions, filter, ref);
    },
    loading: () => [],
    error: (_, __) => [],
  );
});

/// Applies filter criteria to transaction list.
List<Transaction> _applyFilter(
  List<Transaction> transactions,
  TransactionFilter filter,
  Ref ref,
) {
  return transactions.where((transaction) {
    // Date range filter
    if (filter.startDate != null) {
      final transactionDate = DateTime.fromMillisecondsSinceEpoch(transaction.postDate);
      final startDate = DateTime(filter.startDate!.year, filter.startDate!.month, filter.startDate!.day);
      if (transactionDate.isBefore(startDate)) return false;
    }
    
    if (filter.endDate != null) {
      final transactionDate = DateTime.fromMillisecondsSinceEpoch(transaction.postDate);
      final endDate = DateTime(filter.endDate!.year, filter.endDate!.month, filter.endDate!.day, 23, 59, 59);
      if (transactionDate.isAfter(endDate)) return false;
    }
    
    // Search query filter (description + notes)
    if (filter.searchQuery != null && filter.searchQuery!.isNotEmpty) {
      final query = filter.searchQuery!.toLowerCase();
      final description = transaction.description?.toLowerCase() ?? '';
      final notes = transaction.notes?.toLowerCase() ?? '';
      if (!description.contains(query) && !notes.contains(query)) {
        return false;
      }
    }
    
    // Category and account filters need split data
    if (filter.categoryId != null || filter.accountId != null || filter.hasAmountRange) {
      // This requires async split lookup, so we'll handle it differently
      // For now, we'll use a synchronous approach by watching splits
      // In production, this should be done at the database level
      return true; // Will be filtered further in the widget
    }
    
    return true;
  }).toList();
}

/// Provider for filtered transactions with split data (for category/account/amount filtering).
final filteredTransactionsWithSplitsProvider = FutureProvider<List<(Transaction, List<Split>)>>((ref) async {
  final filter = ref.watch(transactionFilterProvider);
  final db = ref.watch(databaseProvider);
  
  // If no filter, return all transactions with splits
  if (filter.isEmpty) {
    final transactions = await ref.watch(transactionsProvider.future);
    final result = <(Transaction, List<Split>)>[];
    for (final t in transactions) {
      final splits = await db.transactionsDao.getSplits(t.id);
      result.add((t, splits));
    }
    return result;
  }
  
  // Build query with filters
  final query = db.select(db.transactions)
    ..where((t) => t.deletedAt.isNull())
    ..orderBy([(t) => drift.OrderingTerm.desc(t.postDate)]);
  
  final transactions = await query.get();
  final result = <(Transaction, List<Split>)>[];
  
  for (final transaction in transactions) {
    final splits = await db.transactionsDao.getSplits(transaction.id);
    
    // Apply date filter
    if (filter.startDate != null) {
      final transactionDate = DateTime.fromMillisecondsSinceEpoch(transaction.postDate);
      final startDate = DateTime(filter.startDate!.year, filter.startDate!.month, filter.startDate!.day);
      if (transactionDate.isBefore(startDate)) continue;
    }
    
    if (filter.endDate != null) {
      final transactionDate = DateTime.fromMillisecondsSinceEpoch(transaction.postDate);
      final endDate = DateTime(filter.endDate!.year, filter.endDate!.month, filter.endDate!.day, 23, 59, 59);
      if (transactionDate.isAfter(endDate)) continue;
    }
    
    // Apply search filter
    if (filter.searchQuery != null && filter.searchQuery!.isNotEmpty) {
      final query = filter.searchQuery!.toLowerCase();
      final description = transaction.description?.toLowerCase() ?? '';
      final notes = transaction.notes?.toLowerCase() ?? '';
      if (!description.contains(query) && !notes.contains(query)) {
        continue;
      }
    }
    
    // Apply category filter
    if (filter.categoryId != null) {
      final hasCategory = splits.any((s) => s.categoryId == filter.categoryId);
      if (!hasCategory) continue;
    }
    
    // Apply account filter
    if (filter.accountId != null) {
      final hasAccount = splits.any((s) => s.accountId == filter.accountId);
      if (!hasAccount) continue;
    }
    
    // Apply amount range filter (absolute value)
    if (filter.hasAmountRange) {
      final totalAmount = splits.fold<int>(0, (sum, s) => sum + s.valueNum.abs());
      final amount = totalAmount / 100.0;
      
      if (filter.minAmount != null && amount < filter.minAmount!) continue;
      if (filter.maxAmount != null && amount > filter.maxAmount!) continue;
    }
    
    result.add((transaction, splits));
  }
  
  return result;
});

class TransactionNotifier extends StateNotifier<AsyncValue<void>> {
  final LocalFinanceDatabase _db;

  TransactionNotifier(this._db) : super(const AsyncValue.data(null));

  Future<void> createTransaction({
    required String accountId,
    required double amount,
    required DateTime date,
    required String currencyId,
    String? description,
    String? notes,
    String? categoryId,
  }) async {
    state = const AsyncValue.loading();
    try {
      final transactionId = const Uuid().v4();
      final splitId = const Uuid().v4();
      final now = DateTime.now().millisecondsSinceEpoch;
      final postDate = date.millisecondsSinceEpoch;
      final amountNum = (amount * 100).round();

      await _db.transaction(() async {
        await _db.into(_db.transactions).insert(
          TransactionsCompanion.insert(
            id: transactionId,
            postDate: postDate,
            enterDate: now,
            currencyId: currencyId,
            description: drift.Value(description),
            notes: drift.Value(notes),
            createdAt: now,
            updatedAt: now,
          ),
        );

        await _db.into(_db.splits).insert(
          SplitsCompanion.insert(
            id: splitId,
            transactionId: transactionId,
            accountId: accountId,
            categoryId: drift.Value(categoryId),
            valueNum: amountNum,
            quantityNum: amountNum,
            createdAt: now,
          ),
        );
      });

      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> updateTransaction(Transaction transaction, Split split) async {
    state = const AsyncValue.loading();
    try {
      await _db.transaction(() async {
        await (_db.update(_db.transactions)
          ..where((t) => t.id.equals(transaction.id))).write(
          TransactionsCompanion(
            description: drift.Value(transaction.description),
            postDate: drift.Value(transaction.postDate),
            notes: drift.Value(transaction.notes),
            updatedAt: drift.Value(DateTime.now().millisecondsSinceEpoch),
          ),
        );

        await (_db.update(_db.splits)
          ..where((s) => s.id.equals(split.id))).write(
          SplitsCompanion(
            valueNum: drift.Value(split.valueNum),
            quantityNum: drift.Value(split.quantityNum),
          ),
        );
      });

      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> deleteTransaction(String id) async {
    state = const AsyncValue.loading();
    try {
      await (_db.update(_db.transactions)..where((t) => t.id.equals(id))).write(
        TransactionsCompanion(
          deletedAt: drift.Value(DateTime.now().millisecondsSinceEpoch),
        ),
      );
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }
}

final transactionNotifierProvider = StateNotifierProvider<TransactionNotifier, AsyncValue<void>>((ref) {
  final db = ref.watch(databaseProvider);
  return TransactionNotifier(db);
});