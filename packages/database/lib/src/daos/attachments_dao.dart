part of '../database.dart';

/// Data Access Object for attachments.
@DriftAccessor(tables: [Attachments])
class AttachmentsDao extends DatabaseAccessor<LocalFinanceDatabase> with _$AttachmentsDaoMixin {
  AttachmentsDao(super.db);

  /// Watches all non-deleted attachments for a specific transaction.
  Stream<List<Attachment>> watchByTransaction(String transactionId) {
    return (select(attachments)
      ..where((a) => a.transactionId.equals(transactionId) & a.deletedAt.isNull())
      ..orderBy([(a) => OrderingTerm(expression: a.sortOrder)]))
      .watch();
  }

  /// Gets all non-deleted attachments for a specific transaction.
  Future<List<Attachment>> getByTransaction(String transactionId) {
    return (select(attachments)
      ..where((a) => a.transactionId.equals(transactionId) & a.deletedAt.isNull())
      ..orderBy([(a) => OrderingTerm(expression: a.sortOrder)]))
      .get();
  }

  /// Gets an attachment by ID.
  Future<Attachment?> getById(String id) {
    return (select(attachments)..where((a) => a.id.equals(id))).getSingleOrNull();
  }

  /// Creates a new attachment with a generated ID.
  Future<String> createAttachment({
    required String transactionId,
    required String fileName,
    required String filePath,
    required String fileType,
    required int fileSize,
    String? thumbnailPath,
    int? thumbnailWidth,
    int? thumbnailHeight,
    String? fileHash,
    String? description,
    int sortOrder = 0,
  }) async {
    final id = DateTime.now().microsecondsSinceEpoch.toString();
    final now = DateTime.now().millisecondsSinceEpoch;
    
    await into(attachments).insert(
      AttachmentsCompanion.insert(
        id: id,
        transactionId: transactionId,
        fileName: fileName,
        filePath: filePath,
        fileType: fileType,
        fileSize: fileSize,
        thumbnailPath: Value(thumbnailPath),
        thumbnailWidth: Value(thumbnailWidth),
        thumbnailHeight: Value(thumbnailHeight),
        fileHash: Value(fileHash),
        description: Value(description),
        sortOrder: Value(sortOrder),
        createdAt: now,
        updatedAt: now,
      ),
    );
    return id;
  }

  /// Updates an existing attachment.
  Future<void> updateAttachment({
    required String id,
    String? fileName,
    String? filePath,
    String? fileType,
    int? fileSize,
    String? thumbnailPath,
    int? thumbnailWidth,
    int? thumbnailHeight,
    String? fileHash,
    String? description,
    int? sortOrder,
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    
    await (update(attachments)..where((a) => a.id.equals(id))).write(
      AttachmentsCompanion(
        updatedAt: Value(now),
        fileName: fileName != null ? Value(fileName) : const Value.absent(),
        filePath: filePath != null ? Value(filePath) : const Value.absent(),
        fileType: fileType != null ? Value(fileType) : const Value.absent(),
        fileSize: fileSize != null ? Value(fileSize) : const Value.absent(),
        thumbnailPath: thumbnailPath != null ? Value(thumbnailPath) : const Value.absent(),
        thumbnailWidth: thumbnailWidth != null ? Value(thumbnailWidth) : const Value.absent(),
        thumbnailHeight: thumbnailHeight != null ? Value(thumbnailHeight) : const Value.absent(),
        fileHash: fileHash != null ? Value(fileHash) : const Value.absent(),
        description: description != null ? Value(description) : const Value.absent(),
        sortOrder: sortOrder != null ? Value(sortOrder) : const Value.absent(),
      ),
    );
  }

  /// Soft deletes an attachment (sets deletedAt).
  Future<void> deleteAttachment(String id) async {
    await (update(attachments)..where((a) => a.id.equals(id))).write(
      AttachmentsCompanion(
        deletedAt: Value(DateTime.now().millisecondsSinceEpoch),
        updatedAt: Value(DateTime.now().millisecondsSinceEpoch),
      ),
    );
  }

  /// Permanently deletes an attachment (hard delete).
  Future<void> hardDeleteAttachment(String id) async {
    await (delete(attachments)..where((a) => a.id.equals(id))).go();
  }

  /// Gets the count of attachments for a transaction.
  Future<int> getAttachmentCount(String transactionId) async {
    final query = selectOnly(attachments)
      ..addColumns([attachments.id.count()])
      ..where(attachments.transactionId.equals(transactionId) & attachments.deletedAt.isNull());
    
    final result = await query.getSingle();
    return result.read(attachments.id.count()) ?? 0;
  }

  /// Updates sort order for multiple attachments.
  Future<void> updateSortOrders(List<(String, int)> orders) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    
    for (final (id, order) in orders) {
      await (update(attachments)..where((a) => a.id.equals(id))).write(
        AttachmentsCompanion(
          sortOrder: Value(order),
          updatedAt: Value(now),
        ),
      );
    }
  }

  /// Finds duplicate attachments by file hash.
  Future<List<Attachment>> findByHash(String fileHash) {
    return (select(attachments)
      ..where((a) => a.fileHash.equals(fileHash) & a.deletedAt.isNull()))
      .get();
  }

  /// Watches all attachments (for debugging/admin purposes).
  Stream<List<Attachment>> watchAll() {
    return (select(attachments)..where((a) => a.deletedAt.isNull())).watch();
  }
}