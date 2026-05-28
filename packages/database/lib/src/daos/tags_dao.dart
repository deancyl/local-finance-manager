part of '../database.dart';

/// Data Access Object for tags.
@DriftAccessor(tables: [Tags, TransactionTags, Transactions])
class TagsDao extends DatabaseAccessor<LocalFinanceDatabase> 
    with _$TagsDaoMixin, AuditableMixin {
  TagsDao(super.db);

  /// Watches all non-deleted tags.
  Stream<List<Tag>> watchAllTags() {
    return (select(tags)..where((t) => t.deletedAt.isNull())).watch();
  }

  /// Gets a tag by ID.
  Future<Tag?> getTagById(String id) {
    return (select(tags)..where((t) => t.id.equals(id))).getSingleOrNull();
  }

  /// Creates a new tag with a generated ID.
  Future<String> createTag({
    required String name,
    String color = '#607D8B',
    String? description,
    String? icon,
  }) async {
    final id = DateTime.now().microsecondsSinceEpoch.toString();
    final now = DateTime.now().millisecondsSinceEpoch;
    
    final tag = TagsCompanion.insert(
      id: id,
      name: name,
      color: Value(color),
      description: Value(description),
      icon: Value(icon),
      createdAt: now,
      updatedAt: now,
    );
    
    await into(tags).insert(tag);
    
    // Audit log for CREATE operation
    await logMutation(
      operation: 'CREATE',
      entityType: 'tag',
      entityId: id,
      newValue: tag.toJson(),
    );
    
    return id;
  }

  /// Updates an existing tag.
  Future<void> updateTag({
    required String id,
    String? name,
    String? color,
    String? description,
    String? icon,
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    
    // Get old value before update for audit log
    final oldTag = await getTagById(id);
    
    final updateData = TagsCompanion(
      updatedAt: Value(now),
      name: name != null ? Value(name) : const Value.absent(),
      color: color != null ? Value(color) : const Value.absent(),
      description: description != null ? Value(description) : const Value.absent(),
      icon: icon != null ? Value(icon) : const Value.absent(),
    );
    
    await (update(tags)..where((t) => t.id.equals(id))).write(updateData);
    
    // Audit log for UPDATE operation
    await logMutation(
      operation: 'UPDATE',
      entityType: 'tag',
      entityId: id,
      oldValue: oldTag?.toJson(),
      newValue: updateData.toJson(),
    );
  }

  /// Soft deletes a tag (sets deletedAt).
  Future<void> deleteTag(String id) async {
    // Get old value before soft delete for audit log
    final oldTag = await getTagById(id);
    
    final now = DateTime.now().millisecondsSinceEpoch;
    await (update(tags)..where((t) => t.id.equals(id))).write(
      TagsCompanion(
        deletedAt: Value(now),
        updatedAt: Value(now),
      ),
    );
    
    // Audit log for DELETE operation (soft delete)
    await logMutation(
      operation: 'DELETE',
      entityType: 'tag',
      entityId: id,
      oldValue: oldTag?.toJson(),
      description: 'Soft delete',
    );
  }

  /// Watches tags linked to a specific transaction.
  Stream<List<Tag>> watchTagsForTransaction(String transactionId) {
    final query = select(tags).join([
      innerJoin(transactionTags, transactionTags.tagId.equalsExp(tags.id)),
    ]);
    
    query.where(transactionTags.transactionId.equals(transactionId) & tags.deletedAt.isNull());
    
    return query.map((row) => row.readTable(tags)).watch();
  }

  /// Adds a tag to a transaction.
  Future<void> addTagToTransaction(String transactionId, String tagId) async {
    await into(transactionTags).insert(
      TransactionTagsCompanion.insert(
        transactionId: transactionId,
        tagId: tagId,
        createdAt: DateTime.now().millisecondsSinceEpoch,
      ),
      mode: InsertMode.insertOrIgnore,
    );
    
    // Increment usage count using custom statement
    await customStatement(
      'UPDATE tags SET usage_count = usage_count + 1 WHERE id = ?',
      [tagId],
    );
  }

  /// Removes a tag from a transaction.
  Future<void> removeTagFromTransaction(String transactionId, String tagId) async {
    await (delete(transactionTags)
          ..where((tt) => tt.transactionId.equals(transactionId) & tt.tagId.equals(tagId)))
        .go();
    
    // Decrement usage count using custom statement
    await customStatement(
      'UPDATE tags SET usage_count = usage_count - 1 WHERE id = ? AND usage_count > 0',
      [tagId],
    );
  }

  /// Gets all transactions with a specific tag.
  Future<List<Transaction>> getTransactionsWithTag(String tagId) async {
    final query = select(transactions).join([
      innerJoin(transactionTags, transactionTags.transactionId.equalsExp(transactions.id)),
    ]);
    
    query.where(transactionTags.tagId.equals(tagId));
    
    return query.map((row) => row.readTable(transactions)).get();
  }

  /// Updates tags for a transaction (replaces all existing tags).
  Future<void> updateTransactionTags(String transactionId, List<String> tagIds) async {
    // Get current tags
    final currentTags = await (select(transactionTags)
            ..where((tt) => tt.transactionId.equals(transactionId)))
        .get();
    
    final currentTagIds = currentTags.map((tt) => tt.tagId).toSet();
    final newTagIds = tagIds.toSet();
    
    // Remove tags that are no longer selected
    final tagsToRemove = currentTagIds.difference(newTagIds);
    for (final tagId in tagsToRemove) {
      await removeTagFromTransaction(transactionId, tagId);
    }
    
    // Add new tags
    final tagsToAdd = newTagIds.difference(currentTagIds);
    for (final tagId in tagsToAdd) {
      await addTagToTransaction(transactionId, tagId);
    }
  }

  /// Gets the count of transactions using a specific tag.
  Future<int> getTagUsageCount(String tagId) async {
    final query = selectOnly(transactionTags)
      ..addColumns([transactionTags.tagId.count()])
      ..where(transactionTags.tagId.equals(tagId));
    
    final result = await query.getSingle();
    return result.read(transactionTags.tagId.count()) ?? 0;
  }

  // ============================================================
  // TAG SEARCH AND AUTOCOMPLETE
  // ============================================================

  /// Searches tags by name (for autocomplete).
  /// Returns tags ordered by usage count (most used first).
  Stream<List<Tag>> searchTags(String query, {int limit = 10}) {
    final searchPattern = '%$query%';
    
    return (select(tags)
          ..where((t) => t.name.like(searchPattern) & t.deletedAt.isNull())
          ..orderBy([(t) => OrderingTerm.desc(t.usageCount)])
          ..limit(limit))
        .watch();
  }

  /// Gets tags matching any of the given IDs.
  Future<List<Tag>> getTagsByIds(List<String> tagIds) async {
    if (tagIds.isEmpty) return [];
    
    return (select(tags)
          ..where((t) => t.id.isIn(tagIds) & t.deletedAt.isNull()))
        .get();
  }

  /// Gets transaction IDs that have ALL specified tags (AND logic).
  Future<List<String>> getTransactionIdsWithAllTags(List<String> tagIds) async {
    if (tagIds.isEmpty) return [];
    
    // For each tag, get the transaction IDs
    final transactionIdSets = <Set<String>>[];
    
    for (final tagId in tagIds) {
      final ids = await (selectOnly(transactionTags)
            ..addColumns([transactionTags.transactionId])
            ..where(transactionTags.tagId.equals(tagId)))
          .map((row) => row.read(transactionTags.transactionId)!)
          .get();
      
      transactionIdSets.add(ids.toSet());
    }
    
    // Intersect all sets to get transactions with ALL tags
    if (transactionIdSets.isEmpty) return [];
    
    var result = transactionIdSets.first;
    for (var i = 1; i < transactionIdSets.length; i++) {
      result = result.intersection(transactionIdSets[i]);
    }
    
    return result.toList();
  }

  /// Gets transaction IDs that have ANY of the specified tags (OR logic).
  Future<List<String>> getTransactionIdsWithAnyTags(List<String> tagIds) async {
    if (tagIds.isEmpty) return [];
    
    final query = selectOnly(transactionTags)
      ..addColumns([transactionTags.transactionId])
      ..where(transactionTags.tagId.isIn(tagIds));
    
    final results = await query.get();
    final uniqueIds = results.map((r) => r.read(transactionTags.transactionId)!).toSet();
    return uniqueIds.toList();
  }

  // ============================================================
  // BULK TAG OPERATIONS
  // ============================================================

  /// Adds tags to multiple transactions (bulk operation).
  Future<void> addTagsToTransactions(List<String> transactionIds, List<String> tagIds) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    
    for (final transactionId in transactionIds) {
      for (final tagId in tagIds) {
        await into(transactionTags).insert(
          TransactionTagsCompanion.insert(
            transactionId: transactionId,
            tagId: tagId,
            createdAt: now,
          ),
          mode: InsertMode.insertOrIgnore,
        );
      }
    }
    
    // Update usage counts for all added tags
    for (final tagId in tagIds) {
      final count = await getTagUsageCount(tagId);
      await (update(tags)..where((t) => t.id.equals(tagId))).write(
        TagsCompanion(usageCount: Value(count)),
      );
    }
  }

  /// Removes tags from multiple transactions (bulk operation).
  Future<void> removeTagsFromTransactions(List<String> transactionIds, List<String> tagIds) async {
    for (final transactionId in transactionIds) {
      await (delete(transactionTags)
            ..where((tt) =>
                tt.transactionId.equals(transactionId) & tt.tagId.isIn(tagIds)))
          .go();
    }
    
    // Update usage counts for all removed tags
    for (final tagId in tagIds) {
      final count = await getTagUsageCount(tagId);
      await (update(tags)..where((t) => t.id.equals(tagId))).write(
        TagsCompanion(usageCount: Value(count)),
      );
    }
  }

  /// Replaces all tags on multiple transactions (bulk operation).
  Future<void> setTagsOnTransactions(List<String> transactionIds, List<String> tagIds) async {
    for (final transactionId in transactionIds) {
      await updateTransactionTags(transactionId, tagIds);
    }
  }

  /// Gets tags with their transaction counts for statistics.
  Stream<List<(Tag, int)>> watchTagsWithTransactionCount() {
    // Simple implementation without join - use usage count from tags table
    return (select(tags)
          ..where((t) => t.deletedAt.isNull())
          ..orderBy([(t) => OrderingTerm.desc(t.usageCount)]))
        .watch()
        .map((tagsList) {
      return tagsList.map((tag) => (tag, tag.usageCount)).toList();
    });
  }

  /// Gets most popular tags (by usage count).
  Future<List<Tag>> getPopularTags({int limit = 10}) async {
    return (select(tags)
          ..where((t) => t.deletedAt.isNull() & t.usageCount.isBiggerOrEqualValue(0))
          ..orderBy([(t) => OrderingTerm.desc(t.usageCount)])
          ..limit(limit))
        .get();
  }
}