part of '../database.dart';

/// DAO for transaction template operations
class TransactionTemplatesDao extends DatabaseAccessor<LocalFinanceDatabase> 
    with AuditableMixin {
  TransactionTemplatesDao(super.db);

  /// Insert a new template
  Future<void> insert(TransactionTemplatesCompanion template) async {
    await into(db.transactionTemplates).insert(template);
    // Audit log for CREATE operation
    await logMutation(
      operation: 'CREATE',
      entityType: 'transaction_template',
      entityId: template.id.value,
      newValue: template.toJson(),
    );
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
      ..orderBy([(t) => OrderingTerm.asc(t.sortOrder)]))
      .get();
  }

  /// Get templates by category
  Future<List<TransactionTemplate>> getByCategory(String category) async {
    return (db.select(db.transactionTemplates)
      ..where((t) => t.category.equals(category) & t.isActive.equals(true))
      ..orderBy([(t) => OrderingTerm.desc(t.useCount)]))
      .get();
  }

  /// Get most recently used templates
  Future<List<TransactionTemplate>> getRecent({int limit = 10}) async {
    return (db.select(db.transactionTemplates)
      ..where((t) => t.isActive.equals(true) & t.lastUsedAt.isNotNull())
      ..orderBy([(t) => OrderingTerm.desc(t.lastUsedAt)])
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
    // Get old value before update for audit log
    final oldTemplate = await getById(template.id.value);
    
    final result = await (db.update(db.transactionTemplates)
      ..where((t) => t.id.equals(template.id.value)))
      .write(template);
    
    // Audit log for UPDATE operation
    await logMutation(
      operation: 'UPDATE',
      entityType: 'transaction_template',
      entityId: template.id.value,
      oldValue: oldTemplate?.toJson(),
      newValue: template.toJson(),
    );
    
    return result;
  }

  /// Increment use count and update last used time
  Future<void> recordUsage(String id) async {
    final template = await getById(id);
    if (template == null) return;

    await (db.update(db.transactionTemplates)
      ..where((t) => t.id.equals(id)))
      .write(TransactionTemplatesCompanion(
        useCount: Value(template.useCount + 1),
        lastUsedAt: Value(DateTime.now()),
      ));
  }

  /// Toggle favorite status
  Future<void> toggleFavorite(String id) async {
    final template = await getById(id);
    if (template == null) return;

    await (db.update(db.transactionTemplates)
      ..where((t) => t.id.equals(id)))
      .write(TransactionTemplatesCompanion(
        isFavorite: Value(!template.isFavorite),
        updatedAt: Value(DateTime.now()),
      ));
  }

  /// Update sort order
  Future<void> updateSortOrder(String id, int sortOrder) async {
    await (db.update(db.transactionTemplates)
      ..where((t) => t.id.equals(id)))
      .write(TransactionTemplatesCompanion(
        sortOrder: Value(sortOrder),
        updatedAt: Value(DateTime.now()),
      ));
  }

  /// Deactivate a template
  Future<void> deactivate(String id) async {
    await (db.update(db.transactionTemplates)
      ..where((t) => t.id.equals(id)))
      .write(TransactionTemplatesCompanion(
        isActive: Value(false),
        updatedAt: Value(DateTime.now()),
      ));
  }

  /// Delete a template
  Future<int> deleteTemplate(String id) async {
    // Get old value before delete for audit log
    final oldTemplate = await getById(id);
    
    final result = await (db.delete(db.transactionTemplates)
      ..where((t) => t.id.equals(id)))
      .go();
    
    // Audit log for DELETE operation
    await logMutation(
      operation: 'DELETE',
      entityType: 'transaction_template',
      entityId: id,
      oldValue: oldTemplate?.toJson(),
    );
    
    return result;
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
