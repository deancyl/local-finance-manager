import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart' as drift;
import 'package:uuid/uuid.dart';

import 'package:database/database.dart';
import 'package:finance_app/features/accounts/data/account_provider.dart';
import '../../transactions/data/transaction_filter.dart' show TagFilterLogic;

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

/// Provider for searching tags (autocomplete).
final tagSearchProvider = StreamProvider.family<List<Tag>, String>((ref, query) {
  final db = ref.watch(databaseProvider);
  if (query.isEmpty) {
    return db.tagsDao.watchAllTags();
  }
  return db.tagsDao.searchTags(query);
});

/// Provider for popular tags (ordered by usage).
final popularTagsProvider = FutureProvider<List<Tag>>((ref) async {
  final db = ref.watch(databaseProvider);
  return db.tagsDao.getPopularTags();
});

/// Provider for tags with transaction counts (statistics).
final tagsWithStatsProvider = StreamProvider<List<(Tag, int)>>((ref) {
  final db = ref.watch(databaseProvider);
  return db.tagsDao.watchTagsWithTransactionCount();
});

/// Provider for selected tag IDs in transaction filter.
final selectedFilterTagsProvider = StateProvider<List<String>>((ref) => []);

/// Provider for tag filter mode (AND/OR logic) - uses TagFilterLogic from transaction_filter.dart.
final tagFilterModeProvider = StateProvider<TagFilterLogic>((ref) => TagFilterLogic.and);

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

  /// Bulk add tags to multiple transactions.
  Future<void> addTagsToTransactions(List<String> transactionIds, List<String> tagIds) async {
    state = const AsyncValue.loading();
    try {
      await _db.tagsDao.addTagsToTransactions(transactionIds, tagIds);
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  /// Bulk remove tags from multiple transactions.
  Future<void> removeTagsFromTransactions(List<String> transactionIds, List<String> tagIds) async {
    state = const AsyncValue.loading();
    try {
      await _db.tagsDao.removeTagsFromTransactions(transactionIds, tagIds);
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  /// Bulk set tags on multiple transactions (replaces existing tags).
  Future<void> setTagsOnTransactions(List<String> transactionIds, List<String> tagIds) async {
    state = const AsyncValue.loading();
    try {
      await _db.tagsDao.setTagsOnTransactions(transactionIds, tagIds);
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
