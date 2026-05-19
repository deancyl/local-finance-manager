import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:database/database.dart';
import '../../data/category_provider.dart';

class CategoriesPage extends ConsumerWidget {
  const CategoriesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categoriesAsync = ref.watch(categoriesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('分类管理'),
      ),
      body: categoriesAsync.when(
        data: (categories) {
          final expenseCategories = categories.where((c) => !c.isIncome).toList();
          final incomeCategories = categories.where((c) => c.isIncome).toList();

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (expenseCategories.isNotEmpty) ...[
                _buildSectionHeader(context, '支出分类', Colors.red),
                ...expenseCategories.map((c) => _buildCategoryItem(context, ref, c)),
                const SizedBox(height: 24),
              ],
              if (incomeCategories.isNotEmpty) ...[
                _buildSectionHeader(context, '收入分类', Colors.green),
                ...incomeCategories.map((c) => _buildCategoryItem(context, ref, c)),
              ],
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('错误: $error')),
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 20,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryItem(BuildContext context, WidgetRef ref, Category category) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: category.color != null
                ? Color(int.parse(category.color!.replaceFirst('#', '0xFF')))
                : Theme.of(context).colorScheme.primary,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            _getIconData(category.icon),
            color: Colors.white,
            size: 20,
          ),
        ),
        title: Text(category.name),
        trailing: IconButton(
          icon: const Icon(Icons.delete_outline),
          onPressed: () => _deleteCategory(context, ref, category),
        ),
      ),
    );
  }

  IconData _getIconData(String? iconName) {
    return switch (iconName) {
      'restaurant' => Icons.restaurant,
      'directions_car' => Icons.directions_car,
      'shopping_cart' => Icons.shopping_cart,
      'movie' => Icons.movie,
      'local_hospital' => Icons.local_hospital,
      'school' => Icons.school,
      'account_balance_wallet' => Icons.account_balance_wallet,
      'card_giftcard' => Icons.card_giftcard,
      'trending_up' => Icons.trending_up,
      _ => Icons.category,
    };
  }

  void _deleteCategory(BuildContext context, WidgetRef ref, Category category) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除分类'),
        content: Text('确定要删除分类 "${category.name}" 吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () {
              ref.read(categoryNotifierProvider.notifier).deleteCategory(category.id);
              Navigator.pop(context);
            },
            child: const Text('删除'),
          ),
        ],
      ),
    );
  }
}