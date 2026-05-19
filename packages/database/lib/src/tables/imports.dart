import 'package:drift/drift.dart';

/// Import sources table - financial institutions and data sources.
class ImportSources extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get sourceType => text().withLength(min: 1, max: 20)();
  TextColumn get institutionId => text().nullable()();
  TextColumn get accountId => text().nullable().references(Accounts, #id)();
  TextColumn get config => text().nullable()();
  IntColumn get lastImportAt => integer().nullable()();
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
  IntColumn get createdAt => integer()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Import batches table - tracking import operations.
class ImportBatches extends Table {
  TextColumn get id => text()();
  TextColumn get sourceId => text().references(ImportSources, #id)();
  IntColumn get importedAt => integer()();
  TextColumn get filename => text().nullable()();
  IntColumn get recordCount => integer().withDefault(const Constant(0))();
  IntColumn get successCount => integer().withDefault(const Constant(0))();
  IntColumn get duplicateCount => integer().withDefault(const Constant(0))();
  IntColumn get errorCount => integer().withDefault(const Constant(0))();
  TextColumn get status => text().withLength(min: 1, max: 20)();
  TextColumn get errorDetails => text().nullable()();
  IntColumn get createdAt => integer()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Reference table for foreign key.
class Accounts extends Table {
  TextColumn get id => text()();
  @override
  Set<Column> get primaryKey => {id};
}