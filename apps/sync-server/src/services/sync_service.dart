import 'dart:convert';
import 'package:uuid/uuid.dart';
import 'package:postgres/postgres.dart';
import '../database/connection.dart';
import '../models/sync_models.dart';
import 'encryption_service.dart';
import 'websocket_service.dart';

class SyncService {
  final EncryptionService _encryption;
  final WebSocketService? _websocket;

  SyncService(this._encryption, this._websocket);

  /// Upload sync records from a device
  Future<SyncUploadResult> upload({
    required String userId,
    required String deviceId,
    required List<SyncRecordRequest> records,
  }) async {
    final conn = await DatabaseConnection.connection;
    final uploadedIds = <String>[];
    final conflicts = <SyncConflict>[];

    for (final record in records) {
      // Check for existing record with same ID
      final existing = await conn.execute(
        Sql.named('SELECT id, data, version FROM sync_records WHERE record_id = @recordId AND table_name = @tableName'),
        parameters: {
          'recordId': record.recordId,
          'tableName': record.tableName,
        },
      );

      if (existing.isNotEmpty) {
        // Check for conflict (different data from different device)
        final existingRow = existing.first;
        final existingData = existingRow[1] as String?;
        final existingVersion = existingRow[2] as int;

        if (existingData != record.data && record.version <= existingVersion) {
          // Conflict detected
          final conflictId = const Uuid().v4();
          await conn.execute(
            Sql.named('''
            INSERT INTO conflicts (id, table_name, record_id, device_id_1, device_id_2, data_1, data_2)
            VALUES (@id, @tableName, @recordId, @deviceId1, @deviceId2, @data1, @data2)
            '''),
            parameters: {
              'id': conflictId,
              'tableName': record.tableName,
              'recordId': record.recordId,
              'deviceId1': existingRow[0] as String,
              'deviceId2': deviceId,
              'data1': existingData,
              'data2': record.data,
            },
          );
          conflicts.add(SyncConflict(
            id: conflictId,
            tableName: record.tableName,
            recordId: record.recordId,
          ));
          
          // Notify user of conflict
          if (_websocket != null) {
            _websocket!.notifyUser(userId, SyncNotification(
              type: NotificationType.conflictDetected,
              tableName: record.tableName,
              recordId: record.recordId,
              timestamp: DateTime.now(),
            ));
          }
          continue;
        }
      }

      // Insert or update the record
      final syncRecordId = const Uuid().v4();
      await conn.execute(
        Sql.named('''
        INSERT INTO sync_records (id, device_id, table_name, record_id, operation, data, version, created_at)
        VALUES (@id, @deviceId, @tableName, @recordId, @operation, @data, @version, @createdAt)
        ON CONFLICT (record_id, table_name) 
        DO UPDATE SET data = @data, version = @version, synced_at = @syncedAt
        '''),
        parameters: {
          'id': syncRecordId,
          'deviceId': deviceId,
          'tableName': record.tableName,
          'recordId': record.recordId,
          'operation': record.operation,
          'data': record.data,
          'version': record.version,
          'createdAt': DateTime.now(),
          'syncedAt': DateTime.now(),
        },
      );
      uploadedIds.add(record.recordId);
    }

    // Update device last sync time
    await conn.execute(
      Sql.named('UPDATE devices SET last_sync_at = @lastSyncAt WHERE id = @deviceId'),
      parameters: {
        'deviceId': deviceId,
        'lastSyncAt': DateTime.now(),
      },
    );

    // Notify user of sync completion
    if (_websocket != null) {
      _websocket!.notifyUser(userId, SyncNotification(
        type: NotificationType.syncComplete,
        tableName: null,
        recordId: null,
        timestamp: DateTime.now(),
      ));
    }

    return SyncUploadResult(
      uploadedCount: uploadedIds.length,
      uploadedIds: uploadedIds,
      conflicts: conflicts,
    );
  }

  /// Download sync records since a given timestamp
  Future<SyncDownloadResult> download({
    required String userId,
    required String deviceId,
    DateTime? since,
    List<String>? tableNames,
  }) async {
    final conn = await DatabaseConnection.connection;

    // Get all devices for this user
    final devices = await conn.execute(
      Sql.named('SELECT id FROM devices WHERE user_id = @userId'),
      parameters: {'userId': userId},
    );

    final deviceIds = devices.map((r) => r[0] as String).toList();

    // Build query
    var query = '''
      SELECT id, device_id, table_name, record_id, operation, data, created_at, synced_at, version
      FROM sync_records
      WHERE device_id = ANY(@deviceIds)
    ''';
    final params = <String, dynamic>{
      'deviceIds': deviceIds,
    };

    if (since != null) {
      query += ' AND created_at > @since';
      params['since'] = since;
    }

    if (tableNames != null && tableNames.isNotEmpty) {
      query += ' AND table_name = ANY(@tableNames)';
      params['tableNames'] = tableNames;
    }

    query += ' ORDER BY created_at ASC LIMIT 1000';

    final result = await conn.execute(Sql.named(query), parameters: params);

    final records = result.map((row) {
      return SyncRecord(
        id: row[0] as String,
        deviceId: row[1] as String,
        tableName: row[2] as String,
        recordId: row[3] as String,
        operation: row[4] as String,
        data: row[5] as String?,
        createdAt: row[6] as DateTime,
        syncedAt: row[7] as DateTime?,
      );
    }).toList();

    return SyncDownloadResult(
      records: records,
      hasMore: records.length == 1000,
    );
  }

