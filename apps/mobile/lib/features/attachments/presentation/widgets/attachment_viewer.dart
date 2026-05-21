import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:photo_view/photo_view.dart';
import 'package:path/path.dart' as p;

import 'package:database/database.dart';
import '../../data/attachment_provider.dart';

/// Widget for viewing attachments.
class AttachmentViewer extends ConsumerWidget {
  final Attachment attachment;
  final VoidCallback? onDelete;

  const AttachmentViewer({
    super.key,
    required this.attachment,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isImage = AttachmentUtils.isImage(attachment.fileType);
    final isPdf = AttachmentUtils.isPdf(attachment.fileType);

    return Dialog(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            ),
            child: Row(
              children: [
                Icon(_getFileIcon(attachment.fileType)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        attachment.fileName,
                        style: Theme.of(context).textTheme.titleMedium,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        AttachmentUtils.formatFileSize(attachment.fileSize),
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                if (onDelete != null)
                  IconButton(
                    icon: const Icon(Icons.delete),
                    onPressed: () => _confirmDelete(context, ref),
                  ),
              ],
            ),
          ),
          // Content
          Flexible(
            child: _buildContent(context, isImage, isPdf),
          ),
          // Footer
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('关闭'),
                ),
                const SizedBox(width: 8),
                FilledButton.icon(
                  onPressed: () => _openExternal(context),
                  icon: const Icon(Icons.open_in_new, size: 18),
                  label: const Text('打开'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(BuildContext context, bool isImage, bool isPdf) {
    final file = File(attachment.filePath);

    if (!file.existsSync()) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 48),
            SizedBox(height: 16),
            Text('文件不存在'),
          ],
        ),
      );
    }

    if (isImage) {
      return PhotoView(
        imageProvider: FileImage(file),
        minScale: PhotoViewComputedScale.contained,
        maxScale: PhotoViewComputedScale.covered * 2,
        initialScale: PhotoViewComputedScale.contained,
        backgroundDecoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
        ),
      );
    }

    if (isPdf) {
      // For PDF, show a placeholder with option to open externally
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.picture_as_pdf, size: 64),
            const SizedBox(height: 16),
            const Text('PDF 文件'),
            const SizedBox(height: 8),
            Text(
              attachment.fileName,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      );
    }

    // For other file types, show file info
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(_getFileIcon(attachment.fileType), size: 64),
          const SizedBox(height: 16),
          Text(AttachmentUtils.getFileTypeName(attachment.fileType)),
          const SizedBox(height: 8),
          Text(
            attachment.fileName,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }

  IconData _getFileIcon(String mimeType) {
    if (AttachmentUtils.isImage(mimeType)) return Icons.image;
    if (AttachmentUtils.isPdf(mimeType)) return Icons.picture_as_pdf;
    if (mimeType.contains('word')) return Icons.description;
    if (mimeType.contains('excel') || mimeType.contains('spreadsheet')) {
      return Icons.table_chart;
    }
    return Icons.attach_file;
  }

  void _confirmDelete(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除附件'),
        content: const Text('确定要删除这个附件吗？此操作无法撤销。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context);
              onDelete?.call();
            },
            child: const Text('删除'),
          ),
        ],
      ),
    );
  }

  void _openExternal(BuildContext context) {
    // In a real app, you'd use url_launcher or open_file package
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('请使用系统文件管理器打开')),
    );
  }
}

/// Thumbnail widget for attachment preview.
class AttachmentThumbnail extends StatelessWidget {
  final Attachment attachment;
  final VoidCallback? onTap;
  final VoidCallback? onDelete;
  final double size;

  const AttachmentThumbnail({
    super.key,
    required this.attachment,
    this.onTap,
    this.onDelete,
    this.size = 80,
  });

  @override
  Widget build(BuildContext context) {
    final isImage = AttachmentUtils.isImage(attachment.fileType);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: Theme.of(context).colorScheme.outline.withOpacity(0.3),
          ),
        ),
        child: Stack(
          children: [
            // Thumbnail or icon
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: isImage && attachment.thumbnailPath != null
                  ? Image.file(
                      File(attachment.thumbnailPath!),
                      width: size,
                      height: size,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _buildPlaceholder(context),
                    )
                  : _buildPlaceholder(context),
            ),
            // Delete button
            if (onDelete != null)
              Positioned(
                top: 4,
                right: 4,
                child: GestureDetector(
                  onTap: onDelete,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.close,
                      color: Colors.white,
                      size: 14,
                    ),
                  ),
                ),
              ),
            // File type indicator
            if (!isImage)
              Positioned(
                bottom: 4,
                left: 4,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    p.extension(attachment.fileName).toUpperCase(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlaceholder(BuildContext context) {
    return Container(
      width: size,
      height: size,
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Icon(
        _getFileIcon(attachment.fileType),
        size: size * 0.4,
        color: Theme.of(context).colorScheme.primary,
      ),
    );
  }

  IconData _getFileIcon(String mimeType) {
    if (AttachmentUtils.isImage(mimeType)) return Icons.image;
    if (AttachmentUtils.isPdf(mimeType)) return Icons.picture_as_pdf;
    if (mimeType.contains('word')) return Icons.description;
    if (mimeType.contains('excel') || mimeType.contains('spreadsheet')) {
      return Icons.table_chart;
    }
    return Icons.attach_file;
  }
}

/// Shows attachment viewer dialog.
Future<void> showAttachmentViewer(
  BuildContext context, {
  required Attachment attachment,
  VoidCallback? onDelete,
}) {
  return showDialog(
    context: context,
    builder: (context) => AttachmentViewer(
      attachment: attachment,
      onDelete: onDelete,
    ),
  );
}
