import 'package:drift/drift.dart';

import 'native.dart'
    if (dart.library.js_interop) 'web.dart';
import '../encryption/db_encryption_service.dart';

QueryExecutor getDatabaseConnection({
  DbEncryptionService? encryptionService,
  bool useEncryption = true,
}) =>
    connectToDatabase(
      encryptionService: encryptionService,
      useEncryption: useEncryption,
    );