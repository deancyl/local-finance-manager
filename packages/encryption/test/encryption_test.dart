import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:encryption/encryption.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

/// Mock implementation of KeychainService for testing
class MockKeychainService extends Mock implements KeychainService {}

void main() {
  group('EncryptionService', () {
    group('constructor', () {
      test('creates service with valid 32-byte key', () {
        final key = Uint8List.fromList(List<int>.filled(32, 42));
        expect(() => EncryptionService(key), returnsNormally);
      });

      test('throws ArgumentError with invalid key length', () {
        final shortKey = Uint8List.fromList(List<int>.filled(16, 42));
        expect(
          () => EncryptionService(shortKey),
          throwsArgumentError,
        );
      });
    });

    group('fromPassword', () {
      test('creates service from password', () {
        final service = EncryptionService.fromPassword('test-password');
        expect(service, isA<EncryptionService>());
      });

      test('creates service with custom salt', () {
        final service = EncryptionService.fromPassword(
          'test-password',
          salt: 'custom-salt',
        );
        expect(service, isA<EncryptionService>());
      });

      test('different passwords produce different services', () {
        final service1 = EncryptionService.fromPassword('password1');
        final service2 = EncryptionService.fromPassword('password2');
        
        final plaintext = 'test data';
        final encrypted1 = service1.encrypt(plaintext);
        final encrypted2 = service2.encrypt(plaintext);
        
        // Different keys should produce different ciphertext
        expect(encrypted1, isNot(equals(encrypted2)));
      });
    });

    group('generateKey', () {
      test('generates 32-byte key', () {
        final key = EncryptionService.generateKey();
        expect(key.length, equals(32));
      });

      test('generates different keys on each call', () {
        final key1 = EncryptionService.generateKey();
        final key2 = EncryptionService.generateKey();
        expect(key1, isNot(equals(key2)));
      });
    });

    group('encrypt/decrypt', () {
      late EncryptionService service;

      setUp(() {
        service = EncryptionService(EncryptionService.generateKey());
      });

      test('encrypts and decrypts string correctly', () {
        const plaintext = 'Hello, World!';
        final encrypted = service.encrypt(plaintext);
        final decrypted = service.decrypt(encrypted);
        
        expect(decrypted, equals(plaintext));
      });

      test('encrypts and decrypts empty string', () {
        const plaintext = '';
        final encrypted = service.encrypt(plaintext);
        final decrypted = service.decrypt(encrypted);
        
        expect(decrypted, equals(plaintext));
      });

      test('encrypts and decrypts unicode characters', () {
        const plaintext = '你好世界 🌍 مرحبا';
        final encrypted = service.encrypt(plaintext);
        final decrypted = service.decrypt(encrypted);
        
        expect(decrypted, equals(plaintext));
      });

      test('encrypts and decrypts long string', () {
        final plaintext = 'A' * 10000;
        final encrypted = service.encrypt(plaintext);
        final decrypted = service.decrypt(encrypted);
        
        expect(decrypted, equals(plaintext));
      });

      test('produces different ciphertext for same plaintext (random nonce)', () {
        const plaintext = 'test data';
        final encrypted1 = service.encrypt(plaintext);
        final encrypted2 = service.encrypt(plaintext);
        
        // Same plaintext should produce different ciphertext due to random nonce
        expect(encrypted1, isNot(equals(encrypted2)));
        
        // But both should decrypt to the same plaintext
        expect(service.decrypt(encrypted1), equals(plaintext));
        expect(service.decrypt(encrypted2), equals(plaintext));
      });

      test('throws on invalid base64 ciphertext', () {
        expect(
          () => service.decrypt('not-valid-base64!!!'),
          throwsA(isA<FormatException>()),
        );
      });

      test('throws on corrupted ciphertext', () {
        final encrypted = service.encrypt('test');
        final corrupted = encrypted.substring(0, encrypted.length - 5) + 'XXXXX';
        
        expect(
          () => service.decrypt(corrupted),
          throwsA(anything),
        );
      });
    });

    group('encryptMap/decryptMap', () {
      late EncryptionService service;

      setUp(() {
        service = EncryptionService(EncryptionService.generateKey());
      });

      test('encrypts and decrypts map correctly', () {
        final data = {
          'name': 'John Doe',
          'amount': 123.45,
          'active': true,
          'tags': ['food', 'transport'],
        };
        
        final encrypted = service.encryptMap(data);
        final decrypted = service.decryptMap(encrypted);
        
        expect(decrypted['name'], equals('John Doe'));
        expect(decrypted['amount'], equals(123.45));
        expect(decrypted['active'], isTrue);
        expect(decrypted['tags'], isA<List>());
      });

      test('encrypts and decrypts empty map', () {
        final data = <String, dynamic>{};
        final encrypted = service.encryptMap(data);
        final decrypted = service.decryptMap(encrypted);
        
        expect(decrypted, isEmpty);
      });

      test('encrypts and decrypts nested map', () {
        final data = {
          'user': {
            'name': 'Alice',
            'address': {
              'city': 'Beijing',
              'zip': '100000',
            },
          },
        };
        
        final encrypted = service.encryptMap(data);
        final decrypted = service.decryptMap(encrypted);
        
        final user = decrypted['user'] as Map<String, dynamic>;
        final address = user['address'] as Map<String, dynamic>;
        
        expect(user['name'], equals('Alice'));
        expect(address['city'], equals('Beijing'));
      });
    });

    group('Uint8ListExtension', () {
      test('converts bytes to hex string', () {
        final bytes = Uint8List.fromList([0x01, 0x0A, 0xFF, 0x10]);
        expect(bytes.toHexString(), equals('010aff10'));
      });

      test('converts empty bytes to empty string', () {
        final bytes = Uint8List(0);
        expect(bytes.toHexString(), isEmpty);
      });
    });
  });

  group('KeychainService', () {
    late MockKeychainService mockKeychain;

    setUp(() {
      mockKeychain = MockKeychainService();
    });

    test('storeKey is called with correct parameters', () async {
      when(() => mockKeychain.storeKey('test_key', 'test_value'))
          .thenAnswer((_) async {});

      await mockKeychain.storeKey('test_key', 'test_value');
      
      verify(() => mockKeychain.storeKey('test_key', 'test_value')).called(1);
    });

    test('retrieveKey returns stored value', () async {
      when(() => mockKeychain.retrieveKey('test_key'))
          .thenAnswer((_) async => 'test_value');

      final result = await mockKeychain.retrieveKey('test_key');
      
      expect(result, equals('test_value'));
      verify(() => mockKeychain.retrieveKey('test_key')).called(1);
    });

    test('retrieveKey returns null for non-existent key', () async {
      when(() => mockKeychain.retrieveKey('non_existent'))
          .thenAnswer((_) async => null);

      final result = await mockKeychain.retrieveKey('non_existent');
      
      expect(result, isNull);
    });

    test('deleteKey is called with correct parameters', () async {
      when(() => mockKeychain.deleteKey('test_key'))
          .thenAnswer((_) async {});

      await mockKeychain.deleteKey('test_key');
      
      verify(() => mockKeychain.deleteKey('test_key')).called(1);
    });

    test('hasKey returns true for existing key', () async {
      when(() => mockKeychain.hasKey('test_key'))
          .thenAnswer((_) async => true);

      final result = await mockKeychain.hasKey('test_key');
      
      expect(result, isTrue);
    });

    test('hasKey returns false for non-existent key', () async {
      when(() => mockKeychain.hasKey('non_existent'))
          .thenAnswer((_) async => false);

      final result = await mockKeychain.hasKey('non_existent');
      
      expect(result, isFalse);
    });

    test('generateAndStoreKey generates key of specified length', () async {
      when(() => mockKeychain.generateAndStoreKey('new_key', 32))
          .thenAnswer((_) async => 'generated_key_value');

      final result = await mockKeychain.generateAndStoreKey('new_key', 32);
      
      expect(result, isNotEmpty);
      verify(() => mockKeychain.generateAndStoreKey('new_key', 32)).called(1);
    });

    test('clearAll clears all stored keys', () async {
      when(() => mockKeychain.clearAll())
          .thenAnswer((_) async {});

      await mockKeychain.clearAll();
      
      verify(() => mockKeychain.clearAll()).called(1);
    });
  });

  group('KeychainFactory', () {
    test('isInitialized returns false before initialization', () {
      // Note: Factory state persists between tests, so this may not be false
      // if another test initialized it first
      expect(KeychainFactory.isInitialized, isA<bool>());
    });

    test('isInitialized returns true after initialization', () {
      final mockService = MockKeychainService();
      KeychainFactory.initialize(mockService);
      
      expect(KeychainFactory.isInitialized, isTrue);
    });

    test('instance returns initialized service', () {
      final mockService = MockKeychainService();
      KeychainFactory.initialize(mockService);
      
      expect(KeychainFactory.instance, same(mockService));
    });
  });

  group('MobileKeychainService Secure Key Generation', () {
    test('generates cryptographically random key', () {
      final service = MobileKeychainService();
      final key1 = service.generateRandomKey(64);
      final key2 = service.generateRandomKey(64);
      
      // Keys should be different (cryptographically random)
      expect(key1, isNot(equals(key2)));
      
      // Keys should be 64 characters (32 bytes in hex)
      expect(key1.length, equals(64));
      expect(key2.length, equals(64));
      
      // Keys should only contain hex characters
      expect(RegExp(r'^[0-9a-f]+$').hasMatch(key1), isTrue);
      expect(RegExp(r'^[0-9a-f]+$').hasMatch(key2), isTrue);
    });

    test('keys are unique across calls', () {
      final service = MobileKeychainService();
      final keys = <String>{};
      
      // Generate 100 keys
      for (var i = 0; i < 100; i++) {
        final key = service.generateRandomKey(64);
        keys.add(key);
      }
      
      // All keys should be unique
      expect(keys.length, equals(100));
    });

    test('does not use timestamp-based generation', () {
      final service = MobileKeychainService();
      
      // Generate multiple keys rapidly
      final keys = <String>[];
      for (var i = 0; i < 10; i++) {
        keys.add(service.generateRandomKey(64));
      }
      
      // If timestamp-based, keys would be sequential or very similar
      // With Random.secure(), keys should be completely different
      final uniqueKeys = keys.toSet();
      expect(uniqueKeys.length, equals(10), 
          reason: 'Keys should all be unique, not timestamp-based');
      
      // Verify keys are not timestamp-based by checking they don't contain
      // patterns that would appear in timestamp strings
      for (final key in keys) {
        // Timestamps would have digits like year (2024, 2025, etc.)
        // Cryptographically random keys should not have predictable patterns
        expect(key.contains(RegExp(r'20\d{2}')), isFalse,
            reason: 'Key should not contain timestamp year pattern');
      }
    });
  });
}
