import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';

import '../../data/attachment_provider.dart';

/// Widget for picking attachments (photos or files).
class AttachmentPicker extends ConsumerWidget {
  final String transactionId;
  final Function(String attachmentId)? onAttachmentAdded;
  final bool showLabel;

  const AttachmentPicker({
    super.key,
    required this.transactionId,
    this.onAttachmentAdded,
    this.showLabel = true,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (showLabel) ...[
          Text(
            '附件',
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 8),
        ],
        Row(
          children: [
            Expanded(
              child: _buildPickerButton(
                context,
                icon: Icons.camera_alt,
                label: '拍照',
                onTap: () => _takePhoto(context, ref),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildPickerButton(
                context,
                icon: Icons.photo_library,
                label: '相册',
                onTap: () => _pickFromGallery(context, ref),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildPickerButton(
                context,
                icon: Icons.attach_file,
                label: '文件',
                onTap: () => _pickFile(context, ref),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildPickerButton(
    BuildContext context, {
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          border: Border.all(
            color: Theme.of(context).colorScheme.outline.withOpacity(0.5),
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _takePhoto(BuildContext context, WidgetRef ref) async {
    try {
      final picker = ImagePicker();
      final image = await picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 85,
        maxWidth: 1920,
        maxHeight: 1920,
      );

      if (image != null) {
        await _addAttachment(
          context,
          ref,
          file: File(image.path),
          fileName: image.name,
          fileType: AttachmentUtils.getMimeType(image.name),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('拍照失败: $e')),
        );
      }
    }
  }

  Future<void> _pickFromGallery(BuildContext context, WidgetRef ref) async {
    try {
      final picker = ImagePicker();
      final images = await picker.pickMultiImage(
        imageQuality: 85,
        maxWidth: 1920,
        maxHeight: 1920,
      );

      for (final image in images) {
        await _addAttachment(
          context,
          ref,
          file: File(image.path),
          fileName: image.name,
          fileType: AttachmentUtils.getMimeType(image.name),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('选择图片失败: $e')),
        );
      }
    }
  }

  Future<void> _pickFile(BuildContext context, WidgetRef ref) async {
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

      if (result != null) {
        for (final file in result.files) {
          if (file.path != null) {
            await _addAttachment(
              context,
              ref,
              file: File(file.path!),
              fileName: file.name,
              fileType: AttachmentUtils.getMimeType(file.name),
            );
          }
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('选择文件失败: $e')),
        );
      }
    }
  }

  Future<void> _addAttachment(
    BuildContext context,
    WidgetRef ref, {
    required File file,
    required String fileName,
    required String fileType,
  }) async {
    final notifier = ref.read(attachmentNotifierProvider.notifier);
    final attachmentId = await notifier.createAttachment(
      transactionId: transactionId,
      file: file,
      fileName: fileName,
      fileType: fileType,
    );

    if (attachmentId != null && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('已添加附件: $fileName')),
      );
      onAttachmentAdded?.call(attachmentId);
    }
  }
}

/// Compact attachment picker button for use in forms.
class CompactAttachmentPicker extends ConsumerWidget {
  final String transactionId;
  final Function(String attachmentId)? onAttachmentAdded;

  const CompactAttachmentPicker({
    super.key,
    required this.transactionId,
    this.onAttachmentAdded,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return PopupMenuButton<String>(
      icon: const Icon(Icons.attach_file),
      tooltip: '添加附件',
      onSelected: (value) {
        switch (value) {
          case 'camera':
            _takePhoto(context, ref);
            break;
          case 'gallery':
            _pickFromGallery(context, ref);
            break;
          case 'file':
            _pickFile(context, ref);
            break;
        }
      },
      itemBuilder: (context) => [
        const PopupMenuItem(
          value: 'camera',
          child: ListTile(
            leading: Icon(Icons.camera_alt),
            title: Text('拍照'),
            contentPadding: EdgeInsets.zero,
          ),
        ),
        const PopupMenuItem(
          value: 'gallery',
          child: ListTile(
            leading: Icon(Icons.photo_library),
            title: Text('从相册选择'),
            contentPadding: EdgeInsets.zero,
          ),
        ),
        const PopupMenuItem(
          value: 'file',
          child: ListTile(
            leading: Icon(Icons.attach_file),
            title: Text('选择文件'),
            contentPadding: EdgeInsets.zero,
          ),
        ),
      ],
    );
  }

  Future<void> _takePhoto(BuildContext context, WidgetRef ref) async {
    try {
      final picker = ImagePicker();
      final image = await picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 85,
        maxWidth: 1920,
        maxHeight: 1920,
      );

      if (image != null) {
        await _addAttachment(
          context,
          ref,
          file: File(image.path),
          fileName: image.name,
          fileType: AttachmentUtils.getMimeType(image.name),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('拍照失败: $e')),
        );
      }
    }
  }

  Future<void> _pickFromGallery(BuildContext context, WidgetRef ref) async {
    try {
      final picker = ImagePicker();
      final images = await picker.pickMultiImage(
        imageQuality: 85,
        maxWidth: 1920,
        maxHeight: 1920,
      );

      for (final image in images) {
        await _addAttachment(
          context,
          ref,
          file: File(image.path),
          fileName: image.name,
          fileType: AttachmentUtils.getMimeType(image.name),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('选择图片失败: $e')),
        );
      }
    }
  }

  Future<void> _pickFile(BuildContext context, WidgetRef ref) async {
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

      if (result != null) {
        for (final file in result.files) {
          if (file.path != null) {
            await _addAttachment(
              context,
              ref,
              file: File(file.path!),
              fileName: file.name,
              fileType: AttachmentUtils.getMimeType(file.name),
            );
          }
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('选择文件失败: $e')),
        );
      }
    }
  }

  Future<void> _addAttachment(
    BuildContext context,
    WidgetRef ref, {
    required File file,
    required String fileName,
    required String fileType,
  }) async {
    final notifier = ref.read(attachmentNotifierProvider.notifier);
    final attachmentId = await notifier.createAttachment(
      transactionId: transactionId,
      file: file,
      fileName: fileName,
      fileType: fileType,
    );

    if (attachmentId != null && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('已添加附件: $fileName')),
      );
      onAttachmentAdded?.call(attachmentId);
    }
  }
}
