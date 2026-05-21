import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart' as drift;
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:crypto/crypto.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:convert';

import 'package:database/database.dart';
import 'package:finance_app/features/accounts/data/account_provider.dart';

/// Provider that watches attachments for a specific transaction.
final transactionAttachmentsProvider = StreamProvider.family<List<Attachment>, String>((ref, transactionId) {
  final db = ref.watch(databaseProvider);
  return db.attachmentsDao.watchByTransaction(transactionId);
});

/// Provider that gets attachment count for a transaction.
final attachmentCountProvider = FutureProvider.family<int, String>((ref, transactionId) async {
  final db = ref.watch(databaseProvider);
  return db.attachmentsDao.getAttachmentCount(transactionId);
});

/// Notifier for attachment CRUD operations.
class AttachmentNotifier extends StateNotifier<AsyncValue<void>> {
  final LocalFinanceDatabase _db;

  AttachmentNotifier(this._db) : super(const AsyncValue.data(null));

  /// Creates an attachment from a file.
  Future<String?> createAttachment({
    required String transactionId,
    required File file,
    required String fileName,
    required String fileType,
    String? description,
  }) async {
    state = const AsyncValue.loading();
    try {
      // Get app document directory for storing attachments
      final appDir = await getApplicationDocumentsDirectory();
      final attachmentsDir = Directory(p.join(appDir.path, 'attachments'));
      
      // Create attachments directory if it doesn't exist
      if (!await attachmentsDir.exists()) {
        await attachmentsDir.create(recursive: true);
      }
      
      // Generate unique filename
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final extension = p.extension(fileName);
      final uniqueFileName = '${transactionId}_$timestamp$extension';
      final destinationPath = p.join(attachmentsDir.path, uniqueFileName);
      
      // Copy file to attachments directory
      await file.copy(destinationPath);
      
      // Calculate file hash for deduplication
      final bytes = await file.readAsBytes();
      final hash = md5.convert(bytes).toString();
      
      // Get file size
      final fileSize = await file.length();
      
      // Generate thumbnail for images
      String? thumbnailPath;
      int? thumbnailWidth;
      int? thumbnailHeight;
      
      if (fileType.startsWith('image/')) {
        // For now, use the original file as thumbnail
        // In a real app, you'd generate a smaller thumbnail
        thumbnailPath = destinationPath;
        thumbnailWidth = 200;
        thumbnailHeight = 200;
      }
      
      // Get current attachment count for sort order
      final currentAttachments = await _db.attachmentsDao.getByTransaction(transactionId);
      final sortOrder = currentAttachments.length;
      
      final id = await _db.attachmentsDao.createAttachment(
        transactionId: transactionId,
        fileName: fileName,
        filePath: destinationPath,
        fileType: fileType,
        fileSize: fileSize,
        thumbnailPath: thumbnailPath,
        thumbnailWidth: thumbnailWidth,
        thumbnailHeight: thumbnailHeight,
        fileHash: hash,
        description: description,
        sortOrder: sortOrder,
      );
      
      state = const AsyncValue.data(null);
      return id;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return null;
    }
  }

