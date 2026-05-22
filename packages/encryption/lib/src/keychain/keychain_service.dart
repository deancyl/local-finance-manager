import 'package:flutter/foundation.dart';

/// Abstract interface for secure key storage.
///
/// Platform-specific implementations:
/// - iOS: Keychain Services
/// - Android: Android Keystore
/// - Windows: Credential Manager
/// - macOS: Keychain Services
/// - Linux: libsecret
/// - Web: Web Crypto API + IndexedDB
abstract class KeychainService {
  /// Stores a key securely.
  Future<void> storeKey(String keyName, String key);

  /// Retrieves a stored key.
  Future<String?> retrieveKey(String keyName);

  /// Deletes a stored key.
  Future<void> deleteKey(String keyName);

  /// Checks if a key exists.
  Future<bool> hasKey(String keyName);

  /// Generates a new random key and stores it.
  Future<String> generateAndStoreKey(String keyName, int length);

  /// Clears all stored keys.
  Future<void> clearAll();
}

/// Factory for creating platform-specific keychain service.
class KeychainFactory {
  static KeychainService? _instance;

  /// Gets the platform-specific keychain service.
  static KeychainService get instance {
    if (_instance == null) {
      throw StateError('KeychainService not initialized. Call initialize() first.');
    }
    return _instance!;
  }

  /// Initializes the keychain service for the current platform.
  static void initialize(KeychainService service) {
    _instance = service;
  }

  /// Checks if the keychain service is initialized.
  static bool get isInitialized => _instance != null;
}