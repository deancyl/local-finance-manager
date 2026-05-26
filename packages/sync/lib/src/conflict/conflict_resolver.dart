import '../models/sync_models.dart';

/// Strategy for resolving sync conflicts.
enum ConflictResolutionStrategy {
  /// Use server version.
  serverWins,
  
  /// Use client version.
  clientWins,
  
  /// Merge fields (last-write-wins per field).
  merge,
  
  /// Require manual resolution.
  manual,
}

/// Represents a sync conflict between client and server data.
class Conflict {
  /// Unique identifier for this conflict.
  final String id;
  
  /// Table where the conflict occurred.
  final String tableName;
  
  /// ID of the conflicting record.
  final String recordId;
  
  /// Client version of the data.
  final Map<String, dynamic> clientData;
  
  /// Server version of the data.
  final Map<String, dynamic> serverData;
  
  /// When this conflict was detected.
  final DateTime detectedAt;

  const Conflict({
    required this.id,
    required this.tableName,
    required this.recordId,
    required this.clientData,
    required this.serverData,
    required this.detectedAt,
  });

  /// Creates a Conflict from a SyncConflict.
  factory Conflict.fromSyncConflict(SyncConflict syncConflict, String conflictId) {
    return Conflict(
      id: conflictId,
      tableName: syncConflict.table,
      recordId: syncConflict.id,
      clientData: syncConflict.localData ?? {},
      serverData: syncConflict.remoteData ?? {},
      detectedAt: syncConflict.timestamp,
    );
  }
}

/// Result of conflict resolution.
class ConflictResolution {
  /// The strategy used for resolution.
  final ConflictResolutionStrategy strategy;
  
  /// The resolved data (null for manual resolution).
  final Map<String, dynamic>? resolvedData;
  
  /// Reason for the resolution decision.
  final String? reason;

  const ConflictResolution({
    required this.strategy,
    this.resolvedData,
    this.reason,
  });

  /// Creates a resolution where server data wins.
  factory ConflictResolution.serverWins(Map<String, dynamic>? data, {String? reason}) {
    return ConflictResolution(
      strategy: ConflictResolutionStrategy.serverWins,
      resolvedData: data,
      reason: reason ?? 'Server version applied',
    );
  }

  /// Creates a resolution where client data wins.
  factory ConflictResolution.clientWins(Map<String, dynamic>? data, {String? reason}) {
    return ConflictResolution(
      strategy: ConflictResolutionStrategy.clientWins,
      resolvedData: data,
      reason: reason ?? 'Client version preserved',
    );
  }

  /// Creates a resolution with merged data.
  factory ConflictResolution.merged(Map<String, dynamic> data, {String? reason}) {
    return ConflictResolution(
      strategy: ConflictResolutionStrategy.merge,
      resolvedData: data,
      reason: reason ?? 'Data merged',
    );
  }

  /// Creates a resolution requiring manual intervention.
  factory ConflictResolution.manual({String? reason}) {
    return ConflictResolution(
      strategy: ConflictResolutionStrategy.manual,
      reason: reason ?? 'Manual resolution required',
    );
  }
}

/// Conflict resolver with finance-specific business rules.
class FinanceConflictResolver {
  /// Tables that require manual resolution for amount changes.
  static const Set<String> _amountTables = {
    'transactions',
    'splits',
    'budgets',
  };
  
  /// Sensitive fields that require manual review when changed.
  static const Set<String> _sensitiveFields = {
    'value_num',
    'value_denom',
    'quantity_num',
    'quantity_denom',
    'amount_num',
    'amount_denom',
  };

  /// Resolves a conflict using business rules.
  /// 
  /// Business rules applied in order:
  /// 1. Delete conflicts: delete wins
  /// 2. Reconciled transactions: manual resolution required
  /// 3. Amount changes in finance tables: manual resolution required
  /// 4. Timestamp-based: newer wins
  /// 5. Default: merge fields
  Future<ConflictResolution> resolve(Conflict conflict) async {
    // Rule 1: Delete conflicts - delete wins
    final deleteResolution = _checkDeleteConflict(conflict);
    if (deleteResolution != null) {
      return deleteResolution;
    }

    // Rule 2: Reconciled transactions require manual resolution
    if (_isReconciledTransaction(conflict)) {
      return ConflictResolution.manual(
        reason: 'Transaction is reconciled - manual resolution required',
      );
    }

    // Rule 3: Sensitive field changes in amount tables require manual resolution
    if (_hasSensitiveFieldChange(conflict)) {
      return ConflictResolution.manual(
        reason: 'Sensitive field change detected in ${conflict.tableName} - manual resolution required',
      );
    }

    // Rule 4: Timestamp-based resolution
    final timestampResolution = _resolveByTimestamp(conflict);
    if (timestampResolution != null) {
      return timestampResolution;
    }

    // Rule 5: Default - merge fields
    return _mergeFields(conflict);
  }

