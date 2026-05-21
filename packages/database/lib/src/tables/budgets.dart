import 'package:drift/drift.dart';
import 'categories.dart';
import 'commodities.dart';

/// Budgets table - spending limits per category.
class Budgets extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get categoryId => text().nullable().references(Categories, #id)();
  IntColumn get amountNum => integer()();
  IntColumn get amountDenom => integer().withDefault(const Constant(1))();
  TextColumn get currencyId => text().references(Commodities, #id)();
  TextColumn get period => text().withLength(min: 1, max: 20)();
  IntColumn get startDate => integer()();
  IntColumn get endDate => integer().nullable()();
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
  // Alert settings
  BoolColumn get alertEnabled => boolean().withDefault(const Constant(true))();
  BoolColumn get alertAt50 => boolean().withDefault(const Constant(true))();
  BoolColumn get alertAt75 => boolean().withDefault(const Constant(true))();
  BoolColumn get alertAt90 => boolean().withDefault(const Constant(true))();
  BoolColumn get alertAt100 => boolean().withDefault(const Constant(true))();
  IntColumn get createdAt => integer()();
  IntColumn get version => integer().withDefault(const Constant(1))();
  DateTimeColumn get updatedAt => dateTime()();
  DateTimeColumn get deletedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}