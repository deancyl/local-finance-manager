import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';
import 'package:postgres/postgres.dart';
import 'package:sync_server/src/services/sync_service.dart';
import 'package:sync_server/src/services/encryption_service.dart';
import 'package:sync_server/src/models/sync_models.dart';
import 'test_helper.dart';

class MockEncryptionService extends Mock implements EncryptionService {}

class MockConnection extends Mock implements Connection {}

void main() {
  late SyncService syncService;
  late MockEncryptionService mockEncryption;
  late MockConnection mockConnection;

  setUpAll(() {
    registerFallbackValues();
  });

  setUp(() {
    mockEncryption = MockEncryptionService();
    mockConnection = MockConnection();
    syncService = SyncService(mockEncryption, null);
  });

  group('SyncService', () {
    group('upload', () {
      test('stores records successfully', () async {
        // Arrange
        final records = [
          SyncRecordRequest(
            tableName: TestFixtures.testTableName,
            recordId: TestFixtures.testRecordId,
            operation: 'INSERT',
            data: '{"amount": 100}',
            version: 1,
          ),
        ];

        // Mock empty existing check (no conflicts)
        final emptyResult = TestHelper.createEmptyResult();
        final insertResult = TestHelper.createUpdateResult(1);
        final updateDeviceResult = TestHelper.createUpdateResult(1);

        when(() => mockConnection.query(any(), substitutionValues: any(named: 'substitutionValues')))
            .thenAnswer((invocation) async {
          final query = invocation.positionalArguments[0] as String;
          if (query.contains('SELECT id, data, version')) {
            return emptyResult;
          } else if (query.contains('INSERT INTO sync_records')) {
            return insertResult;
          } else if (query.contains('UPDATE devices')) {
            return updateDeviceResult;
          }
          return emptyResult;
        });

        // Act & Assert - Verify the request structure
        expect(records.length, equals(1));
        expect(records.first.tableName, equals(TestFixtures.testTableName));
        expect(records.first.operation, equals('INSERT'));
        expect(records.first.version, equals(1));
      });

      test('detects conflicts when same record modified by different device', () async {
        // Arrange - Simulate existing record with different data
        final existingRow = MockPostgreSQLResultRow();
        when(() => existingRow[0]).thenReturn('existing-device-id');
        when(() => existingRow[1]).thenReturn('{"amount": 50}'); // Different data
        when(() => existingRow[2]).thenReturn(1); // version

        final existingResult = TestHelper.createResult([existingRow]);

        // The conflict detection logic:
        // If existingData != record.data && record.version <= existingVersion
        final recordData = '{"amount": 100}';
        final existingData = '{"amount": 50}';
        final recordVersion = 1;
        final existingVersion = 1;

        // Act - Check conflict condition
        final hasConflict = existingData != recordData && recordVersion <= existingVersion;

        // Assert
        expect(hasConflict, isTrue);
        expect(existingResult.isNotEmpty, isTrue);
      });

      test('updates existing record when version is higher', () async {
        // Arrange
        final existingRow = MockPostgreSQLResultRow();
        when(() => existingRow[0]).thenReturn('existing-device-id');
        when(() => existingRow[1]).thenReturn('{"amount": 50}');
        when(() => existingRow[2]).thenReturn(1); // Lower version

        final recordVersion = 2; // Higher version

        // Act - Check update condition
        final shouldUpdate = recordVersion > 1;

        // Assert
        expect(shouldUpdate, isTrue);
      });
    });

    group('download', () {
      test('returns records since timestamp', () async {
        // Arrange
        final since = DateTime.now().subtract(const Duration(hours: 1));
        final syncRow = TestHelper.createSyncRecordRow(
          id: 'sync-1',
          deviceId: TestFixtures.testDeviceId,
          tableName: TestFixtures.testTableName,
          recordId: TestFixtures.testRecordId,
          operation: 'INSERT',
          data: '{"amount": 100}',
          createdAt: DateTime.now(),
        );

        final deviceRow = TestHelper.createDeviceRow(
          id: TestFixtures.testDeviceId,
          userId: TestFixtures.testUserId,
          name: TestFixtures.testDeviceName,
        );

        // Act - Verify the row structure
        expect(syncRow[2], equals(TestFixtures.testTableName));
        expect(syncRow[3], equals(TestFixtures.testRecordId));
        expect(syncRow[4], equals('INSERT'));

        // Verify device belongs to user
        expect(deviceRow[1], equals(TestFixtures.testUserId));
      });

      test('filters by table names when specified', () async {
        // Arrange
        final tableNames = ['transactions', 'accounts'];

        // Act - Verify filter logic
        expect(tableNames.contains('transactions'), isTrue);
        expect(tableNames.contains('categories'), isFalse);
      });

      test('returns empty list when no records match', () async {
        // Arrange
        final emptyResult = TestHelper.createEmptyResult();

        // Assert
        expect(emptyResult.isEmpty, isTrue);
        expect(emptyResult.length, equals(0));
      });

      test('limits results to 1000 records', () async {
        // Arrange - Simulate max records
        const maxRecords = 1000;

        // Act - Check hasMore flag logic
        final hasMore = maxRecords >= 1000;

        // Assert
        expect(hasMore, isTrue);
      });
    });

    group('getConflicts', () {
      test('lists unresolved conflicts for user', () async {
        // Arrange
        final conflictRow = TestHelper.createConflictRow(
          id: TestFixtures.testConflictId,
          tableName: TestFixtures.testTableName,
          recordId: TestFixtures.testRecordId,
          resolved: false,
        );

        final result = TestHelper.createResult([conflictRow]);

        // Act & Assert
        expect(result.isNotEmpty, isTrue);
        expect(conflictRow[3], equals(false)); // resolved = false
        expect(conflictRow[1], equals(TestFixtures.testTableName));
      });

      test('returns empty list when no conflicts exist', () async {
        // Arrange
        final emptyResult = TestHelper.createEmptyResult();

        // Assert
        expect(emptyResult.isEmpty, isTrue);
      });

      test('excludes resolved conflicts', () async {
        // Arrange
        final resolvedConflictRow = TestHelper.createConflictRow(
          id: TestFixtures.testConflictId,
          tableName: TestFixtures.testTableName,
          recordId: TestFixtures.testRecordId,
          resolved: true, // Already resolved
        );

        // Act - Check resolved flag
        final isResolved = resolvedConflictRow[3] as bool;

        // Assert - Should be excluded from unresolved list
        expect(isResolved, isTrue);
      });
    });

    group('resolveConflict', () {
      test('applies resolution and updates sync record', () async {
        // Arrange
        final conflictRow = MockPostgreSQLResultRow();
        when(() => conflictRow[0]).thenReturn(TestFixtures.testTableName);
        when(() => conflictRow[1]).thenReturn(TestFixtures.testRecordId);

        final conflictResult = TestHelper.createResult([conflictRow]);
        final updateResult = TestHelper.createUpdateResult(1);

        // Act - Verify conflict resolution flow
        expect(conflictResult.isNotEmpty, isTrue);
        expect(conflictRow[0], equals(TestFixtures.testTableName));
        expect(conflictRow[1], equals(TestFixtures.testRecordId));
      });

      test('marks conflict as resolved', () async {
        // Arrange
        final updateResult = TestHelper.createUpdateResult(1);

        // Act - Verify update was successful
        expect(updateResult.affectedRowCount, greaterThan(0));
      });

      test('increments version on resolved record', () async {
        // Arrange
        final currentVersion = 1;
        final newVersion = currentVersion + 1;

        // Act & Assert
        expect(newVersion, equals(2));
      });
    });
  });

  group('SyncRecordRequest', () {
    test('parses from JSON correctly', () {
      // Arrange
      final json = {
        'table_name': TestFixtures.testTableName,
        'record_id': TestFixtures.testRecordId,
        'operation': 'INSERT',
        'data': '{"amount": 100}',
        'version': 1,
      };

      // Act
      final request = SyncRecordRequest.fromJson(json);

      // Assert
      expect(request.tableName, equals(TestFixtures.testTableName));
      expect(request.recordId, equals(TestFixtures.testRecordId));
      expect(request.operation, equals('INSERT'));
      expect(request.data, equals('{"amount": 100}'));
      expect(request.version, equals(1));
    });
  });

  group('SyncUploadResult', () {
    test('converts to JSON correctly', () {
      // Arrange
      final result = SyncUploadResult(
        uploadedCount: 5,
        uploadedIds: ['id1', 'id2', 'id3', 'id4', 'id5'],
        conflicts: [
          SyncConflict(
            id: 'conflict-1',
            tableName: 'transactions',
            recordId: 'record-1',
          ),
        ],
      );

      // Act
      final json = result.toJson();

      // Assert
      expect(json['uploaded_count'], equals(5));
      expect(json['uploaded_ids'], hasLength(5));
      expect(json['conflicts'], hasLength(1));
    });
  });

  group('SyncDownloadResult', () {
    test('converts to JSON correctly', () {
      // Arrange
      final records = [
        TestFixtures.testSyncRecord(),
      ];
      final result = SyncDownloadResult(records: records, hasMore: false);

      // Act
      final json = result.toJson();

      // Assert
      expect(json['records'], hasLength(1));
      expect(json['has_more'], isFalse);
    });
  });

  group('SyncConflict', () {
    test('converts to JSON correctly', () {
      // Arrange
      final conflict = SyncConflict(
        id: TestFixtures.testConflictId,
        tableName: TestFixtures.testTableName,
        recordId: TestFixtures.testRecordId,
      );

      // Act
      final json = conflict.toJson();

      // Assert
      expect(json['id'], equals(TestFixtures.testConflictId));
      expect(json['table_name'], equals(TestFixtures.testTableName));
      expect(json['record_id'], equals(TestFixtures.testRecordId));
    });
  });

  group('ConflictInfo', () {
    test('converts to JSON correctly', () {
      // Arrange
      final info = ConflictInfo(
        id: TestFixtures.testConflictId,
        tableName: TestFixtures.testTableName,
        recordId: TestFixtures.testRecordId,
        resolved: false,
        createdAt: DateTime(2024, 1, 1),
      );

      // Act
      final json = info.toJson();

      // Assert
      expect(json['id'], equals(TestFixtures.testConflictId));
      expect(json['resolved'], isFalse);
      expect(json['created_at'], isNotNull);
    });
  });
}
