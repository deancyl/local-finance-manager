import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart' as drift;
import 'package:uuid/uuid.dart';

import 'package:database/database.dart';
import 'package:core/core.dart' as domain;

final databaseProvider = Provider<LocalFinanceDatabase>((ref) {
  return LocalFinanceDatabase();
});

final accountsProvider = StreamProvider<List<Account>>((ref) {
  final db = ref.watch(databaseProvider);
  return db.select(db.accounts).watch();
});

final accountsByTypeProvider = Provider.family<List<Account>, String>((ref, type) {
  final accounts = ref.watch(accountsProvider);
  return accounts.when(
    data: (list) => list.where((a) => a.accountType == type).toList(),
    loading: () => [],
    error: (_, __) => [],
  );
});

class AccountNotifier extends StateNotifier<AsyncValue<void>> {
  final LocalFinanceDatabase _db;

  AccountNotifier(this._db) : super(const AsyncValue.data(null));

  Future<void> createAccount({
    required String name,
    required String accountType,
    required String commodityId,
    String? parentId,
    String? code,
    String? description,
  }) async {
    state = const AsyncValue.loading();
    try {
      final id = const Uuid().v4();
      final now = DateTime.now().millisecondsSinceEpoch;
      
      await _db.into(_db.accounts).insert(
        AccountsCompanion.insert(
          id: id,
          name: name,
          accountType: accountType,
          commodityId: commodityId,
          parentId: drift.Value(parentId),
          code: drift.Value(code),
          description: drift.Value(description),
          createdAt: now,
          updatedAt: now,
        ),
      );
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> updateAccount(Account account) async {
    state = const AsyncValue.loading();
    try {
      await (_db.update(_db.accounts)
        ..where((a) => a.id.equals(account.id))).write(
        AccountsCompanion(
          name: drift.Value(account.name),
          accountType: drift.Value(account.accountType),
          parentId: drift.Value(account.parentId),
          code: drift.Value(account.code),
          description: drift.Value(account.description),
          updatedAt: drift.Value(DateTime.now().millisecondsSinceEpoch),
          version: drift.Value(account.version + 1),
        ),
      );
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> deleteAccount(String id) async {
    state = const AsyncValue.loading();
    try {
      await (_db.delete(_db.accounts)..where((a) => a.id.equals(id))).go();
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }
}

final accountNotifierProvider = StateNotifierProvider<AccountNotifier, AsyncValue<void>>((ref) {
  final db = ref.watch(databaseProvider);
  return AccountNotifier(db);
});