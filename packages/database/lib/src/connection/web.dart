import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:flutter/foundation.dart';

import '../encryption/db_encryption_service.dart';

QueryExecutor connectToDatabase({
  DbEncryptionService? encryptionService,
  bool useEncryption = false, // Web platform doesn't support native encryption
}) {
  return driftDatabase(
    name: 'finance',
    web: DriftWebOptions(
      sqlite3Wasm: Uri.parse('sqlite3.wasm'),
      driftWorker: Uri.parse('drift_worker.dart.js'),
      onResult: (result) {
        if (result.missingFeatures.isNotEmpty) {
          debugPrint(
            'Using ${result.chosenImplementation} due to unsupported '
            'browser features: ${result.missingFeatures}',
          );
        }
      },
    ),
  );
}