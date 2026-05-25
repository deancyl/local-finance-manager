import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/quick_actions_provider.dart';

/// One-tap entry templates for quick transactions
/// 
/// Features:
/// - Pre-configured templates for common transactions
/// - One tap to create transaction with defaults
/// - Customizable by user
/// - Horizontal scrollable grid
class OneTapEntryWidget extends ConsumerStatefulWidget {
  final int maxItems;

  const OneTapEntryWidget({
    super.key,
    this.maxItems = 6,
  });

  @override
  ConsumerState<OneTapEntryWidget> createState() => _OneTapEntryWidgetState();
}

class _OneTapEntryWidgetState extends ConsumerState<OneTapEntryWidget> {
  @override
  Widget build(BuildContext context) {
    final templates = ref.watch(oneTapTemplatesProvider);
    
    if (templates.isEmpty) {
      return _buildEmptyState(context);
    }
    
    final displayTemplates = templates.take(widget.maxItems).toList();
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Row(
            children: [
              Icon(
                Icons.flash_on,
                size: 16,
                color: Theme.of(context).colorScheme.outline,
              ),
              const SizedBox(width: 4),
              Text(
                '一键记账',
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: Theme.of(context).colorScheme.outline,
                ),
              ),
              const Spacer(),
              TextButton.icon(
                icon: const Icon(Icons.edit, size: 16),
                label: const Text('编辑'),
                style: TextButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                ),
                onPressed: () => _showEditDialog(context),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 100,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: displayTemplates.length,
            separatorBuilder: (context, index) => const SizedBox(width: 8),
            itemBuilder: (context, index) {
              final template = displayTemplates[index];
              return _OneTapTemplateCard(
                template: template,
                onTap: () => _handleTemplateTap(template),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(
            Icons.flash_on,
            color: Theme.of(context).colorScheme.outline,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '一键记账',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: 4),
                Text(
                  '创建常用交易模板，一键完成记账',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.outline,
                  ),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: () => _showEditDialog(context),
            child: const Text('创建'),
          ),
        ],
      ),
    );
  }

  void _handleTemplateTap(OneTapEntryTemplate template) {
    // Navigate to transaction page with pre-filled values
    context.push(
      '/transactions/add',
      extra: {
        'categoryId': template.categoryId,
        'accountId': template.accountId,
        'amount': template.defaultAmount,
        'description': template.description,
        'notes': template.notes,
        'isIncome': template.isIncome,
      },
    );
  }

  void _showEditDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => _OneTapTemplatesDialog(
        templates: ref.read(oneTapTemplatesProvider),
        onAdd: (template) {
          ref.read(oneTapTemplatesProvider.notifier).addTemplate(template);
        },
        onUpdate: (template) {
          ref.read(oneTapTemplatesProvider.notifier).updateTemplate(template);
        },
        onDelete: (id) {
          ref.read(oneTapTemplatesProvider.notifier).deleteTemplate(id);
        },
        onReorder: (oldIndex, newIndex) {
          ref.read(oneTapTemplatesProvider.notifier).reorderTemplates(oldIndex, newIndex);
        },
      ),
    );
  }
}

class _OneTapTemplateCard extends StatelessWidget {
  final OneTapEntryTemplate template;
  final VoidCallback onTap;

