import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart' as drift;
import 'package:uuid/uuid.dart';

import 'package:database/database.dart';
import 'package:finance_app/features/accounts/data/account_provider.dart';

/// Provider that watches all non-deleted tags.
final allTagsProvider = StreamProvider<List<Tag>>((ref) {
  final db = ref.watch(databaseProvider);
  return db.tagsDao.watchAllTags();
});

/// Provider that watches tags for a specific transaction.
final transactionTagsProvider = StreamProvider.family<List<Tag>, String>((ref, transactionId) {
  final db = ref.watch(databaseProvider);
  return db.tagsDao.watchTagsForTransaction(transactionId);
});

/// Notifier for tag CRUD operations.
class TagNotifier extends StateNotifier<AsyncValue<void>> {
  final LocalFinanceDatabase _db;

  TagNotifier(this._db) : super(const AsyncValue.data(null));

  Future<void> createTag({
    required String name,
    String color = '#607D8B',
    String? description,
    String? icon,
  }) async {
    state = const AsyncValue.loading();
    try {
      await _db.tagsDao.createTag(
        name: name,
        color: color,
        description: description,
        icon: icon,
      );
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> updateTag({
    required String id,
    String? name,
    String? color,
    String? description,
    String? icon,
  }) async {
    state = const AsyncValue.loading();
    try {
      await _db.tagsDao.updateTag(
        id: id,
        name: name,
        color: color,
        description: description,
        icon: icon,
      );
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> deleteTag(String id) async {
    state = const AsyncValue.loading();
    try {
      await _db.tagsDao.deleteTag(id);
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> updateTransactionTags(String transactionId, List<String> tagIds) async {
    state = const AsyncValue.loading();
    try {
      await _db.tagsDao.updateTransactionTags(transactionId, tagIds);
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }
}

/// Provider for the tag notifier.
final tagNotifierProvider = StateNotifierProvider<TagNotifier, AsyncValue<void>>((ref) {
  final db = ref.watch(databaseProvider);
  return TagNotifier(db);
});
