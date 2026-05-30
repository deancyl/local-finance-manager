import 'package:flutter_test/flutter_test.dart';
import 'package:sync/sync.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Mock implementation of AuthProvider for testing.
class MockAuthProvider implements AuthProvider {
  String? _token;
  String? _userId;
  bool _isAuthenticated = false;

  void setAuthenticated(String userId, String token) {
    _userId = userId;
    _token = token;
    _isAuthenticated = true;
  }

  void setUnauthenticated() {
    _userId = null;
    _token = null;
    _isAuthenticated = false;
  }

  @override
  Future<String?> getToken() async => _token;

  @override
  Future<String?> getUserId() async => _userId;

  @override
  Future<bool> isAuthenticated() async => _isAuthenticated;

  @override
  Future<void> refreshToken() async {
    if (_token != null) {
      _token = 'refreshed_$_token';
    }
  }

  @override
  Future<AuthResult> login(String email, String password) async {
    if (email == 'test@example.com' && password == 'password123') {
      setAuthenticated('user-123', 'test-token-abc');
      return AuthResult.success(userId: 'user-123', token: 'test-token-abc');
    }
    return AuthResult.failure('Invalid credentials');
  }

  @override
  Future<AuthResult> register(String email, String password) async {
    if (email.isNotEmpty && password.length >= 8) {
      setAuthenticated('user-new', 'new-token-xyz');
      return AuthResult.success(userId: 'user-new', token: 'new-token-xyz');
    }
    return AuthResult.failure('Invalid registration data');
  }

  @override
  Future<void> logout() async {
    setUnauthenticated();
  }
}

/// Creates a minimal test schema using local Schema class.
Schema _createTestSchema() {
  return Schema([]);
}

