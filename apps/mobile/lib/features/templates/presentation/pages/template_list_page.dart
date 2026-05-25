import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/template_provider.dart';
import '../widgets/template_card.dart';

/// Template list page for managing transaction templates
class TemplateListPage extends ConsumerStatefulWidget {
  final bool selectMode;
  final void Function(TemplateModel)? onTemplateSelected;

  const TemplateListPage({
    super.key,
    this.selectMode = false,
    this.onTemplateSelected,
  });

  @override
  ConsumerState<TemplateListPage> createState() => _TemplateListPageState();
}

class _TemplateListPageState extends ConsumerState<TemplateListPage> {
  String _searchQuery = '';
  String? _selectedCategory;

  @override
  Widget build(BuildContext context) {
    final templatesAsync = ref.watch(templatesProvider);
    final categoriesAsync = ref.watch(templateCategoriesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('交易模板'),
        actions: [
          if (!widget.selectMode)
            IconButton(
              icon: const Icon(Icons.add),
              onPressed: () => _showCreateDialog(context),
              tooltip: '新建模板',
            ),
        ],
      ),
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              decoration: InputDecoration(
                hintText: '搜索模板...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
              ),
              onChanged: (value) {
                setState(() => _searchQuery = value);
              },
            ),
          ),
          // Category filter
          categoriesAsync.when(
            data: (categories) {
              if (categories.isEmpty) return const SizedBox.shrink();
              return SizedBox(
                height: 50,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  children: [
                    FilterChip(
                      label: const Text('全部'),
                      selected: _selectedCategory == null,
                      onSelected: (_) {
                        setState(() => _selectedCategory = null);
                      },
                    ),
                    const SizedBox(width: 8),
                    ...categories.map((category) => Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: FilterChip(
                            label: Text(category),
                            selected: _selectedCategory == category,
                            onSelected: (_) {
                              setState(() => _selectedCategory = category);
                            },
                          ),
                        )),
                  ],
                ),
              );
            },
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
          ),
          const SizedBox(height: 8),
          // Templates list
          Expanded(
            child: templatesAsync.when(
              data: (templates) {
                // Apply filters
                var filteredTemplates = templates.where((t) {
                  // Search filter
                  if (_searchQuery.isNotEmpty) {
                    final query = _searchQuery.toLowerCase();
                    final nameMatch = t.name.toLowerCase().contains(query);
                    final descMatch =
                        t.description?.toLowerCase().contains(query) ?? false;
                    if (!nameMatch && !descMatch) return false;
                  }
                  // Category filter
                  if (_selectedCategory != null &&
                      t.category != _selectedCategory) {
                    return false;
                  }
                  return true;
                }).toList();

                if (filteredTemplates.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.description_outlined,
                          size: 64,
                          color: Theme.of(context).colorScheme.outline,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _searchQuery.isEmpty
                              ? '暂无模板'
                              : '未找到匹配的模板',
                          style: Theme.of(context).textTheme.bodyLarge,
                        ),
                        if (_searchQuery.isEmpty && !widget.selectMode) ...[
                          const SizedBox(height: 16),
                          ElevatedButton.icon(
                            icon: const Icon(Icons.add),
                            label: const Text('创建模板'),
                            onPressed: () => _showCreateDialog(context),
                          ),
                        ],
                      ],
                    ),
                  );
                }

                // Group by favorites and categories
                final favorites = filteredTemplates.where((t) => t.isFavorite).toList();
                final nonFavorites = filteredTemplates.where((t) => !t.isFavorite).toList();
                final grouped = _groupByCategory(nonFavorites);

                return ListView(
                  children: [
                    // Favorites section
                    if (favorites.isNotEmpty) ...[
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                        child: Text(
                          '收藏',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                      ),
                      ...favorites.map((t) => TemplateCard(
                            template: t,
                            onUse: widget.selectMode
                                ? () => widget.onTemplateSelected?.call(t)
                                : null,
                            onEdit: () => _editTemplate(context, t),
                          )),
                    ],
                    // Categories
                    ...grouped.entries.map((entry) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                            child: Text(
                              entry.key,
                              style:
                                  Theme.of(context).textTheme.titleMedium?.copyWith(
                                        fontWeight: FontWeight.bold,
                                      ),
                            ),
                          ),
                          ...entry.value.map((t) => TemplateCard(
                                template: t,
                                onUse: widget.selectMode
                                    ? () => widget.onTemplateSelected?.call(t)
                                    : null,
                                onEdit: () => _editTemplate(context, t),
                              )),
                        ],
                      );
                    }),
                    const SizedBox(height: 16),
                  ],
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, st) => Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline, size: 48, color: Colors.red),
                    const SizedBox(height: 16),
                    Text('加载失败: $e'),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () => ref.refresh(templatesProvider),
                      child: const Text('重试'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: !widget.selectMode
          ? FloatingActionButton.extended(
              onPressed: () => _showCreateDialog(context),
              icon: const Icon(Icons.add),
              label: const Text('新建模板'),
            )
          : null,
    );
  }

  Map<String, List<TemplateModel>> _groupByCategory(List<TemplateModel> templates) {
    final grouped = <String, List<TemplateModel>>{};

    for (final t in templates) {
      final category = t.category ?? '其他';
      grouped.putIfAbsent(category, () => []).add(t);
    }

    // Sort categories alphabetically, but put '其他' at the end
    final sortedKeys = grouped.keys.toList()
      ..sort((a, b) {
        if (a == '其他') return 1;
        if (b == '其他') return -1;
        return a.compareTo(b);
      });

    return Map.fromEntries(sortedKeys.map((k) => MapEntry(k, grouped[k]!)));
  }

  void _showCreateDialog(BuildContext context) {
    context.push('/settings/templates/edit');
  }

  void _editTemplate(BuildContext context, TemplateModel template) {
    context.push('/settings/templates/edit', extra: template);
  }
}
