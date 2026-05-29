part of '../database.dart';

/// Mixin that provides audit logging capabilities for database operations.
///
/// This mixin adds compliance logging to DAOs by tracking all mutations
/// (CREATE, UPDATE, DELETE) with before/after state snapshots.
mixin AuditableMixin on DatabaseAccessor<LocalFinanceDatabase> {
  /// Logs a mutation to the audit_logs table for compliance tracking.
  ///
  /// Parameters:
  /// - [operation]: The operation type ('CREATE', 'UPDATE', 'DELETE')
  /// - [entityType]: The entity/table name being mutated
  /// - [entityId]: The unique identifier of the entity
  /// - [oldValue]: The previous state (null for CREATE)
  /// - [newValue]: The new state (null for DELETE)
  Future<void> logMutation({
    required String operation,
    required String entityType,
    required String entityId,
    Map<String, dynamic>? oldValue,
    Map<String, dynamic>? newValue,
  }) async {
    await into(db.auditLogs).insert(AuditLogsCompanion(
      id: Value(Uuid().v4()),
      operation: Value(operation),
      entityType: Value(entityType),
      entityId: Value(entityId),
      beforeData: Value(oldValue != null ? jsonEncode(oldValue) : null),
      afterData: Value(newValue != null ? jsonEncode(newValue) : null),
      changedAt: Value(DateTime.now()),
    ));
  }
}
