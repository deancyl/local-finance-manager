# SQLCipher Background Isolate Configuration

This document describes the configuration for SQLCipher database access from background isolates.

## Overview

SQLCipher database connections cannot be directly shared across isolates because:
1. Database connections are not thread-safe
2. Encryption keys must be available in each isolate
3. Connection pooling must be properly managed

## Solution: Isolate-Safe Database Access

### Database Factory Configuration

```dart
Future<QueryExecutor> createBackgroundIsolateExecutor({
  required String databasePath,
  required String encryptionKey,
}) async {
  final db = sqlite3.open(databasePath);
  db.execute('PRAGMA key = "$encryptionKey"');
  db.execute('PRAGMA busy_timeout = 5000');
  db.execute('PRAGMA journal_mode = WAL');
  return SqliteQueryExecutor(db, isReadWrite: true);
}
```

### Background Isolate Database Service

```dart
class IsolateDatabaseService {
  static Database? _database;
  
  static Future<Database> initialize({
    required String databasePath,
    required String encryptionKey,
  }) async {
    if (_database != null) return _database!;
    _database = Database.connect(
      await createBackgroundIsolateExecutor(
        databasePath: databasePath,
        encryptionKey: encryptionKey,
      ),
    );
    return _database!;
  }
}
```

## Encryption Key Management

```dart
final encryptionKeyProvider = Provider<String?>((ref) {
  final secureStorage = ref.watch(secureStorageProvider);
  return secureStorage.read(key: 'db_encryption_key');
});
```

## Performance Considerations

### WAL Mode

```sql
PRAGMA journal_mode = WAL;
PRAGMA synchronous = NORMAL;
```

## Troubleshooting

### Database is locked errors

1. Ensure WAL mode is enabled
2. Check busy_timeout is set
3. Verify connections are properly closed

---

*Document generated: 2026-05-27*