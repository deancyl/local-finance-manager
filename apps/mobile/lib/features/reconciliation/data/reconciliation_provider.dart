import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart' as drift;

import 'package:database/database.dart' as db;
import 'package:core/core.dart' as core;
import '../../accounts/data/account_provider.dart';

// Type aliases
typedef DbAccount = db.Account;
typedef DbTransaction = db.Transaction;
typedef DbSplit = db.Split;

// Conversion helpers
core.Account _convertDbToAccount(DbAccount a) {
  return core.Account(
    id: a.id,
    name: a.name,
    accountType: core.AccountType.values.firstWhere(
      (t) => t.name.toUpperCase() == a.accountType.toUpperCase(),
      orElse: () => core.AccountType.asset,
    ),
    commodityId: a.commodityId,
    parentId: a.parentId,
    description: a.description,
    isPlaceholder: a.isPlaceholder,
    isHidden: a.isHidden,
    sortOrder: a.sortOrder,
    version: a.version,
    createdAt: DateTime.fromMillisecondsSinceEpoch(a.createdAt),
    updatedAt: DateTime.fromMillisecondsSinceEpoch(a.updatedAt),
  );
}

core.Transaction _convertDbToTransaction(DbTransaction t) {
  return core.Transaction(
    id: t.id,
    description: t.description,
    postDate: DateTime.fromMillisecondsSinceEpoch(t.postDate),
    enterDate: DateTime.fromMillisecondsSinceEpoch(t.enterDate),
    commodityId: t.currencyId,
    referenceNumber: t.referenceNum,
    notes: t.notes,
    importBatchId: t.importBatchId,
    externalId: t.externalId,
    isDoubleEntry: t.isDoubleEntry,
    idempotencyKey: t.idempotencyKey,
    version: t.version,
    createdAt: DateTime.fromMillisecondsSinceEpoch(t.createdAt),
    updatedAt: DateTime.fromMillisecondsSinceEpoch(t.updatedAt),
    deletedAt: t.deletedAt != null ? DateTime.fromMillisecondsSinceEpoch(t.deletedAt!) : null,
  );
}

core.Split _convertDbToSplit(DbSplit s) {
  core.ReconcileState reconcileState;
  switch (s.reconcileState) {
    case 'c':
      reconcileState = core.ReconcileState.cleared;
      break;
    case 'y':
      reconcileState = core.ReconcileState.reconciled;
      break;
    case 'v':
      reconcileState = core.ReconcileState.voided;
      break;
    default:
      reconcileState = core.ReconcileState.none;
  }
  
  return core.Split(
    id: s.id,
    transactionId: s.transactionId,
    accountId: s.accountId,
    memo: s.memo,
    valueNum: s.valueNum,
    valueDenom: s.valueDenom,
    quantityNum: s.quantityNum,
    quantityDenom: s.quantityDenom,
    reconcileState: reconcileState,
    reconcileDate: s.reconcileDate != null ? DateTime.fromMillisecondsSinceEpoch(s.reconcileDate!) : null,
    version: s.version,
    createdAt: DateTime.fromMillisecondsSinceEpoch(s.createdAt),
  );
}

/// Provider for the reconciliation service.
final reconciliationServiceProvider = Provider<core.ReconciliationService>((ref) {
  final db = ref.watch(databaseProvider);
  // Create repositories from database
  final accountRepo = _DatabaseAccountRepository(db);
  final transactionRepo = _DatabaseTransactionRepository(db);
  return core.ReconciliationService(accountRepo, transactionRepo);
});

/// Current reconciliation session state.
class ReconciliationState {
  final String? accountId;
  final String? accountName;
  final DateTime? statementDate;
  final int statementBalanceNum;
  final int statementBalanceDenom;
  final core.ReconciliationResult? result;
  final bool isLoading;
  final String? error;

  ReconciliationState({
    this.accountId,
    this.accountName,
    this.statementDate,
    this.statementBalanceNum = 0,
    this.statementBalanceDenom = 1,
    this.result,
    this.isLoading = false,
    this.error,
  });

  ReconciliationState copyWith({
    String? accountId,
    String? accountName,
    DateTime? statementDate,
    int? statementBalanceNum,
    int? statementBalanceDenom,
    core.ReconciliationResult? result,
    bool? isLoading,
    String? error,
    bool clearError = false,
  }) {
    return ReconciliationState(
      accountId: accountId ?? this.accountId,
      accountName: accountName ?? this.accountName,
      statementDate: statementDate ?? this.statementDate,
      statementBalanceNum: statementBalanceNum ?? this.statementBalanceNum,
      statementBalanceDenom: statementBalanceDenom ?? this.statementBalanceDenom,
      result: result ?? this.result,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : error ?? this.error,
    );
  }

  /// Statement balance as decimal (for display).
  double get statementBalance => 
      statementBalanceNum / statementBalanceDenom.toDouble();

  /// Returns true if a reconciliation session is active.
  bool get hasSession => accountId != null && statementDate != null;

