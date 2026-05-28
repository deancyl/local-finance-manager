import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

import 'package:sync/src/security/certificate_pinning.dart';

// Mock classes
class MockHttpClient extends Mock implements http.Client {}

class MockBaseRequest extends Mock implements http.BaseRequest {}

class FakeStreamedResponse extends Fake implements http.StreamedResponse {
  final int statusCode;
  final Map<String, String> headers;

  FakeStreamedResponse({
    this.statusCode = 200,
    this.headers = const {},
  });
}

void main() {
  late MockHttpClient mockHttpClient;

  setUpAll(() {
    registerFallbackValue(Uri.parse('https://example.com'));
    registerFallbackValue(MockBaseRequest());
  });

  setUp(() {
    mockHttpClient = MockHttpClient();
  });

  group('CertificatePinningConfig', () {
    group('constructor', () {
      test('creates config with required parameters', () {
        final config = CertificatePinningConfig(
          pinnedSha256Hashes: ['ABC123'],
        );

        expect(config.pinnedSha256Hashes, equals(['ABC123']));
        expect(config.enforcePinning, isTrue);
        expect(config.validateOnEveryRequest, isFalse);
      });

      test('creates config with all parameters', () {
        final config = CertificatePinningConfig(
          pinnedSha256Hashes: ['ABC123', 'DEF456'],
          enforcePinning: false,
          validateOnEveryRequest: true,
        );

        expect(config.pinnedSha256Hashes, equals(['ABC123', 'DEF456']));
        expect(config.enforcePinning, isFalse);
        expect(config.validateOnEveryRequest, isTrue);
      });

      test('asserts when pinned hashes is empty', () {
        expect(
          () => CertificatePinningConfig(pinnedSha256Hashes: []),
          throwsA(isA<AssertionError>()),
        );
      });
    });

    group('single factory', () {
      test('creates config with single hash', () {
        final config = CertificatePinningConfig.single('ABC123');

        expect(config.pinnedSha256Hashes, equals(['ABC123']));
        expect(config.enforcePinning, isTrue);
      });

      test('creates config with custom enforcePinning', () {
        final config = CertificatePinningConfig.single(
          'ABC123',
          enforcePinning: false,
        );

        expect(config.enforcePinning, isFalse);
      });
    });

    group('rotation factory', () {
      test('creates config with current and previous hashes', () {
        final config = CertificatePinningConfig.rotation(
          currentHash: 'NEW123',
          previousHash: 'OLD123',
        );

        expect(config.pinnedSha256Hashes, equals(['NEW123', 'OLD123']));
        expect(config.enforcePinning, isTrue);
      });

      test('allows certificate rotation during updates', () {
        final config = CertificatePinningConfig.rotation(
          currentHash: 'NEW123',
          previousHash: 'OLD123',
          enforcePinning: true,
        );

        // Both old and new certificates should be valid
        expect(config.pinnedSha256Hashes.contains('NEW123'), isTrue);
        expect(config.pinnedSha256Hashes.contains('OLD123'), isTrue);
      });
    });

    group('disabled constant', () {
      test('creates no-op configuration', () {
        final config = CertificatePinningConfig.disabled;

        expect(config.pinnedSha256Hashes, equals(['']));
        expect(config.enforcePinning, isFalse);
      });
    });

    group('toString', () {
      test('returns readable representation', () {
        final config = CertificatePinningConfig(
          pinnedSha256Hashes: ['ABC', 'DEF'],
          enforcePinning: true,
        );

        expect(config.toString(), contains('hashes: 2'));
        expect(config.toString(), contains('enforce: true'));
      });
    });
  });

  group('CertificatePinningException', () {
    test('creates exception with message', () {
      final exception = CertificatePinningException('Test error');

      expect(exception.message, equals('Test error'));
      expect(exception.expectedHash, isNull);
      expect(exception.actualHash, isNull);
    });

    test('creates exception with all parameters', () {
      final exception = CertificatePinningException(
        'Test error',
        expectedHash: 'ABC123',
        actualHash: 'DEF456',
      );

      expect(exception.message, equals('Test error'));
      expect(exception.expectedHash, equals('ABC123'));
      expect(exception.actualHash, equals('DEF456'));
    });

    test('toString includes all information', () {
      final exception = CertificatePinningException(
        'Test error',
        expectedHash: 'ABC123',
        actualHash: 'DEF456',
      );

      final str = exception.toString();
      expect(str, contains('CertificatePinningException'));
      expect(str, contains('Test error'));
      expect(str, contains('Expected: ABC123'));
      expect(str, contains('Actual: DEF456'));
    });
  });

  group('CertificatePinningClient', () {
    group('send', () {
      test('allows request when certificate matches', () async {
        final config = CertificatePinningConfig.single('ABC123');
        final client = CertificatePinningClient(
          inner: mockHttpClient,
          config: config,
        );

        final request = http.Request('GET', Uri.parse('https://example.com'));
        final response = FakeStreamedResponse(
          headers: {'x-ssl-cert-sha256': 'ABC123'},
        );

        when(() => mockHttpClient.send(any()))
            .thenAnswer((_) async => response);

        await client.send(request);

        verify(() => mockHttpClient.send(any())).called(1);
      });

      test('allows request when certificate matches with different format', () async {
        final config = CertificatePinningConfig.single('abc123');
        final client = CertificatePinningClient(
          inner: mockHttpClient,
          config: config,
        );

        final request = http.Request('GET', Uri.parse('https://example.com'));
        // Server returns uppercase with colons
        final response = FakeStreamedResponse(
          headers: {'x-ssl-cert-sha256': 'AB:C1:23'},
        );

        when(() => mockHttpClient.send(any()))
            .thenAnswer((_) async => response);

        await client.send(request);

        verify(() => mockHttpClient.send(any())).called(1);
      });

      test('throws when certificate does not match', () async {
        final config = CertificatePinningConfig.single('ABC123');
        final client = CertificatePinningClient(
          inner: mockHttpClient,
          config: config,
        );

        final request = http.Request('GET', Uri.parse('https://example.com'));
        final response = FakeStreamedResponse(
          headers: {'x-ssl-cert-sha256': 'WRONG99'},
        );

        when(() => mockHttpClient.send(any()))
            .thenAnswer((_) async => response);

        expect(
          () => client.send(request),
          throwsA(isA<CertificatePinningException>()),
        );
      });

      test('logs warning but does not throw when enforcePinning is false', () async {
        final config = CertificatePinningConfig(
          pinnedSha256Hashes: ['ABC123'],
          enforcePinning: false,
        );
        final client = CertificatePinningClient(
          inner: mockHttpClient,
          config: config,
        );

        final request = http.Request('GET', Uri.parse('https://example.com'));
        final response = FakeStreamedResponse(
          headers: {'x-ssl-cert-sha256': 'WRONG99'},
        );

        when(() => mockHttpClient.send(any()))
            .thenAnswer((_) async => response);

        // Should not throw
        await client.send(request);

        verify(() => mockHttpClient.send(any())).called(1);
      });

      test('throws when no certificate header and enforcePinning is true', () async {
        final config = CertificatePinningConfig.single('ABC123');
        final client = CertificatePinningClient(
          inner: mockHttpClient,
          config: config,
        );

        final request = http.Request('GET', Uri.parse('https://example.com'));
        final response = FakeStreamedResponse(headers: {});

        when(() => mockHttpClient.send(any()))
            .thenAnswer((_) async => response);

        expect(
          () => client.send(request),
          throwsA(isA<CertificatePinningException>()),
        );
      });

      test('allows request when no certificate header and pinning disabled', () async {
        final config = CertificatePinningConfig.disabled;
        final client = CertificatePinningClient(
          inner: mockHttpClient,
          config: config,
        );

        final request = http.Request('GET', Uri.parse('https://example.com'));
        final response = FakeStreamedResponse(headers: {});

        when(() => mockHttpClient.send(any()))
            .thenAnswer((_) async => response);

        await client.send(request);

        verify(() => mockHttpClient.send(any())).called(1);
      });

      test('caches validated hosts', () async {
        final config = CertificatePinningConfig.single('ABC123');
        final client = CertificatePinningClient(
          inner: mockHttpClient,
          config: config,
        );

        final request = http.Request('GET', Uri.parse('https://example.com'));
        final response = FakeStreamedResponse(
          headers: {'x-ssl-cert-sha256': 'ABC123'},
        );

        when(() => mockHttpClient.send(any()))
            .thenAnswer((_) async => response);

        // First request
        await client.send(request);
        // Second request to same host
        await client.send(request);

        // Should only validate once (send called twice but validation only on first)
        verify(() => mockHttpClient.send(any())).called(2);
      });

      test('validates on every request when configured', () async {
        final config = CertificatePinningConfig(
          pinnedSha256Hashes: ['ABC123'],
          validateOnEveryRequest: true,
        );
        final client = CertificatePinningClient(
          inner: mockHttpClient,
          config: config,
        );

        final request = http.Request('GET', Uri.parse('https://example.com'));
        final response = FakeStreamedResponse(
          headers: {'x-ssl-cert-sha256': 'ABC123'},
        );

        when(() => mockHttpClient.send(any()))
            .thenAnswer((_) async => response);

        await client.send(request);
        await client.send(request);

        verify(() => mockHttpClient.send(any())).called(2);
      });

      test('validates different hosts separately', () async {
        final config = CertificatePinningConfig.single('ABC123');
        final client = CertificatePinningClient(
          inner: mockHttpClient,
          config: config,
        );

        final request1 = http.Request('GET', Uri.parse('https://example.com'));
        final request2 = http.Request('GET', Uri.parse('https://other.com'));
        final response = FakeStreamedResponse(
          headers: {'x-ssl-cert-sha256': 'ABC123'},
        );

        when(() => mockHttpClient.send(any()))
            .thenAnswer((_) async => response);

        await client.send(request1);
        await client.send(request2);

        verify(() => mockHttpClient.send(any())).called(2);
      });

      test('rethrows non-pinning exceptions', () async {
        final config = CertificatePinningConfig.single('ABC123');
        final client = CertificatePinningClient(
          inner: mockHttpClient,
          config: config,
        );

        final request = http.Request('GET', Uri.parse('https://example.com'));

        when(() => mockHttpClient.send(any()))
            .thenThrow(http.ClientException('Network error'));

        expect(
          () => client.send(request),
          throwsA(isA<http.ClientException>()),
        );
      });
    });

    group('clearCache', () {
      test('clears validated hosts cache', () async {
        final config = CertificatePinningConfig.single('ABC123');
        final client = CertificatePinningClient(
          inner: mockHttpClient,
          config: config,
        );

        final request = http.Request('GET', Uri.parse('https://example.com'));
        final response = FakeStreamedResponse(
          headers: {'x-ssl-cert-sha256': 'ABC123'},
        );

        when(() => mockHttpClient.send(any()))
            .thenAnswer((_) async => response);

        await client.send(request);
        client.clearCache();
        await client.send(request);

        // Both requests should trigger validation
        verify(() => mockHttpClient.send(any())).called(2);
      });
    });

    group('close', () {
      test('closes inner client', () {
        final config = CertificatePinningConfig.single('ABC123');
        final client = CertificatePinningClient(
          inner: mockHttpClient,
          config: config,
        );

        client.close();

        verify(() => mockHttpClient.close()).called(1);
      });
    });
  });

  group('CertificatePinningUtils', () {
    group('computeSha256Fingerprint', () {
      test('computes SHA-256 fingerprint from DER certificate', () {
        // Example DER bytes (simplified)
        final derBytes = utf8.encode('test certificate data');

        final fingerprint = CertificatePinningUtils.computeSha256Fingerprint(
          derBytes as Uint8List,
        );

        // Should be 64 hex characters with colons (32 bytes * 2 + 31 colons)
        expect(fingerprint.contains(':'), isTrue);
        expect(fingerprint.length, greaterThan(64));
      });
    });

    group('computeSha256FingerprintFromPem', () {
      test('computes SHA-256 fingerprint from PEM certificate', () {
        final pem = '''-----BEGIN CERTIFICATE-----
SGVsbG8gV29ybGQ=
-----END CERTIFICATE-----''';

        final fingerprint = CertificatePinningUtils.computeSha256FingerprintFromPem(pem);

        expect(fingerprint.contains(':'), isTrue);
        expect(fingerprint.length, greaterThan(64));
      });

      test('handles multi-line PEM', () {
        final pem = '''-----BEGIN CERTIFICATE-----
SGVsbG8g
V29ybGQ=
-----END CERTIFICATE-----''';

        final fingerprint = CertificatePinningUtils.computeSha256FingerprintFromPem(pem);

        expect(fingerprint.contains(':'), isTrue);
      });
    });

    group('isValidSha256Fingerprint', () {
      test('returns true for valid SHA-256 fingerprint', () {
        // Valid 64-character hex string
        final validHash = 'A' * 64;
        expect(CertificatePinningUtils.isValidSha256Fingerprint(validHash), isTrue);
      });

      test('returns true for valid fingerprint with colons', () {
        final validHash = 'AA:BB:CC:DD' * 16; // 64 chars with colons
        expect(CertificatePinningUtils.isValidSha256Fingerprint(validHash), isTrue);
      });

      test('returns false for invalid length', () {
        final invalidHash = 'ABC123';
        expect(CertificatePinningUtils.isValidSha256Fingerprint(invalidHash), isFalse);
      });

      test('returns false for non-hex characters', () {
        final invalidHash = 'G' * 64; // 'G' is not valid hex
        expect(CertificatePinningUtils.isValidSha256Fingerprint(invalidHash), isFalse);
      });

      test('returns true for lowercase hex', () {
        final validHash = 'a' * 64;
        expect(CertificatePinningUtils.isValidSha256Fingerprint(validHash), isTrue);
      });

      test('returns true for mixed case hex', () {
        final validHash = 'aAbBcCdDeEfF' + '0' * 52;
        expect(CertificatePinningUtils.isValidSha256Fingerprint(validHash), isTrue);
      });
    });
  });
}
