import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:database/database.dart';
import '../../data/tag_provider.dart';

/// Dialog for bulk tag operations on multiple transactions.
class BulkTagOperationDialog extends ConsumerStatefulWidget {
  /// List of transaction IDs to operate on.
  final List<String> transactionIds;
  
  /// Operation type: 'add', 'remove', or 'replace'.
  final String operationType;

  const BulkTagOperationDialog({
    super.key,
    required this.transactionIds,
    this.operationType = 'add',
  });

  @override
  ConsumerState<BulkTagOperationDialog> createState() => _BulkTagOperationDialogState();
}

class _BulkTagOperationDialogState extends ConsumerState<BulkTagOperationDialog> {
  final Set<String> _selectedTagIds = {};
  bool _isProcessing = false;

  String get _operationTitle {
    switch (widget.operationType) {
      case 'add':
        return '批量添加标签';
      case 'remove':
        return '批量移除标签';
      case 'replace':
        return '批量设置标签';
      default:
        return '批量标签操作';
    }
  }

  String get _operationDescription {
    switch (widget.operationType) {
      case 'add':
        return '为 ${widget.transactionIds.length} 条交易添加标签';
      case 'remove':
        return '从 ${widget.transactionIds.length} 条交易移除标签';
      case 'replace':
        return '为 ${widget.transactionIds.length} 条交易设置标签（替换现有标签）';
      default:
        return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final allTagsAsync = ref.watch(allTagsProvider);

    return AlertDialog(
      title: Text(_operationTitle),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              _operationDescription,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            
            // Tag selection
            allTagsAsync.when(
              data: (tags) {
                if (tags.isEmpty) {
                  return const Text('暂无可用标签，请先创建标签');
                }
                
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '选择标签',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: tags.map((tag) => _buildTagChip(tag)).toList(),
                    ),
                  ],
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => Text('加载标签失败: $error'),
            ),
            
            if (_selectedTagIds.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text(
                '已选择 ${_selectedTagIds.length} 个标签',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isProcessing ? null : () => Navigator.pop(context),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: _isProcessing || _selectedTagIds.isEmpty ? null : _executeOperation,
          child: _isProcessing
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('执行'),
        ),
      ],
    );
  }

  Widget _buildTagChip(Tag tag) {
    final isSelected = _selectedTagIds.contains(tag.id);
    final color = _parseColor(tag.color);
    
    return FilterChip(
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Text('#${tag.name}'),
          if (tag.usageCount > 0) ...[
            const SizedBox(width: 4),
            Text(
              '(${tag.usageCount})',
              style: TextStyle(
                fontSize: 10,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ],
      ),
      selected: isSelected,
      onSelected: (selected) {
        setState(() {
          if (selected) {
            _selectedTagIds.add(tag.id);
          } else {
            _selectedTagIds.remove(tag.id);
          }
        });
      },
      selectedColor: color.withOpacity(0.2),
      checkmarkColor: color,
      side: BorderSide(color: isSelected ? color : Theme.of(context).colorScheme.outline),
    );
  }

  Future<void> _executeOperation() async {
    setState(() => _isProcessing = true);
    
    try {
      final tagIds = _selectedTagIds.toList();
      final notifier = ref.read(tagNotifierProvider.notifier);
      
      switch (widget.operationType) {
        case 'add':
          await notifier.addTagsToTransactions(widget.transactionIds, tagIds);
          break;
        case 'remove':
          await notifier.removeTagsFromTransactions(widget.transactionIds, tagIds);
          break;
        case 'replace':
          await notifier.setTagsOnTransactions(widget.transactionIds, tagIds);
          break;
      }
      
      if (mounted) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('成功处理 ${widget.transactionIds.length} 条交易'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('操作失败: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }
  Color _parseColor(String colorHex) {
    final colorValue = int.tryParse(colorHex.replaceFirst('#', '0xFF'));
    return colorValue != null ? Color(colorValue) : Colors.grey;
  }
  }
}
