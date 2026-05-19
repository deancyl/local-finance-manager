import 'package:uuid/uuid.dart';
import '../database/connection.dart';
import '../models/sync_models.dart';

class DeviceService {
  /// Register a new device for a user
  Future<Device> register({
    required String userId,
    required String name,
    String? publicKey,
  }) async {
    final conn = await DatabaseConnection.connection;
    final deviceId = const Uuid().v4();
    final now = DateTime.now();

    await conn.query(
      '''
      INSERT INTO devices (id, user_id, name, public_key, created_at, last_sync_at)
      VALUES (@id, @userId, @name, @publicKey, @createdAt, @lastSyncAt)
      ''',
      substitutionValues: {
        'id': deviceId,
        'userId': userId,
        'name': name,
        'publicKey': publicKey,
        'createdAt': now,
        'lastSyncAt': now,
      },
    );

    return Device(
      id: deviceId,
      userId: userId,
      name: name,
      publicKey: publicKey,
      createdAt: now,
      lastSyncAt: now,
    );
  }

  /// Get all devices for a user
  Future<List<Device>> getDevices(String userId) async {
    final conn = await DatabaseConnection.connection;

    final result = await conn.query(
      '''
      SELECT id, user_id, name, public_key, created_at, last_sync_at
      FROM devices
      WHERE user_id = @userId
      ORDER BY last_sync_at DESC
      ''',
      substitutionValues: {'userId': userId},
    );

    return result.map((row) => Device.fromRow(row)).toList();
  }

  /// Get a specific device
  Future<Device?> getDevice(String deviceId) async {
    final conn = await DatabaseConnection.connection;

    final result = await conn.query(
      '''
      SELECT id, user_id, name, public_key, created_at, last_sync_at
      FROM devices
      WHERE id = @deviceId
      ''',
      substitutionValues: {'deviceId': deviceId},
    );

    if (result.isEmpty) return null;
    return Device.fromRow(result.first);
  }

  /// Update device's public key
  Future<bool> updatePublicKey({
    required String deviceId,
    required String publicKey,
  }) async {
    final conn = await DatabaseConnection.connection;

    final result = await conn.query(
      '''
      UPDATE devices
      SET public_key = @publicKey
      WHERE id = @deviceId
      ''',
      substitutionValues: {
        'deviceId': deviceId,
        'publicKey': publicKey,
      },
    );

    return result.affectedRowCount > 0;
  }

  /// Update device's last sync time
  Future<bool> updateLastSync(String deviceId) async {
    final conn = await DatabaseConnection.connection;

    final result = await conn.query(
      '''
      UPDATE devices
      SET last_sync_at = @lastSyncAt
      WHERE id = @deviceId
      ''',
      substitutionValues: {
        'deviceId': deviceId,
        'lastSyncAt': DateTime.now(),
      },
    );

    return result.affectedRowCount > 0;
  }

  /// Delete a device
  Future<bool> deleteDevice(String deviceId) async {
    final conn = await DatabaseConnection.connection;

    final result = await conn.query(
      'DELETE FROM devices WHERE id = @deviceId',
      substitutionValues: {'deviceId': deviceId},
    );

    return result.affectedRowCount > 0;
  }

  /// Check if a device belongs to a user
  Future<bool> isDeviceOwnedByUser({
    required String deviceId,
    required String userId,
  }) async {
    final conn = await DatabaseConnection.connection;

    final result = await conn.query(
      '''
      SELECT COUNT(*) FROM devices
      WHERE id = @deviceId AND user_id = @userId
      ''',
      substitutionValues: {
        'deviceId': deviceId,
        'userId': userId,
      },
    );

    return (result.first[0] as int) > 0;
  }
}
