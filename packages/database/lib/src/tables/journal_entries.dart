import 'package:drift/drift.dart';

/// Journal entries for double-entry bookkeeping.
/// 
/// A journal entry represents a complete accounting transaction
/// with multiple debit and credit lines that must balance.
@DataClassName('JournalEntry')
class JournalEntries extends Table {
  /// Unique identifier for the journal entry
  TextColumn get id => text()();
  
  /// Human-readable entry number (e.g., "JE-2024-0001")
  TextColumn get entryNumber => text().unique().nullable()();
  
  /// Description of the journal entry
  TextColumn get description => text().nullable()();
  
  /// Date when the entry was posted (Unix timestamp in milliseconds)
  IntColumn get postDate => integer()();
  
  /// Date when the entry was entered into the system (Unix timestamp in milliseconds)
  IntColumn get enterDate => integer()();
  
  /// Optional reference number or document ID
  TextColumn get reference => text().nullable()();
  
  /// Whether this entry has been posted to the ledger
  BoolColumn get isPosted => boolean().withDefault(const Constant(false))();
  
  /// Whether this entry has been reversed
  BoolColumn get isReversed => boolean().withDefault(const Constant(false))();
  
  /// If reversed, the ID of the reversing entry
  TextColumn get reversedFromId => text().nullable()();
  
  /// Additional notes or comments
  TextColumn get notes => text().nullable()();
  
  /// Version number for optimistic concurrency control
  IntColumn get version => integer().withDefault(const Constant(1))();
  
  /// Creation timestamp (Unix timestamp in milliseconds)
  IntColumn get createdAt => integer()();
  
  /// Last update timestamp (Unix timestamp in milliseconds)
  IntColumn get updatedAt => integer()();
  
  /// Soft delete timestamp (Unix timestamp in milliseconds, null if not deleted)
  IntColumn get deletedAt => integer().nullable()();
  
  @override
  Set<Column> get primaryKey => {id};
}

/// Individual lines within a journal entry.
/// 
/// Each line represents a single debit or credit to an account.
/// The sum of all debits must equal the sum of all credits.
@DataClassName('JournalEntryLine')
class JournalEntryLines extends Table {
  /// Unique identifier for the journal entry line
  TextColumn get id => text()();
  
  /// Reference to the parent journal entry
  TextColumn get journalEntryId => text()();
  
  /// Reference to the account being debited or credited
  TextColumn get accountId => text()();
  
  /// Debit amount numerator (for fractional amounts)
  IntColumn get debitNum => integer()();
  
  /// Debit amount denominator (for fractional amounts, default 1)
  IntColumn get debitDenom => integer().withDefault(const Constant(1))();
  
  /// Credit amount numerator (for fractional amounts)
  IntColumn get creditNum => integer()();
  
  /// Credit amount denominator (for fractional amounts, default 1)
  IntColumn get creditDenom => integer().withDefault(const Constant(1))();
  
  /// Optional memo for this specific line
  TextColumn get memo => text().nullable()();
  
  /// Version number for optimistic concurrency control
  IntColumn get version => integer().withDefault(const Constant(1))();
  
  /// Creation timestamp (Unix timestamp in milliseconds)
  IntColumn get createdAt => integer()();
  
  @override
  Set<Column> get primaryKey => {id};
}