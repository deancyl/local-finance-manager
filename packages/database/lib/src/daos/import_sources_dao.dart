import 'package:drift/drift.dart';

import '../database.dart';

part 'import_sources_dao.g.dart';

/// Data Access Object for import sources.
@DriftAccessor(tables: [ImportSources, ImportBatches])
class ImportSourcesDao extends DatabaseAccessor<LocalFinanceDatabase> with _$ImportSourcesDaoMixin {
  ImportSourcesDao(super.db);

  /// Gets all import sources.
  Future<List<ImportSource>> getAllSources() => select(importSources).get();

  /// Gets an import source by ID.
  Future<ImportSource?> getSourceById(String id) {
    return (select(importSources)..where((s) => s.id.equals(id))).getSingleOrNull();
  }

  /// Gets active import sources.
  Future<List<ImportSource>> getActiveSources() {
    return (select(importSources)..where((s) => s.isActive.equals(true))).get();
  }

  /// Creates a new import source.
  Future<String> createSource(ImportSourcesCompanion source) async {
    await into(importSources).insert(source);
    return source.id.value;
  }

  /// Updates an existing import source.
  Future<void> updateSource(ImportSourcesCompanion source) async {
    await (update(importSources)..where((s) => s.id.equals(source.id.value))).write(source);
  }

  /// Gets import batches for a source.
  Future<List<ImportBatch>> getBatchesBySource(String sourceId) {
    return (select(importBatches)..where((b) => b.sourceId.equals(sourceId))).get();
  }

  /// Creates a new import batch.
  Future<String> createBatch(ImportBatchesCompanion batch) async {
    await into(importBatches).insert(batch);
    return batch.id.value;
  }

  /// Updates an import batch.
  Future<void> updateBatch(ImportBatchesCompanion batch) async {
    await (update(importBatches)..where((b) => b.id.equals(batch.id.value))).write(batch);
  }
}