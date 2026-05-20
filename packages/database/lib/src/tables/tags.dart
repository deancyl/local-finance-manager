import 'package:drift/drift.dart';

/// Tags table - flexible tagging system for transactions.
/// 
/// Tags provide a flexible way to categorize and filter transactions
/// beyond the hierarchical category system. Examples:
/// - #tax-deductible
/// - #business
/// - #reimbursable
/// - #vacation-2024
class Tags extends Table {
  TextColumn get id => text()();
  
  /// Tag name (displayed with or without # prefix)
  TextColumn get name => text().unique()();
  
  /// Display color in hex format (e.g., #FF5722)
  TextColumn get color => text().withDefault(const Constant('#607D8B'))();
  
  /// Optional icon identifier
  TextColumn get icon => text().nullable()();
  
  /// Tag description/notes
  TextColumn get description => text().nullable()();
  
  /// Usage count (updated when transactions are tagged)
  IntColumn get usageCount => integer().withDefault(const Constant(0))();
  
  /// Sort order for display
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
  
  /// Whether this is a system tag (cannot be deleted)
  BoolColumn get isSystem => boolean().withDefault(const Constant(false))();
  
  /// Standard tracking columns
  IntColumn get version => integer().withDefault(const Constant(1))();
  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();
  IntColumn get deletedAt => integer().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// TransactionTags table - many-to-many relationship between transactions and tags.
class TransactionTags extends Table {
  TextColumn get transactionId => text()();
  TextColumn get tagId => text()();
  
  /// When this tag was applied
  IntColumn get createdAt => integer()();

  @override
  Set<Column> get primaryKey => {transactionId, tagId};
}