void main() {
  group('SyncConfig', () {
    late MockAuthProvider authProvider;
    late Schema schema;

    setUp(() async {
      authProvider = MockAuthProvider();
      schema = _createTestSchema();
      
      // Clear storage before each test
      await SyncConfig.clearStorage();
    });

    tearDown(() async {
      // Clean up after each test
      await SyncConfig.clearStorage();
    });

    test('SyncConfig creation with required parameters', () {
      final config = SyncConfig(
        serverUrl: 'https://sync.example.com',
        databaseName: 'test.db',
        schema: schema,
        authProvider: authProvider,
      );

      expect(config.serverUrl, equals('https://sync.example.com'));
      expect(config.databaseName, equals('test.db'));
      expect(config.schema, equals(schema));
      expect(config.authProvider, equals(authProvider));
      expect(config.deviceId, isNull);
      expect(config.syncIntervalSeconds, equals(30));
      expect(config.autoSync, isTrue);
    });

    test('SyncConfig creation with all parameters', () {
      final config = SyncConfig(
        serverUrl: 'https://sync.example.com',
        databaseName: 'custom.db',
        schema: schema,
        authProvider: authProvider,
        deviceId: 'device-123',
        syncIntervalSeconds: 60,
        autoSync: false,
      );

      expect(config.serverUrl, equals('https://sync.example.com'));
      expect(config.databaseName, equals('custom.db'));
      expect(config.deviceId, equals('device-123'));
      expect(config.syncIntervalSeconds, equals(60));
      expect(config.autoSync, isFalse);
    });

    test('fromStorage returns null when empty', () async {
      final config = await SyncConfig.fromStorage(
        schema: schema,
        authProvider: authProvider,
      );

      expect(config, isNull);
    });

    test('save stores credentials', () async {
      final config = SyncConfig(
        serverUrl: 'https://sync.example.com',
        databaseName: 'test.db',
        schema: schema,
        authProvider: authProvider,
        deviceId: 'device-456',
      );

      await config.save();

      // Verify we can load it back
      final loaded = await SyncConfig.fromStorage(
        schema: schema,
        authProvider: authProvider,
      );

      expect(loaded, isNotNull);
      expect(loaded!.serverUrl, equals('https://sync.example.com'));
      expect(loaded.databaseName, equals('test.db'));
      expect(loaded.deviceId, equals('device-456'));
    });

    test('save generates deviceId if not provided', () async {
      final config = SyncConfig(
        serverUrl: 'https://sync.example.com',
        databaseName: 'test.db',
        schema: schema,
        authProvider: authProvider,
      );

      await config.save();

      final loaded = await SyncConfig.fromStorage(
        schema: schema,
        authProvider: authProvider,
      );

      expect(loaded, isNotNull);
      expect(loaded!.deviceId, isNotNull);
      expect(loaded.deviceId, isNotEmpty);
    });

    test('clearStorage removes all', () async {
      // First save some config
      final config = SyncConfig(
        serverUrl: 'https://sync.example.com',
        databaseName: 'test.db',
        schema: schema,
        authProvider: authProvider,
        deviceId: 'device-789',
      );
      await config.save();

      // Also save auth credentials
      await config.saveAuthCredentials(
        userId: 'user-123',
        token: 'token-abc',
        expiresAt: DateTime.now().add(const Duration(hours: 1)),
      );

      // Clear storage
      await SyncConfig.clearStorage();

      // Verify everything is cleared
      final loaded = await SyncConfig.fromStorage(
        schema: schema,
        authProvider: authProvider,
      );
      expect(loaded, isNull);

      final creds = await config.readAuthCredentials();
      expect(creds.userId, isNull);
      expect(creds.token, isNull);
      expect(creds.expiresAt, isNull);
    });

    test('getOrCreateDeviceId returns existing ID', () async {
      final config = SyncConfig(
        serverUrl: 'https://sync.example.com',
        databaseName: 'test.db',
        schema: schema,
        authProvider: authProvider,
        deviceId: 'existing-device',
      );

      final id = await config.getOrCreateDeviceId();
      expect(id, equals('existing-device'));
    });

    test('getOrCreateDeviceId generates new ID if needed', () async {
      final config = SyncConfig(
        serverUrl: 'https://sync.example.com',
        databaseName: 'test.db',
        schema: schema,
        authProvider: authProvider,
      );

      final id = await config.getOrCreateDeviceId();
      expect(id, isNotNull);
      expect(id, isNotEmpty);

      // Calling again should return the same ID
      final id2 = await config.getOrCreateDeviceId();
      expect(id2, equals(id));
    });

    test('powerSyncEndpoint formats URL correctly', () {
      final config1 = SyncConfig(
        serverUrl: 'https://sync.example.com',
        databaseName: 'test.db',
        schema: schema,
        authProvider: authProvider,
      );
      expect(config1.powerSyncEndpoint, equals('https://sync.example.com/api/sync'));

      final config2 = SyncConfig(
        serverUrl: 'https://sync.example.com/',
        databaseName: 'test.db',
        schema: schema,
        authProvider: authProvider,
      );
      expect(config2.powerSyncEndpoint, equals('https://sync.example.com/api/sync'));
    });

    test('copyWith creates modified copy', () {
      final original = SyncConfig(
        serverUrl: 'https://sync.example.com',
        databaseName: 'test.db',
        schema: schema,
        authProvider: authProvider,
        deviceId: 'device-123',
        syncIntervalSeconds: 30,
      );

      final copy = original.copyWith(
        deviceId: 'device-456',
        syncIntervalSeconds: 60,
      );

      expect(copy.serverUrl, equals(original.serverUrl));
      expect(copy.databaseName, equals(original.databaseName));
      expect(copy.deviceId, equals('device-456'));
      expect(copy.syncIntervalSeconds, equals(60));
      expect(original.deviceId, equals('device-123')); // Original unchanged
    });

    test('saveAuthCredentials and readAuthCredentials', () async {
      final config = SyncConfig(
        serverUrl: 'https://sync.example.com',
        databaseName: 'test.db',
        schema: schema,
        authProvider: authProvider,
      );

      final expiresAt = DateTime.now().add(const Duration(hours: 1));
      await config.saveAuthCredentials(
        userId: 'user-xyz',
        token: 'token-123',
        expiresAt: expiresAt,
      );

      final creds = await config.readAuthCredentials();
      expect(creds.userId, equals('user-xyz'));
      expect(creds.token, equals('token-123'));
      expect(creds.expiresAt, isNotNull);
    });

    test('clearAuthCredentials removes only auth data', () async {
      final config = SyncConfig(
        serverUrl: 'https://sync.example.com',
        databaseName: 'test.db',
        schema: schema,
        authProvider: authProvider,
        deviceId: 'device-123',
      );

      await config.save();
      await config.saveAuthCredentials(
        userId: 'user-xyz',
        token: 'token-123',
      );

      await config.clearAuthCredentials();

      // Auth credentials should be cleared
      final creds = await config.readAuthCredentials();
      expect(creds.userId, isNull);
      expect(creds.token, isNull);

      // But config should still be loadable
      final loaded = await SyncConfig.fromStorage(
        schema: schema,
        authProvider: authProvider,
      );
      expect(loaded, isNotNull);
      expect(loaded!.deviceId, equals('device-123'));
    });

    test('equality and hashCode', () {
      final config1 = SyncConfig(
        serverUrl: 'https://sync.example.com',
        databaseName: 'test.db',
        schema: schema,
        authProvider: authProvider,
        deviceId: 'device-123',
        syncIntervalSeconds: 30,
      );

      final config2 = SyncConfig(
        serverUrl: 'https://sync.example.com',
        databaseName: 'test.db',
        schema: schema,
        authProvider: authProvider,
        deviceId: 'device-123',
        syncIntervalSeconds: 30,
      );

      final config3 = SyncConfig(
        serverUrl: 'https://other.example.com',
        databaseName: 'test.db',
        schema: schema,
        authProvider: authProvider,
        deviceId: 'device-123',
        syncIntervalSeconds: 30,
      );

      expect(config1, equals(config2));
      expect(config1, isNot(equals(config3)));
      expect(config1.hashCode, equals(config2.hashCode));
    });
  });

  group('AuthResult', () {
    test('AuthResult.success creates successful result', () {
      final result = AuthResult.success(
        userId: 'user-123',
        token: 'token-abc',
      );

      expect(result.success, isTrue);
      expect(result.userId, equals('user-123'));
      expect(result.token, equals('token-abc'));
      expect(result.error, isNull);
    });

    test('AuthResult.failure creates failed result', () {
      final result = AuthResult.failure('Invalid credentials');

      expect(result.success, isFalse);
      expect(result.userId, isNull);
      expect(result.token, isNull);
      expect(result.error, equals('Invalid credentials'));
    });

    test('toString formats correctly', () {
      final success = AuthResult.success(userId: 'user-123', token: 'token');
      expect(success.toString(), contains('success'));
      expect(success.toString(), contains('user-123'));

      final failure = AuthResult.failure('Error');
      expect(failure.toString(), contains('failure'));
      expect(failure.toString(), contains('Error'));
    });
  });

  group('MockAuthProvider', () {
    late MockAuthProvider authProvider;

    setUp(() {
      authProvider = MockAuthProvider();
    });

    test('login with valid credentials succeeds', () async {
      final result = await authProvider.login(
        'test@example.com',
        'password123',
      );

      expect(result.success, isTrue);
      expect(result.userId, equals('user-123'));
      expect(await authProvider.isAuthenticated(), isTrue);
    });

    test('login with invalid credentials fails', () async {
      final result = await authProvider.login(
        'wrong@example.com',
        'wrongpass',
      );

      expect(result.success, isFalse);
      expect(result.error, equals('Invalid credentials'));
      expect(await authProvider.isAuthenticated(), isFalse);
    });

    test('register with valid data succeeds', () async {
      final result = await authProvider.register(
        'new@example.com',
        'password123',
      );

      expect(result.success, isTrue);
      expect(result.userId, equals('user-new'));
      expect(await authProvider.isAuthenticated(), isTrue);
    });

    test('register with invalid data fails', () async {
      final result = await authProvider.register(
        'new@example.com',
        'short',
      );

      expect(result.success, isFalse);
      expect(await authProvider.isAuthenticated(), isFalse);
    });

    test('logout clears authentication', () async {
      await authProvider.login('test@example.com', 'password123');
      expect(await authProvider.isAuthenticated(), isTrue);

      await authProvider.logout();
      expect(await authProvider.isAuthenticated(), isFalse);
      expect(await authProvider.getToken(), isNull);
      expect(await authProvider.getUserId(), isNull);
    });

    test('refreshToken updates token', () async {
      await authProvider.login('test@example.com', 'password123');
      final originalToken = await authProvider.getToken();

      await authProvider.refreshToken();
      final newToken = await authProvider.getToken();

      expect(newToken, isNot(equals(originalToken)));
      expect(newToken, contains('refreshed_'));
    });
  });
}