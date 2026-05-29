import 'package:database/database.dart';
import 'package:drift/drift.dart';
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

  group('Database Migration', () {
    test('schema version is 17', () {
      expect(db.schemaVersion, equals(17));
    });

    test('creates journal_entries table', () async {
      // Verify table exists by querying it
      final result = await db.customStatement(
        "SELECT name FROM sqlite_master WHERE type='table' AND name='journal_entries'",
      );
      expect(result, isNotEmpty);
    });

    test('creates journal_entry_lines table', () async {
      // Verify table exists by querying it
      final result = await db.customStatement(
        "SELECT name FROM sqlite_master WHERE type='table' AND name='journal_entry_lines'",
      );
      expect(result, isNotEmpty);
    });

    test('journal_entries table has correct columns', () async {
      // Get table info
      final result = await db.customStatement(
        "PRAGMA table_info(journal_entries)",
      );
      
      // Verify expected columns exist
      final columns = result.map((row) => row['name'] as String).toList();
      
      expect(columns.contains('id'), isTrue);
      expect(columns.contains('entry_number'), isTrue);
      expect(columns.contains('description'), isTrue);
      expect(columns.contains('post_date'), isTrue);
      expect(columns.contains('enter_date'), isTrue);
      expect(columns.contains('reference'), isTrue);
      expect(columns.contains('is_posted'), isTrue);
      expect(columns.contains('is_reversed'), isTrue);
      expect(columns.contains('reversed_from_id'), isTrue);
      expect(columns.contains('notes'), isTrue);
      expect(columns.contains('version'), isTrue);
      expect(columns.contains('created_at'), isTrue);
      expect(columns.contains('updated_at'), isTrue);
      expect(columns.contains('deleted_at'), isTrue);
    });

    test('journal_entry_lines table has correct columns', () async {
      // Get table info
      final result = await db.customStatement(
        "PRAGMA table_info(journal_entry_lines)",
      );
      
      // Verify expected columns exist
      final columns = result.map((row) => row['name'] as String).toList();
      
      expect(columns.contains('id'), isTrue);
      expect(columns.contains('journal_entry_id'), isTrue);
      expect(columns.contains('account_id'), isTrue);
      expect(columns.contains('debit_num'), isTrue);
      expect(columns.contains('debit_denom'), isTrue);
      expect(columns.contains('credit_num'), isTrue);
      expect(columns.contains('credit_denom'), isTrue);
      expect(columns.contains('memo'), isTrue);
      expect(columns.contains('version'), isTrue);
      expect(columns.contains('created_at'), isTrue);
    });

    test('journal_entries indexes are created', () async {
      // Verify indexes exist
      final result = await db.customStatement(
        "SELECT name FROM sqlite_master WHERE type='index' AND tbl_name='journal_entries'",
      );
      
      final indexes = result.map((row) => row['name'] as String).toList();
      
      expect(indexes.contains('idx_journal_entries_post_date'), isTrue);
      expect(indexes.contains('idx_journal_entries_entry_number'), isTrue);
      expect(indexes.contains('idx_journal_entries_is_posted'), isTrue);
    });

    test('journal_entry_lines indexes are created', () async {
      // Verify indexes exist
      final result = await db.customStatement(
        "SELECT name FROM sqlite_master WHERE type='index' AND tbl_name='journal_entry_lines'",
      );
      
      final indexes = result.map((row) => row['name'] as String).toList();
      
      expect(indexes.contains('idx_journal_entry_lines_entry'), isTrue);
      expect(indexes.contains('idx_journal_entry_lines_account'), isTrue);
    });
  });

  group('JournalEntries CRUD', () {
    test('can insert and query journal entry', () async {
      final now = DateTime.now().millisecondsSinceEpoch;
      
      final entry = JournalEntriesCompanion.insert(
        id: 'test-je-001',
        postDate: now,
        enterDate: now,
        createdAt: now,
        updatedAt: now,
      );
      
      await db.into(db.journalEntries).insert(entry);
      
      final queried = await (db.select(db.journalEntries)
          .where((t) => t.id.equals('test-je-001')))
          .getSingle();
      
      expect(queried, isNotNull);
      expect(queried!.id, equals('test-je-001'));
      expect(queried.isPosted, isFalse);
      expect(queried.isReversed, isFalse);
      expect(queried.version, equals(1));
    });

    test('can insert journal entry with all fields', () async {
      final now = DateTime.now().millisecondsSinceEpoch;
      
      final entry = JournalEntriesCompanion.insert(
        id: 'test-je-002',
        entryNumber: const Value('JE-2024-0001'),
        description: const Value('Test journal entry'),
        postDate: now,
        enterDate: now,
        reference: const Value('REF-001'),
        isPosted: const Value(true),
        notes: const Value('Test notes'),
        createdAt: now,
        updatedAt: now,
      );
      
      await db.into(db.journalEntries).insert(entry);
      
      final queried = await (db.select(db.journalEntries)
          .where((t) => t.id.equals('test-je-002')))
          .getSingle();
      
      expect(queried, isNotNull);
      expect(queried!.entryNumber, equals('JE-2024-0001'));
      expect(queried.description, equals('Test journal entry'));
      expect(queried.reference, equals('REF-001'));
      expect(queried.isPosted, isTrue);
      expect(queried.notes, equals('Test notes'));
    });
  });

  group('JournalEntryLines CRUD', () {
    test('can insert and query journal entry line', () async {
      final now = DateTime.now().millisecondsSinceEpoch;
      
      // First create a journal entry
      final entry = JournalEntriesCompanion.insert(
        id: 'test-je-003',
        postDate: now,
        enterDate: now,
        createdAt: now,
        updatedAt: now,
      );
      await db.into(db.journalEntries).insert(entry);
      
      // Create a journal entry line
      final line = JournalEntryLinesCompanion.insert(
        id: 'test-jel-001',
        journalEntryId: 'test-je-003',
        accountId: 'account-001',
        debitNum: 10000,
        creditNum: 0,
        createdAt: now,
      );
      
      await db.into(db.journalEntryLines).insert(line);
      
      final queried = await (db.select(db.journalEntryLines)
          .where((t) => t.id.equals('test-jel-001')))
          .getSingle();
      
      expect(queried, isNotNull);
      expect(queried!.journalEntryId, equals('test-je-003'));
      expect(queried.accountId, equals('account-001'));
      expect(queried.debitNum, equals(10000));
      expect(queried.debitDenom, equals(1));
      expect(queried.creditNum, equals(0));
      expect(queried.creditDenom, equals(1));
    });

    test('can create balanced journal entry', () async {
      final now = DateTime.now().millisecondsSinceEpoch;
      
      // Create a journal entry
      final entry = JournalEntriesCompanion.insert(
        id: 'test-je-004',
        description: const Value('Balanced entry'),
        postDate: now,
        enterDate: now,
        createdAt: now,
        updatedAt: now,
      );
      await db.into(db.journalEntries).insert(entry);
      
      // Create debit line
      await db.into(db.journalEntryLines).insert(
        JournalEntryLinesCompanion.insert(
          id: 'test-jel-debit',
          journalEntryId: 'test-je-004',
          accountId: 'cash',
          debitNum: 10000,
          creditNum: 0,
          createdAt: now,
        ),
      );
      
      // Create credit line
      await db.into(db.journalEntryLines).insert(
        JournalEntryLinesCompanion.insert(
          id: 'test-jel-credit',
          journalEntryId: 'test-je-004',
          accountId: 'revenue',
          debitNum: 0,
          creditNum: 10000,
          createdAt: now,
        ),
      );
      
      // Query all lines for this entry
      final lines = await (db.select(db.journalEntryLines)
          .where((t) => t.journalEntryId.equals('test-je-004')))
          .get();
      
      expect(lines.length, equals(2));
      
      // Verify balance (sum of debits = sum of credits)
      final totalDebits = lines.fold<int>(0, (sum, line) => sum + line.debitNum);
      final totalCredits = lines.fold<int>(0, (sum, line) => sum + line.creditNum);
      expect(totalDebits, equals(totalCredits));
    });
  });
}