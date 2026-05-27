import 'package:drift/drift.dart';
import '../database.dart';

part 'journal_entries_dao.dart';

/// Data Access Object for journal entries and journal entry lines.
///
/// Provides methods for:
/// - Creating, reading, updating, deleting journal entries
/// - Managing journal entry lines (splits)
/// - Generating entry numbers
/// - Balance validation
extension JournalEntriesDao on LocalFinanceDatabase {
  /// Gets all journal entries.
  Future<List<JournalEntry>> getAllJournalEntries() {
    return (select(journalEntries)
          ..orderBy([(t) => OrderingTerm.desc(t.date)]))
        .get();
  }

  /// Gets journal entries for a date range.
  Future<List<JournalEntry>> getJournalEntriesForDateRange(
    DateTime startDate,
    DateTime endDate,
  ) {
    return (select(journalEntries)
          ..where((t) =>
              t.date.isBiggerOrEqualValue(startDate) &
              t.date.isSmallerOrEqualValue(endDate))
          ..orderBy([(t) => OrderingTerm.desc(t.date)]))
        .get();
  }

  /// Gets a single journal entry by ID.
  Future<JournalEntry?> getJournalEntry(String id) {
    return (select(journalEntries)..where((t) => t.id.equals(id)))
        .getSingleOrNull();
  }

  /// Gets journal entry with lines.
  Future<JournalEntryWithLines?> getJournalEntryWithLines(String id) async {
    final entry = await getJournalEntry(id);
    if (entry == null) return null;

    final lines = await getJournalEntryLines(id);
    return JournalEntryWithLines(entry: entry, lines: lines);
  }

