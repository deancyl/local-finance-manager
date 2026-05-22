import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../data/template_provider.dart';

/// Template management page
class TemplateListPage extends ConsumerWidget {
  const TemplateListPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final templatesAsync = ref.watch(templatesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('交易模板'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _showCreateDialog(context, ref),
            tooltip: '新建模板',
          ),
        ],
      ),
      body: templatesAsync.when(
        data: (templates) {
          if (templates.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.template, size: 64, color: Colors.grey),
                  const SizedBox(height: 16),
                  const Text('暂无模板'),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.add),
                    label: const Text('创建模板'),
                    onPressed: () => _showCreateDialog(context, ref),
                  ),
                ],
              ),
            );
          }

          // Group by category
          final grouped = _groupByCategory(templates);

          return ListView(
            children: [
              // Favorites section
              ...templates.where((t) => t.isFavorite).map(
                (t) => TemplateTile(template: t),
              ),

              if (templates.any((t) => t.isFavorite))
                const Divider(),

              // Categories
              ...grouped.entries.map((entry) {
                return ExpansionTile(
                  title: Text(entry.key),
                  initiallyExpanded: true,
                  children: entry.value.map(
                    (t) => TemplateTile(template: t),
                  ).toList(),
                );
              }),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) => Center(
          child: Text('加载失败: $e'),
        ),
      ),
    );
  }

  Map<String, List<TemplateModel>> _groupByCategory(List<TemplateModel> templates) {
    final grouped = <String, List<TemplateModel>>{};

    for (final t in templates) {
      if (t.isFavorite) continue; // Skip favorites

      final category = t.category ?? '其他';
      grouped.putIfAbsent(category, () => []).add(t);
    }

    return grouped;
  }

  void _showCreateDialog(BuildContext context, WidgetRef ref) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const TemplateEditPage(),
      ),
    );
  }
}

/// Template tile for list display
class TemplateTile extends ConsumerWidget {
  final TemplateModel template;

  const TemplateTile({super.key, required this.template});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final timeStr = template.lastUsedAt != null
        ? DateFormat('MM-dd HH:mm').format(template.lastUsedAt!)
        : '未使用';

    return ListTile(
      leading: IconButton(
        icon: Icon(
          template.isFavorite ? Icons.star : Icons.star_border,
          color: template.isFavorite ? Colors.amber : null,
        ),
        onPressed: () =>
            ref.read(templateNotifierProvider.notifier).toggleFavorite(template.id),
        tooltip: template.isFavorite ? '取消收藏' : '收藏',
      ),
      title: Text(template.name),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (template.description != null)
            Text(template.description!, maxLines: 1),
          Text('${template.splits.length} 个分录 · 使用 ${template.useCount} 次 · $timeStr'),
        ],
      ),
      trailing: PopupMenuButton(
        itemBuilder: (context) => [
          const PopupMenuItem(
            value: 'edit',
            child: ListTile(
              leading: Icon(Icons.edit),
              title: Text('编辑'),
            ),
          ),
          const PopupMenuItem(
            value: 'use',
            child: ListTile(
              leading: Icon(Icons.add_circle),
              title: Text('使用模板'),
            ),
          ),
          const PopupMenuItem(
            value: 'delete',
            child: ListTile(
              leading: Icon(Icons.delete),
              title: Text('删除'),
            ),
          ),
        ],
        onSelected: (value) {
          switch (value) {
            case 'edit':
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => TemplateEditPage(template: template),
                ),
              );
              break;
            case 'use':
              _useTemplate(context, ref);
              break;
            case 'delete':
              _confirmDelete(context, ref);
              break;
          }
        },
      ),
      onTap: () => _useTemplate(context, ref),
    );
  }

  void _useTemplate(BuildContext context, WidgetRef ref) {
    ref.read(templateNotifierProvider.notifier).recordUsage(template.id);
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
        content: Text('确定删除模板 "${template.name}" 吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              Navigator.pop(context);
              ref.read(templateNotifierProvider.notifier).deleteTemplate(template.id);
            },
            child: const Text('删除'),
          ),
        ],
      ),
    );
  }
}

/// Template edit/create page
class TemplateEditPage extends ConsumerStatefulWidget {
  final TemplateModel? template;

  const TemplateEditPage({super.key, this.template});

  @override
  ConsumerState<TemplateEditPage> createState() => _TemplateEditPageState();
}

class _TemplateEditPageState extends ConsumerState<TemplateEditPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _categoryController = TextEditingController();

  List<SplitTemplateData> _splits = [];

  @override
  void initState() {
    super.initState();
    if (widget.template != null) {
      _nameController.text = widget.template!.name;
      _descriptionController.text = widget.template!.description ?? '';
      _categoryController.text = widget.template!.category ?? '';
      _splits = widget.template!.splits;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _categoryController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.template == null ? '新建模板' : '编辑模板'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: '模板名称',
                hintText: '例如：月薪、房租',
              ),
              validator: (v) => v?.isEmpty == true ? '请输入名称' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _descriptionController,
              decoration: const InputDecoration(
                labelText: '描述',
                hintText: '可选',
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _categoryController,
              decoration: const InputDecoration(
                labelText: '分类',
                hintText: '例如：收入、支出',
              ),
            ),
            const SizedBox(height: 24),
            Text(
              '分录模板',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            ..._splits.asMap().entries.map((entry) {
              final index = entry.key;
              final split = entry.value;
              return Card(
                child: ListTile(
                  title: Text('账户: ${split.accountId}'),
                  subtitle: Text('金额: ${split.amount}'),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete),
                    onPressed: () {
                      setState(() => _splits.removeAt(index));
                    },
                  ),
                ),
              );
            }),
            ElevatedButton.icon(
              icon: const Icon(Icons.add),
              label: const Text('添加分录'),
              onPressed: () {
                // TODO: Show split selection dialog
                setState(() => _splits.add(
                  const SplitTemplateData(accountId: 'placeholder', amount: 0),
                ));
              },
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _saveTemplate,
              child: Text(widget.template == null ? '创建' : '保存'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _saveTemplate() async {
    if (!_formKey.currentState!.validate()) return;
    if (_splits.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请至少添加一个分录')),
      );
      return;
    }

    final notifier = ref.read(templateNotifierProvider.notifier);

    if (widget.template == null) {
      await notifier.createTemplate(
        name: _nameController.text,
        description: _descriptionController.text,
        category: _categoryController.text,
        currencyId: 'CNY',
        splits: _splits,
      );
    } else {
      // Update existing template
      await notifier.updateTemplate(TemplateModel(
        id: widget.template!.id,
        name: _nameController.text,
        description: _descriptionController.text,
        category: _categoryController.text,
        currencyId: widget.template!.currencyId,
        splits: _splits,
        useCount: widget.template!.useCount,
        lastUsedAt: widget.template!.lastUsedAt,
        isFavorite: widget.template!.isFavorite,
      ));
    }

    if (mounted) Navigator.pop(context);
  }
}