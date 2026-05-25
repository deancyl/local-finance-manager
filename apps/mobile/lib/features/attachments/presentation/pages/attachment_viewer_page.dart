import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:photo_view/photo_view.dart';
import 'package:photo_view/photo_view_gallery.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:path/path.dart' as p;

import 'package:database/database.dart';
import '../../data/attachment_provider.dart';
import '../../data/attachment_service.dart';

/// Full-screen page for viewing attachments with gallery support.
class AttachmentViewerPage extends ConsumerStatefulWidget {
  final String transactionId;
  final int initialIndex;
  final String? transactionDescription;

  const AttachmentViewerPage({
    super.key,
    required this.transactionId,
    this.initialIndex = 0,
    this.transactionDescription,
  });

  @override
  ConsumerState<AttachmentViewerPage> createState() => _AttachmentViewerPageState();
}

class _AttachmentViewerPageState extends ConsumerState<AttachmentViewerPage> {
  late PageController _pageController;
  int _currentIndex = 0;
  List<Attachment> _attachments = [];

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final attachmentsAsync = ref.watch(transactionAttachmentsProvider(widget.transactionId));

    return attachmentsAsync.when(
      data: (attachments) {
        if (attachments.isEmpty) {
          return Scaffold(
            appBar: AppBar(title: const Text('附件')),
            body: const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.attach_file, size: 64),
                  SizedBox(height: 16),
                  Text('没有附件'),
                ],
              ),
            ),
          );
        }

        _attachments = attachments;
        final currentAttachment = attachments[_currentIndex];

        return Scaffold(
          backgroundColor: Colors.black,
          extendBodyBehindAppBar: true,
          appBar: AppBar(
            backgroundColor: Colors.black.withValues(alpha: 0.5),
            foregroundColor: Colors.white,
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  currentAttachment.fileName,
                  style: const TextStyle(fontSize: 14),
                  overflow: TextOverflow.ellipsis,
                ),
                if (attachments.length > 1)
                  Text(
                    '${_currentIndex + 1} / ${attachments.length}',
                    style: const TextStyle(fontSize: 12, color: Colors.white70),
                  ),
              ],
            ),
            actions: [
              // Share button
              IconButton(
                icon: const Icon(Icons.share),
                onPressed: () => _shareAttachment(currentAttachment),
                tooltip: '分享',
              ),
              // Open externally button
              IconButton(
                icon: const Icon(Icons.open_in_new),
                onPressed: () => _openExternal(currentAttachment),
                tooltip: '打开',
              ),
              // Delete button
              IconButton(
                icon: const Icon(Icons.delete),
                onPressed: () => _confirmDelete(currentAttachment),
                tooltip: '删除',
              ),
            ],
          ),
          body: Stack(
            alignment: Alignment.bottomCenter,
            children: [
              // Gallery view
              PhotoViewGallery.builder(
                scrollPhysics: const BouncingScrollPhysics(),
                builder: (context, index) {
                  final attachment = attachments[index];
                  final file = File(attachment.filePath);

                  if (!file.existsSync()) {
                    return PhotoViewGalleryPageOptions.customBuilder(
                      builder: (context, photoViewScaleStateController) {
                        return Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.error_outline, size: 64, color: Colors.white),
                              const SizedBox(height: 16),
                              const Text('文件不存在', style: TextStyle(color: Colors.white)),
                              const SizedBox(height: 8),
                              Text(
                                attachment.fileName,
                                style: const TextStyle(color: Colors.white70, fontSize: 12),
                              ),
                            ],
                          ),
                        );
                      },
                    );
                  }

                  if (AttachmentService.isImage(attachment.fileType)) {
                    return PhotoViewGalleryPageOptions(
                      imageProvider: FileImage(file),
                      initialScale: PhotoViewComputedScale.contained,
                      minScale: PhotoViewComputedScale.contained,
                      maxScale: PhotoViewComputedScale.covered * 3,
                      heroAttributes: PhotoViewHeroAttributes(tag: attachment.id),
                    );
                  }

                  // For non-image files, show placeholder
                  return PhotoViewGalleryPageOptions.customBuilder(
                    builder: (context, photoViewScaleStateController) {
                      return Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              _getFileIcon(attachment.fileType),
                              size: 64,
                              color: Colors.white,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              AttachmentService.getFileTypeName(attachment.fileType),
                              style: const TextStyle(color: Colors.white, fontSize: 18),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              attachment.fileName,
                              style: const TextStyle(color: Colors.white70, fontSize: 14),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              AttachmentService.formatFileSize(attachment.fileSize),
                              style: const TextStyle(color: Colors.white60, fontSize: 12),
                            ),
                            const SizedBox(height: 24),
                            ElevatedButton.icon(
                              onPressed: () => _openExternal(attachment),
                              icon: const Icon(Icons.open_in_new),
                              label: const Text('打开文件'),
                            ),
                          ],
                        ),
                      );
                    },
                  );
                },
                itemCount: attachments.length,
                loadingBuilder: (context, event) => Center(
                  child: CircularProgressIndicator(
                    value: event == null ? null : event.cumulativeProgress /
                        (event.expectedTotalBytes ?? 1),
                    color: Colors.white,
                  ),
                ),
                backgroundDecoration: const BoxDecoration(color: Colors.black),
                pageController: _pageController,
                onPageChanged: (index) {
                  setState(() => _currentIndex = index);
                },
              ),
              // Thumbnail strip for multiple attachments
              if (attachments.length > 1)
                Positioned(
                  bottom: 16,
                  left: 0,
                  right: 0,
                  child: _buildThumbnailStrip(attachments),
                ),
            ],
          ),
        );
      },
      loading: () => Scaffold(
        appBar: AppBar(title: const Text('附件')),
        body: const Center(child: CircularProgressIndicator()),
      ),
      error: (error, _) => Scaffold(
        appBar: AppBar(title: const Text('附件')),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 64),
              const SizedBox(height: 16),
              Text('加载失败: $error'),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildThumbnailStrip(List<Attachment> attachments) {
    return Container(
      height: 80,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: attachments.length,
        itemBuilder: (context, index) {
          final attachment = attachments[index];
          final isSelected = index == _currentIndex;

          return GestureDetector(
            onTap: () {
              _pageController.animateToPage(
                index,
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut,
              );
            },
            child: Container(
              width: 60,
              height: 60,
              margin: const EdgeInsets.symmetric(horizontal: 4),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isSelected ? Colors.white : Colors.transparent,
                  width: 2,
                ),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: _buildThumbnail(attachment),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildThumbnail(Attachment attachment) {
    final isImage = AttachmentService.isImage(attachment.fileType);

    if (isImage && attachment.thumbnailPath != null) {
      final file = File(attachment.thumbnailPath!);
      if (file.existsSync()) {
        return Image.file(
          file,
          width: 60,
          height: 60,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _buildPlaceholder(attachment),
        );
      }
    }

    return _buildPlaceholder(attachment);
  }

  Widget _buildPlaceholder(Attachment attachment) {
    return Container(
      color: Colors.grey.shade800,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              _getFileIcon(attachment.fileType),
              size: 24,
              color: Colors.white70,
            ),
            const SizedBox(height: 4),
            Text(
              p.extension(attachment.fileName).toUpperCase(),
              style: const TextStyle(color: Colors.white60, fontSize: 10),
            ),
          ],
        ),
      ),
    );
  }

  IconData _getFileIcon(String mimeType) {
    if (AttachmentService.isImage(mimeType)) return Icons.image;
    if (AttachmentService.isPdf(mimeType)) return Icons.picture_as_pdf;
    if (mimeType.contains('word')) return Icons.description;
    if (mimeType.contains('excel') || mimeType.contains('spreadsheet')) {
      return Icons.table_chart;
    }
    return Icons.attach_file;
  }

  void _shareAttachment(Attachment attachment) {
    final file = File(attachment.filePath);
    if (file.existsSync()) {
      Share.shareXFiles(
        [XFile(attachment.filePath)],
        subject: attachment.fileName,
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('文件不存在，无法分享')),
      );
    }
  }

  Future<void> _openExternal(Attachment attachment) async {
    final file = File(attachment.filePath);
    
    if (!file.existsSync()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('文件不存在')),
      );
      return;
    }

    // Try to open with system app
    try {
      final uri = Uri.file(attachment.filePath);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('无法打开此文件类型')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('打开失败: $e')),
      );
    }
  }

  void _confirmDelete(Attachment attachment) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除附件'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('确定要删除 "${attachment.fileName}" 吗？'),
            const SizedBox(height: 8),
            Text(
              '此操作将永久删除文件，无法撤销。',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.error,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.pop(context);
              await _deleteAttachment(attachment);
            },
            child: const Text('删除'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteAttachment(Attachment attachment) async {
    try {
      // Delete file from storage
      final service = AttachmentService(ref.read(databaseProvider));
      await service.deleteAttachmentFile(attachment);
      
      // Delete from database
      await ref.read(attachmentNotifierProvider.notifier).hardDeleteAttachment(attachment.id);
      
      if (_attachments.isEmpty) {
        // All attachments deleted, close page
        if (mounted) Navigator.pop(context);
      }
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('附件已删除')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('删除失败: $e')),
        );
      }
    }
  }
}

/// Route arguments for AttachmentViewerPage.
class AttachmentViewerArgs {
  final String transactionId;
  final int initialIndex;
  final String? transactionDescription;

  const AttachmentViewerArgs({
    required this.transactionId,
    this.initialIndex = 0,
    this.transactionDescription,
  });
}