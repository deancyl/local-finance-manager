import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart' as drift;
import 'package:uuid/uuid.dart' as uuid_pkg;

import 'package:database/database.dart';
import 'package:finance_app/features/accounts/data/account_provider.dart';

final categoriesProvider = StreamProvider<List<Category>>((ref) {
  final db = ref.watch(databaseProvider);
  return db.select(db.categories).watch();
});

final expenseCategoriesProvider = Provider<List<Category>>((ref) {
  final categories = ref.watch(categoriesProvider);
  return categories.when(
    data: (list) => list.where((c) => !c.isIncome).toList(),
    loading: () => [],
    error: (_, __) => [],
  );
});

final incomeCategoriesProvider = Provider<List<Category>>((ref) {
  final categories = ref.watch(categoriesProvider);
  return categories.when(
    data: (list) => list.where((c) => c.isIncome).toList(),
    loading: () => [],
    error: (_, __) => [],
  );
});

class CategoryNotifier extends StateNotifier<AsyncValue<void>> {
  final LocalFinanceDatabase _db;

  CategoryNotifier(this._db) : super(const AsyncValue.data(null));

  Future<void> createCategory({
    required String name,
    required bool isIncome,
    String? parentId,
    String? icon,
    String? color,
  }) async {
    state = const AsyncValue.loading();
    try {
      final id = const uuid_pkg.Uuid().v4();
      await _db.into(_db.categories).insert(
        CategoriesCompanion.insert(
          id: id,
          name: name,
          isIncome: drift.Value(isIncome),
          parentId: drift.Value(parentId),
          icon: drift.Value(icon),
          color: drift.Value(color),
          createdAt: DateTime.now().millisecondsSinceEpoch,
          updatedAt: DateTime.now(),
        ),
      );
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> updateCategory(
    String id, {
    required String name,
    required bool isIncome,
    String? parentId,
    String? icon,
    String? color,
  }) async {
    state = const AsyncValue.loading();
    try {
      await (_db.update(_db.categories)..where((c) => c.id.equals(id))).write(
        CategoriesCompanion(
          name: drift.Value(name),
          isIncome: drift.Value(isIncome),
          parentId: drift.Value(parentId),
          icon: drift.Value(icon),
          color: drift.Value(color),
          updatedAt: drift.Value(DateTime.now()),
        ),
      );
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> deleteCategory(String id) async {
    state = const AsyncValue.loading();
    try {
      await (_db.delete(_db.categories)..where((c) => c.id.equals(id))).go();
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }
}

final categoryNotifierProvider = StateNotifierProvider<CategoryNotifier, AsyncValue<void>>((ref) {
  final db = ref.watch(databaseProvider);
  return CategoryNotifier(db);
});