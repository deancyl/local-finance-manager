import 'dart:typed_data';
import 'package:drift/drift.dart' as drift;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:importers/importers.dart';
import 'package:core/core.dart' hide ParsedTransaction;
import 'package:core/core.dart' as core show ParsedTransaction;
import 'package:database/database.dart' as db;

import 'package:finance_app/features/accounts/data/account_provider.dart';
import '../data/importer_registry.dart';

// ============================================================
// TOP-LEVEL MAPPER FUNCTIONS
// ============================================================

/// Convert ParsedTransaction from importers to core
core.ParsedTransaction _mapToCoreParsedTransaction(ParsedTransaction t) {
  return core.ParsedTransaction(
    accountId: t.accountId,
    amount: t.amount,
    date: t.date,
    currencyId: t.currencyId,
    description: t.description,
    notes: t.notes,
    memo: t.memo,
    externalId: t.externalId,
    category: t.category,
    payee: t.payee,
  );
}

Account _mapDbToAccount(db.Account dbAccount) {
  return Account(
    id: dbAccount.id,
    name: dbAccount.name,
    accountType: _stringToAccountType(dbAccount.accountType),
    commodityId: dbAccount.commodityId,
    parentId: dbAccount.parentId,
    code: dbAccount.code,
    description: dbAccount.description,
    isPlaceholder: dbAccount.isPlaceholder,
    isHidden: dbAccount.isHidden,
    sortOrder: dbAccount.sortOrder,
    createdAt: DateTime.fromMillisecondsSinceEpoch(dbAccount.createdAt),
    updatedAt: DateTime.fromMillisecondsSinceEpoch(dbAccount.updatedAt),
    version: dbAccount.version,
  );
}

Transaction _mapDbToTransaction(db.Transaction dbTx) {
  return Transaction(
    id: dbTx.id,
    description: dbTx.description,
    postDate: DateTime.fromMillisecondsSinceEpoch(dbTx.postDate),
    enterDate: DateTime.fromMillisecondsSinceEpoch(dbTx.enterDate),
    commodityId: dbTx.currencyId,
    notes: dbTx.notes,
    importBatchId: dbTx.importBatchId,
    externalId: dbTx.externalId,
    isDoubleEntry: dbTx.isDoubleEntry ?? false,
    version: dbTx.version,
    createdAt: DateTime.fromMillisecondsSinceEpoch(dbTx.createdAt),
    updatedAt: DateTime.fromMillisecondsSinceEpoch(dbTx.updatedAt),
    deletedAt: dbTx.deletedAt != null ? DateTime.fromMillisecondsSinceEpoch(dbTx.deletedAt!) : null,
  );
}

Split _mapDbToSplit(db.Split dbSplit) {
  return Split(
    id: dbSplit.id,
    transactionId: dbSplit.transactionId,
    accountId: dbSplit.accountId,
    memo: dbSplit.memo,
    valueNum: dbSplit.valueNum,
    valueDenom: dbSplit.valueDenom,
    quantityNum: dbSplit.quantityNum,
    quantityDenom: dbSplit.quantityDenom,
    reconcileState: _parseReconcileState(dbSplit.reconcileState ?? 'n'),
    reconcileDate: dbSplit.reconcileDate != null ? DateTime.fromMillisecondsSinceEpoch(dbSplit.reconcileDate!) : null,
    version: dbSplit.version,
    createdAt: DateTime.fromMillisecondsSinceEpoch(dbSplit.createdAt),
  );
}

