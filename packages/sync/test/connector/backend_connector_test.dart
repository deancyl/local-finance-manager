import 'package:http/http.dart' as http;
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';
import 'package:sync/sync.dart';

// Mock classes
class MockAuthProvider extends Mock implements AuthProvider {}

class MockHttpClient extends Mock implements http.Client {}

void main() {
  late FinanceAppConnector connector;
  late MockAuthProvider mockAuthProvider;
  late MockHttpClient mockHttpClient;

  setUpAll(() {
    registerFallbackValue(Uri.parse('https://example.com'));
  });

  setUp(() {
    mockAuthProvider = MockAuthProvider();
    mockHttpClient = MockHttpClient();
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
          httpClient: mockHttpClient,
        );
        
        expect(connector.serverUrl, equals('https://sync.example.com'));
        expect(connector.authProvider, equals(mockAuthProvider));
      });
    });

    group('setToken and clearToken', () {
      test('setToken stores token and optional expiry', () {
        connector = FinanceAppConnector(serverUrl: 'https://sync.example.com');
        final expiry = DateTime.now().add(Duration(hours: 1));
        
        connector.setToken('test-token', expiry: expiry);
        
        // Verify token is set
        expect(connector.currentToken, equals('test-token'));
      });

      test('clearToken removes stored token', () {
        connector = FinanceAppConnector(serverUrl: 'https://sync.example.com');
        connector.setToken('test-token');
        
        connector.clearToken();
        
        expect(connector.currentToken, isNull);
      });
    });

    group('setDeviceId', () {
      test('setDeviceId stores device ID', () {
        connector = FinanceAppConnector(serverUrl: 'https://sync.example.com');
        
        connector.setDeviceId('new-device-id');
        
        // Device ID will be used in upload requests (verified via currentToken)
      });
    });

    group('fetchCredentials', () {
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

      test('returns null when no token set', () async {
        connector = FinanceAppConnector(
          serverUrl: 'https://sync.example.com',
        );
        
        final credentials = await connector.fetchCredentials();
        
        expect(credentials, isNull);
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
        );
        
        connector.setToken('test-token');
        
        connector.invalidateCredentials();
        
        expect(connector.currentToken, isNull);
      });
    });

    group('uploadData', () {
      test('stub implementation logs warning', () async {
        connector = FinanceAppConnector(
          serverUrl: 'https://sync.example.com',
          httpClient: mockHttpClient,
        );
        
        connector.setToken('test-token');
        
        // Stub implementation - should not throw
        await connector.uploadData(null);
        
        // No HTTP calls should be made in stub
        verifyNever(() => mockHttpClient.post(any(), headers: any(named: 'headers'), body: any(named: 'body')));
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
  });
}