  /// Get pending conflicts for a user
  Future<List<ConflictInfo>> getConflicts(String userId) async {
    final conn = await DatabaseConnection.connection;

    final result = await conn.execute(
      Sql.named('''
      SELECT c.id, c.table_name, c.record_id, c.resolved, c.created_at
      FROM conflicts c
      JOIN devices d ON c.device_id_1 = d.id
      WHERE d.user_id = @userId AND c.resolved = false
      ORDER BY c.created_at DESC
    '''), parameters: {'userId': userId});

    return result.map((row) {
      return ConflictInfo(
        id: row[0] as String,
        tableName: row[1] as String,
        recordId: row[2] as String,
        resolved: row[3] as bool,
        createdAt: row[4] as DateTime,
      );
    }).toList();
  }

  /// Resolve a conflict
  Future<bool> resolveConflict({
    required String conflictId,
    required String resolution,
    required String resolvedData,
  }) async {
    final conn = await DatabaseConnection.connection;

    await conn.execute(
      Sql.named('''
      UPDATE conflicts 
      SET resolved = true, resolution = @resolution, resolved_at = @resolvedAt
      WHERE id = @conflictId
      '''),
      parameters: {
        'conflictId': conflictId,
        'resolution': resolution,
        'resolvedAt': DateTime.now(),
      },
    );

    // Apply the resolved data to sync_records
    final conflict = await conn.execute(
      Sql.named('SELECT table_name, record_id FROM conflicts WHERE id = @conflictId'),
      parameters: {'conflictId': conflictId},
    );

    if (conflict.isNotEmpty) {
      final tableName = conflict.first[0] as String;
      final recordId = conflict.first[1] as String;

      await conn.execute(
        Sql.named('''
        UPDATE sync_records 
        SET data = @data, version = version + 1, synced_at = @syncedAt
        WHERE table_name = @tableName AND record_id = @recordId
        '''),
        parameters: {
          'tableName': tableName,
          'recordId': recordId,
          'data': resolvedData,
          'syncedAt': DateTime.now(),
        },
      );
    }

    return true;
  }
}

/// Request model for sync upload
class SyncRecordRequest {
  final String tableName;
  final String recordId;
  final String operation; // INSERT, UPDATE, DELETE
  final String? data;
  final int version;

  SyncRecordRequest({
    required this.tableName,
    required this.recordId,
    required this.operation,
    this.data,
    required this.version,
  });

  factory SyncRecordRequest.fromJson(Map<String, dynamic> json) {
    return SyncRecordRequest(
      tableName: json['table_name'] as String,
      recordId: json['record_id'] as String,
      operation: json['operation'] as String,
      data: json['data'] as String?,
      version: json['version'] as int,
    );
  }
}

/// Result of sync upload
class SyncUploadResult {
  final int uploadedCount;
  final List<String> uploadedIds;
  final List<SyncConflict> conflicts;

  SyncUploadResult({
    required this.uploadedCount,
    required this.uploadedIds,
    required this.conflicts,
  });

  Map<String, dynamic> toJson() => {
        'uploaded_count': uploadedCount,
        'uploaded_ids': uploadedIds,
        'conflicts': conflicts.map((c) => c.toJson()).toList(),
      };
}

/// Result of sync download
class SyncDownloadResult {
  final List<SyncRecord> records;
  final bool hasMore;

  SyncDownloadResult({
    required this.records,
    required this.hasMore,
  });

  Map<String, dynamic> toJson() => {
        'records': records
            .map((r) => {
                  'id': r.id,
                  'table_name': r.tableName,
                  'record_id': r.recordId,
                  'operation': r.operation,
                  'data': r.data,
                  'created_at': r.createdAt.toIso8601String(),
                  'version': 1,
                })
            .toList(),
        'has_more': hasMore,
      };
}

/// Conflict information
class SyncConflict {
  final String id;
  final String tableName;
  final String recordId;

  SyncConflict({
    required this.id,
    required this.tableName,
    required this.recordId,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'table_name': tableName,
        'record_id': recordId,
      };
}

/// Conflict info for listing
class ConflictInfo {
  final String id;
  final String tableName;
  final String recordId;
  final bool resolved;
  final DateTime createdAt;

  ConflictInfo({
    required this.id,
    required this.tableName,
    required this.recordId,
    required this.resolved,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'table_name': tableName,
        'record_id': recordId,
        'resolved': resolved,
        'created_at': createdAt.toIso8601String(),
      };
}