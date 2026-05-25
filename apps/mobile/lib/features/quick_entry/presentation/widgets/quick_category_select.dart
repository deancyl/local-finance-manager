import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:database/database.dart';
import '../../data/quick_actions_provider.dart';
import '../../../categories/data/category_provider.dart';

/// Quick category selector showing frequently used categories
/// 
/// Features:
/// - Horizontal scrollable list of favorite categories
/// - Sorted by usage frequency
/// - One-tap selection
class QuickCategorySelect extends ConsumerWidget {
  final String? selectedCategoryId;
  final ValueChanged<String?> onCategorySelected;
  final bool isIncome;
  final int maxItems;

  const QuickCategorySelect({
    super.key,
    this.selectedCategoryId,
    required this.onCategorySelected,
    this.isIncome = false,
    this.maxItems = 10,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final frequentCategoriesAsync = ref.watch(frequentCategoriesProvider);
    
    return frequentCategoriesAsync.when(
      data: (frequentCategories) {
        // Filter by income/expense
        final filtered = frequentCategories
            .where((fc) => fc.category.isIncome == isIncome)
            .take(maxItems)
            .toList();
        
        if (filtered.isEmpty) {
          return const SizedBox.shrink();
        }
        
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Text(
                '常用分类',
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: Theme.of(context).colorScheme.outline,
                ),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 80,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: filtered.length,
                separatorBuilder: (context, index) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  final fc = filtered[index];
                  final isSelected = fc.category.id == selectedCategoryId;
                  
                  return _CategoryChip(
                    category: fc.category,
                    useCount: fc.useCount,
                    isSelected: isSelected,
                    onTap: () => onCategorySelected(
                      isSelected ? null : fc.category.id,
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
      loading: () => const SizedBox(
        height: 80,
        child: Center(
          child: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      ),
      error: (_, __) => const SizedBox.shrink(),
    );
  }
}

class _CategoryChip extends StatelessWidget {
  final Category category;
  final int useCount;
  final bool isSelected;
  final VoidCallback onTap;

  const _CategoryChip({
    required this.category,
    required this.useCount,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = category.color != null
        ? Color(int.parse(category.color!.replaceFirst('#', '0xFF')))
        : Theme.of(context).colorScheme.primary;
    
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: 72,
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: isSelected
                ? color.withOpacity(0.2)
                : Theme.of(context).colorScheme.surfaceContainerHighest,
            border: Border.all(
              color: isSelected ? color : Colors.transparent,
              width: 2,
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Icon
              Icon(
                _getIconData(category.icon),
                size: 28,
                color: isSelected ? color : Theme.of(context).colorScheme.onSurface,
              ),
              const SizedBox(height: 4),
              
              // Name
              Text(
                category.name,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  fontWeight: isSelected ? FontWeight.bold : null,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
              ),
              
              // Use count indicator
              if (useCount > 0) ...[
                const SizedBox(height: 2),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    useCount.toString(),
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      fontSize: 9,
                      color: color,
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

  IconData _getIconData(String? iconName) {
    if (iconName == null) return Icons.category;
    
    // Map common icon names to IconData
    final iconMap = {
      'restaurant': Icons.restaurant,
      'shopping_cart': Icons.shopping_cart,
      'directions_car': Icons.directions_car,
      'local_gas_station': Icons.local_gas_station,
      'home': Icons.home,
      'medical_services': Icons.medical_services,
      'school': Icons.school,
      'sports_esports': Icons.sports_esports,
      'movie': Icons.movie,
      'flight': Icons.flight,
      'work': Icons.work,
      'account_balance_wallet': Icons.account_balance_wallet,
      'savings': Icons.savings,
      'payments': Icons.payments,
      'attach_money': Icons.attach_money,
      'trending_up': Icons.trending_up,
      'card_giftcard': Icons.card_giftcard,
      'redeem': Icons.redeem,
      'fastfood': Icons.fastfood,
      'local_cafe': Icons.local_cafe,
      'local_bar': Icons.local_bar,
      'phone': Icons.phone,
      'wifi': Icons.wifi,
      'electric_bolt': Icons.electric_bolt,
      'water_drop': Icons.water_drop,
      'fitness_center': Icons.fitness_center,
      'pets': Icons.pets,
      'child_care': Icons.child_care,
      'spa': Icons.spa,
    };
    
    return iconMap[iconName] ?? Icons.category;
  }
}
