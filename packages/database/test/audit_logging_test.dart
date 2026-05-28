import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:test/test.dart';
import 'package:database/database.dart';

void main() {
  late LocalFinanceDatabase db;

  setUp(() {
    // Create an in-memory database for testing
    db = LocalFinanceDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  group('Audit Logging Tests', () {
    test('Account creation logs audit entry', () async {
      // Create an account
      final accountId = await db.accountsDao.create(
        AccountsCompanion.insert(
          id: 'test-account-1',
          name: 'Test Account',
          accountType: 'ASSET',
          commodityId: 'CNY',
          createdAt: DateTime.now().millisecondsSinceEpoch,
          updatedAt: DateTime.now().millisecondsSinceEpoch,
        ),
      );

      // Verify the audit log was created
      final auditLogs = await db.auditLogsDao.getByEntity('account', accountId);
      
      expect(auditLogs.length, 1);
      expect(auditLogs.first.operation, 'CREATE');
      expect(auditLogs.first.entityType, 'account');
      expect(auditLogs.first.entityId, accountId);
      expect(auditLogs.first.afterData, isNotNull);
      expect(auditLogs.first.beforeData, isNull);
    });

    test('Account update logs audit entry with old and new values', () async {
      // Create an account
      final accountId = await db.accountsDao.create(
        AccountsCompanion.insert(
          id: 'test-account-2',
          name: 'Original Name',
          accountType: 'ASSET',
          commodityId: 'CNY',
          createdAt: DateTime.now().millisecondsSinceEpoch,
          updatedAt: DateTime.now().millisecondsSinceEpoch,
        ),
      );

      // Update the account
      await db.accountsDao.updateAccount(
        AccountsCompanion(
          id: Value(accountId),
          name: Value('Updated Name'),
          accountType: const Value('ASSET'),
          commodityId: const Value('CNY'),
        ),
      );

      // Verify the audit logs (CREATE + UPDATE)
      final auditLogs = await db.auditLogsDao.getByEntity('account', accountId);
      
      expect(auditLogs.length, 2);
      
      // Check the UPDATE log
      final updateLog = auditLogs.firstWhere((log) => log.operation == 'UPDATE');
      expect(updateLog.beforeData, isNotNull);
      expect(updateLog.afterData, isNotNull);
      expect(updateLog.changedFields, isNotNull);
    });

    test('Account deletion logs audit entry with old value', () async {
      // Create an account
      final accountId = await db.accountsDao.create(
        AccountsCompanion.insert(
          id: 'test-account-3',
          name: 'Account to Delete',
          accountType: 'ASSET',
          commodityId: 'CNY',
          createdAt: DateTime.now().millisecondsSinceEpoch,
          updatedAt: DateTime.now().millisecondsSinceEpoch,
        ),
      );

      // Delete the account
      await db.accountsDao.deleteAccount(accountId);

      // Verify the audit logs (CREATE + DELETE)
      final auditLogs = await db.auditLogsDao.getByEntity('account', accountId);
      
      expect(auditLogs.length, 2);
      
      // Check the DELETE log
      final deleteLog = auditLogs.firstWhere((log) => log.operation == 'DELETE');
      expect(deleteLog.beforeData, isNotNull);
      expect(deleteLog.afterData, isNull);
    });

    test('Category creation logs audit entry', () async {
      // Create a category
      final categoryId = await db.categoriesDao.create(
        CategoriesCompanion.insert(
          id: 'test-category-1',
          name: 'Test Category',
          isIncome: false,
          createdAt: DateTime.now().millisecondsSinceEpoch,
          updatedAt: DateTime.now().millisecondsSinceEpoch,
        ),
      );

      // Verify the audit log was created
      final auditLogs = await db.auditLogsDao.getByEntity('category', categoryId);
      
      expect(auditLogs.length, 1);
      expect(auditLogs.first.operation, 'CREATE');
      expect(auditLogs.first.entityType, 'category');
    });

    test('Budget creation logs audit entry', () async {
      // Create a budget
      final budgetId = await db.budgetsDao.create(
        BudgetsCompanion.insert(
          id: 'test-budget-1',
          name: 'Test Budget',
          amountNum: 100000,
          amountDenom: 100,
          periodType: 'monthly',
          startDate: DateTime.now().millisecondsSinceEpoch,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      );

      // Verify the audit log was created
      final auditLogs = await db.auditLogsDao.getByEntity('budget', budgetId);
      
      expect(auditLogs.length, 1);
      expect(auditLogs.first.operation, 'CREATE');
      expect(auditLogs.first.entityType, 'budget');
    });

    test('Tag creation logs audit entry', () async {
      // Create a tag
      final tagId = await db.tagsDao.createTag(
        name: 'Test Tag',
        color: '#FF5722',
      );

      // Verify the audit log was created
      final auditLogs = await db.auditLogsDao.getByEntity('tag', tagId);
      
      expect(auditLogs.length, 1);
      expect(auditLogs.first.operation, 'CREATE');
      expect(auditLogs.first.entityType, 'tag');
    });

    test('Tag soft delete logs audit entry', () async {
      // Create a tag
      final tagId = await db.tagsDao.createTag(
        name: 'Tag to Delete',
      );

      // Soft delete the tag
      await db.tagsDao.deleteTag(tagId);

      // Verify the audit logs (CREATE + DELETE)
      final auditLogs = await db.auditLogsDao.getByEntity('tag', tagId);
      
      expect(auditLogs.length, 2);
      
      // Check the DELETE log
      final deleteLog = auditLogs.firstWhere((log) => log.operation == 'DELETE');
      expect(deleteLog.description, contains('Soft delete'));
    });

    test('Transaction creation with splits logs audit entry', () async {
      final transactionId = 'test-txn-${DateTime.now().microsecondsSinceEpoch}';
      
      // Create a transaction with splits
      await db.transactionsDao.createWithSplits(
        TransactionsCompanion.insert(
          id: transactionId,
          currencyId: 'CNY',
          postDate: DateTime.now().millisecondsSinceEpoch,
          enterDate: DateTime.now().millisecondsSinceEpoch,
          createdAt: DateTime.now().millisecondsSinceEpoch,
          updatedAt: DateTime.now().millisecondsSinceEpoch,
        ),
        [
          SplitsCompanion.insert(
            id: '$transactionId-split-1',
            transactionId: transactionId,
            accountId: 'account-1',
            valueNum: 10000,
            valueDenom: const Value(100),
            quantityNum: 10000,
            quantityDenom: const Value(100),
            createdAt: DateTime.now().millisecondsSinceEpoch,
          ),
        ],
      );

      // Verify the audit log was created
      final auditLogs = await db.auditLogsDao.getByEntity('transaction', transactionId);
      
      expect(auditLogs.length, 1);
      expect(auditLogs.first.operation, 'CREATE');
      expect(auditLogs.first.entityType, 'transaction');
    });

    test('Transaction soft delete logs audit entry', () async {
      final transactionId = 'test-txn-soft-${DateTime.now().microsecondsSinceEpoch}';
      
      // Create a transaction with splits
      await db.transactionsDao.createWithSplits(
        TransactionsCompanion.insert(
          id: transactionId,
          currencyId: 'CNY',
          postDate: DateTime.now().millisecondsSinceEpoch,
          enterDate: DateTime.now().millisecondsSinceEpoch,
          createdAt: DateTime.now().millisecondsSinceEpoch,
          updatedAt: DateTime.now().millisecondsSinceEpoch,
        ),
        [],
      );

      // Soft delete the transaction
      await db.transactionsDao.softDelete(transactionId);

      // Verify the audit logs (CREATE + DELETE)
      final auditLogs = await db.auditLogsDao.getByEntity('transaction', transactionId);
      
      expect(auditLogs.length, 2);
      
      // Check the DELETE log
      final deleteLog = auditLogs.firstWhere((log) => log.operation == 'DELETE');
      expect(deleteLog.operation, 'DELETE');
    });

    test('Multiple operations on same entity create multiple audit logs', () async {
      final accountId = 'test-account-multi-${DateTime.now().microsecondsSinceEpoch}';
      
      // Create
      await db.accountsDao.create(
        AccountsCompanion.insert(
          id: accountId,
          name: 'Multi Operation Account',
          accountType: 'ASSET',
          commodityId: 'CNY',
          createdAt: DateTime.now().millisecondsSinceEpoch,
          updatedAt: DateTime.now().millisecondsSinceEpoch,
        ),
      );

      // Update
      await db.accountsDao.updateAccount(
        AccountsCompanion(
          id: Value(accountId),
          name: Value('Updated Name 1'),
          accountType: const Value('ASSET'),
          commodityId: const Value('CNY'),
        ),
      );

      // Update again
      await db.accountsDao.updateAccount(
        AccountsCompanion(
          id: Value(accountId),
          name: Value('Updated Name 2'),
          accountType: const Value('ASSET'),
          commodityId: const Value('CNY'),
        ),
      );

      // Verify all audit logs
      final auditLogs = await db.auditLogsDao.getByEntity('account', accountId);
      
      expect(auditLogs.length, 3);
      expect(auditLogs.where((log) => log.operation == 'CREATE').length, 1);
      expect(auditLogs.where((log) => log.operation == 'UPDATE').length, 2);
    });

    test('Audit log contains timestamp', () async {
      final accountId = 'test-account-time-${DateTime.now().microsecondsSinceEpoch}';
      final beforeCreate = DateTime.now();
      
      // Create an account
      await db.accountsDao.create(
        AccountsCompanion.insert(
          id: accountId,
          name: 'Timestamp Test Account',
          accountType: 'ASSET',
          commodityId: 'CNY',
          createdAt: DateTime.now().millisecondsSinceEpoch,
          updatedAt: DateTime.now().millisecondsSinceEpoch,
        ),
      );

      final afterCreate = DateTime.now();

      // Verify the audit log timestamp
      final auditLogs = await db.auditLogsDao.getByEntity('account', accountId);
      
      expect(auditLogs.length, 1);
      expect(auditLogs.first.changedAt, isNotNull);
      expect(
        auditLogs.first.changedAt.isAfter(beforeCreate.subtract(Duration(seconds: 1))),
        isTrue,
      );
      expect(
        auditLogs.first.changedAt.isBefore(afterCreate.add(Duration(seconds: 1))),
        isTrue,
      );
    });
  });
}
