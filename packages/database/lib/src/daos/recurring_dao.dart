part of '../database.dart';

/// Data Access Object for recurring transactions.
@DriftAccessor(tables: [RecurringTransactions, Transactions, Splits])
class RecurringTransactionsDao extends DatabaseAccessor<LocalFinanceDatabase> 
    with _$RecurringTransactionsDaoMixin, _$TransactionsDaoMixin, AuditableMixin {
  RecurringTransactionsDao(super.db);

  /// Watches all non-deleted recurring transactions.
  Stream<List<RecurringTransaction>> watchAll() {
    return (select(recurringTransactions)
          ..where((r) => r.deletedAt.isNull())
          ..orderBy([(r) => OrderingTerm.asc(r.nextDate)]))
        .watch();
  }

  /// Watches active recurring transactions.
  Stream<List<RecurringTransaction>> watchActive() {
    return (select(recurringTransactions)
          ..where((r) => r.isActive.equals(true) & r.deletedAt.isNull())
          ..orderBy([(r) => OrderingTerm.asc(r.nextDate)]))
        .watch();
  }

  /// Gets a recurring transaction by ID.
  Future<RecurringTransaction?> getById(String id) {
    return (select(recurringTransactions)
          ..where((r) => r.id.equals(id)))
        .getSingleOrNull();
  }

  /// Creates a new recurring transaction.
  Future<String> create(RecurringTransactionsCompanion recurring) async {
    await into(recurringTransactions).insert(recurring);
    // Audit log for CREATE operation
    await logMutation(
      operation: 'CREATE',
      entityType: 'recurring_transaction',
      entityId: recurring.id.value,
      newValue: recurring.toJson(),
    );
    return recurring.id.value;
  }

  /// Updates an existing recurring transaction.
  Future<void> updateRecurring(RecurringTransactionsCompanion recurring) async {
    // Get old value before update for audit log
    final oldRecurring = await getById(recurring.id.value);
    
    await (update(recurringTransactions)
          ..where((r) => r.id.equals(recurring.id.value)))
        .write(recurring);
    
    // Audit log for UPDATE operation
    await logMutation(
      operation: 'UPDATE',
      entityType: 'recurring_transaction',
      entityId: recurring.id.value,
      oldValue: oldRecurring?.toJson(),
      newValue: recurring.toJson(),
    );
  }

  /// Soft deletes a recurring transaction.
  Future<void> deleteRecurring(String id) async {
    // Get old value before soft delete for audit log
    final oldRecurring = await getById(id);
    
    final now = DateTime.now().millisecondsSinceEpoch;
    await (update(recurringTransactions)..where((r) => r.id.equals(id)))
        .write(RecurringTransactionsCompanion(
      deletedAt: Value(now),
      updatedAt: Value(now),
    ));
    
    // Audit log for DELETE operation (soft delete)
    await logMutation(
      operation: 'DELETE',
      entityType: 'recurring_transaction',
      entityId: id,
      oldValue: oldRecurring?.toJson(),
      description: 'Soft delete',
    );
  }

  /// Gets recurring transactions that are due for generation.
  /// A transaction is due if:
  /// - It is active
  /// - nextDate <= now
  /// - Not past endDate (if set)
  /// - Not past maxOccurrences (if set)
  Future<List<RecurringTransaction>> getDueTransactions() async {
    final now = DateTime.now().millisecondsSinceEpoch;
    
    return (select(recurringTransactions)
          ..where((r) =>
              r.isActive.equals(true) &
              r.deletedAt.isNull() &
              r.nextDate.isSmallerOrEqualValue(now) &
              // Either no end date, or end date is in the future
              (r.endDate.isNull() | r.endDate.isBiggerThanValue(now))))
        .get();
  }

  /// Generates a transaction from a recurring template.
  /// Creates the transaction and updates the recurring record.
  Future<String> generateTransaction(String recurringId) async {
    final recurring = await getById(recurringId);
    if (recurring == null) {
      throw StateError('Recurring transaction not found: $recurringId');
    }

    // Validate required fields
    if (recurring.accountId == null) {
      throw StateError('Recurring transaction must have an accountId: $recurringId');
    }

    // Check if we've reached max occurrences
    if (recurring.maxOccurrences != null &&
        recurring.occurrenceCount >= recurring.maxOccurrences!) {
      throw StateError('Maximum occurrences reached for recurring transaction: $recurringId');
    }

    // Check if past end date
    if (recurring.endDate != null &&
        recurring.nextDate > recurring.endDate!) {
      throw StateError('End date passed for recurring transaction: $recurringId');
    }

    final now = DateTime.now().millisecondsSinceEpoch;
    final transactionId = '${recurringId}_${now}';

    // Create the transaction - note: currencyId and enterDate are required
    final transaction = TransactionsCompanion.insert(
      id: transactionId,
      currencyId: 'CNY', // Default currency
      description: Value(recurring.description ?? recurring.name),
      notes: Value(recurring.notes),
      postDate: recurring.nextDate,
      enterDate: now,
      createdAt: now,
      updatedAt: now,
    );

    // Create the split - accountId is required, categoryId is optional
    final split = SplitsCompanion.insert(
      id: '${transactionId}_split',
      transactionId: transactionId,
      accountId: recurring.accountId!, // Required, validated above
      categoryId: Value(recurring.categoryId), // Optional
      valueNum: recurring.valueNum,
      valueDenom: Value(recurring.valueDenom),
      quantityNum: recurring.valueNum,
      quantityDenom: Value(recurring.valueDenom),
      memo: Value(recurring.memo),
      createdAt: now,
    );

    // Insert transaction and split
    await batch((b) {
      b.insert(transactions, transaction);
      b.insert(splits, split);
    });

    // Update recurring record
    final newOccurrenceCount = recurring.occurrenceCount + 1;
    final newNextDate = _calculateNextDate(recurring);
    
    // Check if we should deactivate
    final shouldDeactivate = 
        (recurring.endDate != null && newNextDate.isAfter(DateTime.fromMillisecondsSinceEpoch(recurring.endDate!))) ||
        (recurring.maxOccurrences != null && newOccurrenceCount >= recurring.maxOccurrences!);

    await (update(recurringTransactions)..where((r) => r.id.equals(recurringId)))
        .write(RecurringTransactionsCompanion(
      occurrenceCount: Value(newOccurrenceCount),
      nextDate: Value(newNextDate.millisecondsSinceEpoch),
      lastTransactionId: Value(transactionId),
      isActive: Value(shouldDeactivate ? false : recurring.isActive),
      updatedAt: Value(now),
    ));

    return transactionId;
  }

  /// Updates the next occurrence date for a recurring transaction.
  Future<void> updateNextDate(String recurringId) async {
    final recurring = await getById(recurringId);
    if (recurring == null) return;

    final newNextDate = _calculateNextDate(recurring);
    final now = DateTime.now().millisecondsSinceEpoch;

    await (update(recurringTransactions)..where((r) => r.id.equals(recurringId)))
        .write(RecurringTransactionsCompanion(
      nextDate: Value(newNextDate.millisecondsSinceEpoch),
      updatedAt: Value(now),
    ));
  }

  /// Calculates the next occurrence date based on frequency and interval.
  DateTime _calculateNextDate(RecurringTransaction recurring) {
    final currentNext = DateTime.fromMillisecondsSinceEpoch(recurring.nextDate);
    
    switch (recurring.frequency) {
      case 'daily':
        return currentNext.add(Duration(days: recurring.interval));
      
      case 'weekly':
        final next = currentNext.add(Duration(days: 7 * recurring.interval));
        // Adjust to specific day of week if set
        if (recurring.dayOfWeek != null) {
          final daysUntilTarget = (recurring.dayOfWeek! - next.weekday) % 7;
          return next.add(Duration(days: daysUntilTarget));
        }
        return next;
      
      case 'monthly':
        final next = DateTime(
          currentNext.year,
          currentNext.month + recurring.interval,
          recurring.dayOfMonth ?? currentNext.day,
        );
        // Handle last day of month (-1)
        if (recurring.dayOfMonth == -1) {
          final lastDay = DateTime(next.year, next.month + 1, 0);
          return DateTime(next.year, next.month, lastDay.day);
        }
        return next;
      
      case 'yearly':
        return DateTime(
          currentNext.year + recurring.interval,
          recurring.monthOfYear ?? currentNext.month,
          recurring.dayOfMonth ?? currentNext.day,
        );
      
      case 'custom':
        // For custom, default to daily interval
        return currentNext.add(Duration(days: recurring.interval));
      
      default:
        return currentNext.add(Duration(days: 1));
    }
  }

  /// Toggles the active status of a recurring transaction.
  Future<void> toggleActive(String recurringId, bool isActive) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await (update(recurringTransactions)..where((r) => r.id.equals(recurringId)))
        .write(RecurringTransactionsCompanion(
      isActive: Value(isActive),
      updatedAt: Value(now),
    ));
  }

  /// Gets the count of transactions generated from a recurring template.
  Future<int> getGeneratedCount(String recurringId) async {
    final query = selectOnly(transactions)
      ..where(transactions.description.like('%${recurringId}%') & 
              transactions.deletedAt.isNull());
    query.addColumns([transactions.id.count()]);
    
    final result = await query.getSingle();
    return result.read(transactions.id.count()) ?? 0;
  }
}
