import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:encryption/encryption.dart';

class DbEncryptionService {
  static const String _dbKeyName = 'finance_db_encryption_key';
  static const int _keyLength = 32;
  static const int _pbkdf2Iterations = 100000;

  final KeychainService _keychain;

  DbEncryptionService({KeychainService? keychain})
      : _keychain = keychain ?? KeychainFactory.instance;

  Future<void> initialize() async {
    if (!KeychainFactory.isInitialized) {
      throw StateError('KeychainService must be initialized before DbEncryptionService');
    }

    final hasKey = await _keychain.hasKey(_dbKeyName);
    if (!hasKey) {
      await _generateAndStoreKey();
    }
  }

  Future<String> getEncryptionKey() async {
    final key = await _keychain.retrieveKey(_dbKeyName);
    if (key == null) {
      throw StateError('Database encryption key not found. Call initialize() first.');
    }
    return key;
  }

  Future<String> deriveKeyFromPassword(String password, {String? salt}) async {
    final saltBytes = salt != null
        ? utf8.encode(salt)
        : utf8.encode('local-finance-manager-db-salt');

    final pbkdf2 = PBKDF2KeyDerivator(HMac(SHA256Digest(), 64))
      ..init(Pbkdf2Parameters(
        Uint8List.fromList(saltBytes),
        _pbkdf2Iterations,
        _keyLength,
      ));

    final key = pbkdf2.process(Uint8List.fromList(utf8.encode(password)));
    return key.toHexString();
  }

  Future<void> updateEncryptionKey(String newPassword) async {
    final derivedKey = await deriveKeyFromPassword(newPassword);
    await _keychain.storeKey(_dbKeyName, derivedKey);
  }

  Future<bool> verifyEncryptionKey(String testKey) async {
    final storedKey = await getEncryptionKey();
    return storedKey == testKey;
  }

  Future<void> deleteEncryptionKey() async {
    await _keychain.deleteKey(_dbKeyName);
  }

  String escapeKeyForPragma(String key) {
    return key.replaceAll("'", "''");
  }

  Future<void> _generateAndStoreKey() async {
    await _keychain.generateAndStoreKey(_dbKeyName, _keyLength * 2);
  }
}
