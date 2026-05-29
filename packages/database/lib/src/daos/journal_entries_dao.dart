part of '../database.dart';

/// Data Access Object for journal entries.
@DriftAccessor(tables: [JournalEntries, JournalEntryLines])
class JournalEntriesDao extends DatabaseAccessor<LocalFinanceDatabase>
    with _$JournalEntriesDaoMixin {
  JournalEntriesDao(super.db);

  // ============================================================
  // CRUD OPERATIONS
  // ============================================================

  /// Creates a new journal entry with lines atomically.
  /// 
  /// Validates that debits equal credits before creating.
  /// Returns the generated entry ID.
  Future<String> createJournalEntry({
    required String description,
    required DateTime postDate,
    String? reference,
    required List<JournalEntryLineInput> lines,
    String? entryNumber,
  }) async {
    // Validate balance
    final balance = _calculateBalance(lines);
    if (!balance.isBalanced) {
      throw ArgumentError(
        'Journal entry must be balanced. '
        'Debits: ${balance.debits}, Credits: ${balance.credits}',
      );
    }

    // Validate at least one line exists
    if (lines.isEmpty) {
      throw ArgumentError('Journal entry must have at least one line');
    }

    final now = DateTime.now();
    final id = _generateId();
    final actualEntryNumber = entryNumber ?? await generateEntryNumber();

    return await transaction(() async {
      // Insert the journal entry
      await into(journalEntries).insert(JournalEntriesCompanion.insert(
        id: id,
        entryNumber: Value(actualEntryNumber),
        description: Value(description),
        postDate: postDate.millisecondsSinceEpoch,
        enterDate: now.millisecondsSinceEpoch,
        reference: Value(reference),
        createdAt: now.millisecondsSinceEpoch,
        updatedAt: now.millisecondsSinceEpoch,
      ));

      // Insert all lines
      for (final line in lines) {
        final lineId = _generateId();
        await into(journalEntryLines).insert(JournalEntryLinesCompanion.insert(
          id: lineId,
          journalEntryId: id,
          accountId: line.accountId,
          debitNum: line.debitNum,
          debitDenom: Value(line.debitDenom),
          creditNum: line.creditNum,
          creditDenom: Value(line.creditDenom),
          memo: Value(line.memo),
          createdAt: now.millisecondsSinceEpoch,
        ));
      }

      return id;
    });
  }

  /// Gets a journal entry by ID.
  Future<JournalEntry?> getById(String id) {
    return (select(journalEntries)..where((e) => e.id.equals(id)))
        .getSingleOrNull();
  }

  /// Gets a journal entry line by ID.
  Future<JournalEntryLine?> getLineById(String id) {
    return (select(journalEntryLines)..where((l) => l.id.equals(id)))
        .getSingleOrNull();
  }

  /// Gets all lines for a journal entry.
  Future<List<JournalEntryLine>> getLinesForEntry(String journalEntryId) {
    return (select(journalEntryLines)
          ..where((l) => l.journalEntryId.equals(journalEntryId)))
        .get();
  }

  /// Gets a journal entry with all its lines.
  Future<JournalEntryWithLines?> getJournalEntryWithLines(String id) async {
    final entry = await (select(journalEntries)
          ..where((e) => e.id.equals(id)))
        .getSingleOrNull();
    if (entry == null) return null;

    final lines = await (select(journalEntryLines)
          ..where((l) => l.journalEntryId.equals(id)))
        .get();
    return JournalEntryWithLines(entry: entry, lines: lines);
  }

  /// Gets all journal entries.
  Future<List<JournalEntry>> getAll() => select(journalEntries).get();

  /// Gets journal entries by post date range.
  Future<List<JournalEntry>> getByDateRange(
    DateTime startDate,
    DateTime endDate,
  ) {
    return (select(journalEntries)
          ..where((e) =>
              e.postDate.isBiggerOrEqualValue(
                  startDate.millisecondsSinceEpoch) &
              e.postDate.isSmallerOrEqualValue(endDate.millisecondsSinceEpoch))
          ..orderBy([(e) => OrderingTerm.desc(e.postDate)]))
        .get();
  }

  /// Gets posted journal entries.
  Future<List<JournalEntry>> getPostedEntries() {
    return (select(journalEntries)
          ..where((e) => e.isPosted.equals(true))
          ..orderBy([(e) => OrderingTerm.desc(e.postDate)]))
        .get();
  }

  /// Gets unposted journal entries.
  Future<List<JournalEntry>> getUnpostedEntries() {
    return (select(journalEntries)
          ..where((e) => e.isPosted.equals(false))
          ..orderBy([(e) => OrderingTerm.desc(e.postDate)]))
        .get();
  }

  /// Updates a journal entry's metadata (not lines).
  Future<void> updateEntry(
    String id, {
    String? description,
    String? reference,
    DateTime? postDate,
    String? notes,
  }) async {
    final updates = JournalEntriesCompanion(
      id: Value(id),
      updatedAt: Value(DateTime.now().millisecondsSinceEpoch),
    );

    final companion = updates.copyWith(
      description: description != null ? Value(description) : null,
      reference: reference != null ? Value(reference) : null,
      postDate: postDate != null ? Value(postDate.millisecondsSinceEpoch) : null,
      notes: notes != null ? Value(notes) : null,
    );

    await (update(journalEntries)..where((e) => e.id.equals(id))).write(companion);
  }

  /// Updates journal entry lines.
  /// 
  /// Deletes existing lines and inserts new ones.
  /// Validates balance before updating.
  Future<void> updateLines(
    String journalEntryId,
    List<JournalEntryLineInput> newLines,
  ) async {
    // Validate balance
    final balance = _calculateBalance(newLines);
    if (!balance.isBalanced) {
      throw ArgumentError(
        'Journal entry must be balanced. '
        'Debits: ${balance.debits}, Credits: ${balance.credits}',
      );
    }

    // Validate at least one line exists
    if (newLines.isEmpty) {
      throw ArgumentError('Journal entry must have at least one line');
    }

    await transaction(() async {
      // Delete existing lines
      await (delete(journalEntryLines)
            ..where((l) => l.journalEntryId.equals(journalEntryId)))
          .go();

      // Insert new lines
      final now = DateTime.now().millisecondsSinceEpoch;
      for (final line in newLines) {
        final lineId = _generateId();
        await into(journalEntryLines).insert(JournalEntryLinesCompanion.insert(
          id: lineId,
          journalEntryId: journalEntryId,
          accountId: line.accountId,
          debitNum: line.debitNum,
          debitDenom: Value(line.debitDenom),
          creditNum: line.creditNum,
          creditDenom: Value(line.creditDenom),
          memo: Value(line.memo),
          createdAt: now,
        ));
      }

      // Update entry's updated_at timestamp
      await (update(journalEntries)..where((e) => e.id.equals(journalEntryId)))
          .write(JournalEntriesCompanion(
        updatedAt: Value(now),
      ));
    });
  }

  /// Deletes a journal entry and all its lines.
  Future<void> deleteEntry(String id) async {
    await transaction(() async {
      // Delete lines first
      await (delete(journalEntryLines)
            ..where((l) => l.journalEntryId.equals(id)))
          .go();

      // Delete entry
      await (delete(journalEntries)..where((e) => e.id.equals(id))).go();
    });
  }

  // ============================================================
  // POSTING AND REVERSAL
  // ============================================================

  /// Posts a journal entry.
  /// 
  /// Once posted, an entry should not be modified.
  Future<void> postEntry(String id) async {
    // Verify entry exists and is not already posted
    final entry = await getById(id);
    if (entry == null) {
      throw ArgumentError('Entry not found: $id');
    }
    if (entry.isPosted) {
      throw StateError('Entry is already posted: $id');
    }

    await (update(journalEntries)..where((e) => e.id.equals(id))).write(
      JournalEntriesCompanion(
        isPosted: const Value(true),
        updatedAt: Value(DateTime.now().millisecondsSinceEpoch),
      ),
    );
  }

  /// Unposts a journal entry.
  Future<void> unpostEntry(String id) async {
    await (update(journalEntries)..where((e) => e.id.equals(id))).write(
      JournalEntriesCompanion(
        isPosted: const Value(false),
        updatedAt: Value(DateTime.now().millisecondsSinceEpoch),
      ),
    );
  }

  /// Reverses a posted entry by creating a new entry with swapped debits/credits.
  /// 
  /// Returns the ID of the reversing entry.
  Future<String> reverseEntry(String id, {String? description}) async {
    final entryWithLines = await getJournalEntryWithLines(id);
    if (entryWithLines == null) {
      throw ArgumentError('Entry not found: $id');
    }

    // Create reversing entry with swapped debits/credits
    final reversingLines = entryWithLines.lines.map((l) {
      return JournalEntryLineInput(
        accountId: l.accountId,
        debitNum: l.creditNum, // Swapped
        debitDenom: l.creditDenom,
        creditNum: l.debitNum, // Swapped
        creditDenom: l.debitDenom,
        memo: l.memo != null ? 'REVERSAL: ${l.memo}' : null,
      );
    }).toList();

    final now = DateTime.now();
    final reversingId = await createJournalEntry(
      description: description ?? 'REVERSAL: ${entryWithLines.entry.description}',
      postDate: now,
      reference: 'REVERSE-${entryWithLines.entry.id}',
      lines: reversingLines,
    );

    // Mark the original entry as reversed
    await (update(journalEntries)..where((e) => e.id.equals(id))).write(
      JournalEntriesCompanion(
        isReversed: const Value(true),
        reversedFromId: Value(reversingId),
        updatedAt: Value(now.millisecondsSinceEpoch),
      ),
    );

    return reversingId;
  }

  // ============================================================
  // SEQUENTIAL NUMBER GENERATION
  // ============================================================

  /// Generates the next sequential entry number for the current year.
  /// 
  /// Format: JE-YYYY-NNNNNN
  /// Example: JE-2024-000001
  Future<String> generateEntryNumber() async {
    final year = DateTime.now().year;
    final pattern = 'JE-$year-%';

    final count = await (select(journalEntries)
          ..where((e) => e.entryNumber.like(pattern)))
        .get();

    final nextNum = count.length + 1;
    return 'JE-$year-${nextNum.toString().padLeft(6, '0')}';
  }

  /// Gets a journal entry by entry number.
  Future<JournalEntry?> getByEntryNumber(String entryNumber) {
    return (select(journalEntries)
          ..where((e) => e.entryNumber.equals(entryNumber)))
        .getSingleOrNull();
  }

  // ============================================================
  // SEARCH AND QUERY
  // ============================================================

  /// Searches journal entries by description.
  Future<List<JournalEntry>> searchEntries(String query) async {
    return await (select(journalEntries)
          ..where((e) => e.description.like('%$query%'))
          ..orderBy([(e) => OrderingTerm.desc(e.postDate)]))
        .get();
  }

  /// Searches journal entries by description or reference.
  Future<List<JournalEntry>> searchEntriesFull(String query) async {
    return await (select(journalEntries)
          ..where((e) =>
              e.description.like('%$query%') | e.reference.like('%$query%'))
          ..orderBy([(e) => OrderingTerm.desc(e.postDate)]))
        .get();
  }

  /// Gets journal entries involving a specific account.
  Future<List<JournalEntryWithLines>> getEntriesByAccount(
    String accountId,
  ) async {
    // Find all line IDs for this account
    final lines = await (select(journalEntryLines)
          ..where((l) => l.accountId.equals(accountId)))
        .get();

    // Get unique entry IDs
    final entryIds = lines.map((l) => l.journalEntryId).toSet();

    // Fetch entries with lines
    final results = <JournalEntryWithLines>[];
    for (final entryId in entryIds) {
      final entryWithLines = await getJournalEntryWithLines(entryId);
      if (entryWithLines != null) {
        results.add(entryWithLines);
      }
    }

    // Sort by post date descending
    results.sort((a, b) => b.entry.postDate.compareTo(a.entry.postDate));
    return results;
  }

  /// Gets journal entries by reference.
  Future<List<JournalEntry>> getByReference(String reference) {
    return (select(journalEntries)
          ..where((e) => e.reference.equals(reference))
          ..orderBy([(e) => OrderingTerm.desc(e.postDate)]))
        .get();
  }

  // ============================================================
  // WATCH OPERATIONS
  // ============================================================

  /// Watches all journal entries.
  Stream<List<JournalEntry>> watchAll() => select(journalEntries).watch();

  /// Watches a specific journal entry.
  Stream<JournalEntry?> watchById(String id) {
    return (select(journalEntries)..where((e) => e.id.equals(id)))
        .watchSingleOrNull();
  }

  /// Watches posted journal entries.
  Stream<List<JournalEntry>> watchPostedEntries() {
    return (select(journalEntries)
          ..where((e) => e.isPosted.equals(true))
          ..orderBy([(e) => OrderingTerm.desc(e.postDate)]))
        .watch();
  }

  /// Watches unposted journal entries.
  Stream<List<JournalEntry>> watchUnpostedEntries() {
    return (select(journalEntries)
          ..where((e) => e.isPosted.equals(false))
          ..orderBy([(e) => OrderingTerm.desc(e.postDate)]))
        .watch();
  }

  // ============================================================
  // UTILITY METHODS
  // ============================================================

  /// Calculates the balance of journal entry lines.
  BalanceResult _calculateBalance(List<JournalEntryLineInput> lines) {
    int totalDebits = 0;
    int totalCredits = 0;

    for (final line in lines) {
      // Calculate actual debit/credit values (numerator divided by denominator)
      final debitAmount = line.debitDenom != 0
          ? line.debitNum ~/ line.debitDenom
          : line.debitNum;
      final creditAmount = line.creditDenom != 0
          ? line.creditNum ~/ line.creditDenom
          : line.creditNum;

      totalDebits += debitAmount;
      totalCredits += creditAmount;
    }

    return BalanceResult(debits: totalDebits, credits: totalCredits);
  }

  /// Generates a unique ID for journal entries.
  String _generateId() {
    return 'je_${DateTime.now().millisecondsSinceEpoch}_${_random.nextInt(10000).toString().padLeft(4, '0')}';
  }

  static final _random = Random();

  // ============================================================
  // BATCH OPERATIONS
  // ============================================================

  /// Creates multiple journal entries in a batch.
  Future<List<String>> createBatch(
    List<JournalEntryBatchInput> entries,
  ) async {
    final ids = <String>[];
    await transaction(() async {
      for (final entry in entries) {
        final id = await createJournalEntry(
          description: entry.description,
          postDate: entry.postDate,
          reference: entry.reference,
          lines: entry.lines,
          entryNumber: entry.entryNumber,
        );
        ids.add(id);
      }
    });
    return ids;
  }

  /// Counts journal entries.
  Future<int> count() async {
    final entries = await select(journalEntries).get();
    return entries.length;
  }

  /// Counts posted journal entries.
  Future<int> countPosted() async {
    final entries = await (select(journalEntries)..where((e) => e.isPosted.equals(true))).get();
    return entries.length;
  }

  /// Counts unposted journal entries.
  Future<int> countUnposted() async {
    final entries = await (select(journalEntries)..where((e) => e.isPosted.equals(false))).get();
    return entries.length;
  }

  /// Checks if a journal entry exists.
  Future<bool> exists(String id) async {
    final entry = await getById(id);
    return entry != null;
  }
}

