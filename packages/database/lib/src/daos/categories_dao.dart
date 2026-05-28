part of '../database.dart';

/// Data Access Object for categories.
@DriftAccessor(tables: [Categories])
class CategoriesDao extends DatabaseAccessor<LocalFinanceDatabase> 
    with _$CategoriesDaoMixin, AuditableMixin {
  CategoriesDao(super.db);

  /// Gets all categories (excluding deleted).
  Future<List<Category>> getAll() => 
    (select(categories)..where((c) => c.deletedAt.isNull())).get();

  /// Gets a category by ID.
  Future<Category?> getById(String id) {
    return (select(categories)..where((c) => c.id.equals(id))).getSingleOrNull();
  }

  /// Gets categories by parent ID (excluding deleted).
  Future<List<Category>> getByParent(String? parentId) {
    if (parentId == null) {
      return (select(categories)
        ..where((c) => c.parentId.isNull() & c.deletedAt.isNull()))
        .get();
    }
    return (select(categories)
      ..where((c) => c.parentId.equals(parentId) & c.deletedAt.isNull()))
      .get();
  }

  /// Gets income categories (excluding deleted).
  Future<List<Category>> getIncomeCategories() {
    return (select(categories)
      ..where((c) => c.isIncome.equals(true) & c.deletedAt.isNull()))
      .get();
  }

  /// Gets expense categories (excluding deleted).
  Future<List<Category>> getExpenseCategories() {
    return (select(categories)
      ..where((c) => c.isIncome.equals(false) & c.deletedAt.isNull()))
      .get();
  }

  /// Creates a new category.
  Future<String> create(CategoriesCompanion category) async {
    await into(categories).insert(category);
    // Audit log for CREATE operation
    await logMutation(
      operation: 'CREATE',
      entityType: 'category',
      entityId: category.id.value,
      newValue: category.toJson(),
    );
    return category.id.value;
  }

  /// Updates an existing category.
  Future<void> updateCategory(CategoriesCompanion category) async {
    // Get old value before update for audit log
    final oldCategory = await getById(category.id.value);
    await (update(categories)..where((c) => c.id.equals(category.id.value))).write(category);
    // Audit log for UPDATE operation
    await logMutation(
      operation: 'UPDATE',
      entityType: 'category',
      entityId: category.id.value,
      oldValue: oldCategory?.toJson(),
      newValue: category.toJson(),
    );
  }

  /// Deletes a category (hard delete - admin use only).
  Future<void> hardDeleteCategory(String id) async {
    // Get old value before delete for audit log
    final oldCategory = await getById(id);
    await (delete(categories)..where((c) => c.id.equals(id))).go();
    // Audit log for DELETE operation
    await logMutation(
      operation: 'DELETE',
      entityType: 'category',
      entityId: id,
      oldValue: oldCategory?.toJson(),
    );
  }

  /// Checks if a category can be deleted.
  /// Returns true if the category has no dependent records.
  Future<bool> canDelete(String categoryId) async {
    // Check for splits referencing this category
    final splitsCount = await (select(db.splits)
      ..where((s) => s.categoryId.equals(categoryId)))
      .get()
      .then((list) => list.length);
    
    if (splitsCount > 0) {
      return false;
    }
    
    // Check for child categories
    final childCount = await (select(categories)
      ..where((c) => c.parentId.equals(categoryId) & c.deletedAt.isNull()))
      .get()
      .then((list) => list.length);
    
    if (childCount > 0) {
      return false;
    }
    
    return true;
  }

  /// Soft deletes a category by setting deletedAt timestamp.
  /// Returns true if successful, false if the category has dependent records.
  Future<bool> softDeleteCategory(String id) async {
    // Check if category can be deleted
    final canDeleteCategory = await canDelete(id);
    if (!canDeleteCategory) {
      // Audit log for failed delete attempt
      await logMutation(
        operation: 'SOFT_DELETE_FAILED',
        entityType: 'category',
        entityId: id,
        description: 'Cannot delete category: has dependent records (splits or child categories)',
      );
      return false;
    }
    
    // Get old value for audit log
    final oldCategory = await getById(id);
    
    // Perform soft delete
    await (update(categories)..where((c) => c.id.equals(id))).write(
      CategoriesCompanion(
        deletedAt: Value(DateTime.now()),
        updatedAt: Value(DateTime.now()),
      ),
    );
    
    // Audit log for SOFT_DELETE operation
    await logMutation(
      operation: 'SOFT_DELETE',
      entityType: 'category',
      entityId: id,
      oldValue: oldCategory?.toJson(),
    );
    
    return true;
  }

  /// Watches all categories (excluding deleted).
  Stream<List<Category>> watchAll() => 
    (select(categories)..where((c) => c.deletedAt.isNull())).watch();
}