import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:database/database.dart';
import '../../data/attachment_provider.dart';
import '../widgets/attachment_viewer.dart';

/// Widget showing attachment preview in transaction form.
class AttachmentSection extends ConsumerWidget {
  final String? transactionId;
  final bool isEditing;

  const AttachmentSection({
    super.key,
    this.transactionId,
    this.isEditing = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (transactionId == null) {
      return _buildEmptyState(context);
    }

    final attachmentsAsync = ref.watch(transactionAttachmentsProvider(transactionId!));

    return attachmentsAsync.when(
      data: (attachments) => _buildAttachmentGrid(context, ref, attachments),
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '附件',
          style: Theme.of(context).textTheme.titleSmall,
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            border: Border.all(
              color: Theme.of(context).colorScheme.outline.withOpacity(0.3),
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Icon(
                Icons.attach_file,
                color: Theme.of(context).colorScheme.outline,
              ),
              const SizedBox(width: 12),
              Text(
                '保存交易后可添加附件',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.outline,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAttachmentGrid(BuildContext context, WidgetRef ref, List<Attachment> attachments) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              '附件',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(width: 8),
            Text(
              '(${attachments.length})',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const Spacer(),
            TextButton.icon(
              onPressed: () => _navigateToAttachmentsPage(context),
              icon: const Icon(Icons.edit, size: 18),
              label: const Text('管理'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (attachments.isEmpty)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border.all(
                color: Theme.of(context).colorScheme.outline.withOpacity(0.3),
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.attach_file,
                  color: Theme.of(context).colorScheme.outline,
                ),
                const SizedBox(width: 12),
                Text(
                  '暂无附件，点击管理添加',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.outline,
                  ),
                ),
              ],
            ),
          )
        else
          SizedBox(
            height: 80,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: attachments.length,
              itemBuilder: (context, index) {
                final attachment = attachments[index];
                return Padding(
                  padding: EdgeInsets.only(right: index < attachments.length - 1 ? 8 : 0),
                  child: AttachmentThumbnail(
                    attachment: attachment,
                    size: 80,
                    onTap: () => showAttachmentViewer(
                      context,
                      attachment: attachment,
                    ),
                  ),
                );
              },
            ),
          ),
      ],
    );
  }

  void _navigateToAttachmentsPage(BuildContext context) {
    if (transactionId != null) {
      context.push('/transactions/attachments/$transactionId');
    }
  }
}