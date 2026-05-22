import 'package:drift/drift.dart';

/// Exchange rates table - stores currency exchange rates
/// Supports multiple rate sources and historical rates
class ExchangeRates extends Table {
  TextColumn get id => text()();
  TextColumn get fromCurrency => text().withLength(min: 3, max: 10)();
  TextColumn get toCurrency => text().withLength(min: 3, max: 10)();
  RealColumn get rate => real()();
  IntColumn get date => integer()(); // Unix timestamp for the rate date
  TextColumn get source => text().withDefault(const Constant('manual'))();
  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();

  @override
  Set<Column> get primaryKey => {id};

  @override
  List<Set<Column>> get uniqueKeys => [
    {fromCurrency, toCurrency, date, source},
  ];
}
