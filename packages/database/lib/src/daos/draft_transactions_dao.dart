part of '../database.dart';

/// DAO for managing draft transactions (auto-saved incomplete entries)
@DriftAccessor(tables: [DraftTransactions])
class DraftTransactionsDao extends DatabaseAccessor<LocalFinanceDatabase>
    with _$DraftTransactionsDaoMixin {
  DraftTransactionsDao(super.db);

  /// Create a new draft transaction
  Future<DraftTransaction> createDraft({
    required String mode,
    String? fromAccountId,
    String? toAccountId,
    String? amount,
    String? categoryId,
    String? description,
    String? notes,
    required DateTime date,
    String currencyId = 'CNY',
    String? templateId,
    String? splitData,
    String? name,
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final id = Uuid().v4();
    
    await into(draftTransactions).insert(
      DraftTransactionsCompanion.insert(
        id: id,
        mode: mode,
        date: date.toIso8601String(),
        currencyId: Value(currencyId),
        createdAt: now,
        updatedAt: now,
        fromAccountId: Value(fromAccountId),
        toAccountId: Value(toAccountId),
        amount: Value(amount),
        categoryId: Value(categoryId),
        description: Value(description),
        notes: Value(notes),
        templateId: Value(templateId),
        splitData: Value(splitData),
        name: Value(name),
      ),
    );
    
    return (await getDraftById(id))!;
  }

  /// Update an existing draft
  Future<void> updateDraft(
    String id,
    {
      String? mode,
      String? fromAccountId,
      String? toAccountId,
      String? amount,
      String? categoryId,
      String? description,
      String? notes,
      DateTime? date,
      String? currencyId,
      String? templateId,
      String? splitData,
      String? name,
    }
  ) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    
    await (update(draftTransactions)..where((d) => d.id.equals(id))).write(
      DraftTransactionsCompanion(
        mode: Value(mode!),
        fromAccountId: Value(fromAccountId),
        toAccountId: Value(toAccountId),
        amount: Value(amount),
        categoryId: Value(categoryId),
        description: Value(description),
        notes: Value(notes),
        date: Value(date!.toIso8601String()),
        currencyId: Value(currencyId!),
        templateId: Value(templateId),
        splitData: Value(splitData),
        name: Value(name),
        updatedAt: Value(now),
      ),
    );
  }

  /// Get a draft by ID
  Future<DraftTransaction?> getDraftById(String id) async {
    return await (select(draftTransactions)..where((d) => d.id.equals(id)))
        .getSingleOrNull();
  }

  /// Get all drafts, sorted by most recent first
  Future<List<DraftTransaction>> getAllDrafts({int limit = 20}) async {
    return await (select(draftTransactions)
        ..orderBy([(d) => OrderingTerm.desc(d.updatedAt)])
        ..limit(limit))
        .get();
  }

  /// Get drafts by mode
  Future<List<DraftTransaction>> getDraftsByMode(String mode) async {
    return await (select(draftTransactions)
        ..where((d) => d.mode.equals(mode))
        ..orderBy([(d) => OrderingTerm.desc(d.updatedAt)]))
        .get();
  }

  /// Delete a draft by ID
  Future<void> deleteDraft(String id) async {
    await (delete(draftTransactions)..where((d) => d.id.equals(id))).go();
  }

  /// Delete all drafts
  Future<void> deleteAllDrafts() async {
    await delete(draftTransactions).go();
  }

  /// Delete drafts older than a specified number of days
  Future<int> deleteOldDrafts(int daysOld) async {
    final cutoff = DateTime.now().subtract(Duration(days: daysOld)).millisecondsSinceEpoch;
    return await (delete(draftTransactions)
        ..where((d) => d.updatedAt.isSmallerThanValue(cutoff)))
        .go();
  }

  /// Watch a specific draft for changes
  Stream<DraftTransaction?> watchDraft(String id) {
    return (select(draftTransactions)..where((d) => d.id.equals(id)))
        .watchSingleOrNull();
  }

  /// Watch all drafts for changes
  Stream<List<DraftTransaction>> watchAllDrafts({int limit = 20}) {
    return (select(draftTransactions)
        ..orderBy([(d) => OrderingTerm.desc(d.updatedAt)])
        ..limit(limit))
        .watch();
  }
}

/// UUID generator (simple implementation for Drift)
class Uuid {
  String v4() {
    return '${_randomHex(8)}-${_randomHex(4)}-4${_randomHex(3)}-${_randomHex(4)}-${_randomHex(12)}';
  }
  
  String _randomHex(int length) {
    final random = DateTime.now().microsecondsSinceEpoch;
    final buffer = StringBuffer();
    for (var i = 0; i < length; i++) {
      buffer.write((random + i * 16).toRadixString(16).padLeft(2, '0').substring(0, 1));
    }
    return buffer.toString();
  }
}