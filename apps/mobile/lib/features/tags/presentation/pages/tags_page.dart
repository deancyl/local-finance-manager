import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:database/database.dart';
import '../../data/tag_provider.dart';

class TagsPage extends ConsumerWidget {
  const TagsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tagsAsync = ref.watch(allTagsProvider);
    final statsAsync = ref.watch(tagsWithStatsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('标签管理'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _showAddTagDialog(context, ref),
          ),
        ],
      ),
      body: tagsAsync.when(
        data: (tags) {
          if (tags.isEmpty) {
            return const Center(
              child: Text('暂无标签，点击右上角添加'),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: tags.length,
            itemBuilder: (context, index) {
              final tag = tags[index];
              // Get stats for this tag
              final stats = statsAsync.whenOrNull(
                data: (s) => s.where((s) => s.$1.id == tag.id).firstOrNull,
              );
              final transactionCount = stats?.$2 ?? tag.usageCount;
              return _buildTagItem(context, ref, tag, transactionCount);
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('错误: $error')),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddTagDialog(context, ref),
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildTagItem(BuildContext context, WidgetRef ref, Tag tag, int transactionCount) {
    final color = _parseColor(tag.color);
    
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            Icons.label,
            color: _getContrastColor(color),
            size: 20,
          ),
        ),
        title: Text('#${tag.name}'),
        subtitle: tag.description != null
            ? Text(
                tag.description!,
                style: Theme.of(context).textTheme.bodySmall,
              )
            : null,
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Transaction count badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.receipt_long, size: 14, color: color),
                  const SizedBox(width: 4),
                  Text(
                    '$transactionCount',
                    style: TextStyle(
                      color: color,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            if (!tag.isSystem)
              IconButton(
                icon: const Icon(Icons.delete_outline),
                onPressed: () => _deleteTag(context, ref, tag),
              ),
          ],
        ),
        onTap: () => _showEditTagDialog(context, ref, tag),
      ),
    );
  }

  Color _parseColor(String colorHex) {
    final colorValue = int.tryParse(colorHex.replaceFirst('#', '0xFF'));
    return colorValue != null ? Color(colorValue) : Colors.grey;
  }
  }

  Color _getContrastColor(Color color) {
    final luminance = color.computeLuminance();
    return luminance > 0.5 ? Colors.black : Colors.white;
  }

  void _showAddTagDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => _TagFormDialog(
        onSave: (name, color, description) {
          ref.read(tagNotifierProvider.notifier).createTag(
                name: name,
                color: color,
                description: description,
              );
        },
      ),
    );
  }

  void _showEditTagDialog(BuildContext context, WidgetRef ref, Tag tag) {
    showDialog(
      context: context,
      builder: (context) => _TagFormDialog(
        tag: tag,
        onSave: (name, color, description) {
          ref.read(tagNotifierProvider.notifier).updateTag(
                id: tag.id,
                name: name,
                color: color,
                description: description,
              );
        },
      ),
    );
  }

  void _deleteTag(BuildContext context, WidgetRef ref, Tag tag) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除标签'),
        content: Text('确定要删除标签 "#${tag.name}" 吗？\n已使用 ${tag.usageCount} 次。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () {
              ref.read(tagNotifierProvider.notifier).deleteTag(tag.id);
              Navigator.pop(context);
            },
            child: const Text('删除'),
          ),
        ],
      ),
    );
  }
}

class _TagFormDialog extends StatefulWidget {
  final Tag? tag;
  final Function(String name, String color, String? description) onSave;

  const _TagFormDialog({
    this.tag,
    required this.onSave,
  });

  @override
  State<_TagFormDialog> createState() => _TagFormDialogState();
}

class _TagFormDialogState extends State<_TagFormDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  
  String _selectedColor = '#607D8B';
  
  final List<String> _presetColors = [
    '#F44336', '#E91E63', '#9C27B0', '#673AB7',
    '#3F51B5', '#2196F3', '#03A9F4', '#00BCD4',
    '#009688', '#4CAF50', '#8BC34A', '#CDDC39',
    '#FFEB3B', '#FFC107', '#FF9800', '#FF5722',
    '#795548', '#9E9E9E', '#607D8B',
  ];

  @override
  void initState() {
    super.initState();
    if (widget.tag != null) {
      _nameController.text = widget.tag!.name;
      _descriptionController.text = widget.tag!.description ?? '';
      _selectedColor = widget.tag!.color;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.tag == null ? '添加标签' : '编辑标签'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: '标签名称',
                  prefixText: '# ',
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return '请输入标签名称';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _descriptionController,
                decoration: const InputDecoration(
                  labelText: '描述（可选）',
                ),
                maxLines: 2,
              ),
              const SizedBox(height: 16),
              Text(
                '选择颜色',
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
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                  color: Color(int.tryParse(color.replaceFirst('#', '0xFF')) ?? 0xFF607D8B),
                            : null,
                      ),
                      child: isSelected
                          ? const Icon(Icons.check, color: Colors.white)
                          : null,
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: _save,
          child: const Text('保存'),
        ),
      ],
    );
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    
    widget.onSave(
      _nameController.text.trim(),
      _selectedColor,
      _descriptionController.text.isEmpty ? null : _descriptionController.text.trim(),
    );
    Navigator.pop(context);
  }
}
