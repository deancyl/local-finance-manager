part of '../database.dart';

/// Mixin that provides audit logging capabilities for DAOs.
/// 
/// This mixin adds automatic audit logging for CRUD operations (CREATE, UPDATE, DELETE).
/// It should be applied to all DAOs that need compliance tracking.
/// 
/// Usage:
/// ```dart
/// class MyDao extends DatabaseAccessor<LocalFinanceDatabase> 
///     with _$MyDaoMixin, AuditableMixin {
///   MyDao(super.db);
///   
///   Future<String> create(MyTableCompanion data) async {
///     await into(myTable).insert(data);
///     await logMutation(
///       operation: 'CREATE',
///       entityType: 'my_entity',
///       entityId: data.id.value,
///       newValue: data.toJson(),
///     );
///     return data.id.value;
///   }
/// }
/// ```
mixin AuditableMixin on DatabaseAccessor<LocalFinanceDatabase> {
  /// Logs a mutation operation to the audit log.
  /// 
  /// Parameters:
  /// - [operation]: The type of operation ('CREATE', 'UPDATE', 'DELETE')
  /// - [entityType]: The type of entity being modified (e.g., 'account', 'transaction')
  /// - [entityId]: The unique identifier of the entity
  /// - [oldValue]: JSON representation of the entity before the change (null for CREATE)
  /// - [newValue]: JSON representation of the entity after the change (null for DELETE)
  /// - [changedBy]: Optional user/device ID that made the change
  /// - [description]: Optional description or reason for the change
  /// - [sessionId]: Optional session ID for grouping related changes
  /// 
  /// Note: This method does NOT log SELECT operations (read-only) as per compliance requirements.
  Future<void> logMutation({
    required String operation,
    required String entityType,
    required String entityId,
    Map<String, dynamic>? oldValue,
    Map<String, dynamic>? newValue,
    String? changedBy,
    String? description,
    String? sessionId,
  }) async {
    // Generate unique ID for the audit log entry
    final auditLogId = DateTime.now().microsecondsSinceEpoch.toString();
    
    // Determine changed fields for UPDATE operations
    String? changedFields;
    if (operation == 'UPDATE' && oldValue != null && newValue != null) {
      changedFields = _computeChangedFields(oldValue, newValue);
    }
    
    // Create audit log entry
    final auditLog = AuditLogsCompanion.insert(
      id: auditLogId,
      entityType: entityType,
      entityId: entityId,
      operation: operation,
      beforeData: oldValue != null ? Value(jsonEncode(oldValue)) : const Value.absent(),
      afterData: newValue != null ? Value(jsonEncode(newValue)) : const Value.absent(),
      changedFields: changedFields != null ? Value(changedFields) : const Value.absent(),
      changedBy: changedBy != null ? Value(changedBy) : const Value.absent(),
      changedAt: DateTime.now(),
      description: description != null ? Value(description) : const Value.absent(),
      sessionId: sessionId != null ? Value(sessionId) : const Value.absent(),
    );
    
    // Insert audit log using the database's auditLogsDao
    await db.auditLogsDao.insertLog(auditLog);
  }
  
  /// Computes a comma-separated list of field names that changed between old and new values.
  String _computeChangedFields(Map<String, dynamic> oldValue, Map<String, dynamic> newValue) {
    final changedFields = <String>[];
    
    // Check all keys from both maps
    final allKeys = {...oldValue.keys, ...newValue.keys};
    
    for (final key in allKeys) {
      final oldVal = oldValue[key];
      final newVal = newValue[key];
      
      // Skip if both are null or equal
      if (oldVal == newVal) continue;
      
      // Handle special cases for timestamps (allow small differences)
      if (key == 'updatedAt' || key == 'updated_at') continue;
      
      changedFields.add(key);
    }
    
    return changedFields.join(',');
  }
  
  /// Helper method to convert a DataClass to JSON map.
  /// This is a convenience method for DAOs to use when logging.
  Map<String, dynamic> toJsonMap(dynamic data) {
    if (data == null) return {};
    
    // Most Drift-generated DataClass objects have a toJson() method
    if (data is dynamic && data.toJson != null) {
      return (data.toJson() as Map<String, dynamic>);
    }
    
    // Fallback: try to convert using map
    return {};
  }
}
