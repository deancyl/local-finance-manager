part of '../database.dart';

/// Data Access Object for cost centers
extension type CostCentersDao(LocalFinanceDatabase db) implements LocalFinanceDatabase {
  /// Watch all active cost centers
  Stream<List<CostCenter>> watchAll() {
    return (db.select(db.costCenters)
          ..where((t) => t.deletedAt.isNull())
          ..orderBy([(t) => OrderingTerm.asc(t.sortOrder)]))
        .watch();
  }

  /// Get all active cost centers
  Future<List<CostCenter>> getAll() {
    return (db.select(db.costCenters)
          ..where((t) => t.deletedAt.isNull())
          ..orderBy([(t) => OrderingTerm.asc(t.sortOrder)]))
        .get();
  }

  /// Get cost center by ID
  Future<CostCenter?> getById(String id) {
    return (db.select(db.costCenters)
          ..where((t) => t.id.equals(id) & t.deletedAt.isNull()))
        .getSingleOrNull();
  }

  /// Get cost centers by type
  Future<List<CostCenter>> getByType(String type) {
    return (db.select(db.costCenters)
          ..where((t) => t.costCenterType.equals(type) & t.deletedAt.isNull())
          ..orderBy([(t) => OrderingTerm.asc(t.sortOrder)]))
        .get();
  }

  /// Get child cost centers
  Future<List<CostCenter>> getChildren(String parentId) {
    return (db.select(db.costCenters)
          ..where((t) => t.parentId.equals(parentId) & t.deletedAt.isNull())
          ..orderBy([(t) => OrderingTerm.asc(t.sortOrder)]))
        .get();
  }

  /// Get root cost centers (no parent)
  Future<List<CostCenter>> getRoots() {
    return (db.select(db.costCenters)
          ..where((t) => t.parentId.isNull() & t.deletedAt.isNull())
          ..orderBy([(t) => OrderingTerm.asc(t.sortOrder)]))
        .get();
  }

  /// Get active cost centers
  Future<List<CostCenter>> getActive() {
    return (db.select(db.costCenters)
          ..where((t) => t.isActive.equals(true) & t.deletedAt.isNull())
          ..orderBy([(t) => OrderingTerm.asc(t.sortOrder)]))
        .get();
  }

  /// Create a new cost center
  Future<void> create(CostCentersCompanion center) {
    return db.into(db.costCenters).insert(center);
  }

  /// Update a cost center
  Future<int> update(String id, CostCentersCompanion center) {
    return (db.update(db.costCenters)..where((t) => t.id.equals(id))).write(center);
  }

  /// Soft delete a cost center
  Future<int> softDelete(String id) {
    return (db.update(db.costCenters)..where((t) => t.id.equals(id))).write(
      CostCentersCompanion(
        deletedAt: Value(DateTime.now().millisecondsSinceEpoch),
        updatedAt: Value(DateTime.now().millisecondsSinceEpoch),
      ),
    );
  }

  /// Restore a soft-deleted cost center
  Future<int> restore(String id) {
    return (db.update(db.costCenters)..where((t) => t.id.equals(id))).write(
      CostCentersCompanion(
        deletedAt: const Value(null),
        updatedAt: Value(DateTime.now().millisecondsSinceEpoch),
      ),
    );
  }

  /// Set active status
  Future<int> setActive(String id, bool active) {
    return (db.update(db.costCenters)..where((t) => t.id.equals(id))).write(
      CostCentersCompanion(
        isActive: Value(active),
        updatedAt: Value(DateTime.now().millisecondsSinceEpoch),
      ),
    );
  }
}