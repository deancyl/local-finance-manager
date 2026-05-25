import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../data/template_provider.dart';

/// Template card widget for displaying transaction templates
class TemplateCard extends ConsumerWidget {
  final TemplateModel template;
  final VoidCallback? onTap;
  final VoidCallback? onUse;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  const TemplateCard({
    super.key,
    required this.template,
    this.onTap,
    this.onUse,
    this.onEdit,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final timeStr = template.lastUsedAt != null
        ? DateFormat('MM-dd HH:mm').format(template.lastUsedAt!)
        : '未使用';

    return Card(
      elevation: template.isFavorite ? 2 : 1,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: InkWell(
        onTap: onTap ?? () => _useTemplate(context, ref),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header row
              Row(
                children: [
                  // Favorite toggle
                  IconButton(
                    icon: Icon(
                      template.isFavorite ? Icons.star : Icons.star_border,
                      color: template.isFavorite ? Colors.amber : colorScheme.outline,
                    ),
                    onPressed: () => ref
                        .read(templateNotifierProvider.notifier)
                        .toggleFavorite(template.id),
                    tooltip: template.isFavorite ? '取消收藏' : '收藏',
                    constraints: const BoxConstraints(
                      minWidth: 40,
                      minHeight: 40,
                    ),
                    padding: EdgeInsets.zero,
                  ),
                  const SizedBox(width: 8),
                  // Title and category
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          template.name,
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                        ),
                        if (template.category != null)
                          Container(
                            margin: const EdgeInsets.only(top: 4),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: colorScheme.primaryContainer.withOpacity(0.5),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              template.category!,
                              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                    color: colorScheme.onPrimaryContainer,
                                  ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  // Menu
                  PopupMenuButton<String>(
                    icon: const Icon(Icons.more_vert),
                    onSelected: (value) {
                      switch (value) {
                        case 'use':
                          _useTemplate(context, ref);
                          break;
                        case 'edit':
                          onEdit?.call();
                          break;
                        case 'delete':
                          _confirmDelete(context, ref);
                          break;
                      }
                    },
                    itemBuilder: (context) => [
                      const PopupMenuItem(
                        value: 'use',
                        child: ListTile(
                          leading: Icon(Icons.add_circle_outline),
                          title: Text('使用模板'),
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'edit',
                        child: ListTile(
                          leading: Icon(Icons.edit_outlined),
                          title: Text('编辑'),
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'delete',
                        child: ListTile(
                          leading: Icon(Icons.delete_outline),
                          title: Text('删除'),
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Description
              if (template.description != null && template.description!.isNotEmpty) ...[
                Text(
                  template.description!,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 12),
              ],
              // Stats row
              Row(
                children: [
                  _buildStat(
                    context,
                    icon: Icons.content_copy_outlined,
                    label: '${template.splits.length} 分录',
                  ),
                  const SizedBox(width: 16),
                  _buildStat(
                    context,
                    icon: Icons.history,
                    label: '使用 ${template.useCount} 次',
                  ),
                  const SizedBox(width: 16),
                  _buildStat(
                    context,
                    icon: Icons.access_time,
                    label: timeStr,
                  ),
                ],
              ),
              // Splits preview
              if (template.splits.isNotEmpty) ...[
                const SizedBox(height: 12),
                const Divider(height: 1),
                const SizedBox(height: 8),
                ...template.splits.take(3).map((split) => Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Row(
                        children: [
                          Icon(
                            split.amount >= 0
                                ? Icons.arrow_upward
                                : Icons.arrow_downward,
                            size: 14,
                            color: split.amount >= 0 ? Colors.green : Colors.red,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              '账户: ${split.accountId.substring(0, 8)}...',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ),
                          Text(
                            '${split.amount.abs().toStringAsFixed(2)}',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: split.amount >= 0 ? Colors.green : Colors.red,
                                  fontWeight: FontWeight.w500,
                                ),
                          ),
                        ],
                      ),
                    )),
                if (template.splits.length > 3)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      '还有 ${template.splits.length - 3} 个分录...',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: colorScheme.outline,
                            fontStyle: FontStyle.italic,
                          ),
                    ),
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStat(
    BuildContext context, {
    required IconData icon,
    required String label,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          icon,
          size: 14,
          color: Theme.of(context).colorScheme.outline,
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.outline,
              ),
        ),
      ],
    );
  }

  void _useTemplate(BuildContext context, WidgetRef ref) {
    ref.read(templateNotifierProvider.notifier).recordUsage(template.id);
    onUse?.call();
    // Navigate to transaction creation with template
    Navigator.of(context).pushNamed(
      '/transactions/add',
      arguments: template,
    );
  }

  void _confirmDelete(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除模板'),
        content: Text('确定删除模板 "${template.name}" 吗？此操作无法撤销。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Theme.of(context).colorScheme.onError,
            ),
            onPressed: () {
              Navigator.pop(context);
              ref
                  .read(templateNotifierProvider.notifier)
                  .deleteTemplate(template.id);
            },
            child: const Text('删除'),
          ),
        ],
      ),
    );
  }
}

/// Compact template card for inline display
class TemplateCompactCard extends ConsumerWidget {
  final TemplateModel template;
  final VoidCallback? onTap;

  const TemplateCompactCard({
    super.key,
    required this.template,
    this.onTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListTile(
      leading: Icon(
        template.isFavorite ? Icons.star : Icons.receipt_long,
        color: template.isFavorite ? Colors.amber : null,
      ),
      title: Text(template.name),
      subtitle: Text(
        '${template.splits.length} 分录 · 使用 ${template.useCount} 次',
      ),
      trailing: const Icon(Icons.chevron_right),
      onTap: () {
        ref.read(templateNotifierProvider.notifier).recordUsage(template.id);
        onTap?.call();
      },
    );
  }
}
