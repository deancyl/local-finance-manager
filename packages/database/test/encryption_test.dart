import 'dart:io';

import 'package:database/database.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:sqlite3/sqlite3.dart';

class MockKeychainService extends Mock implements KeychainService {}

void main() {
  late MockKeychainService mockKeychain;
  late DbEncryptionService encryptionService;
  late Directory tempDir;

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('encryption_test_');
  });

  tearDownAll() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('DbEncryptionService', () {
    setUp(() {
      mockKeychain = MockKeychainService();
      encryptionService = DbEncryptionService(keychain: mockKeychain);
    });

    test('initialize generates key if not present', () async {
      when(() => mockKeychain.hasKey(any())).thenAnswer((_) async => false);
      when(() => mockKeychain.generateAndStoreKey(any(), any()))
          .thenAnswer((_) async => 'test_key_123');

      await encryptionService.initialize();

      verify(() => mockKeychain.hasKey('finance_db_encryption_key')).called(1);
      verify(() => mockKeychain.generateAndStoreKey(
            'finance_db_encryption_key',
            any(that: equals(64)),
          )).called(1);
    });

    test('initialize skips key generation if key exists', () async {
      when(() => mockKeychain.hasKey(any())).thenAnswer((_) async => true);

      await encryptionService.initialize();

      verify(() => mockKeychain.hasKey('finance_db_encryption_key')).called(1);
      verifyNever(() => mockKeychain.generateAndStoreKey(any(), any()));
    });

    test('getEncryptionKey returns stored key', () async {
      when(() => mockKeychain.retrieveKey(any()))
          .thenAnswer((_) async => 'stored_key_xyz');

      final key = await encryptionService.getEncryptionKey();

      expect(key, equals('stored_key_xyz'));
      verify(() => mockKeychain.retrieveKey('finance_db_encryption_key'))
          .called(1);
    });

    test('getEncryptionKey throws if key not found', () async {
      when(() => mockKeychain.retrieveKey(any()))
          .thenAnswer((_) async => null);

      expect(
        () => encryptionService.getEncryptionKey(),
        throwsA(isA<StateError>()),
      );
    });

    test('deriveKeyFromPassword generates deterministic key', () async {
      final key1 = await encryptionService.deriveKeyFromPassword('password123');
      final key2 = await encryptionService.deriveKeyFromPassword('password123');

      expect(key1, equals(key2));
      expect(key1.length, equals(64));
    });

    test('deriveKeyFromPassword with different passwords gives different keys', () async {
      final key1 = await encryptionService.deriveKeyFromPassword('password1');
      final key2 = await encryptionService.deriveKeyFromPassword('password2');

      expect(key1, isNot(equals(key2)));
    });

    test('deriveKeyFromPassword with custom salt', () async {
      final key1 =
          await encryptionService.deriveKeyFromPassword('password', salt: 'salt1');
      final key2 =
          await encryptionService.deriveKeyFromPassword('password', salt: 'salt2');

      expect(key1, isNot(equals(key2)));
    });

    test('escapeKeyForPragma escapes single quotes', () async {
      final key = "key'with'quotes";
      final escaped = encryptionService.escapeKeyForPragma(key);

      expect(escaped, equals("key''with''quotes"));
    });

    test('updateEncryptionKey stores derived key', () async {
      when(() => mockKeychain.storeKey(any(), any()))
          .thenAnswer((_) async => {});

      await encryptionService.updateEncryptionKey('newPassword');

      verify(() => mockKeychain.storeKey(
            'finance_db_encryption_key',
            any(that: hasLength(64)),
          )).called(1);
    });

    test('verifyEncryptionKey matches stored key', () async {
      when(() => mockKeychain.retrieveKey(any()))
          .thenAnswer((_) async => 'stored_key');

      final result = await encryptionService.verifyEncryptionKey('stored_key');
      expect(result, isTrue);
    });

    test('verifyEncryptionKey fails for mismatched key', () async {
      when(() => mockKeychain.retrieveKey(any()))
          .thenAnswer((_) async => 'stored_key');

      final result = await encryptionService.verifyEncryptionKey('wrong_key');
      expect(result, isFalse);
    });
  });

  group('EncryptionMigrationHelper', () {
    late MockKeychainService mockKeychain;
    late DbEncryptionService encryptionService;
    late EncryptionMigrationHelper migrationHelper;

    setUp(() {
      mockKeychain = MockKeychainService();
      encryptionService = DbEncryptionService(keychain: mockKeychain);
      migrationHelper = EncryptionMigrationHelper(encryptionService);

      when(() => mockKeychain.retrieveKey(any()))
          .thenAnswer((_) async => 'test_encryption_key_12345678901234567890');
    });

    test('isDatabaseEncrypted returns false for nonexistent database', () async {
      final result = await migrationHelper.isDatabaseEncrypted('/nonexistent.db');
      expect(result, isFalse);
    });

    test('isDatabaseEncrypted returns false for plaintext database', () async {
      final dbPath = '${tempDir.path}/plaintext_test.db';
      final db = sqlite3.open(dbPath);

      db.execute('CREATE TABLE test (id INTEGER PRIMARY KEY, value TEXT)');
      db.execute('INSERT INTO test VALUES (1, "plaintext_data")');
      db.dispose();

      final isEncrypted = await migrationHelper.isDatabaseEncrypted(dbPath);
      expect(isEncrypted, isFalse);

      final file = File(dbPath);
      if (await file.exists()) {
        await file.delete();
      }
    });

    test('createEncryptedBackup creates encrypted copy', () async {
      final dbPath = '${tempDir.path}/source.db';
      final backupPath = '${tempDir.path}/backup.db';

      final db = sqlite3.open(dbPath);
      db.execute('CREATE TABLE test (id INTEGER PRIMARY KEY, value TEXT)');
      db.execute('INSERT INTO test VALUES (1, "backup_test")');
      db.dispose();

      final result = await migrationHelper.createEncryptedBackup(dbPath, backupPath);

      expect(result, equals(backupPath));
      expect(await File(backupPath).exists(), isTrue);

      final backupFile = File(backupPath);
      if (await backupFile.exists()) {
        await backupFile.delete();
      }
      final sourceFile = File(dbPath);
      if (await sourceFile.exists()) {
        await sourceFile.delete();
      }
    });

    test('verifyEncryption succeeds for accessible encrypted database', () async {
      final dbPath = '${tempDir.path}/verify_test.db';
      final db = sqlite3.open(dbPath);

      final key = await encryptionService.getEncryptionKey();
      final escapedKey = encryptionService.escapeKeyForPragma(key);
      db.execute("PRAGMA key = '$escapedKey';");
      db.execute('CREATE TABLE test (id INTEGER PRIMARY KEY)');
      db.dispose();

      await migrationHelper.verifyEncryption(dbPath);

      final file = File(dbPath);
      if (await file.exists()) {
        await file.delete();
      }
    });

    test('verifyEncryption fails for inaccessible database', () async {
      final dbPath = '${tempDir.path}/wrong_key.db';
      final db = sqlite3.open(dbPath);

      db.execute("PRAGMA key = 'wrong_key';");
      db.execute('CREATE TABLE test (id INTEGER PRIMARY KEY)');
      db.dispose();

      expect(
        () => migrationHelper.verifyEncryption(dbPath),
        throwsA(isA<StateError>()),
      );

      final file = File(dbPath);
      if (await file.exists()) {
        await file.delete();
      }
    });
  });

  group('Encrypted Database Operations', () {
    test('database can be created with encryption', () async {
      final dbPath = '${tempDir.path}/encrypted_finance.db';
      final executor = NativeDatabase.createInBackground(
        File(dbPath),
        setup: (rawDb) {
          rawDb.execute("PRAGMA key = 'test_encryption_key';");
          rawDb.execute('SELECT count(*) FROM sqlite_master;');
        },
      );

      final db = LocalFinanceDatabase.forTesting(executor);

      await db.customSelect('SELECT 1').get();

      await db.close();

      final file = File(dbPath);
      expect(await file.exists(), isTrue);

      final bytes = await file.readAsBytes();
      expect(bytes.length, greaterThan(0));

      if (await file.exists()) {
        await file.delete();
      }
    });

    test('encrypted database cannot be opened without key', () async {
      final dbPath = '${tempDir.path}/protected.db';

      final db1 = sqlite3.open(dbPath);
      db1.execute("PRAGMA key = 'secret_key';");
      db1.execute('CREATE TABLE test (id INTEGER, data TEXT)');
      db1.execute('INSERT INTO test VALUES (1, "secret_data")');
      db1.dispose();

      final db2 = sqlite3.open(dbPath);
      expect(
        () => db2.execute('SELECT * FROM test'),
        throwsA(isA<SqliteException>()),
      );
      db2.dispose();

      final file = File(dbPath);
      if (await file.exists()) {
        await file.delete();
      }
    });

    test('encryption key must be provided before database access', () async {
      final dbPath = '${tempDir.path}/key_required.db';

      final db = sqlite3.open(dbPath);
      db.execute("PRAGMA key = 'my_secret_key';");
      db.execute('CREATE TABLE secure (id INTEGER PRIMARY KEY)');
      db.dispose();

      final dbWithKey = sqlite3.open(dbPath);
      dbWithKey.execute("PRAGMA key = 'my_secret_key';");
      final result = dbWithKey.execute('SELECT count(*) FROM sqlite_master;');
      expect(result, isNotEmpty);
      dbWithKey.dispose();

      final file = File(dbPath);
      if (await file.exists()) {
        await file.delete();
      }
    });

    test('PRAGMA rekey changes encryption password', () async {
      final dbPath = '${tempDir.path}/rekey_test.db';

      final db = sqlite3.open(dbPath);
      db.execute("PRAGMA key = 'old_key';");
      db.execute('CREATE TABLE test (id INTEGER)');
      db.execute('INSERT INTO test VALUES (42)');
      db.execute("PRAGMA rekey = 'new_key';");
      db.dispose();

      final dbWithOldKey = sqlite3.open(dbPath);
      dbWithOldKey.execute("PRAGMA key = 'old_key';");
      expect(
        () => dbWithOldKey.execute('SELECT * FROM test'),
        throwsA(isA<SqliteException>()),
      );
      dbWithOldKey.dispose();

      final dbWithNewKey = sqlite3.open(dbPath);
      dbWithNewKey.execute("PRAGMA key = 'new_key';");
      final result = dbWithNewKey.execute('SELECT * FROM test');
      expect(result, isNotEmpty);
      dbWithNewKey.dispose();

      final file = File(dbPath);
      if (await file.exists()) {
        await file.delete();
      }
    });
  });
});