  /// Checks if this is a delete conflict and returns appropriate resolution.
  ConflictResolution? _checkDeleteConflict(Conflict conflict) {
    final clientDeleted = conflict.clientData.isEmpty || 
        conflict.clientData['_deleted'] == true;
    final serverDeleted = conflict.serverData.isEmpty || 
        conflict.serverData['_deleted'] == true;

    if (clientDeleted && !serverDeleted) {
      // Client deleted - delete wins
      return ConflictResolution.serverWins(
        conflict.serverData,
        reason: 'Client deleted the record - server version preserved',
      );
    }
    
    if (serverDeleted && !clientDeleted) {
      // Server deleted - delete wins
      return ConflictResolution.serverWins(
        conflict.serverData,
        reason: 'Server deleted the record - delete applied',
      );
    }
    
    if (clientDeleted && serverDeleted) {
      // Both deleted - no conflict
      return ConflictResolution.serverWins(
        conflict.serverData,
        reason: 'Both sides deleted - no conflict',
      );
    }

    return null;
  }

  /// Checks if the conflict involves a reconciled transaction.
  bool _isReconciledTransaction(Conflict conflict) {
    if (conflict.tableName != 'transactions') {
      return false;
    }

    // Check if either version is reconciled
    final clientReconciled = conflict.clientData['reconciled'] == true ||
        conflict.clientData['reconcile_date'] != null;
    final serverReconciled = conflict.serverData['reconciled'] == true ||
        conflict.serverData['reconcile_date'] != null;

    return clientReconciled || serverReconciled;
  }

  /// Checks if the conflict involves sensitive field changes in amount tables.
  bool _hasSensitiveFieldChange(Conflict conflict) {
    if (!_amountTables.contains(conflict.tableName)) {
      return false;
    }

    for (final field in _sensitiveFields) {
      if (conflict.clientData.containsKey(field) && 
          conflict.serverData.containsKey(field)) {
        if (conflict.clientData[field] != conflict.serverData[field]) {
          return true;
        }
      }
    }

    return false;
  }

  /// Resolves conflict based on timestamps (newer wins).
  ConflictResolution? _resolveByTimestamp(Conflict conflict) {
    final clientTimestamp = _extractTimestamp(conflict.clientData);
    final serverTimestamp = _extractTimestamp(conflict.serverData);

    if (clientTimestamp == null || serverTimestamp == null) {
      return null;
    }

    if (clientTimestamp.isAfter(serverTimestamp)) {
      return ConflictResolution.clientWins(
        conflict.clientData,
        reason: 'Client version is newer (${clientTimestamp.toIso8601String()})',
      );
    }

    if (serverTimestamp.isAfter(clientTimestamp)) {
      return ConflictResolution.serverWins(
        conflict.serverData,
        reason: 'Server version is newer (${serverTimestamp.toIso8601String()})',
      );
    }

    // Same timestamp - fall through to merge
    return null;
  }

  /// Extracts timestamp from data map.
  DateTime? _extractTimestamp(Map<String, dynamic> data) {
    // Try common timestamp field names
    final timestampFields = ['updated_at', 'modified_at', 'last_modified'];
    
    for (final field in timestampFields) {
      if (data.containsKey(field)) {
        final value = data[field];
        if (value is DateTime) {
          return value;
        }
        if (value is String) {
          try {
            return DateTime.parse(value);
          } catch (_) {
            // Invalid date string
          }
        }
        if (value is int) {
          // Unix timestamp (milliseconds)
          return DateTime.fromMillisecondsSinceEpoch(value);
        }
      }
    }

    return null;
  }

  /// Merges fields from client and server data.
  ConflictResolution _mergeFields(Conflict conflict) {
    final merged = <String, dynamic>{};
    
    // Get all keys from both sides
    final allKeys = <String>{
      ...conflict.clientData.keys,
      ...conflict.serverData.keys,
    };

    for (final key in allKeys) {
      final clientValue = conflict.clientData[key];
      final serverValue = conflict.serverData[key];

      // Skip internal fields
      if (key.startsWith('_')) {
        continue;
      }

      if (!conflict.clientData.containsKey(key)) {
        // Only in server
        merged[key] = serverValue;
      } else if (!conflict.serverData.containsKey(key)) {
        // Only in client
        merged[key] = clientValue;
      } else if (clientValue == serverValue) {
        // Same value
        merged[key] = clientValue;
      } else {
        // Conflict - use last-write-wins per field based on timestamps
        final clientFieldTimestamp = _extractFieldTimestamp(conflict.clientData, key);
        final serverFieldTimestamp = _extractFieldTimestamp(conflict.serverData, key);

        if (clientFieldTimestamp != null && serverFieldTimestamp != null) {
          merged[key] = clientFieldTimestamp.isAfter(serverFieldTimestamp)
              ? clientValue
              : serverValue;
        } else {
          // No field timestamps - prefer server
          merged[key] = serverValue;
        }
      }
    }

    return ConflictResolution.merged(
      merged,
      reason: 'Fields merged using last-write-wins',
    );
  }

  /// Extracts field-specific timestamp if available.
  DateTime? _extractFieldTimestamp(Map<String, dynamic> data, String field) {
    // Check for field-specific timestamp (e.g., field_updated_at)
    final fieldTimestampKey = '${field}_updated_at';
    if (data.containsKey(fieldTimestampKey)) {
      final value = data[fieldTimestampKey];
      if (value is DateTime) return value;
      if (value is String) {
        try {
          return DateTime.parse(value);
        } catch (_) {}
      }
      if (value is int) {
        return DateTime.fromMillisecondsSinceEpoch(value);
      }
    }

    // Fall back to record timestamp
    return _extractTimestamp(data);
  }
}
