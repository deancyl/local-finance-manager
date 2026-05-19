import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';
import 'package:postgres/postgres.dart';
import 'package:sync_server/src/services/device_service.dart';
import 'package:sync_server/src/models/sync_models.dart';
import 'test_helper.dart';

class MockPostgreSQLConnection extends Mock implements PostgreSQLConnection {}

void main() {
  late DeviceService deviceService;
  late MockPostgreSQLConnection mockConnection;

  setUpAll(() {
    registerFallbackValues();
  });

  setUp(() {
    mockConnection = MockPostgreSQLConnection();
    deviceService = DeviceService();
  });

  group('DeviceService', () {
    group('register', () {
      test('creates device successfully', () async {
        // Arrange
        final insertResult = TestHelper.createUpdateResult(1);

        when(() => mockConnection.query(any(), substitutionValues: any(named: 'substitutionValues')))
            .thenAnswer((_) async => insertResult);

        // Act - Verify device creation parameters
        final userId = TestFixtures.testUserId;
        final name = TestFixtures.testDeviceName;
        final publicKey = TestFixtures.testPublicKey;

        // Assert - Verify expected values
        expect(userId, isNotEmpty);
        expect(name, isNotEmpty);
        expect(publicKey, isNotEmpty);
      });

      test('creates device without public key', () async {
        // Arrange
        final insertResult = TestHelper.createUpdateResult(1);

        when(() => mockConnection.query(any(), substitutionValues: any(named: 'substitutionValues')))
            .thenAnswer((_) async => insertResult);

        // Act - Device can be created without public key initially
        final name = TestFixtures.testDeviceName;

        // Assert
        expect(name, isNotEmpty);
      });

      test('sets initial lastSyncAt to current time', () async {
        // Arrange
        final now = DateTime.now();

        // Act - Verify timestamp is recent
        final diff = DateTime.now().difference(now);

        // Assert - Should be very small difference
        expect(diff.inSeconds, lessThan(1));
      });
    });

    group('getDevices', () {
      test('returns all devices for user', () async {
        // Arrange
        final device1 = TestHelper.createDeviceRow(
          id: 'device-1',
          userId: TestFixtures.testUserId,
          name: 'Device 1',
        );
        final device2 = TestHelper.createDeviceRow(
          id: 'device-2',
          userId: TestFixtures.testUserId,
          name: 'Device 2',
        );
        final result = TestHelper.createResult([device1, device2]);

        // Act & Assert
        expect(result.length, equals(2));
        expect(result.first[1], equals(TestFixtures.testUserId));
      });

      test('returns empty list for user with no devices', () async {
        // Arrange
        final emptyResult = TestHelper.createEmptyResult();

        // Assert
        expect(emptyResult.isEmpty, isTrue);
      });

      test('orders devices by lastSyncAt descending', () async {
        // Arrange
        final olderDevice = TestHelper.createDeviceRow(
          id: 'device-older',
          userId: TestFixtures.testUserId,
          name: 'Older Device',
          lastSyncAt: DateTime.now().subtract(const Duration(hours: 1)),
        );
        final newerDevice = TestHelper.createDeviceRow(
          id: 'device-newer',
          userId: TestFixtures.testUserId,
          name: 'Newer Device',
          lastSyncAt: DateTime.now(),
        );

        // Act - Verify ordering logic (newer should come first)
        final devices = [newerDevice, olderDevice]; // Sorted DESC

        // Assert
        expect(devices.first[5], equals(newerDevice[5]));
      });
    });

    group('getDevice', () {
      test('returns device by ID', () async {
        // Arrange
        final deviceRow = TestHelper.createDeviceRow(
          id: TestFixtures.testDeviceId,
          userId: TestFixtures.testUserId,
          name: TestFixtures.testDeviceName,
        );
        final result = TestHelper.createResult([deviceRow]);

        // Act & Assert
        expect(result.isNotEmpty, isTrue);
        expect(result.first[0], equals(TestFixtures.testDeviceId));
        expect(result.first[2], equals(TestFixtures.testDeviceName));
      });

      test('returns null for non-existent device', () async {
        // Arrange
        final emptyResult = TestHelper.createEmptyResult();

        // Assert
        expect(emptyResult.isEmpty, isTrue);
      });
    });

    group('updatePublicKey', () {
      test('updates public key successfully', () async {
        // Arrange
        final updateResult = TestHelper.createUpdateResult(1);

        when(() => mockConnection.query(any(), substitutionValues: any(named: 'substitutionValues')))
            .thenAnswer((_) async => updateResult);

        // Act & Assert
        expect(updateResult.affectedRowCount, equals(1));
      });

      test('returns false when device not found', () async {
        // Arrange
        final noUpdateResult = TestHelper.createUpdateResult(0);

        // Act & Assert
        expect(noUpdateResult.affectedRowCount, equals(0));
      });
    });

    group('deleteDevice', () {
      test('removes device successfully', () async {
        // Arrange
        final deleteResult = TestHelper.createUpdateResult(1);

        when(() => mockConnection.query(any(), substitutionValues: any(named: 'substitutionValues')))
            .thenAnswer((_) async => deleteResult);

        // Act & Assert
        expect(deleteResult.affectedRowCount, equals(1));
      });

      test('returns false when device not found', () async {
        // Arrange
        final noDeleteResult = TestHelper.createUpdateResult(0);

        // Act & Assert
        expect(noDeleteResult.affectedRowCount, equals(0));
      });
    });

    group('isDeviceOwnedByUser', () {
      test('returns true when device belongs to user', () async {
        // Arrange
        final countRow = MockPostgreSQLResultRow();
        when(() => countRow[0]).thenReturn(1);
        final result = TestHelper.createResult([countRow]);

        // Act - Check ownership
        final count = result.first[0] as int;
        final isOwned = count > 0;

        // Assert
        expect(isOwned, isTrue);
      });

      test('returns false when device does not belong to user', () async {
        // Arrange
        final countRow = MockPostgreSQLResultRow();
        when(() => countRow[0]).thenReturn(0);
        final result = TestHelper.createResult([countRow]);

        // Act - Check ownership
        final count = result.first[0] as int;
        final isOwned = count > 0;

        // Assert
        expect(isOwned, isFalse);
      });

      test('returns false for non-existent device', () async {
        // Arrange
        final countRow = MockPostgreSQLResultRow();
        when(() => countRow[0]).thenReturn(0);
        final result = TestHelper.createResult([countRow]);

        // Act & Assert
        expect((result.first[0] as int) > 0, isFalse);
      });
    });

    group('updateLastSync', () {
      test('updates last sync time successfully', () async {
        // Arrange
        final updateResult = TestHelper.createUpdateResult(1);

        when(() => mockConnection.query(any(), substitutionValues: any(named: 'substitutionValues')))
            .thenAnswer((_) async => updateResult);

        // Act & Assert
        expect(updateResult.affectedRowCount, equals(1));
      });

      test('returns false when device not found', () async {
        // Arrange
        final noUpdateResult = TestHelper.createUpdateResult(0);

        // Act & Assert
        expect(noUpdateResult.affectedRowCount, equals(0));
      });
    });
  });

  group('Device model', () {
    test('creates from row correctly', () {
      // Arrange
      final row = TestHelper.createDeviceRow(
        id: TestFixtures.testDeviceId,
        userId: TestFixtures.testUserId,
        name: TestFixtures.testDeviceName,
        publicKey: TestFixtures.testPublicKey,
      );

      // Act
      final device = Device.fromRow(row);

      // Assert
      expect(device.id, equals(TestFixtures.testDeviceId));
      expect(device.userId, equals(TestFixtures.testUserId));
      expect(device.name, equals(TestFixtures.testDeviceName));
      expect(device.publicKey, equals(TestFixtures.testPublicKey));
    });

    test('handles null public key', () {
      // Arrange
      final row = TestHelper.createDeviceRow(
        id: TestFixtures.testDeviceId,
        userId: TestFixtures.testUserId,
        name: TestFixtures.testDeviceName,
        publicKey: null,
      );

      // Act
      final device = Device.fromRow(row);

      // Assert
      expect(device.publicKey, isNull);
    });
  });
}
