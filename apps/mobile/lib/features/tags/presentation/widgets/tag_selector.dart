import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:database/database.dart';
import '../../data/tag_provider.dart';

/// Tag selector widget for transaction forms.
/// 
/// Allows multi-select of tags with inline tag creation.
class TagSelector extends ConsumerStatefulWidget {
  /// The transaction ID for loading existing tags (for edit mode).
  final String? transactionId;
  
  /// Initial selected tag IDs (for create mode).
  final List<String>? initialTagIds;
  
  /// Callback when selected tags change.
  final void Function(List<String> tagIds)? onChanged;

  const TagSelector({
    super.key,
    this.transactionId,
    this.initialTagIds,
    this.onChanged,
  });

  @override
  ConsumerState<TagSelector> createState() => _TagSelectorState();
}

class _TagSelectorState extends ConsumerState<TagSelector> {
  Set<String> _selectedTagIds = {};
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialTagIds != null) {
      _selectedTagIds = Set.from(widget.initialTagIds!);
      _initialized = true;
    }
  }

  @override
  Widget build(BuildContext context) {
    final allTagsAsync = ref.watch(allTagsProvider);
    
    // If we have a transactionId, watch its tags
    if (widget.transactionId != null && !_initialized) {
      final transactionTagsAsync = ref.watch(transactionTagsProvider(widget.transactionId!));
      transactionTagsAsync.whenData((tags) {
        if (!_initialized) {
          _selectedTagIds = Set.from(tags.map((t) => t.id));
          _initialized = true;
        }
      });
    }

    return allTagsAsync.when(
      data: (allTags) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '标签',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ...allTags.map((tag) => _buildTagChip(tag)),
                _buildAddTagChip(context),
              ],
            ),
          ],
        );
      },
      loading: () => const CircularProgressIndicator(),
      error: (error, _) => Text('加载标签失败: $error'),
    );
  }

  Widget _buildTagChip(Tag tag) {
    final isSelected = _selectedTagIds.contains(tag.id);
    final color = _parseColor(tag.color);
    
    return FilterChip(
      label: Text('#${tag.name}'),
      selected: isSelected,
      onSelected: (selected) {
        setState(() {
          if (selected) {
            _selectedTagIds.add(tag.id);
          } else {
            _selectedTagIds.remove(tag.id);
          }
        });
        widget.onChanged?.call(_selectedTagIds.toList());
      },
      selectedColor: color.withOpacity(0.3),
      checkmarkColor: color,
      side: BorderSide(color: isSelected ? color : Colors.grey),
      labelStyle: TextStyle(
        color: isSelected ? color : Theme.of(context).textTheme.bodyMedium?.color,
      ),
    );
  }

  Widget _buildAddTagChip(BuildContext context) {
    return ActionChip(
      avatar: const Icon(Icons.add, size: 18),
      label: const Text('添加标签'),
      onPressed: () => _showAddTagDialog(context),
    );
  }

  Color _parseColor(String colorHex) {
    final colorValue = int.tryParse(colorHex.replaceFirst('#', '0xFF'));
    return colorValue != null ? Color(colorValue) : Colors.grey;
  }
  }

  void _showAddTagDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => _QuickAddTagDialog(
        onSave: (name, color) async {
          await ref.read(tagNotifierProvider.notifier).createTag(
            name: name,
            color: color,
          );
          
          // Refresh and select the new tag
          final allTags = await ref.read(allTagsProvider.future);
          final newTag = allTags.firstWhere(
            (t) => t.name == name,
            orElse: () => allTags.last,
          );
          
          setState(() {
            _selectedTagIds.add(newTag.id);
          });
          widget.onChanged?.call(_selectedTagIds.toList());
        },
      ),
    );
  }
}

class _QuickAddTagDialog extends StatefulWidget {
  final Function(String name, String color) onSave;

  const _QuickAddTagDialog({required this.onSave});

  @override
  State<_QuickAddTagDialog> createState() => _QuickAddTagDialogState();
}

class _QuickAddTagDialogState extends State<_QuickAddTagDialog> {
  final _nameController = TextEditingController();
  String _selectedColor = '#607D8B';
  
  final List<String> _presetColors = [
    '#F44336', '#E91E63', '#9C27B0', '#673AB7',
    '#3F51B5', '#2196F3', '#03A9F4', '#00BCD4',
    '#009688', '#4CAF50', '#8BC34A', '#CDDC39',
    '#FFEB3B', '#FFC107', '#FF9800', '#FF5722',
    '#795548', '#9E9E9E', '#607D8B',
  ];

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('快速添加标签'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _nameController,
            decoration: const InputDecoration(
              labelText: '标签名称',
              prefixText: '# ',
            ),
            autofocus: true,
          ),
          const SizedBox(height: 16),
          Text(
            '颜色',
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _presetColors.map((color) {
              final isSelected = color == _selectedColor;
              return GestureDetector(
                onTap: () => setState(() => _selectedColor = color),
                child: Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                color: Color(int.tryParse(color.replaceFirst('#', '0xFF')) ?? 0xFF607D8B),
                        : null,
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: _save,
          child: const Text('添加'),
        ),
      ],
    );
  }

  void _save() {
    final name = _nameController.text.trim();
    if (name.isEmpty) return;
    
    widget.onSave(name, _selectedColor);
    Navigator.pop(context);
  }
}