  /// Creates a new journal entry.
  Future<String> createJournalEntry({
    required String id,
    String? entryNumber,
    required DateTime date,
    String? description,
    String? reference,
    String source = 'manual',
    String? createdBy,
  }) {
    return into(journalEntries).insert(
      JournalEntriesCompanion.insert(
        id: id,
        date: date,
        entryNumber: Value(entryNumber),
        description: Value(description),
        reference: Value(reference),
        source: Value(source),
        createdBy: Value(createdBy),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
    );
  }

  /// Updates a journal entry.
  Future<int> updateJournalEntry(JournalEntry entry) {
    return (update(journalEntries)..where((t) => t.id.equals(entry.id))).write(
      JournalEntriesCompanion(
        date: Value(entry.date),
        description: Value(entry.description),
        reference: Value(entry.reference),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  /// Posts a journal entry (finalizes it).
  Future<int> postJournalEntry(String id) {
    return (update(journalEntries)..where((t) => t.id.equals(id))).write(
      JournalEntriesCompanion(
        isPosted: const Value(true),
        postedAt: Value(DateTime.now()),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  /// Reverses a journal entry.
  Future<String> reverseJournalEntry({
    required String originalId,
    required String reversalId,
    required DateTime reversalDate,
    String? reason,
  }) async {
    final original = await getJournalEntryWithLines(originalId);
    if (original == null) {
      throw Exception('Original journal entry not found');
    }

    // Create reversal entry
    await createJournalEntry(
      id: reversalId,
      date: reversalDate,
      description: reason ?? 'Reversal of entry ${original.entry.entryNumber}',
      source: 'reversal',
    );

    // Mark original as reversed
    await (update(journalEntries)..where((t) => t.id.equals(originalId)))
        .write(
      JournalEntriesCompanion(
        isReversed: const Value(true),
        updatedAt: Value(DateTime.now()),
      ),
    );

    // Create reversal lines (swap debit/credit)
    for (final line in original.lines) {
      await createJournalEntryLine(
        id: '${reversalId}-${line.lineOrder}',
        entryId: reversalId,
        accountId: line.accountId,
        description: line.description,
        debitAmount: line.creditAmount,
        creditAmount: line.debitAmount,
        lineOrder: line.lineOrder,
      );
    }

    return reversalId;
  }

  /// Deletes a journal entry (soft delete).
  Future<int> deleteJournalEntry(String id) {
    return (update(journalEntries)..where((t) => t.id.equals(id))).write(
      JournalEntriesCompanion(
        isDeleted: const Value(true),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  /// Gets lines for a journal entry.
  Future<List<JournalEntryLine>> getJournalEntryLines(String entryId) {
    return (select(journalEntryLines)
          ..where((t) => t.entryId.equals(entryId) & t.isDeleted.equals(false))
          ..orderBy([(t) => OrderingTerm.asc(t.lineOrder)]))
        .get();
  }

  /// Creates a journal entry line.
  Future<String> createJournalEntryLine({
    required String id,
    required String entryId,
    required String accountId,
    String? description,
    int debitAmount = 0,
    int creditAmount = 0,
    int lineOrder = 0,
    String? entityType,
    String? entityId,
  }) {
    return into(journalEntryLines).insert(
      JournalEntryLinesCompanion.insert(
        id: id,
        entryId: entryId,
        accountId: accountId,
        description: Value(description),
        debitAmount: Value(debitAmount),
        creditAmount: Value(creditAmount),
        lineOrder: Value(lineOrder),
        entityType: Value(entityType),
        entityId: Value(entityId),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
    );
  }

  /// Validates that a journal entry is balanced.
  /// 
  /// Returns true if total debits equal total credits.
  Future<bool> isJournalEntryBalanced(String entryId) async {
    final lines = await getJournalEntryLines(entryId);
    
    int totalDebits = 0;
    int totalCredits = 0;
    
    for (final line in lines) {
      totalDebits += line.debitAmount;
      totalCredits += line.creditAmount;
    }
    
    return totalDebits == totalCredits;
  }

  /// Gets the balance difference for a journal entry.
  Future<int> getJournalEntryBalanceDifference(String entryId) async {
    final lines = await getJournalEntryLines(entryId);
    
    int totalDebits = 0;
    int totalCredits = 0;
    
    for (final line in lines) {
      totalDebits += line.debitAmount;
      totalCredits += line.creditAmount;
    }
    
    return totalDebits - totalCredits;
  }

  /// Generates the next entry number for a given year.
  Future<String> generateEntryNumber(int year) async {
    final entries = await (select(journalEntries)
          ..where((t) =>
              t.entryNumber.like('JE-$year-%') & t.entryNumber.isNotNull()))
        .get();

    int maxNumber = 0;
    for (final entry in entries) {
      if (entry.entryNumber != null) {
        final parts = entry.entryNumber!.split('-');
        if (parts.length == 3) {
          final num = int.tryParse(parts[2]);
          if (num != null && num > maxNumber) {
            maxNumber = num;
          }
        }
      }
    }

    return 'JE-$year-${(maxNumber + 1).toString().padLeft(5, '0')}';
  }

  /// Gets unposted journal entries.
  Future<List<JournalEntry>> getUnpostedJournalEntries() {
    return (select(journalEntries)
          ..where((t) => t.isPosted.equals(false) & t.isDeleted.equals(false))
          ..orderBy([(t) => OrderingTerm.asc(t.date)]))
        .get();
  }

  /// Searches journal entries by description or reference.
  Future<List<JournalEntry>> searchJournalEntries(String query) {
    final searchPattern = '%$query%';
    return (select(journalEntries)
          ..where((t) =>
              t.description.like(searchPattern) |
              t.reference.like(searchPattern) |
              t.entryNumber.like(searchPattern))
          ..orderBy([(t) => OrderingTerm.desc(t.date)]))
        .get();
  }
}

/// Combined journal entry with its lines.
class JournalEntryWithLines {
  final JournalEntry entry;
  final List<JournalEntryLine> lines;

  const JournalEntryWithLines({
    required this.entry,
    required this.lines,
  });

  /// Total debit amount.
  int get totalDebits =>
      lines.fold(0, (sum, line) => sum + line.debitAmount);

  /// Total credit amount.
  int get totalCredits =>
      lines.fold(0, (sum, line) => sum + line.creditAmount);

  /// Whether the entry is balanced.
  bool get isBalanced => totalDebits == totalCredits;
}