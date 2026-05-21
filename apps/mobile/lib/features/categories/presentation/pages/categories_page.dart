import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:database/database.dart';
import '../../data/category_provider.dart';
import '../widgets/add_category_dialog.dart';
import '../widgets/category_icon_picker.dart';
import '../widgets/category_color_picker.dart';

class CategoriesPage extends ConsumerStatefulWidget {
  const CategoriesPage({super.key});

  @override
  ConsumerState<CategoriesPage> createState() => _CategoriesPageState();
}

class _CategoriesPageState extends ConsumerState<CategoriesPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final categoriesAsync = ref.watch(categoriesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('分类管理'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: '支出分类'),
            Tab(text: '收入分类'),
          ],
        ),
      ),
      body: categoriesAsync.when(
        data: (categories) {
          final expenseCategories = categories.where((c) => !c.isIncome).toList();
          final incomeCategories = categories.where((c) => c.isIncome).toList();

          return TabBarView(
            controller: _tabController,
            children: [
              _buildCategoryList(context, ref, expenseCategories, false),
              _buildCategoryList(context, ref, incomeCategories, true),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('错误: $error')),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddDialog(context),
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildCategoryList(
    BuildContext context,
    WidgetRef ref,
    List<Category> categories,
    bool isIncome,
  ) {
    if (categories.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.category_outlined,
              size: 64,
              color: Theme.of(context).colorScheme.outline,
            ),
            const SizedBox(height: 16),
            Text(
              isIncome ? '暂无收入分类' : '暂无支出分类',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: Theme.of(context).colorScheme.outline,
                  ),
            ),
            const SizedBox(height: 8),
            FilledButton.icon(
              onPressed: () => _showAddDialog(context, isIncome: isIncome),
              icon: const Icon(Icons.add),
              label: const Text('添加分类'),
            ),
          ],
        ),
      );
    }

    // Group by parent
    final rootCategories = categories.where((c) => c.parentId == null).toList();
    final childCategories = categories.where((c) => c.parentId != null).toList();

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: rootCategories.length,
      itemBuilder: (context, index) {
        final category = rootCategories[index];
        final children = childCategories
            .where((c) => c.parentId == category.id)
            .toList();

        return _buildCategoryCard(context, ref, category, children);
      },
    );
  }

  Widget _buildCategoryCard(
    BuildContext context,
    WidgetRef ref,
    Category category,
    List<Category> children,
  ) {
    final color = category.color != null
        ? CategoryColors.hexToColor(category.color)
        : Theme.of(context).colorScheme.primary;
    final icon = CategoryIcons.getIconData(category.icon);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          ListTile(
            onTap: () => _showEditDialog(context, category),
            leading: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: Colors.white, size: 22),
            ),
            title: Text(
              category.name,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            subtitle: children.isNotEmpty
                ? Text('包含 ${children.length} 个子分类')
                : null,
            trailing: PopupMenuButton<String>(
              onSelected: (value) {
                switch (value) {
                  case 'edit':
                    _showEditDialog(context, category);
                    break;
                  case 'add_child':
                    _showAddDialog(
                      context,
                      isIncome: category.isIncome,
                      parentId: category.id,
                    );
                    break;
                  case 'delete':
                    _deleteCategory(context, ref, category);
                    break;
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'edit',
                  child: Row(
                    children: [
                      Icon(Icons.edit_outlined),
                      SizedBox(width: 8),
                      Text('编辑'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'add_child',
                  child: Row(
                    children: [
                      Icon(Icons.add),
                      SizedBox(width: 8),
                      Text('添加子分类'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'delete',
                  child: Row(
                    children: [
                      Icon(Icons.delete_outline, color: Colors.red),
                      SizedBox(width: 8),
                      Text('删除', style: TextStyle(color: Colors.red)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (children.isNotEmpty)
            ...children.map((child) {
              final childColor = child.color ?? category.color;
              final childIcon = CategoryIcons.getIconData(child.icon);
              
              return Container(
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                ),
                child: ListTile(
                  onTap: () => _showEditDialog(context, child),
                  contentPadding: const EdgeInsets.only(
                    left: 72,
                    right: 16,
                    top: 4,
                    bottom: 4,
                  ),
                  leading: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: childColor != null
                          ? CategoryColors.hexToColor(childColor)
                          : color.withOpacity(0.7),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Icon(childIcon, color: Colors.white, size: 16),
                  ),
                  title: Text(
                    child.name,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit_outlined, size: 20),
                        onPressed: () => _showEditDialog(context, child),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline, size: 20),
                        onPressed: () => _deleteCategory(context, ref, child),
                      ),
                    ],
                  ),
                ),
              );
            }),
        ],
      ),
    );
  }

  void _showAddDialog(
    BuildContext context, {
    bool isIncome = false,
    String? parentId,
  }) {
    showDialog(
      context: context,
      builder: (context) => AddCategoryDialog(
        initialIsIncome: isIncome,
      ),
    );
  }

  void _showEditDialog(BuildContext context, Category category) {
    showDialog(
      context: context,
      builder: (context) => AddCategoryDialog(category: category),
    );
  }

  void _deleteCategory(
    BuildContext context,
    WidgetRef ref,
    Category category,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除分类'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('确定要删除分类 "${category.name}" 吗？'),
            const SizedBox(height: 8),
            Text(
              '注意：删除后无法恢复',
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
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () {
              ref.read(categoryNotifierProvider.notifier).deleteCategory(category.id);
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('分类已删除')),
              );
            },
            child: const Text('删除'),
          ),
        ],
      ),
    );
  }
}
