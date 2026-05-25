part of '../database.dart';

/// Data Access Object for saved searches and search history.
@DriftAccessor(tables: [SavedSearches, SearchHistory])
class SavedSearchDao extends DatabaseAccessor<LocalFinanceDatabase> with _$SavedSearchDaoMixin {
  SavedSearchDao(super.db);

  /// Gets all saved searches, sorted by use count (most used first).
  Future<List<SavedSearch>> getAll() async {
    final results = await (select(savedSearches)
          ..orderBy([(s) => OrderingTerm.desc(s.useCount)])
          ..orderBy([(s) => OrderingTerm.desc(s.isFavorite)]))
        .get();
    return results.map(_mapToModel).toList();
  }

  /// Gets favorite saved searches.
  Future<List<SavedSearch>> getFavorites() async {
    final results = await (select(savedSearches)
          ..where((s) => s.isFavorite.equals(true))
          ..orderBy([(s) => OrderingTerm.desc(s.useCount)]))
        .get();
    return results.map(_mapToModel).toList();
  }

  /// Gets a saved search by ID.
  Future<SavedSearch?> getById(String id) async {
    final result = await (select(savedSearches)..where((s) => s.id.equals(id))).getSingleOrNull();
    return result != null ? _mapToModel(result) : null;
  }

  /// Creates a new saved search.
  Future<String> create(SavedSearch search) async {
    await into(savedSearches).insert(_mapToCompanion(search));
    return search.id;
  }

  /// Updates an existing saved search.
  Future<void> update(SavedSearch search) async {
    await (this.savedSearches).replace(_mapToCompanion(search));
  }

  /// Deletes a saved search.
  Future<void> delete(String id) async {
    await (delete(savedSearches)..where((s) => s.id.equals(id))).go();
  }

  /// Increments the use count for a saved search.
  Future<void> incrementUseCount(String id) async {
    final search = await getById(id);
    if (search != null) {
      await update(search.withIncrementedUseCount());
    }
  }

  /// Toggles the favorite status of a saved search.
  Future<void> toggleFavorite(String id) async {
    final search = await getById(id);
    if (search != null) {
      await update(search.copyWith(isFavorite: !search.isFavorite));
    }
  }

  /// Gets recent search history, limited to the last N entries.
  Future<List<SearchHistoryEntry>> getRecentHistory({int limit = 20}) async {
    final results = await (select(searchHistory)
          ..orderBy([(s) => OrderingTerm.desc(s.searchedAt)])
          ..limit(limit))
        .get();
    return results.map((r) => SearchHistoryEntry(
      id: r.id,
      query: r.query,
      searchedAt: DateTime.fromMillisecondsSinceEpoch(r.searchedAt),
    )).toList();
  }

  /// Adds a search query to history.
  Future<void> addToHistory(String query) async {
    if (query.trim().isEmpty) return;
    
    final entry = SearchHistoryEntry.create(query: query.trim());
    await into(searchHistory).insert(SearchHistoryCompanion.insert(
      id: entry.id,
      query: entry.query,
      searchedAt: entry.searchedAt.millisecondsSinceEpoch,
    ));
  }

  /// Clears all search history.
  Future<void> clearHistory() async {
    await delete(searchHistory).go();
  }

  /// Removes duplicate search history entries, keeping only the most recent.
  Future<void> deduplicateHistory() async {
    await customStatement('''
      DELETE FROM search_history
      WHERE rowid NOT IN (
        SELECT MAX(rowid)
        FROM search_history
        GROUP BY query
      )
    ''');
  }

  /// Maps a database row to a SavedSearch model.
  SavedSearch _mapToModel(SavedSearch data) {
    return SavedSearch(
      id: data.id,
      name: data.name,
      description: data.description,
      startDate: data.startDate != null
          ? DateTime.fromMillisecondsSinceEpoch(data.startDate!)
          : null,
      endDate: data.endDate != null
          ? DateTime.fromMillisecondsSinceEpoch(data.endDate!)
          : null,
      categoryId: data.categoryId,
      accountId: data.accountId,
      searchQuery: data.searchQuery,
      minAmount: data.minAmount,
      maxAmount: data.maxAmount,
      tagIds: data.tagIds != null && data.tagIds!.isNotEmpty
          ? data.tagIds!.split(',')
          : [],
      isFavorite: data.isFavorite,
      useCount: data.useCount,
      createdAt: DateTime.fromMillisecondsSinceEpoch(data.createdAt),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(data.updatedAt),
    );
  }

  /// Maps a SavedSearch model to a database companion.
  SavedSearchesCompanion _mapToCompanion(SavedSearch model) {
    return SavedSearchesCompanion.insert(
      id: model.id,
      name: model.name,
      description: Value(model.description),
      startDate: Value(model.startDate?.millisecondsSinceEpoch),
      endDate: Value(model.endDate?.millisecondsSinceEpoch),
      categoryId: Value(model.categoryId),
      accountId: Value(model.accountId),
      searchQuery: Value(model.searchQuery),
      minAmount: Value(model.minAmount),
      maxAmount: Value(model.maxAmount),
      tagIds: Value(model.tagIds.isEmpty ? null : model.tagIds.join(',')),
      isFavorite: Value(model.isFavorite),
      useCount: Value(model.useCount),
      createdAt: model.createdAt.millisecondsSinceEpoch,
      updatedAt: model.updatedAt.millisecondsSinceEpoch,
    );
  }
}
