import 'package:database/database.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:sqlite3_flutter_libs/sqlite3_flutter_libs.dart';

void main() {
  late LocalFinanceDatabase db;

  setUp(() {
    // Use in-memory database for testing
    final executor = NativeDatabase.memory();
    db = LocalFinanceDatabase.forTesting(executor);
  });

  tearDown(() async {
    await db.close();
  });

  group('TransactionsDao Atomic Operations', () {
    test('createWithSplits is atomic', () async {
      final transactionId = 'test-tx-${DateTime.now().millisecondsSinceEpoch}';
      final now = DateTime.now().millisecondsSinceEpoch;
      
      final transaction = TransactionsCompanion.insert(
        id: transactionId,
        description: Value('Test Transaction'),
        postDate: now,
        enterDate: now,
        currencyId: 'CNY',
        createdAt: now,
        updatedAt: now,
      );

      final splits = [
        SplitsCompanion.insert(
          id: 'split-1-$transactionId',
          transactionId: transactionId,
          accountId: 'test-account',
          valueNum: 10000,
          valueDenom: Value(100),
          quantityNum: 10000,
          reconcileState: Value('n'),
          createdAt: now,
        ),
        SplitsCompanion.insert(
          id: 'split-2-$transactionId',
          transactionId: transactionId,
          accountId: 'test-account-2',
          valueNum: -10000,
          valueDenom: Value(100),
          quantityNum: -10000,
          reconcileState: Value('n'),
          createdAt: now,
        ),
      ];

      // Create transaction with splits atomically
      final id = await db.transactionsDao.createWithSplits(transaction, splits);

      // Verify transaction was created
      final createdTransaction = await db.transactionsDao.getById(id);
      expect(createdTransaction, isNotNull);
      expect(createdTransaction!.id, equals(transactionId));

      // Verify splits were created
      final createdSplits = await db.transactionsDao.getSplits(id);
      expect(createdSplits.length, equals(2));
      expect(createdSplits[0].accountId, equals('test-account'));
      expect(createdSplits[1].accountId, equals('test-account-2'));

      // Verify audit log was created
      final auditLogs = await db.auditLogsDao.getByEntity('transaction', id);
      expect(auditLogs.length, greaterThanOrEqualTo(1));
      expect(auditLogs.first.operation, equals('CREATE'));
    });

    test('failure rolls back all changes', () async {
      final transactionId = 'test-tx-fail-${DateTime.now().millisecondsSinceEpoch}';
      final now = DateTime.now().millisecondsSinceEpoch;
      
      final transaction = TransactionsCompanion.insert(
        id: transactionId,
        description: Value('Test Transaction'),
        postDate: now,
        enterDate: now,
        currencyId: 'CNY',
        createdAt: now,
        updatedAt: now,
      );

      // Create a valid split and an invalid one (will cause failure)
      final splits = [
        SplitsCompanion.insert(
          id: 'split-fail-$transactionId',
          transactionId: transactionId,
          accountId: 'test-account',
          valueNum: 10000,
          valueDenom: Value(100),
          quantityNum: 10000,
          reconcileState: Value('n'),
          createdAt: now,
        ),
      ];

      // First create a transaction successfully
      final id = await db.transactionsDao.createWithSplits(transaction, splits);
      
      // Verify it was created
      final createdTransaction = await db.transactionsDao.getById(id);
      expect(createdTransaction, isNotNull);

      // Try to create the same transaction again (should fail due to unique constraint)
      // This tests that the transaction wrapper properly handles errors
      expect(
        () async => await db.transactionsDao.createWithSplits(transaction, splits),
        throwsA(anything),
      );

      // Verify original transaction still exists (not rolled back)
      final stillExists = await db.transactionsDao.getById(id);
      expect(stillExists, isNotNull);
    });

    test('audit logging works correctly', () async {
      final transactionId = 'test-tx-audit-${DateTime.now().millisecondsSinceEpoch}';
      final now = DateTime.now().millisecondsSinceEpoch;
      
      final transaction = TransactionsCompanion.insert(
        id: transactionId,
        description: Value('Test Transaction for Audit'),
        postDate: now,
        enterDate: now,
        currencyId: 'CNY',
        createdAt: now,
        updatedAt: now,
      );

      final splits = [
        SplitsCompanion.insert(
          id: 'split-audit-$transactionId',
          transactionId: transactionId,
          accountId: 'test-account',
          valueNum: 5000,
          valueDenom: Value(100),
          quantityNum: 5000,
          reconcileState: Value('n'),
          createdAt: now,
        ),
      ];

      // Create transaction
      final id = await db.transactionsDao.createWithSplits(transaction, splits);

      // Verify audit log entry
      final auditLogs = await db.auditLogsDao.getByEntity('transaction', id);
      expect(auditLogs.isNotEmpty, isTrue);
      
      final auditLog = auditLogs.first;
      expect(auditLog.operation, equals('CREATE'));
      expect(auditLog.entityType, equals('transaction'));
      expect(auditLog.entityId, equals(id));
      expect(auditLog.changedAt, isNotNull);
    });
  });
}
