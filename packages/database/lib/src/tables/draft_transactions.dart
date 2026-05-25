import 'package:drift/drift.dart';

/// Draft transactions for auto-save functionality.
/// Stores incomplete transaction entries that can be resumed later.
class DraftTransactions extends Table {
  TextColumn get id => text().withLength(min: 1, max: 36)();
  
  /// Entry mode: 'simple', 'transfer', 'split', 'template'
  TextColumn get mode => text().withLength(min: 1, max: 20)();
  
  /// From account ID (for simple and transfer modes)
  TextColumn get fromAccountId => text().nullable().withLength(min: 1, max: 36)();
  
  /// To account ID (for transfer mode)
  TextColumn get toAccountId => text().nullable().withLength(min: 1, max: 36)();
  
  /// Transaction amount (stored as string to preserve decimal precision)
  TextColumn get amount => text().nullable()();
  
  /// Category ID
  TextColumn get categoryId => text().nullable().withLength(min: 1, max: 36)();
  
  /// Transaction description
  TextColumn get description => text().nullable()();
  
  /// Additional notes
  TextColumn get notes => text().nullable()();
  
  /// Transaction date (stored as ISO string)
  TextColumn get date => text()();
  
  /// Currency ID
  TextColumn get currencyId => text().withDefault(const Constant('CNY'))();
  
  /// Template ID (for template mode)
  TextColumn get templateId => text().nullable().withLength(min: 1, max: 36)();
  
  /// JSON-encoded split data (for split mode)
  TextColumn get splitData => text().nullable()();
  
  /// Creation timestamp
  IntColumn get createdAt => integer()();
  
  /// Last update timestamp
  IntColumn get updatedAt => integer()();
  
  /// User-defined name for the draft (optional)
  TextColumn get name => text().nullable()();
  
  @override
  Set<Column> get primaryKey => {id};
  
  @override
  List<Set<Column>>? get uniqueKeys => [
    {name},
  ];
}