  const _OneTapTemplateCard({
    required this.template,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: 100,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: template.isIncome
                ? Colors.green.withOpacity(0.1)
                : Colors.red.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: template.isIncome ? Colors.green : Colors.red,
              width: 1,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Icon
              Icon(
                template.isIncome ? Icons.trending_up : Icons.trending_down,
                color: template.isIncome ? Colors.green : Colors.red,
                size: 32,
              ),
              const SizedBox(height: 8),
              
              // Name
              Text(
                template.name,
                style: Theme.of(context).textTheme.titleSmall,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
              ),
              
              // Amount
              if (template.defaultAmount != null) ...[
                const SizedBox(height: 4),
                Text(
                  '¥${template.defaultAmount!.toStringAsFixed(2)}',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: Theme.of(context).colorScheme.outline,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _OneTapTemplatesDialog extends StatefulWidget {
  final List<OneTapEntryTemplate> templates;
  final ValueChanged<OneTapEntryTemplate> onAdd;
  final ValueChanged<OneTapEntryTemplate> onUpdate;
  final ValueChanged<String> onDelete;
  final void Function(int, int) onReorder;

  const _OneTapTemplatesDialog({
    required this.templates,
    required this.onAdd,
    required this.onUpdate,
    required this.onDelete,
    required this.onReorder,
  });

  @override
  State<_OneTapTemplatesDialog> createState() => _OneTapTemplatesDialogState();
}

class _OneTapTemplatesDialogState extends State<_OneTapTemplatesDialog> {
  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        width: double.maxFinite,
        constraints: const BoxConstraints(maxHeight: 500),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Text(
                    '一键记账模板',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.add),
                    onPressed: () => _showAddEditDialog(context),
                    tooltip: '添加模板',
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            
            // Template list
            Expanded(
              child: widget.templates.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.flash_on,
                            size: 48,
                            color: Theme.of(context).colorScheme.outline,
                          ),
                          const SizedBox(height: 16),
                          const Text('暂无模板'),
                          TextButton(
                            onPressed: () => _showAddEditDialog(context),
                            child: const Text('创建模板'),
                          ),
                        ],
                      ),
                    )
                  : ReorderableListView.builder(
                      itemCount: widget.templates.length,
                      onReorder: widget.onReorder,
                      itemBuilder: (context, index) {
                        final template = widget.templates[index];
                        return ListTile(
                          key: ValueKey(template.id),
                          title: Text(template.name),
                          subtitle: Text(
                            template.isIncome ? '收入' : '支出',
                            style: TextStyle(
                              color: template.isIncome ? Colors.green : Colors.red,
                            ),
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.edit),
                                onPressed: () => _showAddEditDialog(
                                  context,
                                  template: template,
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete),
                                onPressed: () => _confirmDelete(template),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
            
            // Close button
            Padding(
              padding: const EdgeInsets.all(16),
              child: TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('关闭'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showAddEditDialog(BuildContext context, {OneTapEntryTemplate? template}) {
    showDialog(
      context: context,
      builder: (context) => _AddEditTemplateDialog(
        template: template,
        onSave: (newTemplate) {
          if (template == null) {
            widget.onAdd(newTemplate);
          } else {
            widget.onUpdate(newTemplate);
          }
          Navigator.pop(context);
        },
      ),
    );
  }

  void _confirmDelete(OneTapEntryTemplate template) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除模板'),
        content: Text('确定要删除"${template.name}"吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () {
              widget.onDelete(template.id);
              Navigator.pop(context);
            },
            child: const Text('删除'),
          ),
        ],
      ),
    );
  }
}

class _AddEditTemplateDialog extends StatefulWidget {
  final OneTapEntryTemplate? template;
  final ValueChanged<OneTapEntryTemplate> onSave;

  const _AddEditTemplateDialog({
    this.template,
    required this.onSave,
  });

  @override
  State<_AddEditTemplateDialog> createState() => _AddEditTemplateDialogState();
}

class _AddEditTemplateDialogState extends State<_AddEditTemplateDialog> {
  late TextEditingController _nameController;
  late TextEditingController _amountController;
  late TextEditingController _descriptionController;
  bool _isIncome = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.template?.name);
    _amountController = TextEditingController(
      text: widget.template?.defaultAmount?.toStringAsFixed(2),
    );
    _descriptionController = TextEditingController(text: widget.template?.description);
    _isIncome = widget.template?.isIncome ?? false;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _amountController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.template == null ? '创建模板' : '编辑模板'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: '模板名称',
                hintText: '例如：早餐、地铁',
              ),
            ),
            const SizedBox(height: 16),
            
            // Income/Expense toggle
            Row(
              children: [
                Expanded(
                  child: ChoiceChip(
                    label: const Text('支出'),
                    selected: !_isIncome,
                    onSelected: (selected) {
                      setState(() => _isIncome = false);
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ChoiceChip(
                    label: const Text('收入'),
                    selected: _isIncome,
                    onSelected: (selected) {
                      setState(() => _isIncome = true);
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            TextField(
              controller: _amountController,
              decoration: const InputDecoration(
                labelText: '默认金额（可选）',
                prefixText: '¥',
              ),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
            ),
            const SizedBox(height: 16),
            
            TextField(
              controller: _descriptionController,
              decoration: const InputDecoration(
                labelText: '默认描述（可选）',
              ),
            ),
          ],
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
    if (_nameController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请输入模板名称')),
      );
      return;
    }
    
    final amount = double.tryParse(_amountController.text);
    
    widget.onSave(OneTapEntryTemplate(
      id: widget.template?.id ?? '',
      name: _nameController.text,
      defaultAmount: amount,
      description: _descriptionController.text.isEmpty ? null : _descriptionController.text,
      isIncome: _isIncome,
      categoryId: widget.template?.categoryId,
      accountId: widget.template?.accountId,
    ));
  }
}
