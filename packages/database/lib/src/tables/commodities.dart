import 'package:drift/drift.dart';

/// Commodities table - currencies, stocks, crypto, etc.
class Commodities extends Table {
  TextColumn get id => text()();
  TextColumn get namespace => text().withLength(min: 1, max: 50)();
  TextColumn get mnemonic => text().withLength(min: 1, max: 10)();
  TextColumn get fullName => text().nullable()();
  IntColumn get fraction => integer().withDefault(const Constant(100))();
  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();

  @override
  Set<Column> get primaryKey => {id};

  @override
  List<Set<Column>> get uniqueKeys => [
    {namespace, mnemonic},
  ];
}