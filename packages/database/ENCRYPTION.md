# SQLCipher Database Encryption Implementation

## Overview

This implementation adds SQLCipher encryption to the finance application database, ensuring all financial data is encrypted at rest using industry-standard encryption.

## Architecture

### Components

1. **DbEncryptionService** (`lib/src/encryption/db_encryption_service.dart`)
   - Manages encryption key lifecycle
   - Derives keys from passwords using PBKDF2 (100,000 iterations)
   - Stores keys securely in platform-specific keychain (iOS Keychain/Android Keystore)
   - Provides key escaping for SQL PRAGMA statements

2. **EncryptionMigrationHelper** (`lib/src/encryption/encryption_migration_helper.dart`)
   - Migrates existing unencrypted databases to encrypted format
   - Creates encrypted backups
   - Verifies database encryption status
   - Uses `PRAGMA rekey` to encrypt existing databases

3. **Encrypted Database Connection** (`lib/src/connection/native.dart`)
   - Automatically initializes encryption on database open
   - Validates cipher availability before encryption
   - Verifies encryption key correctness
   - Supports disabling encryption for testing/migration

## Security Features

### Encryption Standards
- **Algorithm**: AES-256-GCM
- **Key Derivation**: PBKDF2 with SHA-256
- **Iterations**: 100,000 (OWASP recommended minimum)
- **Key Length**: 256 bits
- **Implementation**: SQLite3MultipleCiphers

### Key Management
- Keys stored in platform secure storage:
  - iOS: Keychain Services
  - Android: Android Keystore (EncryptedSharedPreferences)
  - macOS: Keychain Services
  - Windows: Credential Manager
  - Linux: libsecret
- Keys never stored in database or preferences
- Automatic key generation on first run

## Usage

### Basic Usage

```dart
import 'package:database/database.dart';
import 'package:encryption/encryption.dart';

void main() async {
  // Initialize keychain service
  KeychainFactory.initialize(MobileKeychainService());
  
  // Database will automatically use encryption
  final db = LocalFinanceDatabase();
  
  // Use database normally - all data is encrypted
  await db.accountsDao.insertAccount(...);
}
```

### Custom Encryption Key

```dart
final encryptionService = DbEncryptionService();
await encryptionService.initialize();

// Derive key from user password
final derivedKey = await encryptionService.deriveKeyFromPassword(
  'user_password',
  salt: 'user_specific_salt',
);

// Update encryption key
await encryptionService.updateEncryptionKey('new_password');
```

### Migrate Existing Database

```dart
final encryptionService = DbEncryptionService();
await encryptionService.initialize();

final migrationHelper = EncryptionMigrationHelper(encryptionService);

// Migrate unencrypted database to encrypted
final encryptedPath = await migrationHelper.migrateUnencryptedToEncrypted(
  unencryptedDbPath: '/path/to/old/database.db',
  deleteOriginal: true,
);

// Verify encryption
await migrationHelper.verifyEncryption(encryptedPath);
```

### Create Encrypted Backup

```dart
final migrationHelper = EncryptionMigrationHelper(encryptionService);

final backupPath = await migrationHelper.createEncryptedBackup(
  '/path/to/database.db',
  '/path/to/backup.db',
);
```

## Testing

### Run Tests

```bash
cd packages/database
flutter test test/encryption_test.dart
```

### Test Coverage

- Key generation and retrieval
- Password-based key derivation
- Encryption verification
- Migration from unencrypted to encrypted
- Encrypted database operations
- Key rotation (PRAGMA rekey)
- Backup creation

## Performance Considerations

### Expected Overhead
- **Encryption/Decryption**: ~10-15% overhead (AES-NI hardware acceleration)
- **Key Derivation**: ~100-200ms on mobile (PBKDF2 with 100k iterations)
- **Database Open**: Additional ~50-100ms for encryption setup

### Optimization Tips

