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
  IntColumn get createdAt => integer()();

  @override
  Set<Column> get primaryKey => {id};
}