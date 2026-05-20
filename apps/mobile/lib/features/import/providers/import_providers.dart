import 'dart:typed_data';
import 'package:drift/drift.dart' as drift;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:importers/importers.dart';
import 'package:core/core.dart';
import 'package:database/database.dart';

import 'package:finance_app/features/accounts/data/account_provider.dart';
import '../data/importer_registry.dart';

/// Provider for the importer registry.
final importerRegistryProvider = Provider<ImporterRegistry>((ref) {
  return ImporterRegistry();
});

/// Provider for accounts available for import.
final importAccountsProvider = FutureProvider<List<Account>>((ref) async {
  final db = ref.watch(databaseProvider);
  return (db.select(db.accounts)..where((a) => a.deletedAt.isNull())).get();
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
  Future<void> create(Transaction transaction, List<Split> splits) async {
    await _db.transactionsDao.createWithSplits(
      TransactionsCompanion.insert(
        id: transaction.id,
        postDate: transaction.postDate.millisecondsSinceEpoch,
        commodityId: transaction.commodityId,
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
        categoryId: drift.Value(s.categoryId),
        valueNum: s.valueNum,
        quantityNum: s.quantityNum,
        createdAt: DateTime.now().millisecondsSinceEpoch,
      )).toList(),
    );
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
    return await _db.transactionsDao.getAll();
  }

  @override
  Future<Transaction?> getById(String id) async {
    return await _db.transactionsDao.getById(id);
  }

  @override
  Future<void> update(Transaction transaction) async {
    await (_db.update(_db.transactions)
      ..where((t) => t.id.equals(transaction.id))
    ).write(TransactionsCompanion(
      description: drift.Value(transaction.description),
      notes: drift.Value(transaction.notes),
      updatedAt: drift.Value(DateTime.now().millisecondsSinceEpoch),
    ));
  }

  @override
  Future<void> delete(String id) async {
    await _db.transactionsDao.softDelete(id);
  }
}