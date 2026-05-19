import 'package:drift/drift.dart';

import 'connection/native.dart'
    if (dart.library.js_interop) 'connection/web.dart';

QueryExecutor getDatabaseConnection() => connectToDatabase();