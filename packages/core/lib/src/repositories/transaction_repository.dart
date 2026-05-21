import '../models/transaction.dart';
import '../models/split.dart';

/// Repository interface for transaction operations.
abstract class TransactionRepository {
  /// Gets all transactions.
  Future<List<Transaction>> getAll();

  /// Gets a transaction by ID.
  Future<Transaction?> getById(String id);

  /// Gets transactions within a date range.
  Future<List<Transaction>> getByDateRange(DateTime start, DateTime end);

  /// Gets transactions for an account.
  Future<List<Transaction>> getByAccount(String accountId);

  /// Gets transactions by import batch.
  Future<List<Transaction>> getByImportBatch(String batchId);

  /// Creates a new transaction with splits.
  Future<Transaction> create(Transaction transaction, List<Split> splits);

  /// Updates an existing transaction.
  Future<Transaction> update(Transaction transaction, List<Split> splits);

  /// Soft deletes a transaction.
  Future<void> delete(String id);

  /// Gets splits for a transaction.
  Future<List<Split>> getSplits(String transactionId);

  /// Checks if a transaction with the given external ID exists.
  Future<bool> existsByExternalId(String externalId);

  /// Gets transactions matching the given criteria.
  Future<List<Transaction>> search(TransactionQuery query);

  /// Gets the count of transactions.
  Future<int> count({String? accountId, DateTime? start, DateTime? end});

  /// Gets splits for an account within a date range with transaction info.
  /// Returns a list of SplitWithTransactionData containing split and transaction details.
  Future<List<SplitWithTransactionData>> getSplitsForAccount(
    String accountId, {
    DateTime? startDate,
    DateTime? endDate,
  });

  /// Updates the reconcile state of a split.
  Future<void> updateSplitReconcileState(
    String splitId,
    String reconcileState,
    int? reconcileDate,
  );
}

/// Split data with transaction information for reconciliation and reports.
class SplitWithTransactionData {
  final String splitId;
  final String transactionId;
  final int postDate;
  final String? description;
  final String? memo;
  final int valueNum;
  final int valueDenom;
  final String reconcileState;
  final int? reconcileDate;

  SplitWithTransactionData({
    required this.splitId,
    required this.transactionId,
    required this.postDate,
    this.description,
    this.memo,
    required this.valueNum,
    this.valueDenom = 1,
    required this.reconcileState,
    this.reconcileDate,
  });

  /// Returns the date as DateTime.
  DateTime get date => DateTime.fromMillisecondsSinceEpoch(postDate);

  /// Returns the value as a decimal (for display purposes).
  double get value => valueNum / valueDenom.toDouble();
}

/// Query parameters for searching transactions.
class TransactionQuery {
  final String? accountId;
  final String? categoryId;
  final DateTime? startDate;
  final DateTime? endDate;
  final double? minAmount;
  final double? maxAmount;
  final String? searchText;
  final int? limit;
  final int? offset;
  final String? orderBy;
  final bool descending;

  TransactionQuery({
    this.accountId,
    this.categoryId,
    this.startDate,
    this.endDate,
    this.minAmount,
    this.maxAmount,
    this.searchText,
    this.limit,
    this.offset,
    this.orderBy,
    this.descending = true,
  });

  TransactionQuery copyWith({
    String? accountId,
    String? categoryId,
    DateTime? startDate,
    DateTime? endDate,
    double? minAmount,
    double? maxAmount,
    String? searchText,
    int? limit,
    int? offset,
    String? orderBy,
    bool? descending,
  }) {
    return TransactionQuery(
      accountId: accountId ?? this.accountId,
      categoryId: categoryId ?? this.categoryId,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      minAmount: minAmount ?? this.minAmount,
      maxAmount: maxAmount ?? this.maxAmount,
      searchText: searchText ?? this.searchText,
      limit: limit ?? this.limit,
      offset: offset ?? this.offset,
      orderBy: orderBy ?? this.orderBy,
      descending: descending ?? this.descending,
    );
  }
}