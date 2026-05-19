import 'package:drift/drift.dart';

/// Transactions table - journal entry headers.
class Transactions extends Table {
  TextColumn get id => text()();
  TextColumn get description => text().nullable()();
  IntColumn get postDate => integer()();
  IntColumn get enterDate => integer()();
  TextColumn get currencyId => text().references(Commodities, #id)();
  TextColumn get referenceNum => text().nullable()();
  TextColumn get notes => text().nullable()();
  TextColumn get importBatchId => text().nullable().references(ImportBatches, #id)();
  TextColumn get externalId => text().nullable()();
  BoolColumn get isDoubleEntry => boolean().withDefault(const Constant(false))();
  TextColumn get idempotencyKey => text().nullable().unique()();
  IntColumn get version => integer().withDefault(const Constant(1))();
  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();
  IntColumn get deletedAt => integer().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Splits table - individual debit/credit entries.
class Splits extends Table {
  TextColumn get id => text()();
  TextColumn get transactionId => text().references(Transactions, #id)();
  TextColumn get accountId => text().references(Accounts, #id)();
  TextColumn get memo => text().nullable()();
  IntColumn get valueNum => integer()();
  IntColumn get valueDenom => integer().withDefault(const Constant(1))();
  IntColumn get quantityNum => integer()();
  IntColumn get quantityDenom => integer().withDefault(const Constant(1))();
  TextColumn get reconcileState => text().withLength(min: 1, max: 1).withDefault(const Constant('n'))();
  IntColumn get reconcileDate => integer().nullable()();
  IntColumn get version => integer().withDefault(const Constant(1))();
  IntColumn get createdAt => integer()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Reference tables for foreign keys.
class Commodities extends Table {
  TextColumn get id => text()();
  @override
  Set<Column> get primaryKey => {id};
}

class Accounts extends Table {
  TextColumn get id => text()();
  @override
  Set<Column> get primaryKey => {id};
}

class ImportBatches extends Table {
  TextColumn get id => text()();
  @override
  Set<Column> get primaryKey => {id};
}