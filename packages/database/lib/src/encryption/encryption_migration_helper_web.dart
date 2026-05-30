/// Stub implementation of encryption migration helper for web platform.
/// 
/// Web platform uses drift's built-in web sqlite which doesn't support
/// SQLCipher encryption. This stub provides no-op implementations.
import '../encryption/db_encryption_service.dart';

class EncryptionMigrationHelper {
  final DbEncryptionService _encryptionService;

  EncryptionMigrationHelper(this._encryptionService);

  /// No-op for web platform - encryption not supported
  Future<String?> migrateUnencryptedToEncrypted({
    String? unencryptedDbPath,
    String? encryptedDbPath,
    bool deleteOriginal = true,
  }) async {
    // Web platform uses IndexedDB/sqlite.wasm which doesn't support encryption
    return null;
  }

  /// Always returns false for web platform
  Future<bool> isDatabaseEncrypted(String dbPath) async {
    // Web platform doesn't support database encryption
    return false;
  }

  /// No-op for web platform
  Future<void> verifyEncryption(String dbPath) async {
    // Web platform doesn't support database encryption
    // No-op to avoid breaking the API
  }

  /// No-op for web platform - returns empty string
  Future<String> createEncryptedBackup(String dbPath, String backupPath) async {
    // Web platform doesn't support database encryption
    throw UnsupportedError('Encrypted backups are not supported on web platform');
  }
}
