import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:sqlite3/sqlite3.dart';

import '../encryption/db_encryption_service.dart';

class EncryptionMigrationHelper {
  final DbEncryptionService _encryptionService;

  EncryptionMigrationHelper(this._encryptionService);

  Future<String?> migrateUnencryptedToEncrypted({
    String? unencryptedDbPath,
    String? encryptedDbPath,
    bool deleteOriginal = true,
  }) async {
    final appDir = await getApplicationSupportDirectory();
    final existingPath = unencryptedDbPath ?? '${appDir.path}/finance.db';
    final encryptedPath = encryptedDbPath ?? '${appDir.path}/finance_encrypted.db';

    final existingFile = File(existingPath);
    final encryptedFile = File(encryptedPath);

    if (!await existingFile.exists()) {
      return null;
    }

    if (await encryptedFile.exists()) {
      return encryptedPath;
    }

    final tmpPath = '$encryptedPath.tmp';
    final tmpFile = File(tmpPath);
    if (await tmpFile.exists()) {
      await tmpFile.delete();
    }

    final plaintextDb = sqlite3.open(existingPath);
    try {
      plaintextDb.execute("VACUUM INTO '$tmpPath';");
    } finally {
      plaintextDb.dispose();
    }

    final encryptedDb = sqlite3.open(tmpPath);
    try {
      final key = await _encryptionService.getEncryptionKey();
      final escapedKey = _encryptionService.escapeKeyForPragma(key);
      encryptedDb.execute("PRAGMA rekey = '$escapedKey';");
    } finally {
      encryptedDb.dispose();
    }

    if (!await tmpFile.exists()) {
      throw StateError('Failed to create encrypted database file');
    }

    await tmpFile.rename(encryptedPath);

    if (deleteOriginal) {
      await existingFile.delete();
    }

    return encryptedPath;
  }

  Future<bool> isDatabaseEncrypted(String dbPath) async {
    final file = File(dbPath);
    if (!await file.exists()) {
      return false;
    }

    try {
      final db = sqlite3.open(dbPath);
      try {
        final result = db.select('PRAGMA cipher;');
        return result.isNotEmpty;
      } finally {
        db.dispose();
      }
    } catch (e) {
      return true;
    }
  }

  Future<void> verifyEncryption(String dbPath) async {
    final file = File(dbPath);
    if (!await file.exists()) {
      throw StateError('Database file does not exist: $dbPath');
    }

    final db = sqlite3.open(dbPath);
    try {
      final key = await _encryptionService.getEncryptionKey();
      final escapedKey = _encryptionService.escapeKeyForPragma(key);
      db.execute("PRAGMA key = '$escapedKey';");

      db.execute('SELECT count(*) FROM sqlite_master;');
    } catch (e) {
      throw StateError('Failed to verify database encryption: $e');
    } finally {
      db.dispose();
    }
  }

  Future<String> createEncryptedBackup(String dbPath, String backupPath) async {
    final sourceFile = File(dbPath);
    if (!await sourceFile.exists()) {
      throw StateError('Source database does not exist: $dbPath');
    }

    final backupFile = File(backupPath);
    if (await backupFile.exists()) {
      await backupFile.delete();
    }

    final sourceDb = sqlite3.open(dbPath);
    try {
      final key = await _encryptionService.getEncryptionKey();
      final escapedKey = _encryptionService.escapeKeyForPragma(key);
      sourceDb.execute("PRAGMA key = '$escapedKey';");

      sourceDb.execute("VACUUM INTO '$backupPath';");
    } finally {
      sourceDb.dispose();
    }

    final backupDb = sqlite3.open(backupPath);
    try {
      final key = await _encryptionService.getEncryptionKey();
      final escapedKey = _encryptionService.escapeKeyForPragma(key);
      backupDb.execute("PRAGMA key = '$escapedKey';");
      backupDb.execute('SELECT count(*) FROM sqlite_master;');
    } catch (e) {
      await backupFile.delete();
      throw StateError('Failed to create encrypted backup: $e');
    } finally {
      backupDb.dispose();
    }

    return backupPath;
  }
}
