import 'package:drift/drift.dart';
import 'transactions.dart';

/// Recurring transactions table - templates for scheduled transactions.
/// 
/// Supports various recurrence patterns:
/// - Daily, weekly, monthly, yearly
/// - Custom intervals (every N days/weeks/months)
/// - End conditions (after N occurrences or specific date)
class RecurringTransactions extends Table {
  TextColumn get id => text()();
  
  /// Template name for this recurring transaction
  TextColumn get name => text()();
  
  /// Description to use for generated transactions
  TextColumn get description => text().nullable()();
  
  /// Memo for the split entry
  TextColumn get memo => text().nullable()();
  
  /// Amount in numerator/denominator format (fixed-point)
  IntColumn get valueNum => integer()();
  IntColumn get valueDenom => integer().withDefault(const Constant(100))();
  
  /// Account to debit/credit
  TextColumn get accountId => text().nullable()();
  
  /// Category for the transaction
  TextColumn get categoryId => text().nullable()();
  
  /// Recurrence frequency: daily, weekly, monthly, yearly, custom
  TextColumn get frequency => text().withDefault(const Constant('monthly'))();
  
  /// Custom interval (e.g., every 2 weeks = 2)
  IntColumn get interval => integer().withDefault(const Constant(1))();
  
  /// Day of week for weekly recurrence (0=Sunday, 6=Saturday)
  IntColumn get dayOfWeek => integer().nullable()();
  
  /// Day of month for monthly recurrence (1-31, -1 for last day)
  IntColumn get dayOfMonth => integer().nullable()();
  
  /// Month of year for yearly recurrence (1-12)
  IntColumn get monthOfYear => integer().nullable()();
  
  /// Start date for the recurrence (epoch milliseconds)
  IntColumn get startDate => integer()();
  
  /// Next occurrence date (epoch milliseconds)
  IntColumn get nextDate => integer()();
  
  /// End date for the recurrence (null = no end)
  IntColumn get endDate => integer().nullable()();
  
  /// Maximum number of occurrences (null = unlimited)
  IntColumn get maxOccurrences => integer().nullable()();
  
  /// Current occurrence count
  IntColumn get occurrenceCount => integer().withDefault(const Constant(0))();
  
  /// Whether this recurring transaction is active
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
  
  /// Last generated transaction ID
  TextColumn get lastTransactionId => text().nullable().references(Transactions, #id)();
  
  /// Auto-create reminder before due date (days)
  IntColumn get reminderDays => integer().nullable()();
  
  /// Notes about this recurring transaction
  TextColumn get notes => text().nullable()();
  
  /// Standard tracking columns
  IntColumn get version => integer().withDefault(const Constant(1))();
  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();
  IntColumn get deletedAt => integer().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Indexes for recurring transactions queries
/// - nextDate for finding due transactions
/// - isActive for filtering active recurrences
