import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart' as drift;
import 'package:uuid/uuid.dart';

import 'package:database/database.dart';
import 'package:finance_app/features/accounts/data/account_provider.dart';

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