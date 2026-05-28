import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:test/test.dart';
import 'package:database/database.dart';

/// Tests for database transaction atomicity.
/// 
/// Verifies that operations using transaction() properly rollback
/// on failure, ensuring data consistency.
void main() {
  late LocalFinanceDatabase db;

  setUp(() {
    // Use in-memory database for testing
    db = LocalFinanceDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  group('TransactionsDao - Transaction Atomicity', () {
    test('createWithSplits should rollback on split insertion failure', () async {
      // Setup: Create required account and currency
      final accountId = 'test-account-1';
      final currencyId = 'USD';
      
      await db.into(db.accounts).insert(
        AccountsCompanion.insert(
          id: accountId,
          name: 'Test Account',
          accountType: 'ASSET',
          parentId: '',
          placeholder: false,
          createdAt: DateTime.now().millisecondsSinceEpoch,
          updatedAt: DateTime.now().millisecondsSinceEpoch,
        ),
      );
      
      await db.into(db.commodities).insert(
        CommoditiesCompanion.insert(
          id: currencyId,
          fullname: 'US Dollar',
          namespace: 'CURRENCY',
          createdAt: DateTime.now().millisecondsSinceEpoch,
          updatedAt: DateTime.now().millisecondsSinceEpoch,
        ),
      );

      // Create a valid transaction
      final transactionId = 'test-txn-1';
      final transaction = TransactionsCompanion.insert(
        id: transactionId,
        postDate: DateTime.now().millisecondsSinceEpoch,
        enterDate: DateTime.now().millisecondsSinceEpoch,
        currencyId: currencyId,
        createdAt: DateTime.now().millisecondsSinceEpoch,
        updatedAt: DateTime.now().millisecondsSinceEpoch,
      );

      // Create splits - one valid, one with invalid account reference
      final validSplit = SplitsCompanion.insert(
        id: 'split-1',
        transactionId: transactionId,
        accountId: accountId,
        valueNum: 1000,
        quantityNum: 1000,
        createdAt: DateTime.now().millisecondsSinceEpoch,
      );

      // Attempt to create transaction with splits
      // This should succeed as all references are valid
      await db.transactionsDao.createWithSplits(transaction, [validSplit]);

      // Verify transaction was created
      final createdTransaction = await db.transactionsDao.getById(transactionId);
      expect(createdTransaction, isNotNull);
      expect(createdTransaction!.id, equals(transactionId));

      // Verify splits were created
      final splits = await db.transactionsDao.getSplits(transactionId);
      expect(splits.length, equals(1));
      expect(splits[0].accountId, equals(accountId));
    });

    test('createWithSplits should rollback transaction if split fails', () async {
      // Setup: Create currency but NO account (to force failure)
      final currencyId = 'USD';
      
      await db.into(db.commodities).insert(
        CommoditiesCompanion.insert(
          id: currencyId,
          fullname: 'US Dollar',
          namespace: 'CURRENCY',
          createdAt: DateTime.now().millisecondsSinceEpoch,
          updatedAt: DateTime.now().millisecondsSinceEpoch,
        ),
      );

      final transactionId = 'test-txn-fail';
      final transaction = TransactionsCompanion.insert(
        id: transactionId,
        postDate: DateTime.now().millisecondsSinceEpoch,
        enterDate: DateTime.now().millisecondsSinceEpoch,
        currencyId: currencyId,
        createdAt: DateTime.now().millisecondsSinceEpoch,
        updatedAt: DateTime.now().millisecondsSinceEpoch,
      );

      // Create split with non-existent account (should fail foreign key constraint)
      final invalidSplit = SplitsCompanion.insert(
        id: 'split-invalid',
        transactionId: transactionId,
        accountId: 'non-existent-account', // This will fail
        valueNum: 1000,
        quantityNum: 1000,
        createdAt: DateTime.now().millisecondsSinceEpoch,
      );

      // Attempt to create - should fail and rollback
      expect(
        () => db.transactionsDao.createWithSplits(transaction, [invalidSplit]),
        throwsA(anything),
      );

      // Verify transaction was NOT created (rollback occurred)
      final createdTransaction = await db.transactionsDao.getById(transactionId);
      expect(createdTransaction, isNull);
    });

    test('updateWithSplits should rollback on failure', () async {
      // Setup: Create account, currency, and initial transaction
      final accountId = 'test-account-2';
      final currencyId = 'USD';
      final transactionId = 'test-txn-update';
      
      await db.into(db.accounts).insert(
        AccountsCompanion.insert(
          id: accountId,
          name: 'Test Account',
          accountType: 'ASSET',
          parentId: '',
          placeholder: false,
          createdAt: DateTime.now().millisecondsSinceEpoch,
          updatedAt: DateTime.now().millisecondsSinceEpoch,
        ),
      );
      
      await db.into(db.commodities).insert(
        CommoditiesCompanion.insert(
          id: currencyId,
          fullname: 'US Dollar',
          namespace: 'CURRENCY',
          createdAt: DateTime.now().millisecondsSinceEpoch,
          updatedAt: DateTime.now().millisecondsSinceEpoch,
        ),
      );

      // Create initial transaction
      await db.transactionsDao.createWithSplits(
        TransactionsCompanion.insert(
          id: transactionId,
          postDate: DateTime.now().millisecondsSinceEpoch,
          enterDate: DateTime.now().millisecondsSinceEpoch,
          currencyId: currencyId,
          createdAt: DateTime.now().millisecondsSinceEpoch,
          updatedAt: DateTime.now().millisecondsSinceEpoch,
        ),
        [
          SplitsCompanion.insert(
            id: 'split-initial',
            transactionId: transactionId,
            accountId: accountId,
            valueNum: 500,
            quantityNum: 500,
            createdAt: DateTime.now().millisecondsSinceEpoch,
          ),
        ],
      );

      // Verify initial state
      var splits = await db.transactionsDao.getSplits(transactionId);
      expect(splits.length, equals(1));
      expect(splits[0].valueNum, equals(500));

      // Attempt to update with invalid split (non-existent account)
      expect(
        () => db.transactionsDao.updateWithSplits(
          TransactionsCompanion(
            id: Value(transactionId),
            postDate: Value(DateTime.now().millisecondsSinceEpoch),
            enterDate: Value(DateTime.now().millisecondsSinceEpoch),
            currencyId: Value(currencyId),
            updatedAt: Value(DateTime.now().millisecondsSinceEpoch),
          ),
          [
            SplitsCompanion.insert(
              id: 'split-invalid-update',
              transactionId: transactionId,
              accountId: 'non-existent-account',
              valueNum: 1000,
              quantityNum: 1000,
              createdAt: DateTime.now().millisecondsSinceEpoch,
            ),
          ],
        ),
        throwsA(anything),
      );

      // Verify original data is preserved (rollback occurred)
      splits = await db.transactionsDao.getSplits(transactionId);
      expect(splits.length, equals(1));
      expect(splits[0].valueNum, equals(500));
    });

    test('updateWithSplits should successfully update with valid splits', () async {
      // Setup
      final accountId = 'test-account-3';
      final currencyId = 'USD';
      final transactionId = 'test-txn-success';
      
      await db.into(db.accounts).insert(
        AccountsCompanion.insert(
          id: accountId,
          name: 'Test Account',
          accountType: 'ASSET',
          parentId: '',
          placeholder: false,
          createdAt: DateTime.now().millisecondsSinceEpoch,
          updatedAt: DateTime.now().millisecondsSinceEpoch,
        ),
      );
      
      await db.into(db.commodities).insert(
        CommoditiesCompanion.insert(
          id: currencyId,
          fullname: 'US Dollar',
          namespace: 'CURRENCY',
          createdAt: DateTime.now().millisecondsSinceEpoch,
          updatedAt: DateTime.now().millisecondsSinceEpoch,
        ),
      );

      // Create initial transaction
      await db.transactionsDao.createWithSplits(
        TransactionsCompanion.insert(
          id: transactionId,
          postDate: DateTime.now().millisecondsSinceEpoch,
          enterDate: DateTime.now().millisecondsSinceEpoch,
          currencyId: currencyId,
          createdAt: DateTime.now().millisecondsSinceEpoch,
          updatedAt: DateTime.now().millisecondsSinceEpoch,
        ),
        [
          SplitsCompanion.insert(
            id: 'split-old',
            transactionId: transactionId,
            accountId: accountId,
            valueNum: 500,
            quantityNum: 500,
            createdAt: DateTime.now().millisecondsSinceEpoch,
          ),
        ],
      );

      // Update with new splits
      await db.transactionsDao.updateWithSplits(
        TransactionsCompanion(
          id: Value(transactionId),
          postDate: Value(DateTime.now().millisecondsSinceEpoch),
          enterDate: Value(DateTime.now().millisecondsSinceEpoch),
          currencyId: Value(currencyId),
          updatedAt: Value(DateTime.now().millisecondsSinceEpoch),
        ),
        [
          SplitsCompanion.insert(
            id: 'split-new-1',
            transactionId: transactionId,
            accountId: accountId,
            valueNum: 1000,
            quantityNum: 1000,
            createdAt: DateTime.now().millisecondsSinceEpoch,
          ),
          SplitsCompanion.insert(
            id: 'split-new-2',
            transactionId: transactionId,
            accountId: accountId,
            valueNum: 2000,
            quantityNum: 2000,
            createdAt: DateTime.now().millisecondsSinceEpoch,
          ),
        ],
      );

      // Verify update succeeded
      final splits = await db.transactionsDao.getSplits(transactionId);
      expect(splits.length, equals(2));
      expect(splits.any((s) => s.valueNum == 1000), isTrue);
      expect(splits.any((s) => s.valueNum == 2000), isTrue);
    });
  });

  group('JournalEntriesDao - Transaction Atomicity', () {
    test('reverseJournalEntry should rollback on failure', () async {
      // Setup: Create account and original journal entry
      final accountId = 'journal-account-1';
      final originalEntryId = 'je-original';
      final reversalId = 'je-reversal';
      
      await db.into(db.accounts).insert(
        AccountsCompanion.insert(
          id: accountId,
          name: 'Journal Account',
          accountType: 'ASSET',
          parentId: '',
          placeholder: false,
          createdAt: DateTime.now().millisecondsSinceEpoch,
          updatedAt: DateTime.now().millisecondsSinceEpoch,
        ),
      );

      // Create original journal entry
      await db.createJournalEntry(
        id: originalEntryId,
        date: DateTime.now(),
        description: 'Original Entry',
      );

      // Add lines to original entry
      await db.createJournalEntryLine(
        id: 'line-1',
        entryId: originalEntryId,
        accountId: accountId,
        debitAmount: 1000,
        creditAmount: 0,
        lineOrder: 1,
      );

      await db.createJournalEntryLine(
        id: 'line-2',
        entryId: originalEntryId,
        accountId: accountId,
        debitAmount: 0,
        creditAmount: 1000,
        lineOrder: 2,
      );

      // Verify original entry exists
      var original = await db.getJournalEntryWithLines(originalEntryId);
      expect(original, isNotNull);
      expect(original!.lines.length, equals(2));
      expect(original.entry.isReversed, isFalse);

      // Attempt to reverse with non-existent original ID
      expect(
        () => db.reverseJournalEntry(
          originalId: 'non-existent-entry',
          reversalId: reversalId,
          reversalDate: DateTime.now(),
        ),
        throwsA(anything),
      );

      // Verify no reversal was created
      final reversal = await db.getJournalEntry(reversalId);
      expect(reversal, isNull);

      // Verify original entry is unchanged
      original = await db.getJournalEntryWithLines(originalEntryId);
      expect(original!.entry.isReversed, isFalse);
    });

    test('reverseJournalEntry should successfully create reversal', () async {
      // Setup
      final accountId = 'journal-account-2';
      final originalEntryId = 'je-original-2';
      final reversalId = 'je-reversal-2';
      
      await db.into(db.accounts).insert(
        AccountsCompanion.insert(
          id: accountId,
          name: 'Journal Account 2',
          accountType: 'ASSET',
          parentId: '',
          placeholder: false,
          createdAt: DateTime.now().millisecondsSinceEpoch,
          updatedAt: DateTime.now().millisecondsSinceEpoch,
        ),
      );

      // Create original journal entry
      await db.createJournalEntry(
        id: originalEntryId,
        date: DateTime.now(),
        description: 'Original Entry for Reversal',
      );

      // Add lines
      await db.createJournalEntryLine(
        id: 'line-orig-1',
        entryId: originalEntryId,
        accountId: accountId,
        debitAmount: 5000,
        creditAmount: 0,
        lineOrder: 1,
      );

      await db.createJournalEntryLine(
        id: 'line-orig-2',
        entryId: originalEntryId,
        accountId: accountId,
        debitAmount: 0,
        creditAmount: 5000,
        lineOrder: 2,
      );

      // Reverse the entry
      await db.reverseJournalEntry(
        originalId: originalEntryId,
        reversalId: reversalId,
        reversalDate: DateTime.now(),
        reason: 'Test reversal',
      );

      // Verify reversal was created
      final reversal = await db.getJournalEntryWithLines(reversalId);
      expect(reversal, isNotNull);
      expect(reversal!.lines.length, equals(2));
      
      // Verify debit/credit are swapped
      final reversalLine1 = reversal.lines.firstWhere((l) => l.lineOrder == 1);
      expect(reversalLine1.debitAmount, equals(0)); // Original was 5000 debit
      expect(reversalLine1.creditAmount, equals(5000));

      final reversalLine2 = reversal.lines.firstWhere((l) => l.lineOrder == 2);
      expect(reversalLine2.debitAmount, equals(5000)); // Original was 5000 credit
      expect(reversalLine2.creditAmount, equals(0));

      // Verify original is marked as reversed
      final original = await db.getJournalEntryWithLines(originalEntryId);
      expect(original!.entry.isReversed, isTrue);
    });

    test('reverseJournalEntry should rollback if line creation fails', () async {
      // Setup: Create entry but don't create account for lines
      final originalEntryId = 'je-original-3';
      final reversalId = 'je-reversal-3';
      
      // Create original journal entry
      await db.createJournalEntry(
        id: originalEntryId,
        date: DateTime.now(),
        description: 'Original Entry',
      );

      // Add lines with non-existent account (will fail on reversal)
      await db.createJournalEntryLine(
        id: 'line-fail-1',
        entryId: originalEntryId,
        accountId: 'non-existent-account',
        debitAmount: 1000,
        creditAmount: 0,
        lineOrder: 1,
      );

      // Attempt to reverse - should fail and rollback
      expect(
        () => db.reverseJournalEntry(
          originalId: originalEntryId,
          reversalId: reversalId,
          reversalDate: DateTime.now(),
        ),
        throwsA(anything),
      );

      // Verify no reversal was created
      final reversal = await db.getJournalEntry(reversalId);
      expect(reversal, isNull);

      // Verify original entry is NOT marked as reversed (rollback occurred)
      final original = await db.getJournalEntry(originalEntryId);
      expect(original!.isReversed, isFalse);
    });
  });

  group('Transaction Isolation', () {
    test('Multiple operations in transaction should be atomic', () async {
      // Setup
      final accountId = 'isolation-account';
      final currencyId = 'EUR';
      final transactionId = 'isolation-txn';
      
      await db.into(db.accounts).insert(
        AccountsCompanion.insert(
          id: accountId,
          name: 'Isolation Test Account',
          accountType: 'ASSET',
          parentId: '',
          placeholder: false,
          createdAt: DateTime.now().millisecondsSinceEpoch,
          updatedAt: DateTime.now().millisecondsSinceEpoch,
        ),
      );
      
      await db.into(db.commodities).insert(
        CommoditiesCompanion.insert(
          id: currencyId,
          fullname: 'Euro',
          namespace: 'CURRENCY',
          createdAt: DateTime.now().millisecondsSinceEpoch,
          updatedAt: DateTime.now().millisecondsSinceEpoch,
        ),
      );

      // Create transaction with multiple splits
      await db.transactionsDao.createWithSplits(
        TransactionsCompanion.insert(
          id: transactionId,
          postDate: DateTime.now().millisecondsSinceEpoch,
          enterDate: DateTime.now().millisecondsSinceEpoch,
          currencyId: currencyId,
          createdAt: DateTime.now().millisecondsSinceEpoch,
          updatedAt: DateTime.now().millisecondsSinceEpoch,
        ),
        [
          SplitsCompanion.insert(
            id: 'split-iso-1',
            transactionId: transactionId,
            accountId: accountId,
            valueNum: 100,
            quantityNum: 100,
            createdAt: DateTime.now().millisecondsSinceEpoch,
          ),
          SplitsCompanion.insert(
            id: 'split-iso-2',
            transactionId: transactionId,
            accountId: accountId,
            valueNum: 200,
            quantityNum: 200,
            createdAt: DateTime.now().millisecondsSinceEpoch,
          ),
          SplitsCompanion.insert(
            id: 'split-iso-3',
            transactionId: transactionId,
            accountId: accountId,
            valueNum: 300,
            quantityNum: 300,
            createdAt: DateTime.now().millisecondsSinceEpoch,
          ),
        ],
      );

      // Verify all splits were created atomically
      final splits = await db.transactionsDao.getSplits(transactionId);
      expect(splits.length, equals(3));
      
      // Verify total
      final total = splits.fold<int>(0, (sum, s) => sum + s.valueNum);
      expect(total, equals(600));
    });
  });
}
