part of '../database.dart';

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
    await batch((b) async {
      b.insert(transactions, transaction);
      for (final split in splitList) {
        b.insert(splits, split);
      }
    });
    return transaction.id.value;
  }

  /// Updates a transaction with splits.
  Future<void> updateWithSplits(
    TransactionsCompanion transaction,
    List<SplitsCompanion> splitList,
  ) async {
    await batch((b) async {
      b.replace(transactions, transaction);
      // Delete existing splits
      await (delete(splits)..where((s) => s.transactionId.equals(transaction.id.value))).go();
      // Insert new splits
      for (final split in splitList) {
        b.insert(splits, split);
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

  /// Gets all splits for non-deleted transactions.
  Future<List<Split>> getAllSplits() {
    final query = select(splits).join([
      innerJoin(transactions, transactions.id.equalsExp(splits.transactionId)),
    ])
      ..where(transactions.deletedAt.isNull());
    
    return query.map((row) => row.readTable(splits)).get();
  }

  /// Watches all splits for non-deleted transactions.
  Stream<List<Split>> watchAllSplits() {
    final query = select(splits).join([
      innerJoin(transactions, transactions.id.equalsExp(splits.transactionId)),
    ])
      ..where(transactions.deletedAt.isNull());
    
    return query.map((row) => row.readTable(splits)).watch();
  }

  /// Monthly trend result for aggregated income/expense data.
  /// Returns month label, income total, and expense total.
  Future<List<({String monthLabel, double income, double expense})>> getMonthlyTrend(
    DateTime startDate,
    DateTime endDate,
  ) async {
    final startMs = startDate.millisecondsSinceEpoch;
    final endMs = endDate.millisecondsSinceEpoch;

    // Single query with JOINs to get all splits with account type and transaction date
    // Filter by date range and group by month
    final query = customSelect(
      '''
      SELECT 
        strftime('%Y-%m', datetime(t.post_date / 1000, 'unixepoch')) AS month_label,
        SUM(CASE WHEN a.account_type = 'INCOME' THEN ABS(s.value_num) ELSE 0 END) / 100.0 AS income,
        SUM(CASE WHEN a.account_type = 'EXPENSE' THEN ABS(s.value_num) ELSE 0 END) / 100.0 AS expense
      FROM splits s
      INNER JOIN transactions t ON t.id = s.transaction_id
      INNER JOIN accounts a ON a.id = s.account_id
      WHERE t.post_date >= ?1 
        AND t.post_date <= ?2
        AND t.deleted_at IS NULL
        AND s.value_num != 0
      GROUP BY month_label
      ORDER BY month_label ASC
      ''',
      variables: [Variable.withInt(startMs), Variable.withInt(endMs)],
      readsFrom: {transactions, splits, accounts},
    );

    final results = await query.get();

    return results.map((row) {
      final monthLabel = row.read<String>('month_label');
      final income = row.read<double>('income') ?? 0.0;
      final expense = row.read<double>('expense') ?? 0.0;
      return (monthLabel: monthLabel, income: income, expense: expense);
    }).toList();
  }
}