import 'package:mocktail/mocktail.dart';
import 'package:postgres/postgres.dart';
import 'package:sync_server/src/models/sync_models.dart';

/// Mock PostgreSQL connection for testing
class MockPostgreSQLConnection extends Mock implements PostgreSQLConnection {}

/// Mock PostgreSQL result for testing
class MockPostgreSQLResult extends Mock implements PostgreSQLResult {}

/// Mock PostgreSQL result row
class MockPostgreSQLResultRow extends Mock implements PostgreSQLResultRow {}

/// Test helper for creating mock database responses
class TestHelper {
  /// Create a mock user row
  static MockPostgreSQLResultRow createUserRow({
    required String id,
    required String email,
    String? encryptedKey,
    DateTime? createdAt,
  }) {
    final row = MockPostgreSQLResultRow();
    when(() => row[0]).thenReturn(id);
    when(() => row[1]).thenReturn(email);
    when(() => row[2]).thenReturn(encryptedKey);
    when(() => row[3]).thenReturn(createdAt ?? DateTime.now());
    return row;
  }

  /// Create a mock device row
  static MockPostgreSQLResultRow createDeviceRow({
    required String id,
    required String userId,
    required String name,
    String? publicKey,
    DateTime? createdAt,
    DateTime? lastSyncAt,
  }) {
    final row = MockPostgreSQLResultRow();
    when(() => row[0]).thenReturn(id);
    when(() => row[1]).thenReturn(userId);
    when(() => row[2]).thenReturn(name);
    when(() => row[3]).thenReturn(publicKey);
    when(() => row[4]).thenReturn(createdAt ?? DateTime.now());
    when(() => row[5]).thenReturn(lastSyncAt ?? DateTime.now());
    return row;
  }

  /// Create a mock sync record row
  static MockPostgreSQLResultRow createSyncRecordRow({
    required String id,
    required String deviceId,
    required String tableName,
    required String recordId,
    required String operation,
    String? data,
    DateTime? createdAt,
    DateTime? syncedAt,
    int version = 1,
  }) {
    final row = MockPostgreSQLResultRow();
    when(() => row[0]).thenReturn(id);
    when(() => row[1]).thenReturn(deviceId);
    when(() => row[2]).thenReturn(tableName);
    when(() => row[3]).thenReturn(recordId);
    when(() => row[4]).thenReturn(operation);
    when(() => row[5]).thenReturn(data);
    when(() => row[6]).thenReturn(createdAt ?? DateTime.now());
    when(() => row[7]).thenReturn(syncedAt);
    when(() => row[8]).thenReturn(version);
    return row;
  }

  /// Create a mock conflict row
  static MockPostgreSQLResultRow createConflictRow({
    required String id,
    required String tableName,
    required String recordId,
    bool resolved = false,
    DateTime? createdAt,
  }) {
    final row = MockPostgreSQLResultRow();
    when(() => row[0]).thenReturn(id);
    when(() => row[1]).thenReturn(tableName);
    when(() => row[2]).thenReturn(recordId);
    when(() => row[3]).thenReturn(resolved);
    when(() => row[4]).thenReturn(createdAt ?? DateTime.now());
    return row;
  }

  /// Create a mock result with rows
  static MockPostgreSQLResult createResult(List<MockPostgreSQLResultRow> rows) {
    final result = MockPostgreSQLResult();
    when(() => result.toList()).thenReturn(rows);
    when(() => result.isEmpty).thenReturn(rows.isEmpty);
    when(() => result.isNotEmpty).thenReturn(rows.isNotEmpty);
    when(() => result.first).thenReturn(rows.isNotEmpty ? rows.first : MockPostgreSQLResultRow());
    when(() => result.length).thenReturn(rows.length);
    when(() => result.map<dynamic>(any())).thenReturn(rows.map((r) => r as dynamic).toList());
    when(() => result.affectedRowCount).thenReturn(rows.length);
    return result;
  }

  /// Create an empty result
  static MockPostgreSQLResult createEmptyResult() {
    final result = MockPostgreSQLResult();
    when(() => result.toList()).thenReturn([]);
    when(() => result.isEmpty).thenReturn(true);
    when(() => result.isNotEmpty).thenReturn(false);
    when(() => result.length).thenReturn(0);
    when(() => result.affectedRowCount).thenReturn(0);
    return result;
  }

  /// Create a result with affected row count
  static MockPostgreSQLResult createUpdateResult(int affectedRows) {
    final result = MockPostgreSQLResult();
    when(() => result.affectedRowCount).thenReturn(affectedRows);
    when(() => result.isEmpty).thenReturn(true);
    return result;
  }
}

/// Test fixtures for consistent test data
class TestFixtures {
  static const String testUserId = 'user-123-456-789';
  static const String testEmail = 'test@example.com';
  static const String testPassword = 'securePassword123';
  static const String testSalt = 'abcd1234efgh5678';
  static const String testHash = 'hashedpassword123';
  static const String testDeviceId = 'device-123-456-789';
  static const String testDeviceName = 'Test Device';
  static const String testPublicKey = 'public-key-abc123';
  static const String testJwtSecret = 'test-jwt-secret-key-for-testing';
  static const String testEncryptionKey = 'test-encryption-key-32-chars!!';
  static const String testTableName = 'transactions';
  static const String testRecordId = 'record-123-456';
  static const String testConflictId = 'conflict-123-456';

  /// Create a test user
  static User testUser({
    String? id,
    String? email,
    String? encryptedKey,
    DateTime? createdAt,
  }) {
    return User(
      id: id ?? testUserId,
      email: email ?? testEmail,
      encryptedKey: encryptedKey ?? '$testSalt:$testHash',
      createdAt: createdAt ?? DateTime.now(),
    );
  }

  /// Create a test device
  static Device testDevice({
    String? id,
    String? userId,
    String? name,
    String? publicKey,
    DateTime? createdAt,
    DateTime? lastSyncAt,
  }) {
    return Device(
      id: id ?? testDeviceId,
      userId: userId ?? testUserId,
      name: name ?? testDeviceName,
      publicKey: publicKey ?? testPublicKey,
      createdAt: createdAt ?? DateTime.now(),
      lastSyncAt: lastSyncAt ?? DateTime.now(),
    );
  }

  /// Create a test sync record
  static SyncRecord testSyncRecord({
    String? id,
    String? deviceId,
    String? tableName,
    String? recordId,
    String? operation,
    String? data,
    DateTime? createdAt,
    DateTime? syncedAt,
  }) {
    return SyncRecord(
      id: id ?? 'sync-123',
      deviceId: deviceId ?? testDeviceId,
      tableName: tableName ?? testTableName,
      recordId: recordId ?? testRecordId,
      operation: operation ?? 'INSERT',
      data: data ?? '{"amount": 100}',
      createdAt: createdAt ?? DateTime.now(),
      syncedAt: syncedAt ?? DateTime.now(),
    );
  }
}

/// Register fallback values for mocktail
void registerFallbackValues() {
  registerFallbackValue(MockPostgreSQLConnection());
  registerFallbackValue(MockPostgreSQLResult());
  registerFallbackValue(MockPostgreSQLResultRow());
  registerFallbackValue('');
  registerFallbackValue(<String, dynamic>{});
  registerFallbackValue(DateTime.now());
}
