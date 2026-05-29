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
    await into(auditLogs).insert(AuditLogsCompanion.insert(
      operation: operation,
      entityType: entityType,
      entityId: entityId,
      oldValue: Value(oldValue != null ? jsonEncode(oldValue) : null),
      newValue: Value(newValue != null ? jsonEncode(newValue) : null),
      timestamp: DateTime.now(),
    ));
  }
}
