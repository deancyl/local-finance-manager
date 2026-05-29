import 'package:database/database.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

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

  group('JournalEntriesDao CRUD Operations', () {
    test('creates a journal entry', () async {
      // Create test accounts first
      await _createTestAccount(db, 'cash-account', 'Cash');
      await _createTestAccount(db, 'revenue-account', 'Revenue');

      final lines = [
        JournalEntryLineInput.debit(
          accountId: 'cash-account',
          amount: 10000,
          memo: 'Cash received',
        ),
        JournalEntryLineInput.credit(
          accountId: 'revenue-account',
          amount: 10000,
          memo: 'Revenue earned',
        ),
      ];

      final id = await db.journalEntriesDao.createJournalEntry(
        description: 'Test Journal Entry',
        postDate: DateTime(2024, 1, 15),
        reference: 'REF-001',
        lines: lines,
      );

      // Verify entry was created
      final entry = await db.journalEntriesDao.getById(id);
      expect(entry, isNotNull);
      expect(entry!.description, equals('Test Journal Entry'));
      expect(entry.reference, equals('REF-001'));
      expect(entry.isPosted, isFalse);
    });

    test('adds journal entry lines', () async {
      await _createTestAccount(db, 'account-1', 'Account 1');
      await _createTestAccount(db, 'account-2', 'Account 2');
      await _createTestAccount(db, 'account-3', 'Account 3');

      final lines = [
        JournalEntryLineInput.debit(accountId: 'account-1', amount: 5000),
        JournalEntryLineInput.debit(accountId: 'account-2', amount: 5000),
        JournalEntryLineInput.credit(accountId: 'account-3', amount: 10000),
      ];

      final id = await db.journalEntriesDao.createJournalEntry(
        description: 'Multi-line Entry',
        postDate: DateTime.now(),
        lines: lines,
      );

      final entryWithLines = await db.journalEntriesDao.getJournalEntryWithLines(id);
      expect(entryWithLines, isNotNull);
      expect(entryWithLines!.lines.length, equals(3));
    });

    test('validates balanced entries', () async {
      await _createTestAccount(db, 'cash', 'Cash');
      await _createTestAccount(db, 'expense', 'Expense');

      // Balanced entry should succeed
      final balancedLines = [
        JournalEntryLineInput.debit(accountId: 'expense', amount: 1000),
        JournalEntryLineInput.credit(accountId: 'cash', amount: 1000),
      ];

      final id = await db.journalEntriesDao.createJournalEntry(
        description: 'Balanced Entry',
        postDate: DateTime.now(),
        lines: balancedLines,
      );

      final entry = await db.journalEntriesDao.getById(id);
      expect(entry, isNotNull);
    });

    test('rejects unbalanced entries', () async {
      await _createTestAccount(db, 'cash', 'Cash');
      await _createTestAccount(db, 'expense', 'Expense');

      // Unbalanced entry should fail
      final unbalancedLines = [
        JournalEntryLineInput.debit(accountId: 'expense', amount: 1000),
        JournalEntryLineInput.credit(accountId: 'cash', amount: 500),
      ];

      expect(
        () async => await db.journalEntriesDao.createJournalEntry(
          description: 'Unbalanced Entry',
          postDate: DateTime.now(),
          lines: unbalancedLines,
        ),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('rejects entry with no lines', () async {
      expect(
        () async => await db.journalEntriesDao.createJournalEntry(
          description: 'Empty Entry',
          postDate: DateTime.now(),
          lines: [],
        ),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('gets entry by ID', () async {
      await _createTestAccount(db, 'account-1', 'Account 1');
      await _createTestAccount(db, 'account-2', 'Account 2');

      final lines = [
        JournalEntryLineInput.debit(accountId: 'account-1', amount: 100),
        JournalEntryLineInput.credit(accountId: 'account-2', amount: 100),
      ];

      final id = await db.journalEntriesDao.createJournalEntry(
        description: 'Test Entry',
        postDate: DateTime.now(),
        lines: lines,
      );

      final entry = await db.journalEntriesDao.getById(id);
      expect(entry, isNotNull);
      expect(entry!.id, equals(id));
    });

    test('gets entry with lines', () async {
      await _createTestAccount(db, 'account-1', 'Account 1');
      await _createTestAccount(db, 'account-2', 'Account 2');

      final lines = [
        JournalEntryLineInput.debit(accountId: 'account-1', amount: 100),
        JournalEntryLineInput.credit(accountId: 'account-2', amount: 100),
      ];

      final id = await db.journalEntriesDao.createJournalEntry(
        description: 'Test Entry',
        postDate: DateTime.now(),
        lines: lines,
      );

      final entryWithLines = await db.journalEntriesDao.getJournalEntryWithLines(id);
      expect(entryWithLines, isNotNull);
      expect(entryWithLines!.entry.id, equals(id));
      expect(entryWithLines.lines.length, equals(2));
    });

    test('updates entry metadata', () async {
      await _createTestAccount(db, 'account-1', 'Account 1');
      await _createTestAccount(db, 'account-2', 'Account 2');

      final lines = [
        JournalEntryLineInput.debit(accountId: 'account-1', amount: 100),
        JournalEntryLineInput.credit(accountId: 'account-2', amount: 100),
      ];

      final id = await db.journalEntriesDao.createJournalEntry(
        description: 'Original Description',
        postDate: DateTime(2024, 1, 1),
        reference: 'REF-001',
        lines: lines,
      );

      await db.journalEntriesDao.updateEntry(
        id,
        description: 'Updated Description',
        reference: 'REF-002',
        postDate: DateTime(2024, 1, 31),
      );

      final updated = await db.journalEntriesDao.getById(id);
      expect(updated!.description, equals('Updated Description'));
      expect(updated.reference, equals('REF-002'));
      expect(
        DateTime.fromMillisecondsSinceEpoch(updated.postDate),
        equals(DateTime(2024, 1, 31)),
      );
    });

    test('updates entry lines', () async {
      await _createTestAccount(db, 'account-1', 'Account 1');
      await _createTestAccount(db, 'account-2', 'Account 2');
      await _createTestAccount(db, 'account-3', 'Account 3');

      final originalLines = [
        JournalEntryLineInput.debit(accountId: 'account-1', amount: 100),
        JournalEntryLineInput.credit(accountId: 'account-2', amount: 100),
      ];

      final id = await db.journalEntriesDao.createJournalEntry(
        description: 'Test Entry',
        postDate: DateTime.now(),
        lines: originalLines,
      );

      // Update lines
      final newLines = [
        JournalEntryLineInput.debit(accountId: 'account-1', amount: 200),
        JournalEntryLineInput.credit(accountId: 'account-3', amount: 200),
      ];

      await db.journalEntriesDao.updateLines(id, newLines);

      final entryWithLines = await db.journalEntriesDao.getJournalEntryWithLines(id);
      expect(entryWithLines!.lines.length, equals(2));
      expect(entryWithLines.lines[0].debitNum, equals(200));
      expect(entryWithLines.lines[1].accountId, equals('account-3'));
    });

    test('deletes entry and lines', () async {
      await _createTestAccount(db, 'account-1', 'Account 1');
      await _createTestAccount(db, 'account-2', 'Account 2');

      final lines = [
        JournalEntryLineInput.debit(accountId: 'account-1', amount: 100),
        JournalEntryLineInput.credit(accountId: 'account-2', amount: 100),
      ];

      final id = await db.journalEntriesDao.createJournalEntry(
        description: 'To Be Deleted',
        postDate: DateTime.now(),
        lines: lines,
      );

      // Delete entry
      await db.journalEntriesDao.deleteEntry(id);

      // Verify entry is gone
      final entry = await db.journalEntriesDao.getById(id);
      expect(entry, isNull);
    });
  });

  group('JournalEntriesDao Posting and Reversal', () {
    test('posts entry', () async {
      await _createTestAccount(db, 'account-1', 'Account 1');
      await _createTestAccount(db, 'account-2', 'Account 2');

      final lines = [
        JournalEntryLineInput.debit(accountId: 'account-1', amount: 100),
        JournalEntryLineInput.credit(accountId: 'account-2', amount: 100),
      ];

      final id = await db.journalEntriesDao.createJournalEntry(
        description: 'To Post',
        postDate: DateTime.now(),
        lines: lines,
      );

      // Post entry
      await db.journalEntriesDao.postEntry(id);

      final entry = await db.journalEntriesDao.getById(id);
      expect(entry!.isPosted, isTrue);
    });

    test('rejects posting already posted entry', () async {
      await _createTestAccount(db, 'account-1', 'Account 1');
      await _createTestAccount(db, 'account-2', 'Account 2');

      final lines = [
        JournalEntryLineInput.debit(accountId: 'account-1', amount: 100),
        JournalEntryLineInput.credit(accountId: 'account-2', amount: 100),
      ];

      final id = await db.journalEntriesDao.createJournalEntry(
        description: 'Already Posted',
        postDate: DateTime.now(),
        lines: lines,
      );

      await db.journalEntriesDao.postEntry(id);

      // Try to post again
      expect(
        () async => await db.journalEntriesDao.postEntry(id),
        throwsA(isA<StateError>()),
      );
    });

    test('unposts entry', () async {
      await _createTestAccount(db, 'account-1', 'Account 1');
      await _createTestAccount(db, 'account-2', 'Account 2');

      final lines = [
        JournalEntryLineInput.debit(accountId: 'account-1', amount: 100),
        JournalEntryLineInput.credit(accountId: 'account-2', amount: 100),
      ];

      final id = await db.journalEntriesDao.createJournalEntry(
        description: 'To Unpost',
        postDate: DateTime.now(),
        lines: lines,
      );

      await db.journalEntriesDao.postEntry(id);
      await db.journalEntriesDao.unpostEntry(id);

      final entry = await db.journalEntriesDao.getById(id);
      expect(entry!.isPosted, isFalse);
    });

    test('reverses entry with swapped debits/credits', () async {
      await _createTestAccount(db, 'cash', 'Cash');
      await _createTestAccount(db, 'revenue', 'Revenue');

      final originalLines = [
        JournalEntryLineInput.debit(accountId: 'cash', amount: 10000),
        JournalEntryLineInput.credit(accountId: 'revenue', amount: 10000),
      ];

      final originalId = await db.journalEntriesDao.createJournalEntry(
        description: 'Original Entry',
        postDate: DateTime(2024, 1, 15),
        reference: 'REF-001',
        lines: originalLines,
      );

      await db.journalEntriesDao.postEntry(originalId);

      // Reverse the entry
      final reversalId = await db.journalEntriesDao.reverseEntry(originalId);

      // Verify reversal entry was created
      final reversal = await db.journalEntriesDao.getJournalEntryWithLines(reversalId);
      expect(reversal, isNotNull);
      expect(reversal!.entry.description, contains('REVERSAL'));

      // Verify debits and credits are swapped
      // Original: Debit cash 10000, Credit revenue 10000
      // Reversal: Credit cash 10000, Debit revenue 10000
      final cashLine = reversal.lines.firstWhere((l) => l.accountId == 'cash');
      final revenueLine = reversal.lines.firstWhere((l) => l.accountId == 'revenue');

      expect(cashLine.creditNum, equals(10000));
      expect(cashLine.debitNum, equals(0));
      expect(revenueLine.debitNum, equals(10000));
      expect(revenueLine.creditNum, equals(0));

      // Verify original entry is marked as reversed
      final original = await db.journalEntriesDao.getById(originalId);
      expect(original!.isReversed, isTrue);
    });
  });

  group('JournalEntriesDao Sequential Number Generation', () {
    test('generates sequential entry numbers', () async {
      await _createTestAccount(db, 'account-1', 'Account 1');
      await _createTestAccount(db, 'account-2', 'Account 2');

      final lines = [
        JournalEntryLineInput.debit(accountId: 'account-1', amount: 100),
        JournalEntryLineInput.credit(accountId: 'account-2', amount: 100),
      ];

      final id1 = await db.journalEntriesDao.createJournalEntry(
        description: 'Entry 1',
        postDate: DateTime.now(),
        lines: lines,
      );

      final id2 = await db.journalEntriesDao.createJournalEntry(
        description: 'Entry 2',
        postDate: DateTime.now(),
        lines: lines,
      );

      final entry1 = await db.journalEntriesDao.getById(id1);
      final entry2 = await db.journalEntriesDao.getById(id2);

      expect(entry1!.entryNumber, isNotNull);
      expect(entry2!.entryNumber, isNotNull);
      expect(entry1.entryNumber, isNot(equals(entry2.entryNumber)));
    });

    test('generates entry number format correctly', () async {
      final entryNumber = await db.journalEntriesDao.generateEntryNumber();
      final year = DateTime.now().year;

      expect(entryNumber, startsWith('JE-$year-'));
      expect(entryNumber.length, equals(15)); // JE-YYYY-NNNNNN
    });

    test('gets entry by entry number', () async {
      await _createTestAccount(db, 'account-1', 'Account 1');
      await _createTestAccount(db, 'account-2', 'Account 2');

      final lines = [
        JournalEntryLineInput.debit(accountId: 'account-1', amount: 100),
        JournalEntryLineInput.credit(accountId: 'account-2', amount: 100),
      ];

      final id = await db.journalEntriesDao.createJournalEntry(
        description: 'Test Entry',
        postDate: DateTime.now(),
        lines: lines,
      );

      final entry = await db.journalEntriesDao.getById(id);
      final found = await db.journalEntriesDao.getByEntryNumber(entry!.entryNumber!);

      expect(found, isNotNull);
      expect(found!.id, equals(id));
    });
  });

  group('JournalEntriesDao Search and Query', () {
    test('searches by description', () async {
      await _createTestAccount(db, 'account-1', 'Account 1');
      await _createTestAccount(db, 'account-2', 'Account 2');

      final lines = [
        JournalEntryLineInput.debit(accountId: 'account-1', amount: 100),
        JournalEntryLineInput.credit(accountId: 'account-2', amount: 100),
      ];

      await db.journalEntriesDao.createJournalEntry(
        description: 'Salary Payment',
        postDate: DateTime.now(),
        lines: lines,
      );

      await db.journalEntriesDao.createJournalEntry(
        description: 'Rent Payment',
        postDate: DateTime.now(),
        lines: lines,
      );

      await db.journalEntriesDao.createJournalEntry(
        description: 'Salary Bonus',
        postDate: DateTime.now(),
        lines: lines,
      );

      final results = await db.journalEntriesDao.searchEntries('Salary');
      expect(results.length, equals(2));
    });

    test('searches by description or reference', () async {
      await _createTestAccount(db, 'account-1', 'Account 1');
      await _createTestAccount(db, 'account-2', 'Account 2');

      final lines = [
        JournalEntryLineInput.debit(accountId: 'account-1', amount: 100),
        JournalEntryLineInput.credit(accountId: 'account-2', amount: 100),
      ];

      await db.journalEntriesDao.createJournalEntry(
        description: 'Payment 1',
        postDate: DateTime.now(),
        reference: 'INV-001',
        lines: lines,
      );

      await db.journalEntriesDao.createJournalEntry(
        description: 'Payment 2',
        postDate: DateTime.now(),
        reference: 'INV-002',
        lines: lines,
      );

      await db.journalEntriesDao.createJournalEntry(
        description: 'Miscellaneous',
        postDate: DateTime.now(),
        reference: 'MISC-001',
        lines: lines,
      );

      final results = await db.journalEntriesDao.searchEntriesFull('INV');
      expect(results.length, equals(2));
    });

    test('gets entries by date range', () async {
      await _createTestAccount(db, 'account-1', 'Account 1');
      await _createTestAccount(db, 'account-2', 'Account 2');

      final lines = [
        JournalEntryLineInput.debit(accountId: 'account-1', amount: 100),
        JournalEntryLineInput.credit(accountId: 'account-2', amount: 100),
      ];

      await db.journalEntriesDao.createJournalEntry(
        description: 'January Entry',
        postDate: DateTime(2024, 1, 15),
        lines: lines,
      );

      await db.journalEntriesDao.createJournalEntry(
        description: 'February Entry',
        postDate: DateTime(2024, 2, 15),
        lines: lines,
      );

      await db.journalEntriesDao.createJournalEntry(
        description: 'March Entry',
        postDate: DateTime(2024, 3, 15),
        lines: lines,
      );

      final results = await db.journalEntriesDao.getByDateRange(
        DateTime(2024, 1, 1),
        DateTime(2024, 2, 28),
      );

      expect(results.length, equals(2));
    });

    test('gets entries by account', () async {
      await _createTestAccount(db, 'cash', 'Cash');
      await _createTestAccount(db, 'bank', 'Bank');
      await _createTestAccount(db, 'expense', 'Expense');

      // Entry 1: Cash and Expense
      await db.journalEntriesDao.createJournalEntry(
        description: 'Entry 1',
        postDate: DateTime.now(),
        lines: [
          JournalEntryLineInput.debit(accountId: 'expense', amount: 100),
          JournalEntryLineInput.credit(accountId: 'cash', amount: 100),
        ],
      );

      // Entry 2: Bank and Expense
      await db.journalEntriesDao.createJournalEntry(
        description: 'Entry 2',
        postDate: DateTime.now(),
        lines: [
          JournalEntryLineInput.debit(accountId: 'expense', amount: 200),
          JournalEntryLineInput.credit(accountId: 'bank', amount: 200),
        ],
      );

      // Entry 3: Cash and Bank
      await db.journalEntriesDao.createJournalEntry(
        description: 'Entry 3',
        postDate: DateTime.now(),
        lines: [
          JournalEntryLineInput.debit(accountId: 'bank', amount: 500),
          JournalEntryLineInput.credit(accountId: 'cash', amount: 500),
        ],
      );

      final cashEntries = await db.journalEntriesDao.getEntriesByAccount('cash');
      expect(cashEntries.length, equals(2));

      final expenseEntries = await db.journalEntriesDao.getEntriesByAccount('expense');
      expect(expenseEntries.length, equals(2));

      final bankEntries = await db.journalEntriesDao.getEntriesByAccount('bank');
      expect(bankEntries.length, equals(2));
    });

    test('gets posted entries', () async {
      await _createTestAccount(db, 'account-1', 'Account 1');
      await _createTestAccount(db, 'account-2', 'Account 2');

      final lines = [
        JournalEntryLineInput.debit(accountId: 'account-1', amount: 100),
        JournalEntryLineInput.credit(accountId: 'account-2', amount: 100),
      ];

      final id1 = await db.journalEntriesDao.createJournalEntry(
        description: 'Posted Entry',
        postDate: DateTime.now(),
        lines: lines,
      );

      await db.journalEntriesDao.createJournalEntry(
        description: 'Unposted Entry',
        postDate: DateTime.now(),
        lines: lines,
      );

      await db.journalEntriesDao.postEntry(id1);

      final posted = await db.journalEntriesDao.getPostedEntries();
      expect(posted.length, equals(1));

      final unposted = await db.journalEntriesDao.getUnpostedEntries();
      expect(unposted.length, equals(1));
    });

    test('gets entries by reference', () async {
      await _createTestAccount(db, 'account-1', 'Account 1');
      await _createTestAccount(db, 'account-2', 'Account 2');

      final lines = [
        JournalEntryLineInput.debit(accountId: 'account-1', amount: 100),
        JournalEntryLineInput.credit(accountId: 'account-2', amount: 100),
      ];

      await db.journalEntriesDao.createJournalEntry(
        description: 'Entry 1',
        postDate: DateTime.now(),
        reference: 'INV-001',
        lines: lines,
      );

      await db.journalEntriesDao.createJournalEntry(
        description: 'Entry 2',
        postDate: DateTime.now(),
        reference: 'INV-002',
        lines: lines,
      );

      await db.journalEntriesDao.createJournalEntry(
        description: 'Entry 3',
        postDate: DateTime.now(),
        reference: 'INV-001', // Duplicate reference
        lines: lines,
      );

      final results = await db.journalEntriesDao.getByReference('INV-001');
      expect(results.length, equals(2));
    });
  });

  group('JournalEntriesDao Watch Operations', () {
    test('watches all entries', () async {
      await _createTestAccount(db, 'account-1', 'Account 1');
      await _createTestAccount(db, 'account-2', 'Account 2');

      final lines = [
        JournalEntryLineInput.debit(accountId: 'account-1', amount: 100),
        JournalEntryLineInput.credit(accountId: 'account-2', amount: 100),
      ];

      final stream = db.journalEntriesDao.watchAll();

      await db.journalEntriesDao.createJournalEntry(
        description: 'Test Entry',
        postDate: DateTime.now(),
        lines: lines,
      );

      final entries = await stream.first;
      expect(entries.length, equals(1));
    });

    test('watches posted entries', () async {
      await _createTestAccount(db, 'account-1', 'Account 1');
      await _createTestAccount(db, 'account-2', 'Account 2');

      final lines = [
        JournalEntryLineInput.debit(accountId: 'account-1', amount: 100),
        JournalEntryLineInput.credit(accountId: 'account-2', amount: 100),
      ];

      final id = await db.journalEntriesDao.createJournalEntry(
        description: 'Test Entry',
        postDate: DateTime.now(),
        lines: lines,
      );

      await db.journalEntriesDao.postEntry(id);

      final stream = db.journalEntriesDao.watchPostedEntries();
      final entries = await stream.first;
      expect(entries.length, equals(1));
    });
  });

  group('JournalEntriesDao Batch Operations', () {
    test('creates multiple entries in batch', () async {
      await _createTestAccount(db, 'account-1', 'Account 1');
      await _createTestAccount(db, 'account-2', 'Account 2');

      final lines = [
        JournalEntryLineInput.debit(accountId: 'account-1', amount: 100),
        JournalEntryLineInput.credit(accountId: 'account-2', amount: 100),
      ];

      final batchInput = [
        JournalEntryBatchInput(
          description: 'Batch Entry 1',
          postDate: DateTime.now(),
          lines: lines,
        ),
        JournalEntryBatchInput(
          description: 'Batch Entry 2',
          postDate: DateTime.now(),
          lines: lines,
        ),
        JournalEntryBatchInput(
          description: 'Batch Entry 3',
          postDate: DateTime.now(),
          lines: lines,
        ),
      ];

      final ids = await db.journalEntriesDao.createBatch(batchInput);
      expect(ids.length, equals(3));

      final count = await db.journalEntriesDao.count();
      expect(count, equals(3));
    });

    test('counts entries correctly', () async {
      await _createTestAccount(db, 'account-1', 'Account 1');
      await _createTestAccount(db, 'account-2', 'Account 2');

      final lines = [
        JournalEntryLineInput.debit(accountId: 'account-1', amount: 100),
        JournalEntryLineInput.credit(accountId: 'account-2', amount: 100),
      ];

      expect(await db.journalEntriesDao.count(), equals(0));

      await db.journalEntriesDao.createJournalEntry(
        description: 'Entry 1',
        postDate: DateTime.now(),
        lines: lines,
      );

      expect(await db.journalEntriesDao.count(), equals(1));

      await db.journalEntriesDao.createJournalEntry(
        description: 'Entry 2',
        postDate: DateTime.now(),
        lines: lines,
      );

      expect(await db.journalEntriesDao.count(), equals(2));
    });

    test('checks if entry exists', () async {
      await _createTestAccount(db, 'account-1', 'Account 1');
      await _createTestAccount(db, 'account-2', 'Account 2');

      final lines = [
        JournalEntryLineInput.debit(accountId: 'account-1', amount: 100),
        JournalEntryLineInput.credit(accountId: 'account-2', amount: 100),
      ];

      final id = await db.journalEntriesDao.createJournalEntry(
        description: 'Test Entry',
        postDate: DateTime.now(),
        lines: lines,
      );

      expect(await db.journalEntriesDao.exists(id), isTrue);
      expect(await db.journalEntriesDao.exists('non-existent-id'), isFalse);
    });
  });
}

/// Helper function to create a test account.
Future<void> _createTestAccount(
  LocalFinanceDatabase db,
  String id,
  String name,
) async {
  await db.accountsDao.create(
    AccountsCompanion.insert(
      id: id,
      name: name,
      accountType: 'ASSET',
      commodityId: 'CNY',
      createdAt: DateTime.now().millisecondsSinceEpoch,
      updatedAt: DateTime.now().millisecondsSinceEpoch,
    ),
  );
}