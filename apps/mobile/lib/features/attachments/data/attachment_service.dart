import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:crypto/crypto.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:convert';

import 'package:database/database.dart';

/// Service for managing file attachments.
/// 
/// Handles:
/// - File storage and retrieval
/// - Thumbnail generation
/// - File deduplication via hash
/// - Camera/gallery/file picker integration
class AttachmentService {
  final LocalFinanceDatabase _db;

  AttachmentService(this._db);

  /// Gets the attachments directory path.
  Future<String> getAttachmentsDirPath() async {
    final appDir = await getApplicationDocumentsDirectory();
    return p.join(appDir.path, 'attachments');
  }

  /// Gets the attachments directory, creating it if needed.
  Future<Directory> getAttachmentsDir() async {
    final path = await getAttachmentsDirPath();
    final dir = Directory(path);
    
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    
    return dir;
  }

  /// Stores a file in the attachments directory.
  /// 
  /// Returns the path where the file was stored.
  Future<String> storeFile({
    required File file,
    required String transactionId,
    required String fileName,
  }) async {
    final attachmentsDir = await getAttachmentsDir();
    
    // Generate unique filename
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final extension = p.extension(fileName);
    final uniqueFileName = '${transactionId}_$timestamp$extension';
    final destinationPath = p.join(attachmentsDir.path, uniqueFileName);
    
    // Copy file to attachments directory
    await file.copy(destinationPath);
    
    return destinationPath;
  }

  /// Calculates the MD5 hash of a file for deduplication.
  Future<String> calculateFileHash(File file) async {
    final bytes = await file.readAsBytes();
    return md5.convert(bytes).toString();
  }

  /// Gets file size in bytes.
  Future<int> getFileSize(File file) async {
    return await file.length();
  }

  /// Generates thumbnail info for an image file.
  /// 
  /// For now, uses the original file as thumbnail.
  /// In production, would generate a smaller thumbnail.
  Future<ThumbnailInfo?> generateThumbnail({
    required String filePath,
    required String mimeType,
  }) async {
    if (!mimeType.startsWith('image/')) {
      return null;
    }
    
    // For now, use the original file as thumbnail
    // In a real app, you'd generate a smaller thumbnail using image package
    return ThumbnailInfo(
      path: filePath,
      width: 200,
      height: 200,
    );
  }

  /// Creates an attachment record in the database.
  Future<String> createAttachment({
    required String transactionId,
    required File file,
    required String fileName,
    required String fileType,
    String? description,
  }) async {
    // Store the file
    final filePath = await storeFile(
      file: file,
      transactionId: transactionId,
      fileName: fileName,
    );
    
    // Calculate hash for deduplication
    final hash = await calculateFileHash(file);
    
    // Get file size
    final fileSize = await getFileSize(file);
    
    // Generate thumbnail if applicable
    final thumbnail = await generateThumbnail(
      filePath: filePath,
      mimeType: fileType,
    );
    
    // Get current attachment count for sort order
    final currentAttachments = await _db.attachmentsDao.getByTransaction(transactionId);
    final sortOrder = currentAttachments.length;
    
    // Create database record
    final id = await _db.attachmentsDao.createAttachment(
      transactionId: transactionId,
      fileName: fileName,
      filePath: filePath,
      fileType: fileType,
      fileSize: fileSize,
      thumbnailPath: thumbnail?.path,
      thumbnailWidth: thumbnail?.width,
      thumbnailHeight: thumbnail?.height,
      fileHash: hash,
      description: description,
      sortOrder: sortOrder,
    );
    
    return id;
  }

  /// Picks an image from camera and creates attachment.
  Future<String?> pickFromCamera({
    required String transactionId,
  }) async {
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
        fileType: getMimeType(image.name),
      );
    }
    return null;
  }

  /// Picks images from gallery and creates attachments.
  Future<List<String>> pickFromGallery({
    required String transactionId,
  }) async {
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
        fileType: getMimeType(image.name),
      );
      ids.add(id);
    }
    return ids;
  }

  /// Picks files using file picker and creates attachments.
  Future<List<String>> pickFiles({
    required String transactionId,
  }) async {
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
            fileType: getMimeType(file.name),
          );
          ids.add(id);
        }
      }
    }
    return ids;
  }

  /// Deletes an attachment file from storage.
  Future<void> deleteAttachmentFile(Attachment attachment) async {
    // Delete main file
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

  /// Exports all attachments for backup.
  /// 
  /// Returns a map of relative path -> file bytes.
  Future<Map<String, List<int>>> exportAttachments() async {
    final attachmentsDir = await getAttachmentsDir();
    final result = <String, List<int>>{};
    
    if (await attachmentsDir.exists()) {
      await for (final entity in attachmentsDir.list(recursive: true)) {
        if (entity is File) {
          final relativePath = entity.path.substring(attachmentsDir.path.length + 1);
          result[relativePath] = await entity.readAsBytes();
        }
      }
    }
    
    return result;
  }

  /// Imports attachments from backup data.
  Future<void> importAttachments(Map<String, List<int>> attachmentsData) async {
    final attachmentsDir = await getAttachmentsDir();
    
    for (final entry in attachmentsData.entries) {
      final filePath = p.join(attachmentsDir.path, entry.key);
      final file = File(filePath);
      
      // Ensure parent directory exists
      final parentDir = file.parent;
      if (!await parentDir.exists()) {
        await parentDir.create(recursive: true);
      }
      
      await file.writeAsBytes(entry.value);
    }
  }

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

/// Thumbnail information for an attachment.
class ThumbnailInfo {
  final String path;
  final int width;
  final int height;

  const ThumbnailInfo({
    required this.path,
    required this.width,
    required this.height,
  });
}
