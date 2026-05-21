import 'package:drift/drift.dart';
import 'accounts.dart';

/// Closing entries table - stores closing entries for the accounting cycle.
///
/// Closing entries transfer temporary account balances (revenues, expenses)
/// to permanent accounts (Retained Earnings) at the end of an accounting period.
class ClosingEntries extends Table {
  /// Unique identifier for this closing entry.
  TextColumn get id => text()();
  
  /// Fiscal period this entry belongs to.
  TextColumn get fiscalPeriodId => text()();
  
  /// Type of closing entry (close_revenue, close_expense, etc.).
  TextColumn get closingType => text().withLength(min: 1, max: 30)();
  
  /// Status of this entry (pending, executed, failed, reversed).
  TextColumn get status => text().withLength(min: 1, max: 20)();
  
  /// Source account (the account being closed).
  TextColumn get sourceAccountId => text().references(Accounts, #id)();
  
  /// Target account (the account receiving the balance).
  TextColumn get targetAccountId => text().references(Accounts, #id)();
  
  /// Amount numerator (for fractional amounts).
  IntColumn get amountNum => integer()();
  
  /// Amount denominator (for fractional amounts).
  IntColumn get amountDenom => integer().withDefault(const Constant(1))();
  
  /// Optional description of this closing entry.
  TextColumn get description => text().nullable()();
  
  /// Reference to the generated transaction.
  TextColumn get transactionId => text().nullable()();
  
  /// When this entry was executed.
  IntColumn get executedAt => integer()();
  
  /// When this entry was created.
  IntColumn get createdAt => integer()();
  
  /// When this entry was last updated.
  IntColumn get updatedAt => integer()();
  
  /// Version for optimistic locking.
  IntColumn get version => integer().withDefault(const Constant(1))();

  @override
  Set<Column> get primaryKey => {id};
}
