import 'package:test/test.dart';

// Import the server file to access _validateSecret
// Note: _validateSecret is a top-level function in server.dart
import 'package:sync_server/server.dart' as server;

void main() {
  group('_validateSecret', () {
    test('throws StateError when secret is null', () {
      expect(
        () => server._validateSecret('JWT_SECRET', null, 32),
        throwsA(isA<StateError>().having(
          (e) => e.message,
          'message',
          contains('JWT_SECRET environment variable is not set'),
        )),
      );
    });

    test('throws StateError when secret is empty', () {
      expect(
        () => server._validateSecret('JWT_SECRET', '', 32),
        throwsA(isA<StateError>().having(
          (e) => e.message,
          'message',
          contains('JWT_SECRET environment variable is not set'),
        )),
      );
    });

    test('throws StateError when secret contains "default"', () {
      expect(
        () => server._validateSecret('JWT_SECRET', 'my-default-secret-key-here', 32),
        throwsA(isA<StateError>().having(
          (e) => e.message,
          'message',
          contains('JWT_SECRET contains placeholder value'),
        )),
      );
    });

    test('throws StateError when secret contains "change"', () {
      expect(
        () => server._validateSecret('ENCRYPTION_KEY', 'please-change-this-key-now', 32),
        throwsA(isA<StateError>().having(
          (e) => e.message,
          'message',
          contains('ENCRYPTION_KEY contains placeholder value'),
        )),
      );
    });

    test('throws StateError when secret is too short', () {
      expect(
        () => server._validateSecret('JWT_SECRET', 'too-short', 32),
        throwsA(isA<StateError>().having(
          (e) => e.message,
          'message',
          allOf(
            contains('JWT_SECRET must be at least 32 characters'),
            contains('Got 9'),
          ),
        )),
      );
    });

    test('throws StateError when ENCRYPTION_KEY is too short', () {
      expect(
        () => server._validateSecret('ENCRYPTION_KEY', 'short-key', 32),
        throwsA(isA<StateError>().having(
          (e) => e.message,
          'message',
          allOf(
            contains('ENCRYPTION_KEY must be at least 32 characters'),
            contains('Got 9'),
          ),
        )),
      );
    });

    test('does not throw for valid secret with exact minimum length', () {
      // Exactly 32 characters
      expect(
        () => server._validateSecret('JWT_SECRET', 'a' * 32, 32),
        returnsNormally,
      );
    });

    test('does not throw for valid secret longer than minimum', () {
      // 64 characters
      expect(
        () => server._validateSecret('ENCRYPTION_KEY', 'b' * 64, 32),
        returnsNormally,
      );
    });

    test('does not throw for valid complex secret', () {
      const validSecret = 'MyS3cur3P@ssw0rd!WithSp3c1alChars#2024';
      expect(
        () => server._validateSecret('JWT_SECRET', validSecret, 32),
        returnsNormally,
      );
    });

    test('validates different minimum lengths correctly', () {
      // Test with minLength of 16
      expect(
        () => server._validateSecret('API_KEY', 'short', 16),
        throwsA(isA<StateError>().having(
          (e) => e.message,
          'message',
          contains('API_KEY must be at least 16 characters'),
        )),
      );

      // Valid for minLength 16
      expect(
        () => server._validateSecret('API_KEY', 'valid-16-char-key', 16),
        returnsNormally,
      );
    });
  });
}
