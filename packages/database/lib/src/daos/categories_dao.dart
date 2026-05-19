import 'package:drift/drift.dart';

import '../database.dart';

part 'categories_dao.g.dart';

/// Data Access Object for categories.
@DriftAccessor(tables: [Categories])
class CategoriesDao extends DatabaseAccessor<LocalFinanceDatabase> with _$CategoriesDaoMixin {
  CategoriesDao(super.db);

  /// Gets all categories.
  Future<List<Category>> getAll() => select(categories).get();

  /// Gets a category by ID.
  Future<Category?> getById(String id) {
    return (select(categories)..where((c) => c.id.equals(id))).getSingleOrNull();
  }

  /// Gets categories by parent ID.
  Future<List<Category>> getByParent(String? parentId) {
    if (parentId == null) {
      return (select(categories)..where((c) => c.parentId.isNull())).get();
    }
    return (select(categories)..where((c) => c.parentId.equals(parentId))).get();
  }

  /// Gets income categories.
  Future<List<Category>> getIncomeCategories() {
    return (select(categories)..where((c) => c.isIncome.equals(true))).get();
  }

  /// Gets expense categories.
  Future<List<Category>> getExpenseCategories() {
    return (select(categories)..where((c) => c.isIncome.equals(false))).get();
  }

  /// Creates a new category.
  Future<String> create(CategoriesCompanion category) async {
    await into(categories).insert(category);
    return category.id.value;
  }

  /// Updates an existing category.
  Future<void> updateCategory(CategoriesCompanion category) async {
    await (update(categories)..where((c) => c.id.equals(category.id.value))).write(category);
  }

  /// Deletes a category.
  Future<void> deleteCategory(String id) async {
    await (delete(categories)..where((c) => c.id.equals(id))).go();
  }

  /// Watches all categories.
  Stream<List<Category>> watchAll() => select(categories).watch();
}