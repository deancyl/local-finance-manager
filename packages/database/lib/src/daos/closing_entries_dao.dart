part of '../database.dart';

/// Data Access Object for closing entries.
@DriftAccessor(tables: [ClosingEntries, Accounts])
class ClosingEntriesDao extends DatabaseAccessor<LocalFinanceDatabase> 
    with _$ClosingEntriesDaoMixin, AuditableMixin {
  ClosingEntriesDao(super.db);

  /// Gets all closing entries.
  Future<List<ClosingEntry>> getAll() => select(closingEntries).get();

  /// Gets a closing entry by ID.
  Future<ClosingEntry?> getById(String id) {
    return (select(closingEntries)..where((e) => e.id.equals(id))).getSingleOrNull();
  }

  /// Gets closing entries by fiscal period.
  Future<List<ClosingEntry>> getByFiscalPeriod(String fiscalPeriodId) {
    return (select(closingEntries)
      ..where((e) => e.fiscalPeriodId.equals(fiscalPeriodId))
      ..orderBy([(e) => OrderingTerm(expression: e.closingType)]))
      .get();
  }

  /// Gets closing entries by type.
  Future<List<ClosingEntry>> getByType(String closingType) {
    return (select(closingEntries)
      ..where((e) => e.closingType.equals(closingType)))
      .get();
  }

  /// Gets closing entries by status.
  Future<List<ClosingEntry>> getByStatus(String status) {
    return (select(closingEntries)
      ..where((e) => e.status.equals(status)))
      .get();
  }

  /// Gets closing entries by fiscal period and type.
  Future<List<ClosingEntry>> getByFiscalPeriodAndType(
    String fiscalPeriodId,
    String closingType,
  ) {
    return (select(closingEntries)
      ..where((e) =>
          e.fiscalPeriodId.equals(fiscalPeriodId) &
          e.closingType.equals(closingType)))
      .get();
  }

  /// Creates a new closing entry.
  Future<String> create(ClosingEntriesCompanion entry) async {
    await into(closingEntries).insert(entry);
    // Audit log for CREATE operation
    await logMutation(
      operation: 'CREATE',
      entityType: 'closing_entry',
      entityId: entry.id.value,
      newValue: entry.toJson(),
    );
    return entry.id.value;
  }

  /// Creates multiple closing entries in a batch.
  Future<void> createBatch(List<ClosingEntriesCompanion> entries) async {
    await batch((b) {
      b.insertAll(closingEntries, entries);
    });
  }

  /// Updates an existing closing entry.
  Future<void> updateEntry(ClosingEntriesCompanion entry) async {
    // Get old value before update for audit log
    final oldEntry = await getById(entry.id.value);
    await (update(closingEntries)..where((e) => e.id.equals(entry.id.value))).write(entry);
    // Audit log for UPDATE operation
    await logMutation(
      operation: 'UPDATE',
      entityType: 'closing_entry',
      entityId: entry.id.value,
      oldValue: oldEntry?.toJson(),
      newValue: entry.toJson(),
    );
  }

  /// Updates the status of a closing entry.
  Future<void> updateStatus(String id, String status, {String? transactionId}) async {
    final companion = ClosingEntriesCompanion(
      id: Value(id),
      status: Value(status),
      updatedAt: Value(DateTime.now().millisecondsSinceEpoch),
    );
    
    if (transactionId != null) {
      await (update(closingEntries)..where((e) => e.id.equals(id))).write(
        companion.copyWith(transactionId: Value(transactionId)),
      );
    } else {
      await (update(closingEntries)..where((e) => e.id.equals(id))).write(companion);
    }
  }

  /// Deletes a closing entry.
  Future<void> deleteEntry(String id) async {
    // Get old value before delete for audit log
    final oldEntry = await getById(id);
    await (delete(closingEntries)..where((e) => e.id.equals(id))).go();
    // Audit log for DELETE operation
    await logMutation(
      operation: 'DELETE',
      entityType: 'closing_entry',
      entityId: id,
      oldValue: oldEntry?.toJson(),
    );
  }

  /// Deletes all closing entries for a fiscal period.
  Future<void> deleteByFiscalPeriod(String fiscalPeriodId) async {
    await (delete(closingEntries)..where((e) => e.fiscalPeriodId.equals(fiscalPeriodId))).go();
  }

  /// Watches all closing entries.
  Stream<List<ClosingEntry>> watchAll() => select(closingEntries).watch();

  /// Watches closing entries by fiscal period.
  Stream<List<ClosingEntry>> watchByFiscalPeriod(String fiscalPeriodId) {
    return (select(closingEntries)
      ..where((e) => e.fiscalPeriodId.equals(fiscalPeriodId))
      ..orderBy([(e) => OrderingTerm(expression: e.closingType)]))
      .watch();
  }

  /// Gets closing entries with account details.
  Future<List<ClosingEntryWithAccounts>> getEntriesWithAccounts(String fiscalPeriodId) {
    return (select(closingEntries).join([
      leftOuterJoin(accounts, accounts.id.equalsExp(closingEntries.sourceAccountId)),
      leftOuterJoin(accounts, accounts.id.equalsExp(closingEntries.targetAccountId), useColumns: false),
    ])
      ..where(closingEntries.fiscalPeriodId.equals(fiscalPeriodId)))
      .get()
      .then((rows) {
        return rows.map((row) {
          return ClosingEntryWithAccounts(
            entry: row.readTable(closingEntries),
            sourceAccount: row.readTable(accounts),
          );
        }).toList();
      });
  }

  /// Checks if closing entries exist for a fiscal period.
  Future<bool> existsForFiscalPeriod(String fiscalPeriodId) async {
    final count = await (select(closingEntries)
      ..where((e) => e.fiscalPeriodId.equals(fiscalPeriodId)))
      .get()
      .then((list) => list.length);
    return count > 0;
  }

  /// Gets the count of closing entries by status for a fiscal period.
  Future<Map<String, int>> getCountByStatus(String fiscalPeriodId) async {
    final entries = await getByFiscalPeriod(fiscalPeriodId);
    final result = <String, int>{};
    for (final entry in entries) {
      result[entry.status] = (result[entry.status] ?? 0) + 1;
    }
    return result;
  }
}

/// Closing entry with source account details.
class ClosingEntryWithAccounts {
  final ClosingEntry entry;
  final Account sourceAccount;

  ClosingEntryWithAccounts({
    required this.entry,
    required this.sourceAccount,
  });
}
