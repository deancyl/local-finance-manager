import 'package:drift/drift.dart';
import 'commodities.dart';

/// Accounts table - chart of accounts with hierarchical structure.
class Accounts extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get accountType => text().withLength(min: 1, max: 20)();
  TextColumn get parentId => text().nullable().references(Accounts, #id)();
  TextColumn get commodityId => text().references(Commodities, #id)();
  TextColumn get code => text().nullable()();
  TextColumn get description => text().nullable()();
  BoolColumn get isPlaceholder => boolean().withDefault(const Constant(false))();
  BoolColumn get isHidden => boolean().withDefault(const Constant(false))();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();
  IntColumn get version => integer().withDefault(const Constant(1))();

  @override
  Set<Column> get primaryKey => {id};
}