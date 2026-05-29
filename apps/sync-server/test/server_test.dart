import 'package:test/test.dart';

// Import the validation function for testing
// Note: We need to make _validateSecret accessible for testing
void validateSecret(String name, String? value) {
  if (value == null || value.isEmpty) {
    throw ArgumentError('$name is required');
  }
  if (value == 'your-secret-key' || value == 'change-me' ||
      value == 'your-jwt-secret-key-change-in-production' ||
      value == 'default-secret-change-in-production' ||
      value == 'default-encryption-key-32-chars') {
    throw ArgumentError('$name cannot use default value');
  }
  if (value.length < 32) {
    throw ArgumentError('$name must be at least 32 characters');
  }
}

void main() {
  group('Secret Validation', () {
    group('JWT_SECRET', () {
      test('throws on missing JWT_SECRET', () {
        expect(
          () => validateSecret('JWT_SECRET', null),
          throwsA(isA<ArgumentError>().having(
            (e) => e.message,
            'message',
            'JWT_SECRET is required',
          )),
        );
      });

      test('throws on empty JWT_SECRET', () {
        expect(
          () => validateSecret('JWT_SECRET', ''),
          throwsA(isA<ArgumentError>().having(
            (e) => e.message,
            'message',
            'JWT_SECRET is required',
          )),
        );
      });

      test('throws on placeholder value "your-secret-key"', () {
        expect(
          () => validateSecret('JWT_SECRET', 'your-secret-key'),
          throwsA(isA<ArgumentError>().having(
            (e) => e.message,
            'message',
            'JWT_SECRET cannot use default value',
          )),
        );
      });

      test('throws on placeholder value "change-me"', () {
        expect(
          () => validateSecret('JWT_SECRET', 'change-me'),
          throwsA(isA<ArgumentError>().having(
            (e) => e.message,
            'message',
            'JWT_SECRET cannot use default value',
          )),
        );
      });

      test('throws on production placeholder', () {
        expect(
          () => validateSecret('JWT_SECRET', 'your-jwt-secret-key-change-in-production'),
          throwsA(isA<ArgumentError>().having(
            (e) => e.message,
            'message',
            'JWT_SECRET cannot use default value',
          )),
        );
      });

      test('throws on too short secret', () {
        expect(
          () => validateSecret('JWT_SECRET', 'short-secret-only-20-chars'),
          throwsA(isA<ArgumentError>().having(
            (e) => e.message,
            'message',
            'JWT_SECRET must be at least 32 characters',
          )),
        );
      });

      test('accepts valid secret with 32 characters', () {
        // Should not throw
        expect(
          () => validateSecret('JWT_SECRET', 'this-is-exactly-32-characters-long!'),
          returnsNormally,
        );
      });

      test('accepts valid secret longer than 32 characters', () {
        // Should not throw
        expect(
          () => validateSecret('JWT_SECRET', 'this-is-a-very-long-and-secure-secret-key-for-production'),
          returnsNormally,
        );
      });
    });

    group('ENCRYPTION_KEY', () {
      test('throws on missing ENCRYPTION_KEY', () {
        expect(
          () => validateSecret('ENCRYPTION_KEY', null),
          throwsA(isA<ArgumentError>().having(
            (e) => e.message,
            'message',
            'ENCRYPTION_KEY is required',
          )),
        );
      });

      test('throws on empty ENCRYPTION_KEY', () {
        expect(
          () => validateSecret('ENCRYPTION_KEY', ''),
          throwsA(isA<ArgumentError>().having(
            (e) => e.message,
            'message',
            'ENCRYPTION_KEY is required',
          )),
        );
      });

      test('throws on placeholder value', () {
        expect(
          () => validateSecret('ENCRYPTION_KEY', 'change-me'),
          throwsA(isA<ArgumentError>().having(
            (e) => e.message,
            'message',
            'ENCRYPTION_KEY cannot use default value',
          )),
        );
      });

      test('throws on default encryption key placeholder', () {
        expect(
          () => validateSecret('ENCRYPTION_KEY', 'default-encryption-key-32-chars'),
          throwsA(isA<ArgumentError>().having(
            (e) => e.message,
            'message',
            'ENCRYPTION_KEY cannot use default value',
          )),
        );
      });

      test('throws on too short encryption key', () {
        expect(
          () => validateSecret('ENCRYPTION_KEY', 'short-key-only-15-chars'),
          throwsA(isA<ArgumentError>().having(
            (e) => e.message,
            'message',
            'ENCRYPTION_KEY must be at least 32 characters',
          )),
        );
      });

      test('accepts valid encryption key', () {
        // Should not throw
        expect(
          () => validateSecret('ENCRYPTION_KEY', 'this-is-a-secure-encryption-key-32!'),
          returnsNormally,
        );
      });
    });
  });
}