  /// Returns true if reconciliation is balanced.
  bool get isBalanced => result?.isBalanced ?? false;

  /// Returns the difference amount.
  double get difference => result?.difference ?? 0.0;
}

/// Notifier for managing reconciliation sessions.
class ReconciliationNotifier extends StateNotifier<ReconciliationState> {
  final core.ReconciliationService _service;
  final db.LocalFinanceDatabase _db;

  ReconciliationNotifier(this._service, this._db) : super(ReconciliationState());

  /// Starts a new reconciliation session.
  Future<void> startSession({
    required String accountId,
    required String accountName,
    required DateTime statementDate,
    required int statementBalanceNum,
    int statementBalanceDenom = 1,
  }) async {
    state = state.copyWith(
      accountId: accountId,
      accountName: accountName,
      statementDate: statementDate,
      statementBalanceNum: statementBalanceNum,
      statementBalanceDenom: statementBalanceDenom,
      isLoading: true,
      clearError: true,
    );

    try {
      final result = await _service.startReconciliation(
        accountId: accountId,
        statementDate: statementDate,
        statementBalanceNum: statementBalanceNum,
        statementBalanceDenom: statementBalanceDenom,
      );

      state = state.copyWith(
        result: result,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  /// Refreshes the reconciliation result.
  Future<void> refresh() async {
    if (!state.hasSession) return;

    state = state.copyWith(isLoading: true, clearError: true);

    try {
      final result = await _service.startReconciliation(
        accountId: state.accountId!,
        statementDate: state.statementDate!,
        statementBalanceNum: state.statementBalanceNum,
        statementBalanceDenom: state.statementBalanceDenom,
      );

      state = state.copyWith(
        result: result,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  /// Marks a split as cleared.
  Future<void> markCleared(String splitId) async {
    try {
      await _service.markSplitCleared(splitId);
      await refresh();
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  /// Marks a split as reconciled.
  Future<void> markReconciled(String splitId) async {
    try {
      await _service.markSplitReconciled(splitId);
      await refresh();
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  /// Marks a split as not reconciled.
  Future<void> markNotReconciled(String splitId) async {
    try {
      await _service.markSplitNotReconciled(splitId);
      await refresh();
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  /// Finalizes reconciliation when balanced.
  Future<void> finalize() async {
    if (!state.isBalanced || state.result == null) {
      state = state.copyWith(error: 'Cannot finalize: reconciliation not balanced');
      return;
    }

    try {
      // Mark all cleared splits as reconciled
      final clearedSplitIds = state.result!.splits
          .where((s) => s.reconcileState == core.ReconcileState.cleared)
          .map((s) => s.splitId)
          .toList();

      await _service.finalizeReconciliation(clearedSplitIds);
      
      // Clear the session
      state = ReconciliationState();
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  /// Cancels the current session.
  void cancelSession() {
    state = ReconciliationState();
  }
}

/// Provider for reconciliation state management.
final reconciliationNotifierProvider = 
    StateNotifierProvider<ReconciliationNotifier, ReconciliationState>((ref) {
  final service = ref.watch(reconciliationServiceProvider);
  final db = ref.watch(databaseProvider);
  return ReconciliationNotifier(service, db);
});

/// Provider for accounts eligible for reconciliation (non-placeholder, non-hidden).
/// Returns core.Account type for use with reconciliation service.
final reconcilableAccountsProvider = Provider<List<core.Account>>((ref) {
  final accountsAsync = ref.watch(accountsProvider);
  return accountsAsync.when(
    data: (accounts) => accounts
        .where((a) => !a.isPlaceholder && !a.isHidden)
        .map((a) => _convertDbToAccount(a))
        .toList(),
    loading: () => [],
    error: (_, __) => [],
  );
});

// ============================================================
// INTERNAL REPOSITORY IMPLEMENTATIONS
// These provide the interface implementations using the database directly.
// ============================================================

/// Internal account repository implementation using database.
class _DatabaseAccountRepository implements core.AccountRepository {
  final db.LocalFinanceDatabase _db;

  _DatabaseAccountRepository(this._db);

  @override
  Future<core.Account?> getById(String id) async {
    final dbAccount = await _db.accountsDao.getById(id);
    return dbAccount != null ? _convertDbToAccount(dbAccount) : null;
  }

  @override
  Future<List<core.Account>> getAll() async {
    final dbAccounts = await _db.accountsDao.getAll();
    return dbAccounts.map(_convertDbToAccount).toList();
  }

  @override
  Future<List<core.Account>> getByType(core.AccountType type) async {
    final dbAccounts = await _db.accountsDao.getByType(type.name.toUpperCase());
    return dbAccounts.map(_convertDbToAccount).toList();
  }

  @override
  Future<List<core.Account>> getChildren(String parentId) async {
    final dbAccounts = await _db.accountsDao.getChildren(parentId);
    return dbAccounts.map(_convertDbToAccount).toList();
  }

  @override
  Future<List<core.AccountNode>> getHierarchy() async {
    // Not implemented for reconciliation use case
    return [];
  }

  @override
  Future<double> getBalance(String accountId) async {
    final splits = await _db.splitsDao.getSplitsForAccount(accountId);
    // Sum using integer arithmetic
    int totalNum = 0;
    int denom = 1;
    for (final split in splits) {
      final commonDenom = denom * split.valueDenom;
      totalNum = totalNum * split.valueDenom + split.valueNum * denom;
      denom = commonDenom;
    }
    return totalNum / denom.toDouble();
  }

  @override
  Future<core.Account> create(core.Account account) async {
    throw UnimplementedError('Use AccountNotifier for creating accounts');
  }

  @override
  Future<core.Account> update(core.Account account) async {
    throw UnimplementedError('Use AccountNotifier for updating accounts');
  }

  @override
  Future<void> delete(String id) async {
    throw UnimplementedError('Use AccountNotifier for deleting accounts');
  }
}

/// Internal transaction repository implementation using database.
class _DatabaseTransactionRepository implements core.TransactionRepository {
  final db.LocalFinanceDatabase _db;

  _DatabaseTransactionRepository(this._db);

  @override
  Future<List<core.Transaction>> getAll() async {
    final dbTransactions = await _db.transactionsDao.getAll();
    return dbTransactions.map(_convertDbToTransaction).toList();
  }

  @override
  Future<core.Transaction?> getById(String id) async {
    final dbTransaction = await _db.transactionsDao.getById(id);
    return dbTransaction != null ? _convertDbToTransaction(dbTransaction) : null;
  }

  @override
  Future<List<core.Transaction>> getByDateRange(DateTime start, DateTime end) async {
    final dbTransactions = await _db.transactionsDao.getByDateRange(start, end);
    return dbTransactions.map(_convertDbToTransaction).toList();
  }

  @override
  Future<List<core.Transaction>> getByAccount(String accountId) async {
    final dbTransactions = await _db.transactionsDao.getByAccount(accountId);
    return dbTransactions.map(_convertDbToTransaction).toList();
  }

  @override
  Future<List<core.Transaction>> getByImportBatch(String batchId) async {
    // Not implemented in DAO, return empty
    return [];
  }

  @override
  Future<core.Transaction> create(core.Transaction transaction, List<core.Split> splits) async {
    throw UnimplementedError('Use TransactionNotifier for creating transactions');
  }

  @override
  Future<core.Transaction> update(core.Transaction transaction, List<core.Split> splits) async {
    throw UnimplementedError('Use TransactionNotifier for updating transactions');
  }

  @override
  Future<void> delete(String id) async {
    await _db.transactionsDao.softDelete(id);
  }

  @override
  Future<List<core.Split>> getSplits(String transactionId) async {
    final dbSplits = await _db.transactionsDao.getSplits(transactionId);
    return dbSplits.map(_convertDbToSplit).toList();
  }

  @override
  Future<bool> existsByExternalId(String externalId) async {
    return await _db.transactionsDao.existsByExternalId(externalId);
  }

  @override
  Future<List<core.Transaction>> search(core.TransactionQuery query) async {
    // Use filtered query from DAO
    final results = await _db.transactionsDao.getFilteredTransactionsPaginated(
      limit: query.limit ?? 100,
      offset: query.offset ?? 0,
      startDate: query.startDate,
      endDate: query.endDate,
      accountId: query.accountId,
      categoryId: query.categoryId,
      searchQuery: query.searchText,
    );
    return results.map((r) => _convertDbToTransaction(r.$1)).toList();
  }

  @override
  Future<int> count({String? accountId, DateTime? start, DateTime? end}) async {
    return await _db.transactionsDao.count(accountId: accountId);
  }

  @override
  Future<List<core.SplitWithTransactionData>> getSplitsForAccount(
    String accountId, {
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    // Get splits with transaction info using GeneralLedgerSplitData from DAO
    final splitsData = await _db.splitsDao.getSplitsWithTransactionInfo(
      accountId,
      startDate: startDate,
      endDate: endDate,
    );

    return splitsData.map((data) => core.SplitWithTransactionData(
      splitId: data.splitId,
      transactionId: data.transactionId,
      postDate: data.postDate,
      description: data.description,
      memo: data.memo,
      valueNum: data.valueNum,
      valueDenom: data.valueDenom,
      reconcileState: 'n', // Will need to fetch from actual split
      reconcileDate: null,
    )).toList();
  }

  @override
  Future<void> updateSplitReconcileState(
    String splitId,
    String reconcileState,
    int? reconcileDate,
  ) async {
    await (_db.update(_db.splits)
      ..where((s) => s.id.equals(splitId))).write(
      db.SplitsCompanion(
        reconcileState: drift.Value(reconcileState),
        reconcileDate: drift.Value(reconcileDate),
      ),
    );
  }
}
