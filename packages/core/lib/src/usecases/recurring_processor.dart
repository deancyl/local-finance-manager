import 'package:database/database.dart';

/// Service for processing recurring transactions and generating due transactions.
///
/// This service handles:
/// - Checking all active recurring templates
/// - Generating transactions that are due
/// - Tracking generated transactions via recurring ID
class RecurringProcessor {
  final LocalFinanceDatabase _db;

  RecurringProcessor(this._db);

  /// Process all due recurring transactions.
  ///
  /// Returns a list of generated transaction IDs.
  /// This should be called on app startup or periodically.
  Future<List<String>> processDueTransactions() async {
    final dueTransactions = await _db.recurringTransactionsDao.getDueTransactions();
    
    if (dueTransactions.isEmpty) {
      return [];
    }

    final generatedIds = <String>[];
    
    for (final recurring in dueTransactions) {
      try {
        final transactionId = await _db.recurringTransactionsDao.generateTransaction(recurring.id);
        generatedIds.add(transactionId);
      } catch (e) {
        // Log error but continue processing other transactions
        print('Failed to generate transaction for recurring ${recurring.id}: $e');
      }
    }
    
    return generatedIds;
  }

  /// Generate a single transaction from a recurring template.
  ///
  /// This is for manual triggering when user wants to generate now.
  Future<String?> generateSingle(String recurringId) async {
    try {
      return await _db.recurringTransactionsDao.generateTransaction(recurringId);
    } catch (e) {
      print('Failed to generate transaction for recurring $recurringId: $e');
      return null;
    }
  }

  /// Get upcoming scheduled transactions for the next N days.
  ///
  /// Returns active recurring templates whose nextDate falls within the window.
  Future<List<RecurringTransaction>> getUpcomingTransactions({
    int days = 7,
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final endDate = DateTime.now().add(Duration(days: days)).millisecondsSinceEpoch;
    
    // Query active recurring transactions where nextDate is in the window
    final upcoming = await (_db.select(_db.recurringTransactions)
          ..where((r) =>
              r.isActive.equals(true) &
              r.deletedAt.isNull() &
              r.nextDate.isBiggerOrEqualValue(now) &
              r.nextDate.isSmallerOrEqualValue(endDate)))
        .get();
    
    return upcoming;
  }

  /// Watch upcoming scheduled transactions for the next N days.
  ///
  /// Returns a stream that updates when recurring templates change.
  Stream<List<RecurringTransaction>> watchUpcomingTransactions({
    int days = 7,
  }) {
    final now = DateTime.now().millisecondsSinceEpoch;
    final endDate = DateTime.now().add(Duration(days: days)).millisecondsSinceEpoch;
    
    return (_db.select(_db.recurringTransactions)
          ..where((r) =>
              r.isActive.equals(true) &
              r.deletedAt.isNull() &
              r.nextDate.isBiggerOrEqualValue(now) &
              r.nextDate.isSmallerOrEqualValue(endDate))
          ..orderBy([(r) => OrderingTerm.asc(r.nextDate)]))
        .watch();
  }

  /// Get count of transactions that will be due in the next N days.
  Future<int> getUpcomingCount({int days = 7}) async {
    final upcoming = await getUpcomingTransactions(days: days);
    return upcoming.length;
  }

  /// Check if there are any overdue transactions (nextDate < now).
  Future<bool> hasOverdueTransactions() async {
    final due = await _db.recurringTransactionsDao.getDueTransactions();
    return due.isNotEmpty;
  }

  /// Get all overdue recurring templates.
  Future<List<RecurringTransaction>> getOverdueTransactions() async {
    return await _db.recurringTransactionsDao.getDueTransactions();
  }
}