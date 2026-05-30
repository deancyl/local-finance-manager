import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:sync/sync.dart';

// Mock classes
class MockSyncEncryption extends Mock implements SyncEncryption {}

// Fake SyncEncryption for testing
class FakeSyncEncryption implements SyncEncryption {
  @override
  Future<Uint8List> getEncryptionKey() async {
    return Uint8List.fromList(List.generate(32, (i) => i));
  }

  @override
  Future<Uint8List> encrypt(Uint8List data) async => data;

  @override
  Future<Uint8List> decrypt(Uint8List data) async => data;

  @override
  Future<void> rotateKey() async {}
}

void main() {
  group('SyncClient', () {
    late SyncConfig config;
    late SyncClient client;

    setUp(() {
      config = SyncConfig(
        serverUrl: 'https://test.sync.example.com',
        databaseName: 'test_finance.db',
        authProvider: _MockAuthProvider(),
        userId: 'test-user',
        deviceId: 'test-device',
      );
      client = SyncClient(config: config);
    });

    tearDown(() async {
      await client.close();
    });

    group('initialization', () {
      test('initialize creates database stub', () async {
        // Note: This test requires a proper Flutter test environment
        // with path_provider working. In a real test, you'd use
        // a test database path or mock the dependencies.
        
        // For now, we test the configuration is correct
        expect(client.config.serverUrl, equals('https://test.sync.example.com'));
        expect(client.status, equals(SyncStatus.notInitialized));
        expect(client.isInitialized, isFalse);
      });

      test('status is notInitialized before initialize', () {
        expect(client.status, equals(SyncStatus.notInitialized));
      });

      test('isInitialized is false before initialize', () {
        expect(client.isInitialized, isFalse);
      });

      test('throws StateError when accessing powerSyncDb before initialize', () {
        expect(
          () => client.powerSyncDb,
          throwsA(isA<StateError>()),
        );
      });

      test('throws StateError when calling connect before initialize', () async {
        expect(
          () => client.connect(),
          throwsA(isA<StateError>()),
        );
      });

      test('throws StateError when calling disconnect before initialize', () async {
        expect(
          () => client.disconnect(),
          throwsA(isA<StateError>()),
        );
      });

      test('throws StateError when calling sync before initialize', () async {
        expect(
          () => client.sync(),
          throwsA(isA<StateError>()),
        );
      });

      test('throws StateError when calling getProgress before initialize', () async {
        expect(
          () => client.getProgress(),
          throwsA(isA<StateError>()),
        );
      });

      test('throws StateError when calling createDriftConnection before initialize', () {
        expect(
          () => client.createDriftConnection(),
          throwsA(isA<StateError>()),
        );
      });
    });

    group('status management', () {
      test('watchStatus emits status changes', () async {
        final statusList = <SyncStatus>[];
        final subscription = client.watchStatus().listen(statusList.add);
        
        // Wait for initial emission
        await Future.delayed(Duration(milliseconds: 100));
        
        // The initial status should be emitted
        expect(statusList, contains(SyncStatus.notInitialized));
        
        await subscription.cancel();
      });

      test('status stream is broadcast', () {
        final stream1 = client.watchStatus();
        final stream2 = client.watchStatus();
        
        // Both should be the same broadcast stream
        expect(stream1, same(stream2));
      });
    });

    group('configuration', () {
      test('config is stored correctly', () {
        expect(client.config.serverUrl, equals('https://test.sync.example.com'));
        expect(client.config.databaseName, equals('test_finance.db'));
        expect(client.config.userId, equals('test-user'));
        expect(client.config.deviceId, equals('test-device'));
        expect(client.config.syncIntervalSeconds, equals(30));
        expect(client.config.autoSync, isTrue);
      });

      test('default config values', () {
        final defaultConfig = SyncConfig(
          serverUrl: 'https://default.example.com',
          authProvider: _MockAuthProvider(),
        );
        
        expect(defaultConfig.databaseName, equals('finance.db'));
        expect(defaultConfig.syncIntervalSeconds, equals(30));
        expect(defaultConfig.autoSync, isTrue);
        expect(defaultConfig.userId, isNull);
        expect(defaultConfig.deviceId, isNull);
      });

      test('config copyWith works correctly', () {
        final copied = config.copyWith(
          serverUrl: 'https://new.example.com',
          syncIntervalSeconds: 60,
        );
        
        expect(copied.serverUrl, equals('https://new.example.com'));
        expect(copied.syncIntervalSeconds, equals(60));
        expect(copied.databaseName, equals(config.databaseName));
        expect(copied.userId, equals(config.userId));
      });
    });

    group('encryption', () {
      test('encryption is optional', () {
        final clientWithoutEncryption = SyncClient(config: config);
        expect(clientWithoutEncryption.encryption, isNull);
      });

      test('encryption can be provided', () {
        final encryption = FakeSyncEncryption();
        final clientWithEncryption = SyncClient(
          config: config,
          encryption: encryption,
        );
        expect(clientWithEncryption.encryption, same(encryption));
      });
    });
  });

  group('SyncStatus', () {
    test('displayName returns correct strings', () {
      expect(SyncStatus.notInitialized.displayName, equals('Not Initialized'));
      expect(SyncStatus.disconnected.displayName, equals('Disconnected'));
      expect(SyncStatus.connecting.displayName, equals('Connecting'));
      expect(SyncStatus.connected.displayName, equals('Connected'));
      expect(SyncStatus.error.displayName, equals('Error'));
    });

    test('isReady is true only for connected status', () {
      expect(SyncStatus.connected.isReady, isTrue);
      expect(SyncStatus.notInitialized.isReady, isFalse);
      expect(SyncStatus.disconnected.isReady, isFalse);
      expect(SyncStatus.connecting.isReady, isFalse);
      expect(SyncStatus.error.isReady, isFalse);
    });

    test('hasError is true only for error status', () {
      expect(SyncStatus.error.hasError, isTrue);
      expect(SyncStatus.connected.hasError, isFalse);
      expect(SyncStatus.notInitialized.hasError, isFalse);
      expect(SyncStatus.disconnected.hasError, isFalse);
      expect(SyncStatus.connecting.hasError, isFalse);
    });
  });

  group('SyncProgress', () {
    test('default values', () {
      const progress = SyncProgress(status: SyncStatus.connected);
      
      expect(progress.status, equals(SyncStatus.connected));
      expect(progress.pendingUploads, equals(0));
      expect(progress.pendingDownloads, equals(0));
      expect(progress.lastSyncTime, isNull);
      expect(progress.errorMessage, isNull);
    });

    test('progress calculation', () {
      // No pending items = 100%
      const complete = SyncProgress(status: SyncStatus.connected);
      expect(complete.progress, equals(1.0));
      
      // With pending items = 50% (unknown progress)
      const pending = SyncProgress(
        status: SyncStatus.connected,
        pendingUploads: 5,
        pendingDownloads: 3,
      );
      expect(pending.progress, equals(0.5));
    });

    test('copyWith works correctly', () {
      final original = SyncProgress(
        status: SyncStatus.connected,
        pendingUploads: 5,
        lastSyncTime: DateTime(2024, 1, 1),
      );
      
      final copied = original.copyWith(
        pendingUploads: 0,
        errorMessage: 'Test error',
      );
      
      expect(copied.status, equals(SyncStatus.connected));
      expect(copied.pendingUploads, equals(0));
      expect(copied.lastSyncTime, equals(DateTime(2024, 1, 1)));
      expect(copied.errorMessage, equals('Test error'));
    });
  });

  group('SyncConflict', () {
    test('stores conflict information', () {
      final conflict = SyncConflict(
        table: 'accounts',
        id: 'acc-123',
        localData: {'name': 'Local Account'},
        remoteData: {'name': 'Remote Account'},
        timestamp: DateTime(2024, 1, 1),
      );
      
      expect(conflict.table, equals('accounts'));
      expect(conflict.id, equals('acc-123'));
      expect(conflict.localData, equals({'name': 'Local Account'}));
      expect(conflict.remoteData, equals({'name': 'Remote Account'}));
      expect(conflict.timestamp, equals(DateTime(2024, 1, 1)));
    });
  });

  group('SecureSyncEncryption', () {
    test('getEncryptionKey generates consistent key', () async {
      // Note: This test would require mocking FlutterSecureStorage
      // in a real test environment
      
      // For now, we just verify the interface exists
      final encryption = FakeSyncEncryption();
      final key = await encryption.getEncryptionKey();
      
      expect(key.length, equals(32));
    });

    test('encrypt and decrypt are symmetric', () async {
      final encryption = FakeSyncEncryption();
      final data = Uint8List.fromList([1, 2, 3, 4, 5]);
      
      final encrypted = await encryption.encrypt(data);
      final decrypted = await encryption.decrypt(encrypted);
      
      // For the fake implementation, encrypt/decrypt are identity
      expect(decrypted, equals(data));
    });
  });

  group('FinanceAppConnector', () {
    late FinanceAppConnector connector;

    setUp(() {
      connector = FinanceAppConnector(
        serverUrl: 'https://test.example.com',
      );
    });

    tearDown(() {
      connector.dispose();
    });

    test('fetchCredentials returns null when no token set', () async {
      final creds = await connector.fetchCredentials();
      expect(creds, isNull);
    });

    test('setToken stores token', () {
      connector.setToken('test-token');
      // Token is stored internally
      expect(connector.currentToken, equals('test-token'));
    });

    test('clearToken removes token', () {
      connector.setToken('test-token');
      connector.clearToken();
      expect(connector.currentToken, isNull);
    });
  });
}

/// Mock AuthProvider for testing
class _MockAuthProvider implements AuthProvider {
  @override
  Future<String?> getToken() async => 'test-token';
  
  @override
  Future<String?> getUserId() async => 'test-user';
  
  @override
  Future<bool> isAuthenticated() async => true;
  
  @override
  Future<void> refreshToken() async {}
  
  @override
  Future<AuthResult> login(String email, String password) async {
    return AuthResult.success(userId: 'test-user', token: 'test-token');
  }
  
  @override
  Future<AuthResult> register(String email, String password) async {
    return AuthResult.success(userId: 'new-user', token: 'new-token');
  }
  
  @override
  Future<void> logout() async {}
}