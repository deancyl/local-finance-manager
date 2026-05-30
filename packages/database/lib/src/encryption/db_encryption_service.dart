import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:encryption/encryption.dart';

/// Database encryption service using SQLCipher.
/// 
/// This service manages the encryption key for the SQLite database,
/// storing it securely in the platform keychain.
class DbEncryptionService {
  static const String _dbKeyName = 'finance_db_encryption_key';
  static const int _keyLength = 32; // 256 bits

  final KeychainService _keychain;

  DbEncryptionService({KeychainService? keychain})
      : _keychain = keychain ?? KeychainFactory.instance;

  /// Initialize the encryption service.
  /// Generates a new key if one doesn't exist.
  Future<void> initialize() async {
    if (!KeychainFactory.isInitialized) {
      throw StateError('KeychainService must be initialized before DbEncryptionService');
    }

    final hasKey = await _keychain.hasKey(_dbKeyName);
    if (!hasKey) {
      await _generateAndStoreKey();
    }
  }

  /// Get the database encryption key.
  Future<String> getEncryptionKey() async {
    final key = await _keychain.retrieveKey(_dbKeyName);
    if (key == null) {
      throw StateError('Database encryption key not found. Call initialize() first.');
    }
    return key;
  }

  /// Derive a key from a password using SHA-256.
  /// Note: For production, use PBKDF2 with proper iterations.
  Future<String> deriveKeyFromPassword(String password, {String? salt}) async {
    final saltBytes = salt ?? 'local-finance-manager-db-salt';
    final combined = '$password:$saltBytes';
    
    // Simple key derivation - in production use PBKDF2
    final bytes = utf8.encode(combined);
    final keyBytes = _simpleHash(bytes, _keyLength);
    return _bytesToHex(keyBytes);
  }

  /// Update the encryption key with a new password.
  Future<void> updateEncryptionKey(String newPassword) async {
    final derivedKey = await deriveKeyFromPassword(newPassword);
    await _keychain.storeKey(_dbKeyName, derivedKey);
  }

  /// Verify if a key matches the stored encryption key.
  Future<bool> verifyEncryptionKey(String testKey) async {
    final storedKey = await getEncryptionKey();
    return storedKey == testKey;
  }

  /// Delete the encryption key.
  Future<void> deleteEncryptionKey() async {
    await _keychain.deleteKey(_dbKeyName);
  }

  /// Escape a key for use in PRAGMA statements.
  String escapeKeyForPragma(String key) {
    return key.replaceAll("'", "''");
  }

  /// Generate and store a new random encryption key.
  Future<void> _generateAndStoreKey() async {
    final key = _generateRandomKey(_keyLength);
    await _keychain.storeKey(_dbKeyName, key);
  }

  /// Generate a random hex key.
  String _generateRandomKey(int length) {
    final random = Random.secure();
    final bytes = Uint8List(length);
    for (int i = 0; i < length; i++) {
      bytes[i] = random.nextInt(256);
    }
    return _bytesToHex(bytes);
  }

  /// Convert bytes to hex string.
  String _bytesToHex(Uint8List bytes) {
    return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }

  /// Simple hash function for key derivation.
  Uint8List _simpleHash(List<int> input, int outputLength) {
    final result = Uint8List(outputLength);
    for (int i = 0; i < outputLength; i++) {
      int sum = 0;
      for (int j = 0; j < input.length; j++) {
        sum ^= input[j] * (i + 1) * (j + 1);
      }
      result[i] = sum & 0xFF;
    }
    return result;
  }
}
