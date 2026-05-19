import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'keychain_service.dart';

/// Web keychain service using Web Crypto API and IndexedDB.
///
/// For web platform, we use a combination of:
/// - Web Crypto API for key generation
/// - IndexedDB for storage (encrypted with user password)
class WebKeychainService implements KeychainService {
  final Map<String, String> _storage = {};
  final String _userPassword;

  WebKeychainService({required String userPassword}) : _userPassword = userPassword;

  @override
  Future<void> storeKey(String keyName, String key) async {
    final encrypted = _encrypt(key, _userPassword);
    _storage[keyName] = encrypted;
    // In production, store to IndexedDB
  }

  @override
  Future<String?> retrieveKey(String keyName) async {
    final encrypted = _storage[keyName];
    if (encrypted == null) return null;
    return _decrypt(encrypted, _userPassword);
  }

  @override
  Future<void> deleteKey(String keyName) async {
    _storage.remove(keyName);
  }

  @override
  Future<bool> hasKey(String keyName) async {
    return _storage.containsKey(keyName);
  }

  @override
  Future<String> generateAndStoreKey(String keyName, int length) async {
    final key = _generateRandomKey(length);
    await storeKey(keyName, key);
    return key;
  }

  @override
  Future<void> clearAll() async {
    _storage.clear();
  }

  String _generateRandomKey(int length) {
    final random = Random.secure();
    final values = List<int>.generate(length, (i) => random.nextInt(256));
    return base64Url.encode(values);
  }

  String _encrypt(String data, String password) {
    final key = sha256.convert(utf8.encode(password)).bytes;
    final bytes = utf8.encode(data);
    // Simple XOR encryption for demo (use AES in production)
    final encrypted = bytes.map((b) => b ^ key[b % key.length]).toList();
    return base64Url.encode(encrypted);
  }

  String _decrypt(String encrypted, String password) {
    final key = sha256.convert(utf8.encode(password)).bytes;
    final bytes = base64Url.decode(encrypted);
    final decrypted = bytes.map((b) => b ^ key[b % key.length]).toList();
    return utf8.decode(decrypted);
  }
}