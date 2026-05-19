import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:sqlite3_flutter_libs/sqlite3_flutter_libs.dart';

QueryExecutor connectToDatabase() {
  return LazyDatabase(() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbFolder.path, 'finance.db'));

    if (Platform.isAndroid) {
      await applyWorkaroundToOpenSqlCipherOnOldAndroidVersions();
    }

    return NativeDatabase.createInBackground(file);
  });
}

Future<void> applyWorkaroundToOpenSqlCipherOnOldAndroidVersions() async {
  if (Platform.isAndroid) {
    await ensureSqlCipherIsLoadedOnAndroid();
  }
}

Future<void> ensureSqlCipherIsLoadedOnAndroid() async {
  final db = sqlite3.openInMemory();
  db.dispose();
}