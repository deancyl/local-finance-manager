import 'package:drift/drift.dart';
import 'categories.dart';
import 'accounts.dart';

/// SavedSearches table - stores user's saved search presets.
///
/// Allows users to save frequently used search filters for quick access.
class SavedSearches extends Table {
  TextColumn get id => text()();
  
  /// Search preset name
  TextColumn get name => text()();
  
  /// Optional description
  TextColumn get description => text().nullable()();
  
  /// Date range filter - start
  IntColumn get startDate => integer().nullable()();
  
  /// Date range filter - end
  IntColumn get endDate => integer().nullable()();
  
  /// Category filter
  TextColumn get categoryId => text().nullable().references(Categories, #id)();
  
  /// Account filter
  TextColumn get accountId => text().nullable().references(Accounts, #id)();
  
  /// Full-text search query
  TextColumn get searchQuery => text().nullable()();
  
  /// Amount range filter - minimum
  RealColumn get minAmount => real().nullable()();
  
  /// Amount range filter - maximum
  RealColumn get maxAmount => real().nullable()();
  
  /// Tag IDs (comma-separated)
  TextColumn get tagIds => text().nullable()();
  
  /// Whether this is a favorite search
  BoolColumn get isFavorite => boolean().withDefault(const Constant(false))();
  
  /// Usage count for sorting by most used
  IntColumn get useCount => integer().withDefault(const Constant(0))();
  
  /// Standard tracking columns
  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();

  @override
  Set<Column> get primaryKey => {id};
}

/// SearchHistory table - stores recent search queries.
///
/// Tracks user's search history for quick re-use.
class SearchHistory extends Table {
  TextColumn get id => text()();
  
  /// The search query text
  TextColumn get query => text()();
  
  /// When this search was performed
  IntColumn get searchedAt => integer()();

  @override
  Set<Column> get primaryKey => {id};
}