// ============================================================
// HELPER CLASSES
// ============================================================

/// Input for creating a journal entry line.
class JournalEntryLineInput {
  final String accountId;
  final int debitNum;
  final int debitDenom;
  final int creditNum;
  final int creditDenom;
  final String? memo;

  JournalEntryLineInput({
    required this.accountId,
    this.debitNum = 0,
    this.debitDenom = 1,
    this.creditNum = 0,
    this.creditDenom = 1,
    this.memo,
  });

  /// Creates a debit line.
  factory JournalEntryLineInput.debit({
    required String accountId,
    required int amount,
    String? memo,
  }) {
    return JournalEntryLineInput(
      accountId: accountId,
      debitNum: amount,
      creditNum: 0,
      memo: memo,
    );
  }

  /// Creates a credit line.
  factory JournalEntryLineInput.credit({
    required String accountId,
    required int amount,
    String? memo,
  }) {
    return JournalEntryLineInput(
      accountId: accountId,
      debitNum: 0,
      creditNum: amount,
      memo: memo,
    );
  }
}

/// Journal entry with all its lines.
class JournalEntryWithLines {
  final JournalEntry entry;
  final List<JournalEntryLine> lines;

  JournalEntryWithLines({required this.entry, required this.lines});
}

/// Balance calculation result.
class BalanceResult {
  final int debits;
  final int credits;

  BalanceResult({required this.debits, required this.credits});

  /// Returns true if debits equal credits.
  bool get isBalanced => debits == credits;

  /// Returns the difference (positive = more debits, negative = more credits).
  int get difference => debits - credits;
}

/// Input for creating a journal entry in batch.
class JournalEntryBatchInput {
  final String description;
  final DateTime postDate;
  final String? reference;
  final List<JournalEntryLineInput> lines;
  final String? entryNumber;

  JournalEntryBatchInput({
    required this.description,
    required this.postDate,
    this.reference,
    required this.lines,
    this.entryNumber,
  });
}