AccountType _stringToAccountType(String type) {
  switch (type) {
    case 'ASSET':
      return AccountType.asset;
    case 'LIABILITY':
      return AccountType.liability;
    case 'EQUITY':
      return AccountType.equity;
    case 'INCOME':
      return AccountType.income;
    case 'EXPENSE':
      return AccountType.expense;
    default:
      return AccountType.asset;
  }
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

// ============================================================
// PROVIDERS
// ============================================================

/// Provider for the importer registry.
final importerRegistryProvider = Provider<ImporterRegistry>((ref) {
  return ImporterRegistry();
});

/// Provider for accounts available for import.
final importAccountsProvider = FutureProvider<List<Account>>((ref) async {
  final database = ref.watch(databaseProvider);
  final dbAccounts = await database.select(database.accounts).get();
  return dbAccounts.map(_mapDbToAccount).toList();
});

/// Provider for default asset account.
final defaultAssetAccountProvider = Provider<Account?>((ref) {
  final accounts = ref.watch(accountsProvider);
  return accounts.when(
    data: (list) {
      // Find first ASSET type account and map to core Account
      final assetAccounts = list.where((a) => a.accountType == 'ASSET').toList();
      return assetAccounts.isNotEmpty ? _mapDbToAccount(assetAccounts.first) : null;
    },
    loading: () => null,
    error: (_, __) => null,
  );
});

/// Provider for ImportTransactions use case.
final importTransactionsProvider = Provider<ImportTransactions>((ref) {
  final database = ref.watch(databaseProvider);
  final repo = TransactionRepositoryImpl(database);
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

/// Progress state for import operation with row-by-row tracking.
class ImportProgress {
  /// Total rows to process.
  final int totalRows;
  
  /// Current row being processed.
  final int currentRow;
  
  /// Successfully processed rows.
  final int successCount;
  
  /// Failed rows.
  final int errorCount;
  
  /// Duplicate rows skipped.
  final int duplicateCount;
  
  /// Current status message.
  final String statusMessage;
  
  /// Whether the import is cancelled.
  final bool isCancelled;
  
  /// Whether the import is complete.
  final bool isComplete;
  
  /// Processing start time.
  final DateTime? startTime;
  
  /// Processing end time.
  final DateTime? endTime;

  const ImportProgress({
    this.totalRows = 0,
    this.currentRow = 0,
    this.successCount = 0,
    this.errorCount = 0,
    this.duplicateCount = 0,
    this.statusMessage = '',
    this.isCancelled = false,
    this.isComplete = false,
    this.startTime,
    this.endTime,
  });

  /// Progress percentage (0.0 to 1.0).
  double get progress => totalRows > 0 ? currentRow / totalRows : 0;
  
  /// Progress percentage as integer (0 to 100).
  int get progressPercent => (progress * 100).round();
  
  /// Whether progress should be shown (for files > 100 rows).
  bool get showProgress => totalRows > 100;
  
  /// Estimated time remaining in seconds.
  int? get estimatedSecondsRemaining {
    if (startTime == null || currentRow == 0 || currentRow >= totalRows) return null;
    final elapsed = DateTime.now().difference(startTime!);
    final rowsPerMs = currentRow / elapsed.inMilliseconds;
    final remainingRows = totalRows - currentRow;
    return (remainingRows / rowsPerMs / 1000).round();
  }
  
  /// Elapsed time in seconds.
  int get elapsedSeconds {
    if (startTime == null) return 0;
    final end = endTime ?? DateTime.now();
    return end.difference(startTime!).inSeconds;
  }

  ImportProgress copyWith({
    int? totalRows,
    int? currentRow,
    int? successCount,
    int? errorCount,
    int? duplicateCount,
    String? statusMessage,
    bool? isCancelled,
    bool? isComplete,
    DateTime? startTime,
    DateTime? endTime,
  }) {
    return ImportProgress(
      totalRows: totalRows ?? this.totalRows,
      currentRow: currentRow ?? this.currentRow,
      successCount: successCount ?? this.successCount,
      errorCount: errorCount ?? this.errorCount,
      duplicateCount: duplicateCount ?? this.duplicateCount,
      statusMessage: statusMessage ?? this.statusMessage,
      isCancelled: isCancelled ?? this.isCancelled,
      isComplete: isComplete ?? this.isComplete,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
    );
  }
}

/// Notifier for performing import operations.
class ImportNotifier extends StateNotifier<ImportState> {
  final Ref _ref;
  
  /// Current import progress.
  ImportProgress _progress = const ImportProgress();
  
  /// Whether a cancel request has been made.
  bool _cancelRequested = false;

  ImportNotifier(this._ref) : super(const ImportState());

  /// Get current progress.
  ImportProgress get progress => _progress;
  
  /// Request cancellation of the current import.
  void cancelImport() {
    _cancelRequested = true;
  }
  
  /// Reset the cancel flag.
  void _resetCancel() {
    _cancelRequested = false;
  }
  
  /// Check if cancellation was requested.
  bool get isCancelled => _cancelRequested;

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
        transactions: result.transactions.map(_mapToCoreParsedTransaction).toList(),
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
  
  /// Perform import with a custom ImportConfig (including field mapping).
  Future<ImportBatch> performImportWithConfig({
    required ImporterBase importer,
    required Uint8List content,
    required ImportConfig config,
    required String filename,
    void Function(ImportProgress)? onProgress,
  }) async {
    _resetCancel();
    state = const ImportState(isLoading: true);
    _progress = ImportProgress(
      startTime: DateTime.now(),
      statusMessage: '正在解析文件...',
    );
    onProgress?.call(_progress);

    try {
      // Merge default category mappings with provided config
      final mergedConfig = config.copyWith(
        categoryMapping: {
          ...importer.getDefaultCategoryMappings(),
          ...config.categoryMapping,
        },
      );

      // Parse the file first
      final result = await importer.parse(
        content: content,
        config: mergedConfig,
      );
      
      // Update progress with total rows
      final totalRows = result.transactions.length;
      _progress = _progress.copyWith(
        totalRows: totalRows,
        statusMessage: '准备导入 $totalRows 条交易...',
      );
      onProgress?.call(_progress);
      
      // Check for cancellation
      if (_cancelRequested) {
        _progress = _progress.copyWith(
          isCancelled: true,
          endTime: DateTime.now(),
          statusMessage: '导入已取消',
        );
        onProgress?.call(_progress);
        throw Exception('Import cancelled by user');
      }

      final useCase = _ref.read(importTransactionsProvider);
      
      // For large files, simulate progress updates
      // Note: The actual import is done in batch, so we show parsing progress
      if (totalRows > 100) {
        // Import in smaller batches for progress updates
        const batchSize = 50;
        var importedCount = 0;
        final allTransactions = result.transactions;
        ImportBatch? finalBatch;
        
        for (var i = 0; i < allTransactions.length; i += batchSize) {
          if (_cancelRequested) {
            _progress = _progress.copyWith(
              isCancelled: true,
              endTime: DateTime.now(),
              statusMessage: '导入已取消 (已导入 $importedCount 条)',
            );
            onProgress?.call(_progress);
            throw Exception('Import cancelled by user');
          }
          
          final end = (i + batchSize < allTransactions.length) 
              ? i + batchSize 
              : allTransactions.length;
          final batch = allTransactions.sublist(i, end);
          
          _progress = _progress.copyWith(
            currentRow: end,
            successCount: importedCount,
            statusMessage: '正在处理第 $end / $totalRows 条...',
          );
          onProgress?.call(_progress);
          
          // Import this batch
          final batchResult = await useCase.import(
            sourceId: importer.sourceId,
            transactions: batch.map(_mapToCoreParsedTransaction).toList(),
            filename: filename,
            skipDuplicates: mergedConfig.skipDuplicates,
          );
          
          importedCount += batchResult.successCount;
          finalBatch = batchResult;
        }
        
        _progress = _progress.copyWith(
          currentRow: totalRows,
          successCount: importedCount,
          isComplete: true,
          endTime: DateTime.now(),
          statusMessage: '导入完成',
        );
        onProgress?.call(_progress);
        
        state = ImportState(batch: finalBatch);
        return finalBatch!;
      } else {
        // Small file, import directly
        final batch = await useCase.import(
          sourceId: importer.sourceId,
          transactions: result.transactions.map(_mapToCoreParsedTransaction).toList(),
          filename: filename,
          skipDuplicates: mergedConfig.skipDuplicates,
        );
        
        _progress = _progress.copyWith(
          currentRow: totalRows,
          successCount: batch.successCount,
          duplicateCount: batch.duplicateCount,
          isComplete: true,
          endTime: DateTime.now(),
          statusMessage: '导入完成',
        );
        onProgress?.call(_progress);

        state = ImportState(batch: batch);
        return batch;
      }
    } catch (e) {
      _progress = _progress.copyWith(
        isComplete: true,
        endTime: DateTime.now(),
        statusMessage: '导入失败: $e',
      );
      onProgress?.call(_progress);
      state = ImportState(error: e.toString());
      rethrow;
    }
  }
}

final importNotifierProvider = StateNotifierProvider<ImportNotifier, ImportState>((ref) {
  return ImportNotifier(ref);
});

/// Provider for import progress state.
final importProgressProvider = StateProvider<ImportProgress>((ref) {
  return const ImportProgress();
});

/// Simple TransactionRepository implementation for import.
class TransactionRepositoryImpl implements TransactionRepository {
  final db.LocalFinanceDatabase _db;

  TransactionRepositoryImpl(this._db);

  @override
  Future<Transaction> create(Transaction transaction, List<Split> splits) async {
    await _db.transactionsDao.createWithSplits(
      db.TransactionsCompanion.insert(
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
      splits.map((s) => db.SplitsCompanion.insert(
        id: s.id,
        transactionId: s.transactionId,
        accountId: s.accountId,
        valueNum: s.valueNum,
        valueDenom: drift.Value(s.valueDenom),
        quantityNum: s.quantityNum,
        quantityDenom: drift.Value(s.quantityDenom),
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
    ).write(db.TransactionsCompanion(
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

  @override
  Future<List<SplitWithTransactionData>> getSplitsForAccount(
    String accountId, {
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    // Not implemented for import use case
    return [];
  }

  @override
  Future<void> updateSplitReconcileState(
    String splitId,
    String reconcileState,
    int? reconcileDate,
  ) async {
    // Not implemented for import use case
  }
}
