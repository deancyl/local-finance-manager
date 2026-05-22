import 'package:drift/drift.dart';

/// Audit log table for tracking all data changes.
/// 
/// Records CREATE, UPDATE, DELETE operations on all entities
/// for compliance and debugging purposes.
@DataClassName('AuditLog')
class AuditLogs extends Table {
  /// Unique identifier for the audit log entry
  TextColumn get id => text()();

  /// Type of entity being modified (e.g., 'account', 'transaction', 'split')
  TextColumn get entityType => text()();

  /// ID of the entity being modified
  TextColumn get entityId => text()();

  /// Type of operation: 'CREATE', 'UPDATE', 'DELETE'
  TextColumn get operation => text()();

  /// JSON representation of the entity before the change (null for CREATE)
  TextColumn get beforeData => text().nullable()();

  /// JSON representation of the entity after the change (null for DELETE)
  TextColumn get afterData => text().nullable()();

  /// List of changed field names (for UPDATE operations)
  TextColumn get changedFields => text().nullable()();

  /// User ID or device ID that made the change
  TextColumn get changedBy => text().nullable()();

  /// Timestamp of the change
  DateTimeColumn get changedAt => dateTime()();

  /// Optional description or reason for the change
  TextColumn get description => text().nullable()();

  /// Session ID for grouping related changes
  TextColumn get sessionId => text().nullable()();

  /// IP address or device info (optional)
  TextColumn get clientInfo => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};

  @override
  List<Set<Column>>? get uniqueKeys => [
    {entityType, entityId, changedAt},
  ];
}
