part of '../database.dart';

/// DAO for audit log operations
class AuditLogsDao extends DatabaseAccessor<LocalFinanceDatabase> {
  AuditLogsDao(super.db);

  /// Insert an audit log entry
  Future<void> insertLog(AuditLogsCompanion log) async {
    await into(db.auditLogs).insert(log);
  }

  /// Get all audit logs, ordered by timestamp (newest first)
  Future<List<AuditLog>> getAll({
    int limit = 100,
    int offset = 0,
  }) async {
    return (db.select(db.auditLogs)
      ..orderBy([(l) => OrderingTerm.desc(l.changedAt)])
      ..limit(limit, offset: offset))
      .get();
  }

  /// Get audit logs for a specific entity
  Future<List<AuditLog>> getByEntity(
    String entityType,
    String entityId,
  ) async {
    return (db.select(db.auditLogs)
      ..where((l) =>
          l.entityType.equals(entityType) & l.entityId.equals(entityId))
      ..orderBy([(l) => OrderingTerm.desc(l.changedAt)]))
      .get();
  }

  /// Get audit logs by operation type
  Future<List<AuditLog>> getByOperation(
    String operation, {
    int limit = 100,
  }) async {
    return (db.select(db.auditLogs)
      ..where((l) => l.operation.equals(operation))
      ..orderBy([(l) => OrderingTerm.desc(l.changedAt)])
      ..limit(limit))
      .get();
  }

  /// Get audit logs within a date range
  Future<List<AuditLog>> getByDateRange(
    DateTime start,
    DateTime end, {
    int limit = 500,
  }) async {
    return (db.select(db.auditLogs)
      ..where((l) =>
          l.changedAt.isBiggerOrEqualValue(start) &
          l.changedAt.isSmallerOrEqualValue(end))
      ..orderBy([(l) => OrderingTerm.desc(l.changedAt)])
      ..limit(limit))
      .get();
  }

  /// Get audit logs by session ID
  Future<List<AuditLog>> getBySession(String sessionId) async {
    return (db.select(db.auditLogs)
      ..where((l) => l.sessionId.equals(sessionId))
      ..orderBy([(l) => OrderingTerm.asc(l.changedAt)]))
      .get();
  }

  /// Get audit logs by user/device
  Future<List<AuditLog>> getByChangedBy(
    String changedBy, {
    int limit = 100,
  }) async {
    return (db.select(db.auditLogs)
      ..where((l) => l.changedBy.equals(changedBy))
      ..orderBy([(l) => OrderingTerm.desc(l.changedAt)])
      ..limit(limit))
      .get();
  }

  /// Get recent audit logs
  Future<List<AuditLog>> getRecent({int limit = 50}) async {
    return (db.select(db.auditLogs)
      ..orderBy([(l) => OrderingTerm.desc(l.changedAt)])
      ..limit(limit))
      .get();
  }

  /// Get audit logs for entity types
  Future<List<AuditLog>> getByEntityTypes(
    List<String> entityTypes, {
    int limit = 100,
  }) async {
    return (db.select(db.auditLogs)
      ..where((l) => l.entityType.isIn(entityTypes))
      ..orderBy([(l) => OrderingTerm.desc(l.changedAt)])
      ..limit(limit))
      .get();
  }

  /// Search audit logs by description
  Future<List<AuditLog>> search(
    String query, {
    int limit = 50,
  }) async {
    return (db.select(db.auditLogs)
      ..where((l) => l.description.like('%$query%'))
      ..orderBy([(l) => OrderingTerm.desc(l.changedAt)])
      ..limit(limit))
      .get();
  }

  /// Count total audit logs
  Future<int> count() async {
    final result = db.selectOnly(db.auditLogs)
      ..addColumns([db.auditLogs.id.count()]);
    final row = await result.getSingle();
    return row.read(db.auditLogs.id.count()) ?? 0;
  }

  /// Count audit logs by entity type
  Future<Map<String, int>> countByEntityType() async {
    final query = db.selectOnly(db.auditLogs)
      ..addColumns([db.auditLogs.entityType, db.auditLogs.id.count()])
      ..groupBy([db.auditLogs.entityType]);

    final result = await query.get();
    return {
      for (final row in result)
        row.read(db.auditLogs.entityType)!: row.read(db.auditLogs.id.count()) ?? 0
    };
  }

  /// Delete audit logs older than a specified date
  Future<int> deleteOlderThan(DateTime date) async {
    return (db.delete(db.auditLogs)
      ..where((l) => l.changedAt.isSmallerThanValue(date)))
      .go();
  }

  /// Clear all audit logs (use with caution!)
  Future<int> clearAll() async {
    return db.delete(db.auditLogs).go();
  }
}
