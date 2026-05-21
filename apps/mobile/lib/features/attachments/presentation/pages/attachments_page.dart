import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:database/database.dart';

import '../../data/attachment_provider.dart';
import '../widgets/attachment_picker.dart';
import '../widgets/attachment_viewer.dart';

/// Page for managing attachments for a transaction.
class AttachmentsPage extends ConsumerWidget {
  final String transactionId;
  final String? transactionDescription;

  const AttachmentsPage({
    super.key,
    required this.transactionId,
    this.transactionDescription,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final attachmentsAsync = ref.watch(transactionAttachmentsProvider(transactionId));

    return Scaffold(
      appBar: AppBar(
        title: Text(transactionDescription ?? '附件管理'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _showAddOptions(context, ref),
          ),
        ],
      ),
      body: attachmentsAsync.when(
        data: (attachments) {
          if (attachments.isEmpty) {
            return _buildEmptyState(context, ref);
          }
          return _buildAttachmentList(context, ref, attachments);
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 48),
              const SizedBox(height: 16),
              Text('加载失败: $error'),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, WidgetRef ref) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.attach_file,
            size: 64,
            color: Theme.of(context).colorScheme.outline,
          ),
          const SizedBox(height: 16),
          Text(
            '暂无附件',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Text(
            '点击右上角添加按钮添加附件',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: () => _showAddOptions(context, ref),
            icon: const Icon(Icons.add),
            label: const Text('添加附件'),
          ),
        ],
      ),
    );
  }

  Widget _buildAttachmentList(BuildContext context, WidgetRef ref, List<Attachment> attachments) {
    return Column(
      children: [
        // Attachment picker at top
        Padding(
          padding: const EdgeInsets.all(16),
          child: AttachmentPicker(transactionId: transactionId),
        ),
        const Divider(),
        // Attachment grid
        Expanded(
          child: GridView.builder(
            padding: const EdgeInsets.all(16),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
            ),
            itemCount: attachments.length,
            itemBuilder: (context, index) {
              final attachment = attachments[index];
              return AttachmentThumbnail(
                attachment: attachment,
                size: 100,
                onTap: () => showAttachmentViewer(
                  context,
                  attachment: attachment,
                  onDelete: () => _deleteAttachment(context, ref, attachment.id),
                ),
                onDelete: () => _confirmDelete(context, ref, attachment),
              );
            },
          ),
        ),
        // Summary info
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '共 ${attachments.length} 个附件',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(width: 8),
              Text(
                '总大小: ${_calculateTotalSize(attachments)}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _showAddOptions(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.camera_alt),
                title: const Text('拍照'),
                onTap: () {
                  Navigator.pop(context);
                  // Trigger camera picker
                  ref.read(attachmentNotifierProvider.notifier).createAttachmentFromCamera(
                    transactionId: transactionId,
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_library),
                title: const Text('从相册选择'),
                onTap: () {
                  Navigator.pop(context);
                  // Trigger gallery picker
                  ref.read(attachmentNotifierProvider.notifier).createAttachmentFromGallery(
                    transactionId: transactionId,
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.folder),
                title: const Text('选择文件'),
                onTap: () {
                  Navigator.pop(context);
                  // Trigger file picker
                  ref.read(attachmentNotifierProvider.notifier).createAttachmentFromFile(
                    transactionId: transactionId,
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _confirmDelete(BuildContext context, WidgetRef ref, Attachment attachment) {
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
            onPressed: () {
              Navigator.pop(context);
              _deleteAttachment(context, ref, attachment.id);
            },
            child: const Text('删除'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteAttachment(BuildContext context, WidgetRef ref, String attachmentId) async {
    try {
      await ref.read(attachmentNotifierProvider.notifier).hardDeleteAttachment(attachmentId);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('附件已删除')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('删除失败: $e')),
        );
      }
    }
  }

  String _calculateTotalSize(List<Attachment> attachments) {
    final totalBytes = attachments.fold(0, (sum, a) => sum + a.fileSize);
    return AttachmentUtils.formatFileSize(totalBytes);
  }
}