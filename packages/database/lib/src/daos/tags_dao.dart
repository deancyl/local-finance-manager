part of '../database.dart';

/// Data Access Object for tags.
@DriftAccessor(tables: [Tags, TransactionTags])
class TagsDao extends DatabaseAccessor<LocalFinanceDatabase> with _$TagsDaoMixin {
  TagsDao(super.db);

  /// Watches all non-deleted tags.
  Stream<List<Tag>> watchAllTags() {
    return (select(tags)..where((t) => t.deletedAt.isNull())).watch();
  }

  /// Gets a tag by ID.
  Future<Tag?> getTagById(String id) {
    return (select(tags)..where((t) => t.id.equals(id))).getSingleOrNull();
  }

  /// Creates a new tag.
  Future<String> createTag({
    required String name,
    String color = '#607D8B',
    String? description,
    String? icon,
  }) async {
    final id = const Uuid().v4();
    final now = DateTime.now().millisecondsSinceEpoch;
    
    await into(tags).insert(
      TagsCompanion.insert(
        id: id,
        name: name,
        color: Value(color),
        description: Value(description),
        icon: Value(icon),
        createdAt: now,
        updatedAt: now,
      ),
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
    
    await (update(tags)..where((t) => t.id.equals(id))).write(
      TagsCompanion(
        updatedAt: Value(now),
        name: name != null ? Value(name) : const Value.absent(),
        color: color != null ? Value(color) : const Value.absent(),
        description: description != null ? Value(description) : const Value.absent(),
        icon: icon != null ? Value(icon) : const Value.absent(),
      ),
    );
  }

  /// Soft deletes a tag (sets deletedAt).
  Future<void> deleteTag(String id) async {
    await (update(tags)..where((t) => t.id.equals(id))).write(
      TagsCompanion(
        deletedAt: Value(DateTime.now().millisecondsSinceEpoch),
        updatedAt: Value(DateTime.now().millisecondsSinceEpoch),
      ),
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
    
    // Increment usage count
    await (update(tags)..where((t) => t.id.equals(tagId))).write(
      TagsCompanion(
        usageCount: tags.usageCount + const Value(1),
      ),
    );
  }

  /// Removes a tag from a transaction.
  Future<void> removeTagFromTransaction(String transactionId, String tagId) async {
    await (delete(transactionTags)
          ..where((tt) => tt.transactionId.equals(transactionId) & tt.tagId.equals(tagId)))
        .go();
    
    // Decrement usage count
    await (update(tags)..where((t) => t.id.equals(tagId))).write(
      TagsCompanion(
        usageCount: tags.usageCount - const Value(1),
      ),
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
}
