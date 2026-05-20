import 'dart:typed_data';
import 'package:drift/drift.dart' as drift;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:importers/importers.dart';
import 'package:core/core.dart';
import 'package:database/database.dart' hide Transaction, Split, Account, ImportBatch, TransactionRepository;

import 'package:finance_app/features/accounts/data/account_provider.dart';
import '../data/importer_registry.dart';

/// Provider for the importer registry.
final importerRegistryProvider = Provider<ImporterRegistry>((ref) {
  return ImporterRegistry();
});

/// Provider for accounts available for import.
final importAccountsProvider = FutureProvider<List<Account>>((ref) async {
  final db = ref.watch(databaseProvider);
  return db.select(db.accounts).get();
});

/// Provider for default asset account.
final defaultAssetAccountProvider = Provider<Account?>((ref) {
  final accounts = ref.watch(accountsProvider);
  return accounts.when(
    data: (list) {
      // Find first ASSET type account
      final assetAccounts = list.where((a) => a.accountType == 'ASSET').toList();
      return assetAccounts.isNotEmpty ? assetAccounts.first : null;
    },
    loading: () => null,
    error: (_, __) => null,
  );
});

/// Provider for ImportTransactions use case.
final importTransactionsProvider = Provider<ImportTransactions>((ref) {
  final db = ref.watch(databaseProvider);
  final repo = TransactionRepositoryImpl(db);
  return ImportTransactions(repo);
});

/// State for import operation.
class ImportState {
  final bool isLoading;
  final ImportBatch? batch;
  final String? error;

  const ImportState({
    this.isLoading = false,
    this.batch,
    this.error,
  });

  ImportState copyWith({
    bool? isLoading,
    ImportBatch? batch,
    String? error,
  }) {
    return ImportState(
      isLoading: isLoading ?? this.isLoading,
      batch: batch ?? this.batch,
      error: error ?? this.error,
    );
  }
}

/// Notifier for performing import operations.
class ImportNotifier extends StateNotifier<ImportState> {
  final Ref _ref;

  ImportNotifier(this._ref) : super(const ImportState());

  Future<ImportBatch> performImport({
    required ImporterBase importer,
    required Uint8List content,
    required String targetAccountId,
    required String filename,
  }) async {
    state = const ImportState(isLoading: true);

    try {
      final config = ImportConfig(
        targetAccountId: targetAccountId,
        defaultCurrencyId: 'CNY',
        categoryMapping: importer.getDefaultCategoryMappings(),
        skipDuplicates: true,
      );

      final result = await importer.parse(
        content: content,
        config: config,
      );

      final useCase = _ref.read(importTransactionsProvider);
      
      final batch = await useCase.import(
        sourceId: importer.sourceId,
        transactions: result.transactions,
        filename: filename,
        skipDuplicates: true,
      );

      state = ImportState(batch: batch);
      return batch;
    } catch (e) {
      state = ImportState(error: e.toString());
      rethrow;
    }
  }
}

final importNotifierProvider = StateNotifierProvider<ImportNotifier, ImportState>((ref) {
  return ImportNotifier(ref);
});

/// Simple TransactionRepository implementation for import.
class TransactionRepositoryImpl implements TransactionRepository {
  final LocalFinanceDatabase _db;

  TransactionRepositoryImpl(this._db);

  @override
  Future<Transaction> create(Transaction transaction, List<Split> splits) async {
    await _db.transactionsDao.createWithSplits(
      TransactionsCompanion.insert(
        id: transaction.id,
        postDate: transaction.postDate.millisecondsSinceEpoch,
        enterDate: transaction.enterDate.millisecondsSinceEpoch,
        currencyId: transaction.commodityId,
        description: drift.Value(transaction.description),
        notes: drift.Value(transaction.notes),
        externalId: drift.Value(transaction.externalId),
        importBatchId: drift.Value(transaction.importBatchId),
        createdAt: DateTime.now().millisecondsSinceEpoch,
        updatedAt: DateTime.now().millisecondsSinceEpoch,
      ),
      splits.map((s) => SplitsCompanion.insert(
        id: s.id,
        transactionId: s.transactionId,
        accountId: s.accountId,
        valueNum: s.valueNum,
        valueDenom: s.valueDenom,
        quantityNum: s.quantityNum,
        quantityDenom: s.quantityDenom,
        createdAt: DateTime.now().millisecondsSinceEpoch,
      )).toList(),
    );
    return transaction;
  }

  @override
  Future<bool> existsByExternalId(String externalId) async {
    final result = await (_db.select(_db.transactions)
      ..where((t) => t.externalId.equals(externalId))
    ).getSingleOrNull();
    return result != null;
  }

  @override
  Future<List<Transaction>> getAll() async {
    final dbTransactions = await _db.transactionsDao.getAll();
    return dbTransactions.map(_mapDbToTransaction).toList();
  }

  @override
  Future<Transaction?> getById(String id) async {
    final dbTransaction = await _db.transactionsDao.getById(id);
    return dbTransaction != null ? _mapDbToTransaction(dbTransaction) : null;
  }