  /// Updates an attachment's description.
  Future<void> updateAttachmentDescription(String id, String? description) async {
    state = const AsyncValue.loading();
    try {
      await _db.attachmentsDao.updateAttachment(
        id: id,
        description: description,
      );
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  /// Soft deletes an attachment.
  Future<void> deleteAttachment(String id) async {
    state = const AsyncValue.loading();
    try {
      await _db.attachmentsDao.deleteAttachment(id);
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  /// Permanently deletes an attachment and its file.
  Future<void> hardDeleteAttachment(String id) async {
    state = const AsyncValue.loading();
    try {
      // Get attachment to find file path
      final attachment = await _db.attachmentsDao.getById(id);
      
      if (attachment != null) {
        // Delete the file
        final file = File(attachment.filePath);
        if (await file.exists()) {
          await file.delete();
        }
        
        // Delete thumbnail if different from main file
        if (attachment.thumbnailPath != null && 
            attachment.thumbnailPath != attachment.filePath) {
          final thumbnailFile = File(attachment.thumbnailPath!);
          if (await thumbnailFile.exists()) {
            await thumbnailFile.delete();
          }
        }
      }
      
      // Delete from database
      await _db.attachmentsDao.hardDeleteAttachment(id);
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  /// Reorders attachments.
  Future<void> reorderAttachments(String transactionId, List<String> attachmentIds) async {
    state = const AsyncValue.loading();
    try {
      final orders = attachmentIds
          .asMap()
          .entries
          .map((e) => (e.value, e.key))
          .toList();
      
      await _db.attachmentsDao.updateSortOrders(orders);
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  /// Creates attachment from camera.
  Future<String?> createAttachmentFromCamera({
    required String transactionId,
  }) async {
    try {
      final picker = ImagePicker();
      final image = await picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 85,
        maxWidth: 1920,
        maxHeight: 1920,
      );

      if (image != null) {
        return await createAttachment(
          transactionId: transactionId,
          file: File(image.path),
          fileName: image.name,
          fileType: AttachmentUtils.getMimeType(image.name),
        );
      }
      return null;
    } catch (e) {
      state = AsyncValue.error(e, StackTrace.current);
      return null;
    }
  }

  /// Creates attachment from gallery.
  Future<List<String>> createAttachmentFromGallery({
    required String transactionId,
  }) async {
    try {
      final picker = ImagePicker();
      final images = await picker.pickMultiImage(
        imageQuality: 85,
        maxWidth: 1920,
        maxHeight: 1920,
      );

      final ids = <String>[];
      for (final image in images) {
        final id = await createAttachment(
          transactionId: transactionId,
          file: File(image.path),
          fileName: image.name,
          fileType: AttachmentUtils.getMimeType(image.name),
        );
        if (id != null) ids.add(id);
      }
      return ids;
    } catch (e) {
      state = AsyncValue.error(e, StackTrace.current);
      return [];
    }
  }

  /// Creates attachment from file picker.
  Future<List<String>> createAttachmentFromFile({
    required String transactionId,
  }) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: [
          'jpg', 'jpeg', 'png', 'gif', 'webp',
          'pdf',
          'doc', 'docx',
          'xls', 'xlsx',
        ],
      );

      final ids = <String>[];
      if (result != null) {
        for (final file in result.files) {
          if (file.path != null) {
            final id = await createAttachment(
              transactionId: transactionId,
              file: File(file.path!),
              fileName: file.name,
              fileType: AttachmentUtils.getMimeType(file.name),
            );
            if (id != null) ids.add(id);
          }
        }
      }
      return ids;
    } catch (e) {
      state = AsyncValue.error(e, StackTrace.current);
      return [];
    }
  }
}

/// Provider for the attachment notifier.
final attachmentNotifierProvider = StateNotifierProvider<AttachmentNotifier, AsyncValue<void>>((ref) {
  final db = ref.watch(databaseProvider);
  return AttachmentNotifier(db);
});

/// Helper class for file utilities.
class AttachmentUtils {
  /// Gets the MIME type from file extension.
  static String getMimeType(String fileName) {
    final extension = p.extension(fileName).toLowerCase();
    switch (extension) {
      case '.jpg':
      case '.jpeg':
        return 'image/jpeg';
      case '.png':
        return 'image/png';
      case '.gif':
        return 'image/gif';
      case '.webp':
        return 'image/webp';
      case '.pdf':
        return 'application/pdf';
      case '.doc':
        return 'application/msword';
      case '.docx':
        return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
      case '.xls':
        return 'application/vnd.ms-excel';
      case '.xlsx':
        return 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';
      default:
        return 'application/octet-stream';
    }
  }

  /// Checks if the file type is an image.
  static bool isImage(String mimeType) {
    return mimeType.startsWith('image/');
  }

  /// Checks if the file type is a PDF.
  static bool isPdf(String mimeType) {
    return mimeType == 'application/pdf';
  }

  /// Gets a user-friendly file type name.
  static String getFileTypeName(String mimeType) {
    if (isImage(mimeType)) return 'Image';
    if (isPdf(mimeType)) return 'PDF';
    if (mimeType.startsWith('video/')) return 'Video';
    if (mimeType.startsWith('audio/')) return 'Audio';
    return 'Document';
  }

  /// Formats file size for display.
  static String formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }
}
