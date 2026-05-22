import 'package:drift/drift.dart';

/// Cost centers for tracking expenses by department/project.
/// Used for management accounting and cost allocation.
class CostCenters extends Table {
  /// Unique identifier (e.g., 'CC001', 'PROJECT-A')
  TextColumn get id => text()();

  /// Cost center name (e.g., 'Marketing Department', 'Project Alpha')
  TextColumn get name => text()();

  /// Cost center code (optional, for reference)
  TextColumn get code => text().nullable()();

  /// Parent cost center ID (for hierarchical cost centers)
  TextColumn get parentId => text().nullable()();

  /// Cost center type (DEPARTMENT, PROJECT, ACTIVITY, LOCATION)
  TextColumn get costCenterType => text().withDefault(const Constant('DEPARTMENT'))();

  /// Description
  TextColumn get description => text().nullable()();

  /// Whether this cost center is active
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();

  /// Manager/responsible person ID (optional)
  TextColumn get managerId => text().nullable()();

  /// Budget limit (optional, in cents)
  IntColumn get budgetLimitNum => integer().nullable()();

  /// Budget limit denominator
  IntColumn get budgetLimitDenom => integer().nullable()();

  /// Budget currency
  TextColumn get budgetCurrency => text().nullable()();

  /// Sort order for display
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();

  /// Version for sync
  IntColumn get version => integer().withDefault(const Constant(1))();

  /// Created timestamp (milliseconds since epoch)
  IntColumn get createdAt => integer()();

  /// Updated timestamp (milliseconds since epoch)
  IntColumn get updatedAt => integer()();

  /// Soft delete timestamp
  IntColumn get deletedAt => integer().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}