1. **Cache encryption service instance** - avoid repeated keychain access
2. **Use background isolate** - database operations already run in background with `driftDatabase`
3. **Batch operations** - minimize number of transactions
4. **Hardware acceleration** - AES-NI is automatically used on supported devices

## Platform-Specific Notes

### iOS
- Keychain accessibility: `first_unlock_this_device`
- Face ID/Touch ID integration available
- No code signing changes required

### Android
- Uses Android Keystore with EncryptedSharedPreferences
- API level 23+ required for hardware-backed keystore
- Automatic key rotation available

### Desktop (macOS/Windows/Linux)
- Full encryption support
- Secure storage via platform-specific credential managers

## Security Best Practices

1. **Never log or display encryption keys**
2. **Use biometric authentication before accessing encrypted data**
3. **Implement secure key rotation mechanism**
4. **Backup encryption key separately from database**
5. **Test key recovery procedures**
6. **Monitor for encryption failures in production**

## Migration Guide

### From Unencrypted Database

```dart
// 1. Initialize encryption service
final encryptionService = DbEncryptionService();
await encryptionService.initialize();

// 2. Create migration helper
final migrationHelper = EncryptionMigrationHelper(encryptionService);

// 3. Check if migration needed
final dbPath = await getDatabasePath();
if (!await migrationHelper.isDatabaseEncrypted(dbPath)) {
  // 4. Migrate to encrypted
  await migrationHelper.migrateUnencryptedToEncrypted(
    unencryptedDbPath: dbPath,
    deleteOriginal: true,
  );
}

// 5. Verify encryption
await migrationHelper.verifyEncryption(dbPath);
```

### From SQLCipher 4.x

If migrating from an older SQLCipher implementation:

```dart
// In database setup callback
rawDb.execute("PRAGMA cipher = 'sqlcipher';");
rawDb.execute("PRAGMA legacy = 4;");
rawDb.execute("PRAGMA key = '$key';");
```

## Troubleshooting

### "library is not available" Error
- Ensure `sqlite3_flutter_libs` dependency is added
- On iOS: Add `-framework SQLCipher` to Other Linker Flags in Xcode
- On Android: Call `applyWorkaroundToOpenSqlCipherOnOldAndroidVersions()` for API < 23

### "Failed to open encrypted database" Error
- Verify encryption key is correct
- Check keychain access permissions
- Ensure database wasn't corrupted

### Performance Issues
- Verify AES-NI is enabled (check device capabilities)
- Reduce PBKDF2 iterations for development (NOT production)
- Use connection pooling for high-frequency operations

## API Reference

### DbEncryptionService

```dart
class DbEncryptionService {
  // Initialize service and generate key if needed
  Future<void> initialize();
  
  // Get current encryption key
  Future<String> getEncryptionKey();
  
  // Derive key from password
  Future<String> deriveKeyFromPassword(String password, {String? salt});
  
  // Update encryption key
  Future<void> updateEncryptionKey(String newPassword);
  
  // Verify encryption key
  Future<bool> verifyEncryptionKey(String testKey);
  
  // Delete encryption key
  Future<void> deleteEncryptionKey();
  
  // Escape key for SQL PRAGMA
  String escapeKeyForPragma(String key);
}
```

### EncryptionMigrationHelper

```dart
class EncryptionMigrationHelper {
  // Migrate unencrypted database to encrypted
  Future<String?> migrateUnencryptedToEncrypted({
    String? unencryptedDbPath,
    String? encryptedDbPath,
    bool deleteOriginal = true,
  });
  
  // Check if database is encrypted
  Future<bool> isDatabaseEncrypted(String dbPath);
  
  // Verify database encryption
  Future<void> verifyEncryption(String dbPath);
  
  // Create encrypted backup
  Future<String> createEncryptedBackup(String dbPath, String backupPath);
}
```

## Version Compatibility

- Drift: 2.22.1+
- sqlite3: 2.4.6+
- sqlite3_flutter_libs: 0.5.28+
- flutter_secure_storage: 9.2.2+

## License

MIT License
