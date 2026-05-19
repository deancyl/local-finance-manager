import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:encryption/encryption.dart' as core;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:pointycastle/export.dart';

/// Sync-specific encryption wrapper that reuses packages/encryption.
///
/// Provides:
/// - Password-derived encryption keys (for multi-device sync)
/// - Secure key storage in platform keychain
/// - Encrypt/decrypt sync payloads
class SyncEncryption {
  static const String _keyStorageKey = 'sync_encryption_key';
  static const String _saltStorageKey = 'sync_encryption_salt';
  static const int _keyLength = 32; // 256 bits
  static const int _pbkdf2Iterations = 100000;

  final FlutterSecureStorage _storage;
  core.EncryptionService? _encryptionService;
  String? _storedKeyBase64;
  String? _storedSaltBase64;

  SyncEncryption({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage();

  /// Whether the encryption service has been initialized.
  bool get isInitialized => _encryptionService != null;

  /// Initialize encryption with a password using PBKDF2 key derivation.
  ///
  /// Generates a new salt if one doesn't exist in storage.
  /// Derives a 256-bit key using PBKDF2 with SHA-256 and 100,000 iterations.
  Future<void> initializeWithPassword(String password) async {
    // Get or generate salt
    String saltBase64;
    final existingSalt = await _storage.read(key: _saltStorageKey);
    
    if (existingSalt != null) {
      saltBase64 = existingSalt;
    } else {
      // Generate new salt
      final salt = _generateSalt();
      saltBase64 = base64Url.encode(salt);
      await _storage.write(key: _saltStorageKey, value: saltBase64);
    }

    // Derive key from password
    final key = _deriveKeyFromPassword(password, saltBase64);
    final keyBase64 = base64Url.encode(key);

    // Store the derived key
    await _storage.write(key: _keyStorageKey, value: keyBase64);
    _storedKeyBase64 = keyBase64;
    _storedSaltBase64 = saltBase64;

    // Initialize encryption service
    _encryptionService = core.EncryptionService(key);
  }

  /// Initialize encryption from stored key.
  ///
  /// Returns true if a key was found and loaded successfully.
  /// Returns false if no key exists in storage.
  Future<bool> initializeFromStorage() async {
    final keyBase64 = await _storage.read(key: _keyStorageKey);
    final saltBase64 = await _storage.read(key: _saltStorageKey);

    if (keyBase64 == null) {
      return false;
    }

    _storedKeyBase64 = keyBase64;
    _storedSaltBase64 = saltBase64;

    final key = base64Url.decode(keyBase64);
    _encryptionService = core.EncryptionService(Uint8List.fromList(key));
    return true;
  }

  /// Generate a random encryption key and store it securely.
  ///
  /// Use this for non-password-based key generation.
  Future<void> generateAndStoreKey() async {
    // Generate random key
    final key = core.EncryptionService.generateKey();
    final keyBase64 = base64Url.encode(key);

    // Generate and store salt (for consistency with password-based flow)
    final salt = _generateSalt();
    final saltBase64 = base64Url.encode(salt);

    // Store both
    await _storage.write(key: _keyStorageKey, value: keyBase64);
    await _storage.write(key: _saltStorageKey, value: saltBase64);

    _storedKeyBase64 = keyBase64;
    _storedSaltBase64 = saltBase64;
    _encryptionService = core.EncryptionService(key);
  }

  /// Get the encryption key as base64 string.
  ///
  /// This can be used to pass to PowerSync or other sync services.
  /// Throws StateError if not initialized.
  String getEncryptionKey() {
    if (_storedKeyBase64 == null) {
      throw StateError('Encryption not initialized. Call initializeWithPassword, initializeFromStorage, or generateAndStoreKey first.');
    }
    return _storedKeyBase64!;
  }

  /// Get the salt as base64 string.
  ///
  /// Throws StateError if not initialized.
  String getSalt() {
    if (_storedSaltBase64 == null) {
      throw StateError('Encryption not initialized. Call initializeWithPassword, initializeFromStorage, or generateAndStoreKey first.');
    }
    return _storedSaltBase64!;
  }

  /// Encrypt a record (Map) to JSON string.
  ///
  /// Throws StateError if not initialized.
  String encryptRecord(Map<String, dynamic> record) {
    _ensureInitialized();
    return _encryptionService!.encryptMap(record);
  }

  /// Decrypt a JSON string to record (Map).
  ///
  /// Throws StateError if not initialized.
  Map<String, dynamic> decryptRecord(String ciphertext) {
    _ensureInitialized();
    return _encryptionService!.decryptMap(ciphertext);
  }

  /// Encrypt a raw string.
  ///
  /// Throws StateError if not initialized.
  String encrypt(String plaintext) {
    _ensureInitialized();
    return _encryptionService!.encrypt(plaintext);
  }

  /// Decrypt a raw string.
  ///
  /// Throws StateError if not initialized.
  String decrypt(String ciphertext) {
    _ensureInitialized();
    return _encryptionService!.decrypt(ciphertext);
  }

  /// Clear all stored encryption data.
  ///
  /// After calling this, the service will need to be re-initialized.
  Future<void> clear() async {
    await _storage.delete(key: _keyStorageKey);
    await _storage.delete(key: _saltStorageKey);
    _encryptionService = null;
    _storedKeyBase64 = null;
    _storedSaltBase64 = null;
  }

  /// Derive a key from password using PBKDF2.
  ///
  /// Uses SHA-256, 100,000 iterations, and produces a 32-byte (256-bit) key.
  Uint8List _deriveKeyFromPassword(String password, String base64Salt) {
    final salt = base64Url.decode(base64Salt);
    final pbkdf2 = PBKDF2KeyDerivator(HMac(SHA256Digest(), 64))
      ..init(Pbkdf2Parameters(
        Uint8List.fromList(salt),
        _pbkdf2Iterations,
        _keyLength,
      ));
    return pbkdf2.process(Uint8List.fromList(utf8.encode(password)));
  }

  /// Generate a random 32-byte salt.
  Uint8List _generateSalt() {
    final random = Random.secure();
    return Uint8List.fromList(
      List<int>.generate(32, (_) => random.nextInt(256)),
    );
  }

  /// Ensure the encryption service is initialized.
  void _ensureInitialized() {
    if (_encryptionService == null) {
      throw StateError(
        'Encryption not initialized. Call initializeWithPassword, initializeFromStorage, or generateAndStoreKey first.',
      );
    }
  }
}
