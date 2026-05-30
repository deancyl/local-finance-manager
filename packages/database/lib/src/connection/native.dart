import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqlite3/sqlite3.dart';

import '../encryption/db_encryption_service.dart';

QueryExecutor connectToDatabase({
  DbEncryptionService? encryptionService,
  bool useEncryption = true,
}) {
  return driftDatabase(
    name: 'finance',
    native: DriftNativeOptions(
      databaseDirectory: getApplicationSupportDirectory,
      setup: (rawDb) async {
        if (useEncryption) {
          final service = encryptionService ?? DbEncryptionService();
          await service.initialize();

          final hasCipher = _debugCheckHasCipher(rawDb);
          if (!hasCipher) {
            throw UnsupportedError(
              'This database needs to run with sqlite3multipleciphers, but that '
              'library is not available!',
            );
          }

          final key = await service.getEncryptionKey();
          final escapedKey = service.escapeKeyForPragma(key);
          rawDb.execute("PRAGMA key = '$escapedKey';");

          try {
            rawDb.execute('SELECT count(*) FROM sqlite_master;');
          } catch (e) {
            throw StateError(
              'Failed to open encrypted database. The encryption key may be incorrect. Error: $e',
            );
          }
        }
      },
    ),
  );
}

bool _debugCheckHasCipher(CommonDatabase database) {
  try {
    final result = database.select('PRAGMA cipher;');
    return result.isNotEmpty;
  } catch (e) {
    return false;
  }
}