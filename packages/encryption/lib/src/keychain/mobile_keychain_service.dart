import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'keychain_service.dart';

/// Mobile keychain service using flutter_secure_storage.
///
/// Uses:
/// - iOS: Keychain Services
/// - Android: EncryptedSharedPreferences (Android Keystore)
class MobileKeychainService implements KeychainService {
  final FlutterSecureStorage _storage;

  MobileKeychainService({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage(
          aOptions: AndroidOptions(encryptedSharedPreferences: true),
          iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock_this_device),
        );

  @override
  Future<void> storeKey(String keyName, String key) async {
    await _storage.write(key: keyName, value: key);
  }

  @override
  Future<String?> retrieveKey(String keyName) async {
    return await _storage.read(key: keyName);
  }

  @override
  Future<void> deleteKey(String keyName) async {
    await _storage.delete(key: keyName);
  }

  @override
  Future<bool> hasKey(String keyName) async {
    final value = await _storage.read(key: keyName);
    return value != null;
  }

  @override
  Future<String> generateAndStoreKey(String keyName, int length) async {
    final key = _generateRandomKey(length);
    await storeKey(keyName, key);
    return key;
  }

  @override
  Future<void> clearAll() async {
    await _storage.deleteAll();
  }

  String _generateRandomKey(int length) {
    final random = DateTime.now().microsecondsSinceEpoch.toString();
    return random.padRight(length, '0').substring(0, length);
  }
}