  @override
  Future<Transaction> update(Transaction transaction, List<Split> splits) async {
    await (_db.update(_db.transactions)
      ..where((t) => t.id.equals(transaction.id))
    ).write(TransactionsCompanion(
      description: drift.Value(transaction.description),
      notes: drift.Value(transaction.notes),
      updatedAt: drift.Value(DateTime.now().millisecondsSinceEpoch),
    ));
    return transaction;
  }

  @override
  Future<void> delete(String id) async {
    await _db.transactionsDao.softDelete(id);
  }

  @override
  Future<List<Transaction>> getByDateRange(DateTime start, DateTime end) async {
    final dbTransactions = await _db.transactionsDao.getByDateRange(start, end);
    return dbTransactions.map(_mapDbToTransaction).toList();
  }

  @override
  Future<List<Transaction>> getByAccount(String accountId) async {
    final splits = await (_db.select(_db.splits)
      ..where((s) => s.accountId.equals(accountId))
    ).get();
    final transactionIds = splits.map((s) => s.transactionId).toSet();
    if (transactionIds.isEmpty) return [];
    final dbTransactions = await (_db.select(_db.transactions)
      ..where((t) => t.id.isIn(transactionIds))
    ).get();
    return dbTransactions.map(_mapDbToTransaction).toList();
  }

  @override
  Future<List<Transaction>> getByImportBatch(String batchId) async {
    final dbTransactions = await (_db.select(_db.transactions)
      ..where((t) => t.importBatchId.equals(batchId))
    ).get();
    return dbTransactions.map(_mapDbToTransaction).toList();
  }

  @override
  Future<List<Split>> getSplits(String transactionId) async {
    final dbSplits = await _db.transactionsDao.getSplits(transactionId);
    return dbSplits.map(_mapDbToSplit).toList();
  }

  @override
  Future<List<Transaction>> search(TransactionQuery query) async {
    var q = _db.select(_db.transactions);
    
    if (query.startDate != null) {
      q = q..where((t) => t.postDate.isBiggerOrEqualValue(query.startDate!.millisecondsSinceEpoch));
    }
    if (query.endDate != null) {
      q = q..where((t) => t.postDate.isSmallerOrEqualValue(query.endDate!.millisecondsSinceEpoch));
    }
    if (query.searchText != null && query.searchText!.isNotEmpty) {
      q = q..where((t) => t.description.like('%${query.searchText}%'));
    }
    
    var results = await q.get();
    
    if (query.limit != null) {
      results = results.take(query.limit!).toList();
    }
    
    return results.map(_mapDbToTransaction).toList();
  }

  @override
  Future<int> count({String? accountId, DateTime? start, DateTime? end}) async {
    var q = _db.selectOnly(_db.transactions);
    q.addColumns([_db.transactions.id.count()]);
    
    if (start != null) {
      q = q..where(_db.transactions.postDate.isBiggerOrEqualValue(start.millisecondsSinceEpoch));
    }
    if (end != null) {
      q = q..where(_db.transactions.postDate.isSmallerOrEqualValue(end.millisecondsSinceEpoch));
    }
    
    final result = await q.getSingle();
    return result.read(_db.transactions.id.count()) ?? 0;
  }

  // Mapper functions
  Transaction _mapDbToTransaction(dynamic db) {
    // Database Transaction has: id, description, postDate (int), enterDate (int), currencyId, etc.
    return Transaction(
      id: db.id as String,
      description: db.description as String?,
      postDate: DateTime.fromMillisecondsSinceEpoch(db.postDate as int),
      enterDate: DateTime.fromMillisecondsSinceEpoch(db.enterDate as int),
      commodityId: db.currencyId as String,
      notes: db.notes as String?,
      importBatchId: db.importBatchId as String?,
      externalId: db.externalId as String?,
      isDoubleEntry: db.isDoubleEntry as bool? ?? false,
      version: db.version as int? ?? 1,
      createdAt: DateTime.fromMillisecondsSinceEpoch(db.createdAt as int),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(db.updatedAt as int),
      deletedAt: db.deletedAt != null ? DateTime.fromMillisecondsSinceEpoch(db.deletedAt as int) : null,
    );
  }

  Split _mapDbToSplit(dynamic db) {
    // Database Split has: id, transactionId, accountId, memo, valueNum, valueDenom, quantityNum, quantityDenom, reconcileState, reconcileDate, version, createdAt
    return Split(
      id: db.id as String,
      transactionId: db.transactionId as String,
      accountId: db.accountId as String,
      memo: db.memo as String?,
      valueNum: db.valueNum as int,
      valueDenom: db.valueDenom as int? ?? 1,
      quantityNum: db.quantityNum as int,
      quantityDenom: db.quantityDenom as int? ?? 1,
      reconcileState: _parseReconcileState(db.reconcileState as String? ?? 'n'),
      reconcileDate: db.reconcileDate != null ? DateTime.fromMillisecondsSinceEpoch(db.reconcileDate as int) : null,
      version: db.version as int? ?? 1,
      createdAt: DateTime.fromMillisecondsSinceEpoch(db.createdAt as int),
    );
  }

  ReconcileState _parseReconcileState(String code) {
    switch (code) {
      case 'n':
        return ReconcileState.none;
      case 'c':
        return ReconcileState.cleared;
      case 'y':
        return ReconcileState.reconciled;
      case 'v':
        return ReconcileState.voided;
      default:
        return ReconcileState.none;
    }
  }
}
