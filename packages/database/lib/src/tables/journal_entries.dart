import 'package:drift/drift.dart';

/// Journal entries table for double-entry bookkeeping.
/// 
/// Each journal entry represents a complete accounting transaction
/// with debits and credits that must balance.
class JournalEntries extends Table {
  /// Unique identifier for the journal entry.
  TextColumn get id => text()();
  
  /// Entry number for reference (e.g., JE-2024-001).
  TextColumn get entryNumber => text().nullable()();
  
  /// Date of the transaction.
  DateTimeColumn get date => dateTime()();
  
  /// Description/memo for the entry.
  TextColumn get description => text().nullable()();
  
  /// Reference document (invoice, receipt, etc.).
  TextColumn get reference => text().nullable()();
  
  /// Source of the entry (manual, import, system).
  TextColumn get source => text().withDefault(const Constant('manual'))();
  
  /// Whether the entry is reversed.
  BoolColumn get isReversed => boolean().withDefault(const Constant(false))();
  
  /// Original entry ID if this is a reversal.
  TextColumn get originalEntryId => text().nullable().references(JournalEntries, #id)();
  
  /// Whether the entry is posted (finalized).
  BoolColumn get isPosted => boolean().withDefault(const Constant(false))();
  
  /// Posted timestamp.
  DateTimeColumn get postedAt => dateTime().nullable()();
  
  /// User who created the entry.
  TextColumn get createdBy => text().nullable()();
  
  /// Creation timestamp.
  DateTimeColumn get createdAt => dateTime()();
  
  /// Last update timestamp.
  DateTimeColumn get updatedAt => dateTime()();
  
  /// Soft delete flag.
  BoolColumn get isDeleted => boolean().withDefault(const Constant(false))();
  
  /// Sync status.
  TextColumn get syncStatus => text().withDefault(const Constant('pending'))();
  
  @override
  Set<Column> get primaryKey => {id};
}

/// Journal entry lines (splits) for double-entry bookkeeping.
/// 
/// Each line represents a debit or credit to a specific account.
class JournalEntryLines extends Table {
  /// Unique identifier for the line.
  TextColumn get id => text()();
  
  /// Parent journal entry.
  TextColumn get entryId => text().references(JournalEntries, #id)();
  
  /// Account affected.
  TextColumn get accountId => text()();
  
  /// Line description.
  TextColumn get description => text().nullable()();
  
  /// Debit amount (in base currency smallest unit, e.g., cents).
  IntColumn get debitAmount => integer().withDefault(const Constant(0))();
  
  /// Credit amount (in base currency smallest unit).
  IntColumn get creditAmount => integer().withDefault(const Constant(0))();
  
  /// Line order within the entry.
  IntColumn get lineOrder => integer().withDefault(const Constant(0))();
  
  /// Related entity type (transaction, invoice, etc.).
  TextColumn get entityType => text().nullable()();
  
  /// Related entity ID.
  TextColumn get entityId => text().nullable()();
  
  /// Creation timestamp.
  DateTimeColumn get createdAt => dateTime()();
  
  /// Last update timestamp.
  DateTimeColumn get updatedAt => dateTime()();
  
  /// Soft delete flag.
  BoolColumn get isDeleted => boolean().withDefault(const Constant(false))();
  
  @override
  Set<Column> get primaryKey => {id};
}

/// Account types for double-entry bookkeeping.
enum AccountType {
  asset,
  liability,
  equity,
  revenue,
  expense,
}

/// Account categories within types.
enum AccountCategory {
  // Assets
  cash,
  bank,
  accountsReceivable,
  inventory,
  fixedAssets,
  otherAssets,
  
  // Liabilities
  accountsPayable,
  creditCard,
  loans,
  otherLiabilities,
  
  // Equity
  capital,
  retainedEarnings,
  drawings,
  
  // Revenue
  sales,
  interestIncome,
  otherRevenue,
  
  // Expense
  costOfGoodsSold,
  payroll,
  rent,
  utilities,
  interestExpense,
  otherExpense,
}

/// Normal balance direction for accounts.
enum NormalBalance {
  debit,  // Assets, Expenses
  credit, // Liabilities, Equity, Revenue
}