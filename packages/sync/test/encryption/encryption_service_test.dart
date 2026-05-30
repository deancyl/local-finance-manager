import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sync/sync.dart';

void main() {
  group('SyncEncryption', () {
    late SyncEncryption encryption;
    late FlutterSecureStorage storage;

    setUp(() async {
      // Use in-memory storage mock for testing
      storage = FlutterSecureStorage();
      encryption = SyncEncryption(storage: storage);
      
      // Clear any existing data
      await encryption.clear();
    });

    tearDown(() async {
      await encryption.clear();
    });

    test('initializeWithPassword creates key', () async {
      // Arrange
      const password = 'test-password-123';
      
      // Act
      await encryption.initializeWithPassword(password);
      
      // Assert
      expect(encryption.isInitialized, isTrue);
      expect(encryption.getEncryptionKey(), isNotEmpty);
      expect(encryption.getSalt(), isNotEmpty);
    });

    test('initializeWithPassword creates same key with same password and salt', () async {
      // Arrange
      const password = 'test-password-123';
      
      // Act - Initialize first time
      await encryption.initializeWithPassword(password);
      final key1 = encryption.getEncryptionKey();
      final salt = encryption.getSalt();
      
      // Clear and reinitialize with same password
      await encryption.clear();
      // Manually set the salt to ensure same derivation
      await storage.write(key: 'sync_encryption_salt', value: salt);
      await encryption.initializeWithPassword(password);
      final key2 = encryption.getEncryptionKey();
      
      // Assert - Same password + same salt = same key
      expect(key1, equals(key2));
    });

    test('encrypt/decrypt round-trip succeeds', () async {
      // Arrange
      const plaintext = 'Hello, World! This is a secret message.';
      await encryption.generateAndStoreKey();
      
      // Act
      final ciphertext = encryption.encrypt(plaintext);
      final decrypted = encryption.decrypt(ciphertext);
      
      // Assert
      expect(decrypted, equals(plaintext));
      expect(ciphertext, isNot(equals(plaintext)));
    });

    test('encryptRecord/decryptRecord round-trip', () async {
      // Arrange
      final record = {
        'id': '123',
        'amount': 100.50,
        'description': 'Test transaction',
        'timestamp': '2024-01-15T10:30:00Z',
        'tags': ['food', 'lunch'],
      };
      await encryption.generateAndStoreKey();
      
      // Act
      final ciphertext = encryption.encryptRecord(record);
      final decrypted = encryption.decryptRecord(ciphertext);
      
      // Assert
      expect(decrypted['id'], equals(record['id']));
      expect(decrypted['amount'], equals(record['amount']));
      expect(decrypted['description'], equals(record['description']));
      expect(decrypted['timestamp'], equals(record['timestamp']));
      expect(decrypted['tags'], equals(record['tags']));
    });

    test('initializeFromStorage returns true after save', () async {
      // Arrange
      await encryption.generateAndStoreKey();
      final savedKey = encryption.getEncryptionKey();
      
      // Create new instance to simulate app restart
      final newEncryption = SyncEncryption(storage: storage);
      
      // Act
      final result = await newEncryption.initializeFromStorage();
      
      // Assert
      expect(result, isTrue);
      expect(newEncryption.isInitialized, isTrue);
      expect(newEncryption.getEncryptionKey(), equals(savedKey));
    });

    test('initializeFromStorage returns false when no key exists', () async {
      // Arrange
      final freshEncryption = SyncEncryption(storage: storage);
      await freshEncryption.clear();
      
      // Act
      final result = await freshEncryption.initializeFromStorage();
      
      // Assert
      expect(result, isFalse);
      expect(freshEncryption.isInitialized, isFalse);
    });

    test('clear removes all data', () async {
      // Arrange
      await encryption.generateAndStoreKey();
      expect(encryption.isInitialized, isTrue);
      
      // Act
      await encryption.clear();
      
      // Assert
      expect(encryption.isInitialized, isFalse);
      
      // Verify storage is empty
      final key = await storage.read(key: 'sync_encryption_key');
      final salt = await storage.read(key: 'sync_encryption_salt');
      expect(key, isNull);
      expect(salt, isNull);
    });

    test('generateAndStoreKey creates valid key', () async {
      // Act
      await encryption.generateAndStoreKey();
      
      // Assert
      expect(encryption.isInitialized, isTrue);
      final key = encryption.getEncryptionKey();
      expect(key, isNotEmpty);
      
      // Key should be valid base64
      final keyBytes = base64Url.decode(key);
      expect(keyBytes.length, equals(32)); // 256 bits
    });

    test('encrypt throws when not initialized', () {
      // Arrange
      final uninitializedEncryption = SyncEncryption(storage: storage);
      
      // Act & Assert
      expect(
        () => uninitializedEncryption.encrypt('test'),
        throwsStateError,
      );
    });

    test('decrypt throws when not initialized', () {
      // Arrange
      final uninitializedEncryption = SyncEncryption(storage: storage);
      
      // Act & Assert
      expect(
        () => uninitializedEncryption.decrypt('dGVzdA=='),
        throwsStateError,
      );
    });

    test('encryptRecord throws when not initialized', () {
      // Arrange
      final uninitializedEncryption = SyncEncryption(storage: storage);
      
      // Act & Assert
      expect(
        () => uninitializedEncryption.encryptRecord({'test': 'data'}),
        throwsStateError,
      );
    });

    test('decryptRecord throws when not initialized', () {
      // Arrange
      final uninitializedEncryption = SyncEncryption(storage: storage);
      
      // Act & Assert
      expect(
        () => uninitializedEncryption.decryptRecord('dGVzdA=='),
        throwsStateError,
      );
    });

    test('getEncryptionKey throws when not initialized', () {
      // Arrange
      final uninitializedEncryption = SyncEncryption(storage: storage);
      
      // Act & Assert
      expect(
        () => uninitializedEncryption.getEncryptionKey(),
        throwsStateError,
      );
    });

    test('different passwords produce different keys', () async {
      // Arrange
      const password1 = 'password1';
      const password2 = 'password2';
      
      // Act
      await encryption.initializeWithPassword(password1);
      final key1 = encryption.getEncryptionKey();
      
      await encryption.clear();
      await encryption.initializeWithPassword(password2);
      final key2 = encryption.getEncryptionKey();
      
      // Assert
      expect(key1, isNot(equals(key2)));
    });

    test('encrypted data cannot be decrypted with different key', () async {
      // Arrange
      const plaintext = 'Secret message';
      
      // Encrypt with first key
      await encryption.generateAndStoreKey();
      final ciphertext = encryption.encrypt(plaintext);
      
      // Create new encryption with different key
      final encryption2 = SyncEncryption(storage: storage);
      await encryption2.clear();
      await encryption2.generateAndStoreKey();
      
      // Act & Assert - Decryption should fail or produce garbage
      expect(
        () => encryption2.decrypt(ciphertext),
        throwsA(anything), // Will throw due to authentication failure
      );
    });
  });
}
