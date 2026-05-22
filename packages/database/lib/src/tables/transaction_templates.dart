import 'package:drift/drift.dart';

/// Transaction templates table for quick entry.
/// 
/// Stores reusable transaction patterns for efficiency.
@DataClassName('TransactionTemplate')
class TransactionTemplates extends Table {
  /// Unique identifier
  TextColumn get id => text()();

  /// Template name (e.g., "Weekly Salary", "Monthly Rent")
  TextColumn get name => text()();

  /// Template description
  TextColumn get description => text().nullable()();

  /// Template category (for grouping)
  TextColumn get category => text().nullable()();

  /// Default currency ID
  TextColumn get currencyId => text()();

  /// Default description for created transactions
  TextColumn get defaultTxnDescription => text().nullable()();

  /// Default notes for created transactions
  TextColumn get defaultNotes => text().nullable()();

  /// JSON-encoded list of split templates
  /// Format: [{"accountId": "...", "categoryId": "...", "amount": 100.0}]
  TextColumn get splitTemplates => text()();

  /// Usage frequency (auto-updated when used)
  IntColumn get useCount => integer().withDefault(const Constant(0))();

  /// Last used timestamp
  DateTimeColumn get lastUsedAt => dateTime().nullable()();

  /// Whether template is favorite (pinned)
  BoolColumn get isFavorite => boolean().withDefault(const Constant(false))();

  /// Sort order for display
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();

  /// Whether template is active
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();

  /// Creation timestamp
  DateTimeColumn get createdAt => dateTime()();

  /// Last update timestamp
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};

  @override
  List<Set<Column>>? get uniqueKeys => [
    {name},
  ];
}