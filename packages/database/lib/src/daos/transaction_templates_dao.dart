part of '../database.dart';

/// DAO for transaction template operations
class TransactionTemplatesDao extends DatabaseAccessor<LocalFinanceDatabase> {
  TransactionTemplatesDao(super.db);

  /// Insert a new template
  Future<void> insert(TransactionTemplatesCompanion template) async {
    await into(db.transactionTemplates).insert(template);
  }

  /// Get all templates, sorted by use count (most used first)
  Future<List<TransactionTemplate>> getAll() async {
    return (db.select(db.transactionTemplates)
      ..orderBy([(t) => OrderingTerm.desc(t.useCount)]))
      .get();
  }

  /// Get favorite templates
  Future<List<TransactionTemplate>> getFavorites() async {
    return (db.select(db.transactionTemplates)
      ..where((t) => t.isFavorite.equals(true) & t.isActive.equals(true))
      .orderBy([(t) => OrderingTerm.asc(t.sortOrder)]))
      .get();
  }

  /// Get templates by category
  Future<List<TransactionTemplate>> getByCategory(String category) async {
    return (db.select(db.transactionTemplates)
      ..where((t) => t.category.equals(category) & t.isActive.equals(true))
      .orderBy([(t) => OrderingTerm.desc(t.useCount)]))
      .get();
  }

  /// Get most recently used templates
  Future<List<TransactionTemplate>> getRecent({int limit = 10}) async {
    return (db.select(db.transactionTemplates)
      ..where((t) => t.isActive.equals(true) & t.lastUsedAt.isNotNull())
      .orderBy([(t) => OrderingTerm.desc(t.lastUsedAt)])
      ..limit(limit))
      .get();
  }

  /// Get template by ID
  Future<TransactionTemplate?> getById(String id) async {
    return (db.select(db.transactionTemplates)
      ..where((t) => t.id.equals(id)))
      .getSingleOrNull();
  }

  /// Get template by name
  Future<TransactionTemplate?> getByName(String name) async {
    return (db.select(db.transactionTemplates)
      ..where((t) => t.name.equals(name)))
      .getSingleOrNull();
  }

  /// Update a template
  Future<int> updateTemplate(TransactionTemplatesCompanion template) async {
    return (db.update(db.transactionTemplates)
      ..where((t) => t.id.equals(template.id.value)))
      .write(template);
  }

  /// Increment use count and update last used time
  Future<void> recordUsage(String id) async {
    final template = await getById(id);
    if (template == null) return;

    await (db.update(db.transactionTemplates)
      ..where((t) => t.id.equals(id)))
      .write(TransactionTemplatesCompanion(
        useCount: drift.Value(template.useCount + 1),
        lastUsedAt: drift.Value(DateTime.now()),
      ));
  }

  /// Toggle favorite status
  Future<void> toggleFavorite(String id) async {
    final template = await getById(id);
    if (template == null) return;

    await (db.update(db.transactionTemplates)
      ..where((t) => t.id.equals(id)))
      .write(TransactionTemplatesCompanion(
        isFavorite: drift.Value(!template.isFavorite),
        updatedAt: drift.Value(DateTime.now()),
      ));
  }

  /// Update sort order
  Future<void> updateSortOrder(String id, int sortOrder) async {
    await (db.update(db.transactionTemplates)
      ..where((t) => t.id.equals(id)))
      .write(TransactionTemplatesCompanion(
        sortOrder: drift.Value(sortOrder),
        updatedAt: drift.Value(DateTime.now()),
      ));
  }

  /// Deactivate a template
  Future<void> deactivate(String id) async {
    await (db.update(db.transactionTemplates)
      ..where((t) => t.id.equals(id)))
      .write(TransactionTemplatesCompanion(
        isActive: drift.Value(false),
        updatedAt: drift.Value(DateTime.now()),
      ));
  }

  /// Delete a template
  Future<int> deleteTemplate(String id) async {
    return (db.delete(db.transactionTemplates)
      ..where((t) => t.id.equals(id)))
      .go();
  }

  /// Search templates by name or description
  Future<List<TransactionTemplate>> search(String query) async {
    return (db.select(db.transactionTemplates)
      ..where((t) =>
          t.name.like('%$query%') |
          t.description.like('%$query%'))
      ..orderBy([(t) => OrderingTerm.desc(t.useCount)]))
      .get();
  }

  /// Get distinct categories
  Future<List<String>> getCategories() async {
    final query = db.selectOnly(db.transactionTemplates)
      ..addColumns([db.transactionTemplates.category])
      ..where(db.transactionTemplates.category.isNotNull())
      ..groupBy([db.transactionTemplates.category]);

    final result = await query.get();
    return result
        .map((row) => row.read(db.transactionTemplates.category))
        .whereType<String>()
        .toList();
  }
}
