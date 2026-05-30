import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:path_provider/path_provider.dart';

import '../encryption/db_encryption_service.dart';

QueryExecutor connectToDatabase({
  DbEncryptionService? encryptionService,
  bool useEncryption = false, // Disabled by default until encryption is fully integrated
}) {
  return driftDatabase(
    name: 'finance',
    native: DriftNativeOptions(
      databaseDirectory: getApplicationSupportDirectory,
    ),
  );
}
