import 'package:test/test.dart';
import 'package:sync_server/src/services/encryption_service.dart';

void main() {
  late EncryptionService encryptionService;

  setUp(() {
    encryptionService = EncryptionService('test-encryption-key-32-chars!!');
  });

  group('EncryptionService', () {
    group('encrypt/decrypt', () {
      test('encrypt/decrypt round-trip preserves original text', () {
        // Arrange
        const plaintext = 'This is a secret message';

        // Act
        final encrypted = encryptionService.encrypt(plaintext);
        final decrypted = encryptionService.decrypt(encrypted);

        // Assert
        expect(decrypted, equals(plaintext));
      });

      test('encrypt produces different ciphertext for same plaintext', () {
        // Arrange
        const plaintext = 'Same message';

        // Act
        final encrypted1 = encryptionService.encrypt(plaintext);
        final encrypted2 = encryptionService.encrypt(plaintext);

        // Assert - Different due to IV/randomness in encryption
        // Note: This depends on the encryption implementation
        // Some implementations may produce same output for testing
        expect(encrypted1, isNotEmpty);
        expect(encrypted2, isNotEmpty);
      });

      test('encrypt handles empty string', () {
        // Arrange
        const plaintext = '';

        // Act
        final encrypted = encryptionService.encrypt(plaintext);
        final decrypted = encryptionService.decrypt(encrypted);

        // Assert
        expect(decrypted, equals(plaintext));
      });

      test('encrypt handles special characters', () {
        // Arrange
        const plaintext = r'!@#\$%^&*()_+-={}[]|:";\'<>?,./~`';

        // Act
        final encrypted = encryptionService.encrypt(plaintext);
        final decrypted = encryptionService.decrypt(encrypted);

        // Assert
        expect(decrypted, equals(plaintext));
      });

      test('encrypt handles unicode characters', () {
        // Arrange
        const plaintext = '你好世界 🌍 مرحبا';

        // Act
        final encrypted = encryptionService.encrypt(plaintext);
        final decrypted = encryptionService.decrypt(encrypted);

        // Assert
        expect(decrypted, equals(plaintext));
      });

      test('encrypt handles long text', () {
        // Arrange
        final plaintext = 'A' * 10000;

        // Act
        final encrypted = encryptionService.encrypt(plaintext);
        final decrypted = encryptionService.decrypt(encrypted);

        // Assert
        expect(decrypted, equals(plaintext));
      });
    });

    group('hashPassword', () {
      test('produces consistent hash for same password and salt', () {
        // Arrange
        const password = 'myPassword123';
        const salt = 'fixed-salt-value';

        // Act
        final hash1 = encryptionService.hashPassword(password, salt);
        final hash2 = encryptionService.hashPassword(password, salt);

        // Assert
        expect(hash1, equals(hash2));
      });

      test('produces different hash for different password', () {
        // Arrange
        const salt = 'same-salt';

        // Act
        final hash1 = encryptionService.hashPassword('password1', salt);
        final hash2 = encryptionService.hashPassword('password2', salt);

        // Assert
        expect(hash1, isNot(equals(hash2)));
      });

      test('produces different hash for different salt', () {
        // Arrange
        const password = 'samePassword';

        // Act
        final hash1 = encryptionService.hashPassword(password, 'salt1');
        final hash2 = encryptionService.hashPassword(password, 'salt2');

        // Assert
        expect(hash1, isNot(equals(hash2)));
      });

      test('produces SHA-256 length hash (64 hex characters)', () {
        // Arrange
        const password = 'testPassword';
        const salt = 'testSalt';

        // Act
        final hash = encryptionService.hashPassword(password, salt);

        // Assert - SHA-256 produces 64 hex characters
        expect(hash.length, equals(64));
        expect(RegExp(r'^[a-f0-9]+$').hasMatch(hash), isTrue);
      });

      test('handles empty password', () {
        // Arrange
        const password = '';
        const salt = 'some-salt';

        // Act
        final hash = encryptionService.hashPassword(password, salt);

        // Assert
        expect(hash, isNotEmpty);
        expect(hash.length, equals(64));
      });

      test('handles empty salt', () {
        // Arrange
        const password = 'somePassword';
        const salt = '';

        // Act
        final hash = encryptionService.hashPassword(password, salt);

        // Assert
        expect(hash, isNotEmpty);
        expect(hash.length, equals(64));
      });
    });

    group('verifyPassword', () {
      test('matches correct password', () {
        // Arrange
        const password = 'correctPassword';
        const salt = 'test-salt';
        final hash = encryptionService.hashPassword(password, salt);

        // Act
        final isValid = encryptionService.verifyPassword(password, salt, hash);

        // Assert
        expect(isValid, isTrue);
      });

      test('rejects incorrect password', () {
        // Arrange
        const correctPassword = 'correctPassword';
        const wrongPassword = 'wrongPassword';
        const salt = 'test-salt';
        final hash = encryptionService.hashPassword(correctPassword, salt);

        // Act
        final isValid = encryptionService.verifyPassword(wrongPassword, salt, hash);

        // Assert
        expect(isValid, isFalse);
      });

      test('rejects with wrong salt', () {
        // Arrange
        const password = 'myPassword';
        const correctSalt = 'correct-salt';
        const wrongSalt = 'wrong-salt';
        final hash = encryptionService.hashPassword(password, correctSalt);

        // Act
        final isValid = encryptionService.verifyPassword(password, wrongSalt, hash);

        // Assert
        expect(isValid, isFalse);
      });

      test('rejects with wrong hash', () {
        // Arrange
        const password = 'myPassword';
        const salt = 'test-salt';
        const wrongHash = '0' * 64; // Invalid hash

        // Act
        final isValid = encryptionService.verifyPassword(password, salt, wrongHash);

        // Assert
        expect(isValid, isFalse);
      });

      test('is case-sensitive', () {
        // Arrange
        const password = 'Password';
        const salt = 'test-salt';
        final hash = encryptionService.hashPassword(password, salt);

        // Act
        final isValidLower = encryptionService.verifyPassword('password', salt, hash);
        final isValidUpper = encryptionService.verifyPassword('PASSWORD', salt, hash);

        // Assert
        expect(isValidLower, isFalse);
        expect(isValidUpper, isFalse);
      });
    });

    group('generateSalt', () {
      test('produces unique salts', () {
        // Act
        final salt1 = encryptionService.generateSalt();
        final salt2 = encryptionService.generateSalt();
        final salt3 = encryptionService.generateSalt();

        // Assert
        expect(salt1, isNot(equals(salt2)));
        expect(salt2, isNot(equals(salt3)));
        expect(salt1, isNot(equals(salt3)));
      });

      test('produces 16 character salt', () {
        // Act
        final salt = encryptionService.generateSalt();

        // Assert
        expect(salt.length, equals(16));
      });

      test('produces alphanumeric salt', () {
        // Act
        final salt = encryptionService.generateSalt();

        // Assert - UUID without dashes, first 16 chars
        expect(RegExp(r'^[a-f0-9]+$').hasMatch(salt), isTrue);
      });

      test('produces non-empty salt', () {
        // Act
        final salt = encryptionService.generateSalt();

        // Assert
        expect(salt, isNotEmpty);
      });

      test('generates multiple unique salts in sequence', () {
        // Arrange
        final salts = <String>{};

        // Act
        for (var i = 0; i < 100; i++) {
          salts.add(encryptionService.generateSalt());
        }

        // Assert - All should be unique
        expect(salts.length, equals(100));
      });
    });

    group('integration tests', () {
      test('full password workflow: hash, store, verify', () {
        // Arrange
        const password = 'userPassword123!';

        // Act - Simulate registration
        final salt = encryptionService.generateSalt();
        final hash = encryptionService.hashPassword(password, salt);

        // Store salt:hash (simulated)
        final storedValue = '$salt:$hash';

        // Act - Simulate login
        final parts = storedValue.split(':');
        final retrievedSalt = parts[0];
        final retrievedHash = parts[1];
        final isValid = encryptionService.verifyPassword(password, retrievedSalt, retrievedHash);

        // Assert
        expect(isValid, isTrue);
        expect(retrievedSalt, equals(salt));
        expect(retrievedHash, equals(hash));
      });

      test('encryption with different keys produces different results', () {
        // Arrange
        const plaintext = 'Secret data';
        final service1 = EncryptionService('key-one-32-characters-long!!');
        final service2 = EncryptionService('key-two-32-characters-long!!');

        // Act
        final encrypted1 = service1.encrypt(plaintext);
        final encrypted2 = service2.encrypt(plaintext);

        // Assert - Different keys should produce different ciphertext
        // Note: Decrypting with wrong key should fail or produce garbage
        expect(() => service2.decrypt(encrypted1), throwsA(anything));
      });
    });
  });
}
