import 'package:drift/drift.dart';

import '../database.dart';

part 'transactions_dao.g.dart';

/// Data Access Object for transactions.
@DriftAccessor(tables: [Transactions, Splits])
class TransactionsDao extends DatabaseAccessor<LocalFinanceDatabase> with _$TransactionsDaoMixin {
  TransactionsDao(super.db);

  /// Gets all transactions (not deleted).
  Future<List<Transaction>> getAll() {
    return (select(transactions)..where((t) => t.deletedAt.isNull())).get();
  }

  /// Gets a transaction by ID.
  Future<Transaction?> getById(String id) {
    return (select(transactions)..where((t) => t.id.equals(id))).getSingleOrNull();
  }

  /// Gets transactions within a date range.
  Future<List<Transaction>> getByDateRange(DateTime start, DateTime end) {
    final startMs = start.millisecondsSinceEpoch;
    final endMs = end.millisecondsSinceEpoch;
    return (select(transactions)
          ..where((t) => t.postDate.isBetweenValues(startMs, endMs) & t.deletedAt.isNull())
          ..orderBy([(t) => OrderingTerm.desc(t.postDate)]))
        .get();
  }

  /// Gets transactions for an account via splits.
  Future<List<Transaction>> getByAccount(String accountId) {
    final query = select(transactions).join([
      innerJoin(splits, splits.transactionId.equalsExp(transactions.id)),
    ])
      ..where(splits.accountId.equals(accountId) & transactions.deletedAt.isNull())
      ..orderBy([OrderingTerm.desc(transactions.postDate)]);

    return query.map((row) => row.readTable(transactions)).get();
  }

  /// Gets splits for a transaction.
  Future<List<Split>> getSplits(String transactionId) {
    return (select(splits)..where((s) => s.transactionId.equals(transactionId))).get();
  }

  /// Creates a transaction with splits in a single transaction.
  Future<String> createWithSplits(
    TransactionsCompanion transaction,
    List<SplitsCompanion> splitList,
  ) async {
    return await transaction(() async {
      await into(transactions).insert(transaction);
      for (final split in splitList) {
        await into(splits).insert(split);
      }
      return transaction.id.value;
    });
  }

  /// Updates a transaction with splits.
  Future<void> updateWithSplits(
    TransactionsCompanion transaction,
    List<SplitsCompanion> splitList,
  ) async {
    await transaction(() async {
      await (update(transactions)..where((t) => t.id.equals(transaction.id.value))).write(transaction);
      // Delete existing splits
      await (delete(splits)..where((s) => s.transactionId.equals(transaction.id.value))).go();
      // Insert new splits
      for (final split in splitList) {
        await into(splits).insert(split);
      }
    });
  }

  /// Soft deletes a transaction.
  Future<void> softDelete(String id) async {
    await (update(transactions)..where((t) => t.id.equals(id)))
        .write(TransactionsCompanion(deletedAt: Value(DateTime.now().millisecondsSinceEpoch)));
  }

  /// Checks if a transaction exists by external ID.
  Future<bool> existsByExternalId(String externalId) async {
    final result = await (select(transactions)
          ..where((t) => t.externalId.equals(externalId)))
        .getSingleOrNull();
    return result != null;
  }

  /// Watches transactions within a date range.
  Stream<List<Transaction>> watchByDateRange(DateTime start, DateTime end) {
    final startMs = start.millisecondsSinceEpoch;
    final endMs = end.millisecondsSinceEpoch;
    return (select(transactions)
          ..where((t) => t.postDate.isBetweenValues(startMs, endMs) & t.deletedAt.isNull())
          ..orderBy([(t) => OrderingTerm.desc(t.postDate)]))
        .watch();
  }

  /// Gets transaction count.
  Future<int> count({String? accountId}) async {
    if (accountId != null) {
      final query = selectOnly(transactions)
        ..join([innerJoin(splits, splits.transactionId.equalsExp(transactions.id))])
        ..where(splits.accountId.equals(accountId) & transactions.deletedAt.isNull());
      query.addColumns([transactions.id.count()]);
      final result = await query.getSingle();
      return result.read(transactions.id.count()) ?? 0;
    }
    final query = selectOnly(transactions)..where(transactions.deletedAt.isNull());
    query.addColumns([transactions.id.count()]);
    final result = await query.getSingle();
    return result.read(transactions.id.count()) ?? 0;
  }
}