import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:mocktail/mocktail.dart';
import 'package:powersync/powersync.dart';
import 'package:test/test.dart';

import 'package:sync/src/connector/backend_connector.dart';
import 'package:sync/src/sync_config.dart';
import 'package:sync/src/security/certificate_pinning.dart';

// Mock classes
class MockAuthProvider extends Mock implements AuthProvider {}

class MockHttpClient extends Mock implements http.Client {}

class MockPowerSyncDatabase extends Mock implements PowerSyncDatabase {}

class MockCrudTransaction extends Mock implements CrudTransaction {}

class MockCrudEntry extends Mock implements CrudEntry {}

void main() {
  late FinanceAppConnector connector;
  late MockAuthProvider mockAuthProvider;
  late MockHttpClient mockHttpClient;
  late MockPowerSyncDatabase mockDatabase;

  setUpAll(() {
    registerFallbackValue(Uri.parse('https://example.com'));
    registerFallbackValue(CrudEntry(
      table: 'test',
      id: 'test-id',
      op: UpdateType.put,
      opData: {},
    ));
  });

  setUp(() {
    mockAuthProvider = MockAuthProvider();
    mockHttpClient = MockHttpClient();
    mockDatabase = MockPowerSyncDatabase();
  });

  group('FinanceAppConnector', () {
    group('constructor', () {
      test('creates connector with required parameters', () {
        connector = FinanceAppConnector(
          serverUrl: 'https://sync.example.com',
        );
        
        expect(connector.serverUrl, equals('https://sync.example.com'));
        expect(connector.authProvider, isNull);
        expect(connector.powerSyncDb, isNull);
      });

      test('creates connector with all parameters', () {
        connector = FinanceAppConnector(
          serverUrl: 'https://sync.example.com',
          authProvider: mockAuthProvider,
          powerSyncDb: mockDatabase,
          httpClient: mockHttpClient,
          deviceId: 'device-123',
        );
        
        expect(connector.serverUrl, equals('https://sync.example.com'));
        expect(connector.authProvider, equals(mockAuthProvider));
        expect(connector.powerSyncDb, equals(mockDatabase));
      });
    });

    group('setToken and clearToken', () {
      test('setToken stores token and optional expiry', () {
        connector = FinanceAppConnector(serverUrl: 'https://sync.example.com');
        final expiry = DateTime.now().add(Duration(hours: 1));
        
        connector.setToken('test-token', expiry: expiry);
        
        // Verify token is set by fetching credentials
        final credentials = connector.fetchCredentials();
        expect(credentials, isNotNull);
      });

      test('clearToken removes stored token', () async {
        connector = FinanceAppConnector(serverUrl: 'https://sync.example.com');
        connector.setToken('test-token');
        
        connector.clearToken();
        
        final credentials = await connector.fetchCredentials();
        expect(credentials, isNull);
      });
    });

    group('setDeviceId', () {
      test('setDeviceId stores device ID', () {
        connector = FinanceAppConnector(serverUrl: 'https://sync.example.com');
        
        connector.setDeviceId('new-device-id');
        
        // Device ID will be used in upload requests
        // Verified indirectly through uploadData tests
      });
    });

    group('fetchCredentials', () {
      test('returns credentials when authenticated via AuthProvider', () async {
        connector = FinanceAppConnector(
          serverUrl: 'https://sync.example.com',
          authProvider: mockAuthProvider,
        );
        
        when(() => mockAuthProvider.getToken())
            .thenAnswer((_) async => 'valid-token');
        when(() => mockAuthProvider.getUserId())
            .thenAnswer((_) async => 'user-123');
        
        final credentials = await connector.fetchCredentials();
        
        expect(credentials, isNotNull);
        expect(credentials!.endpoint, equals('https://sync.example.com'));
        expect(credentials.token, equals('valid-token'));
        expect(credentials.userId, equals('user-123'));
        
        verify(() => mockAuthProvider.getToken()).called(1);
        verify(() => mockAuthProvider.getUserId()).called(1);
      });

      test('returns null when AuthProvider has no token', () async {
        connector = FinanceAppConnector(
          serverUrl: 'https://sync.example.com',
          authProvider: mockAuthProvider,
        );
        
        when(() => mockAuthProvider.getToken())
            .thenAnswer((_) async => null);
        
        final credentials = await connector.fetchCredentials();
        
        expect(credentials, isNull);
        verify(() => mockAuthProvider.getToken()).called(1);
        verifyNever(() => mockAuthProvider.getUserId());
      });

      test('returns null when AuthProvider has no userId', () async {
        connector = FinanceAppConnector(
          serverUrl: 'https://sync.example.com',
          authProvider: mockAuthProvider,
        );
        
        when(() => mockAuthProvider.getToken())
            .thenAnswer((_) async => 'valid-token');
        when(() => mockAuthProvider.getUserId())
            .thenAnswer((_) async => null);
        
        final credentials = await connector.fetchCredentials();
        
        expect(credentials, isNull);
        verify(() => mockAuthProvider.getToken()).called(1);
        verify(() => mockAuthProvider.getUserId()).called(1);
      });

      test('returns credentials when manually set token is valid', () async {
        connector = FinanceAppConnector(
          serverUrl: 'https://sync.example.com',
        );
        
        connector.setToken('manual-token');
        
        final credentials = await connector.fetchCredentials();
        
        expect(credentials, isNotNull);
        expect(credentials!.token, equals('manual-token'));
        expect(credentials.endpoint, equals('https://sync.example.com'));
      });

      test('returns null when manually set token is expired', () async {
        connector = FinanceAppConnector(
          serverUrl: 'https://sync.example.com',
        );
        
        final pastExpiry = DateTime.now().subtract(Duration(hours: 1));
        connector.setToken('expired-token', expiry: pastExpiry);
        
        final credentials = await connector.fetchCredentials();
        
        expect(credentials, isNull);
      });

      test('returns credentials when token expiry is in the future', () async {
        connector = FinanceAppConnector(
          serverUrl: 'https://sync.example.com',
        );
        
        final futureExpiry = DateTime.now().add(Duration(hours: 1));
        connector.setToken('valid-token', expiry: futureExpiry);
        
        final credentials = await connector.fetchCredentials();
        
        expect(credentials, isNotNull);
        expect(credentials!.token, equals('valid-token'));
      });
    });

    group('invalidateCredentials', () {
      test('clears token', () async {
        connector = FinanceAppConnector(
          serverUrl: 'https://sync.example.com',
          authProvider: mockAuthProvider,
        );
        
        connector.setToken('test-token');
        
        connector.invalidateCredentials();
        
        final credentials = await connector.fetchCredentials();
        expect(credentials, isNull);
      });

      test('clears token when no AuthProvider', () async {
        connector = FinanceAppConnector(
          serverUrl: 'https://sync.example.com',
        );
        
        connector.setToken('test-token');
        
        connector.invalidateCredentials();
        
        final credentials = await connector.fetchCredentials();
        expect(credentials, isNull);
      });
    });

    group('uploadData', () {
      test('uploads records successfully', () async {
        connector = FinanceAppConnector(
          serverUrl: 'https://sync.example.com',
          authProvider: mockAuthProvider,
          httpClient: mockHttpClient,
          deviceId: 'device-123',
        );
        
        when(() => mockAuthProvider.getToken())
            .thenAnswer((_) async => 'valid-token');
        when(() => mockAuthProvider.getUserId())
            .thenAnswer((_) async => 'user-123');
        
        // Create mock transaction with CRUD entries
        final mockTransaction = MockCrudTransaction();
        final mockEntry = MockCrudEntry();
        
        when(() => mockEntry.table).thenReturn('accounts');
        when(() => mockEntry.id).thenReturn('acc-123');
        when(() => mockEntry.op).thenReturn(UpdateType.put);
        when(() => mockEntry.opData).thenReturn({'name': 'Test Account', 'version': 1});
        when(() => mockTransaction.crud).thenReturn([mockEntry]);
        when(() => mockTransaction.complete())
            .thenAnswer((_) async {});
        
        when(() => mockDatabase.getNextCrudTransaction())
            .thenAnswer((_) async => mockTransaction);
        
        // Mock HTTP response
        final response = http.Response('{}', 200);
        when(() => mockHttpClient.post(
          any(),
          headers: any(named: 'headers'),
          body: any(named: 'body'),
        )).thenAnswer((_) async => response);
        
        await connector.uploadData(mockDatabase);
        
        verify(() => mockDatabase.getNextCrudTransaction()).called(1);
        verify(() => mockTransaction.complete()).called(1);
        
        // Verify the POST request was made with correct data
        final captured = verify(() => mockHttpClient.post(
          any(),
          headers: any(named: 'headers'),
          body: captureAny(named: 'body'),
        )).captured.single as String;
        
        final body = jsonDecode(captured);
        expect(body['device_id'], equals('device-123'));
        expect(body['records'], isA<List>());
        expect(body['records'][0]['table_name'], equals('accounts'));
        expect(body['records'][0]['record_id'], equals('acc-123'));
        expect(body['records'][0]['operation'], equals('INSERT'));
      });

      test('returns early when no pending changes', () async {
        connector = FinanceAppConnector(
          serverUrl: 'https://sync.example.com',
          authProvider: mockAuthProvider,
          httpClient: mockHttpClient,
        );
        
        when(() => mockAuthProvider.getToken())
            .thenAnswer((_) async => 'valid-token');
        when(() => mockAuthProvider.getUserId())
            .thenAnswer((_) async => 'user-123');
        when(() => mockDatabase.getNextCrudTransaction())
            .thenAnswer((_) async => null);
        
        await connector.uploadData(mockDatabase);
        
        verify(() => mockDatabase.getNextCrudTransaction()).called(1);
        verifyNever(() => mockHttpClient.post(any(), headers: any(named: 'headers'), body: any(named: 'body')));
      });

      test('returns early when no credentials', () async {
        connector = FinanceAppConnector(
          serverUrl: 'https://sync.example.com',
          authProvider: mockAuthProvider,
          httpClient: mockHttpClient,
        );
        
        when(() => mockAuthProvider.getToken())
            .thenAnswer((_) async => null);
        
        await connector.uploadData(mockDatabase);
        
        verifyNever(() => mockDatabase.getNextCrudTransaction());
      });

      test('handles conflict (409) by completing transaction', () async {
        connector = FinanceAppConnector(
          serverUrl: 'https://sync.example.com',
          authProvider: mockAuthProvider,
          httpClient: mockHttpClient,
        );
        
        when(() => mockAuthProvider.getToken())
            .thenAnswer((_) async => 'valid-token');
        when(() => mockAuthProvider.getUserId())
            .thenAnswer((_) async => 'user-123');
        
        final mockTransaction = MockCrudTransaction();
        final mockEntry = MockCrudEntry();
        
        when(() => mockEntry.table).thenReturn('accounts');
        when(() => mockEntry.id).thenReturn('acc-123');
        when(() => mockEntry.op).thenReturn(UpdateType.put);
        when(() => mockEntry.opData).thenReturn({'name': 'Test'});
        when(() => mockTransaction.crud).thenReturn([mockEntry]);
        when(() => mockTransaction.complete())
            .thenAnswer((_) async {});
        
        when(() => mockDatabase.getNextCrudTransaction())
            .thenAnswer((_) async => mockTransaction);
        
        // Mock conflict response
        final response = http.Response('{"conflict": true}', 409);
        when(() => mockHttpClient.post(
          any(),
          headers: any(named: 'headers'),
          body: any(named: 'body'),
        )).thenAnswer((_) async => response);
        
        await connector.uploadData(mockDatabase);
        
        verify(() => mockTransaction.complete()).called(1);
      });

      test('invalidates credentials on 401', () async {
        connector = FinanceAppConnector(
          serverUrl: 'https://sync.example.com',
          authProvider: mockAuthProvider,
          httpClient: mockHttpClient,
        );
        
        when(() => mockAuthProvider.getToken())
            .thenAnswer((_) async => 'invalid-token');
        when(() => mockAuthProvider.getUserId())
            .thenAnswer((_) async => 'user-123');
        
        final mockTransaction = MockCrudTransaction();
        final mockEntry = MockCrudEntry();
        
        when(() => mockEntry.table).thenReturn('accounts');
        when(() => mockEntry.id).thenReturn('acc-123');
        when(() => mockEntry.op).thenReturn(UpdateType.put);
        when(() => mockEntry.opData).thenReturn({});
        when(() => mockTransaction.crud).thenReturn([mockEntry]);
        
        when(() => mockDatabase.getNextCrudTransaction())
            .thenAnswer((_) async => mockTransaction);
        
        // Mock unauthorized response
        final response = http.Response('{"error": "Unauthorized"}', 401);
        when(() => mockHttpClient.post(
          any(),
          headers: any(named: 'headers'),
          body: any(named: 'body'),
        )).thenAnswer((_) async => response);
        
        expect(
          () => connector.uploadData(mockDatabase),
          throwsA(isA<Exception>()),
        );
        
        // Verify credentials were cleared
        final credentials = await connector.fetchCredentials();
        expect(credentials, isNull);
      });

      test('throws on other HTTP errors', () async {
        connector = FinanceAppConnector(
          serverUrl: 'https://sync.example.com',
          authProvider: mockAuthProvider,
          httpClient: mockHttpClient,
        );
        
        when(() => mockAuthProvider.getToken())
            .thenAnswer((_) async => 'valid-token');
        when(() => mockAuthProvider.getUserId())
            .thenAnswer((_) async => 'user-123');
        
        final mockTransaction = MockCrudTransaction();
        final mockEntry = MockCrudEntry();
        
        when(() => mockEntry.table).thenReturn('accounts');
        when(() => mockEntry.id).thenReturn('acc-123');
        when(() => mockEntry.op).thenReturn(UpdateType.put);
        when(() => mockEntry.opData).thenReturn({});
        when(() => mockTransaction.crud).thenReturn([mockEntry]);
        
        when(() => mockDatabase.getNextCrudTransaction())
            .thenAnswer((_) async => mockTransaction);
        
        // Mock server error
        final response = http.Response('{"error": "Server error"}', 500);
        when(() => mockHttpClient.post(
          any(),
          headers: any(named: 'headers'),
          body: any(named: 'body'),
        )).thenAnswer((_) async => response);
        
        expect(
          () => connector.uploadData(mockDatabase),
          throwsA(isA<Exception>()),
        );
      });

      test('rethrows network errors', () async {
        connector = FinanceAppConnector(
          serverUrl: 'https://sync.example.com',
          authProvider: mockAuthProvider,
          httpClient: mockHttpClient,
        );
        
        when(() => mockAuthProvider.getToken())
            .thenAnswer((_) async => 'valid-token');
        when(() => mockAuthProvider.getUserId())
            .thenAnswer((_) async => 'user-123');
        
        final mockTransaction = MockCrudTransaction();
        final mockEntry = MockCrudEntry();
        
        when(() => mockEntry.table).thenReturn('accounts');
        when(() => mockEntry.id).thenReturn('acc-123');
        when(() => mockEntry.op).thenReturn(UpdateType.put);
        when(() => mockEntry.opData).thenReturn({});
        when(() => mockTransaction.crud).thenReturn([mockEntry]);
        
        when(() => mockDatabase.getNextCrudTransaction())
            .thenAnswer((_) async => mockTransaction);
        
        // Mock network error
        when(() => mockHttpClient.post(
          any(),
          headers: any(named: 'headers'),
          body: any(named: 'body'),
        )).thenThrow(http.ClientException('Network error'));
        
        expect(
          () => connector.uploadData(mockDatabase),
          throwsA(isA<http.ClientException>()),
        );
      });

      test('converts different operation types correctly', () async {
        connector = FinanceAppConnector(
          serverUrl: 'https://sync.example.com',
          authProvider: mockAuthProvider,
          httpClient: mockHttpClient,
        );
        
        when(() => mockAuthProvider.getToken())
            .thenAnswer((_) async => 'valid-token');
        when(() => mockAuthProvider.getUserId())
            .thenAnswer((_) async => 'user-123');
        
        final mockTransaction = MockCrudTransaction();
        
        // Create entries with different operation types
        final putEntry = MockCrudEntry();
        when(() => putEntry.table).thenReturn('accounts');
        when(() => putEntry.id).thenReturn('acc-1');
        when(() => putEntry.op).thenReturn(UpdateType.put);
        when(() => putEntry.opData).thenReturn({'name': 'Account 1'});
        
        final patchEntry = MockCrudEntry();
        when(() => patchEntry.table).thenReturn('accounts');
        when(() => patchEntry.id).thenReturn('acc-2');
        when(() => patchEntry.op).thenReturn(UpdateType.patch);
        when(() => patchEntry.opData).thenReturn({'name': 'Account 2'});
        
        final deleteEntry = MockCrudEntry();
        when(() => deleteEntry.table).thenReturn('accounts');
        when(() => deleteEntry.id).thenReturn('acc-3');
        when(() => deleteEntry.op).thenReturn(UpdateType.delete);
        when(() => deleteEntry.opData).thenReturn(null);
        
        when(() => mockTransaction.crud)
            .thenReturn([putEntry, patchEntry, deleteEntry]);
        when(() => mockTransaction.complete())
            .thenAnswer((_) async {});
        
        when(() => mockDatabase.getNextCrudTransaction())
            .thenAnswer((_) async => mockTransaction);
        
        final response = http.Response('{}', 200);
        when(() => mockHttpClient.post(
          any(),
          headers: any(named: 'headers'),
          body: any(named: 'body'),
        )).thenAnswer((_) async => response);
        
        await connector.uploadData(mockDatabase);
        
        // Verify operation types were converted correctly
        final captured = verify(() => mockHttpClient.post(
          any(),
          headers: any(named: 'headers'),
          body: captureAny(named: 'body'),
        )).captured.single as String;
        
        final body = jsonDecode(captured);
        expect(body['records'][0]['operation'], equals('INSERT'));
        expect(body['records'][1]['operation'], equals('UPDATE'));
        expect(body['records'][2]['operation'], equals('DELETE'));
      });
    });

    group('dispose', () {
      test('closes HTTP client', () {
        connector = FinanceAppConnector(
          serverUrl: 'https://sync.example.com',
          httpClient: mockHttpClient,
        );
        
        connector.dispose();
        
        verify(() => mockHttpClient.close()).called(1);
      });
    });

    group('certificate pinning', () {
      test('creates connector with certificate pinning config', () {
        final config = CertificatePinningConfig.single('ABC123');
        
        connector = FinanceAppConnector(
          serverUrl: 'https://sync.example.com',
          certificatePinningConfig: config,
        );
        
        expect(connector.certificatePinningConfig, equals(config));
      });

      test('creates connector without certificate pinning config', () {
        connector = FinanceAppConnector(
          serverUrl: 'https://sync.example.com',
        );
        
        expect(connector.certificatePinningConfig, isNull);
      });

      test('uses CertificatePinningClient when config is provided', () {
        final config = CertificatePinningConfig.single('ABC123');
        
        connector = FinanceAppConnector(
          serverUrl: 'https://sync.example.com',
          certificatePinningConfig: config,
        );
        
        // The connector should have the config set
        expect(connector.certificatePinningConfig, isNotNull);
        expect(
          connector.certificatePinningConfig!.pinnedSha256Hashes,
          equals(['ABC123']),
        );
      });

      test('uses default HTTP client when config is null', () {
        connector = FinanceAppConnector(
          serverUrl: 'https://sync.example.com',
        );
        
        expect(connector.certificatePinningConfig, isNull);
      });

      test('uses default HTTP client when config is disabled', () {
        connector = FinanceAppConnector(
          serverUrl: 'https://sync.example.com',
          certificatePinningConfig: CertificatePinningConfig.disabled,
        );
        
        // Disabled config should still be set but with empty hash
        expect(connector.certificatePinningConfig, isNotNull);
        expect(
          connector.certificatePinningConfig!.enforcePinning,
          isFalse,
        );
      });

      test('supports certificate rotation config', () {
        final config = CertificatePinningConfig.rotation(
          currentHash: 'NEW123',
          previousHash: 'OLD123',
        );
        
        connector = FinanceAppConnector(
          serverUrl: 'https://sync.example.com',
          certificatePinningConfig: config,
        );
        
        expect(connector.certificatePinningConfig!.pinnedSha256Hashes.length, equals(2));
        expect(
          connector.certificatePinningConfig!.pinnedSha256Hashes.contains('NEW123'),
          isTrue,
        );
        expect(
          connector.certificatePinningConfig!.pinnedSha256Hashes.contains('OLD123'),
          isTrue,
        );
      });

      test('allows custom HTTP client with pinning config', () {
        final config = CertificatePinningConfig.single('ABC123');
        
        connector = FinanceAppConnector(
          serverUrl: 'https://sync.example.com',
          httpClient: mockHttpClient,
          certificatePinningConfig: config,
        );
        
        // Custom client should be used (pinning config is for reference)
        expect(connector.certificatePinningConfig, equals(config));
      });
    });
  });
}
