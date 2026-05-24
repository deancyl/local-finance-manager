import 'package:postgres/postgres.dart';

class SyncRecord {
  final String id;
  final String deviceId;
  final String tableName;
  final String recordId;
  final String operation;
  final String? data;
  final DateTime createdAt;
  final DateTime? syncedAt;

  SyncRecord({
    required this.id,
    required this.deviceId,
    required this.tableName,
    required this.recordId,
    required this.operation,
    this.data,
    required this.createdAt,
    this.syncedAt,
  });

  factory SyncRecord.fromRow(ResultRow row) {
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
  }
}

class Device {
  final String id;
  final String userId;
  final String name;
  final String? publicKey;
  final DateTime createdAt;
  final DateTime lastSyncAt;

  Device({
    required this.id,
    required this.userId,
    required this.name,
    this.publicKey,
    required this.createdAt,
    required this.lastSyncAt,
  });

  factory Device.fromRow(ResultRow row) {
    return Device(
      id: row[0] as String,
      userId: row[1] as String,
      name: row[2] as String,
      publicKey: row[3] as String?,
      createdAt: row[4] as DateTime,
      lastSyncAt: row[5] as DateTime,
    );
  }
}

class User {
  final String id;
  final String email;
  final String? encryptedKey;
  final DateTime createdAt;

  User({
    required this.id,
    required this.email,
    this.encryptedKey,
    required this.createdAt,
  });

  factory User.fromRow(ResultRow row) {
    return User(
      id: row[0] as String,
      email: row[1] as String,
      encryptedKey: row[2] as String?,
      createdAt: row[3] as DateTime,
    );
  }
}