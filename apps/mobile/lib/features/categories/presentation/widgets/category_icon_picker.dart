import 'package:flutter/material.dart';

/// Icon data for category icons
class CategoryIconData {
  final String name;
  final IconData icon;
  final String label;

  const CategoryIconData({
    required this.name,
    required this.icon,
    required this.label,
  });
}

/// Common finance category icons
class CategoryIcons {
  static const List<CategoryIconData> expenseIcons = [
    CategoryIconData(name: 'restaurant', icon: Icons.restaurant, label: '餐饮'),
    CategoryIconData(name: 'directions_car', icon: Icons.directions_car, label: '交通'),
    CategoryIconData(name: 'shopping_cart', icon: Icons.shopping_cart, label: '购物'),
    CategoryIconData(name: 'movie', icon: Icons.movie, label: '娱乐'),
    CategoryIconData(name: 'local_hospital', icon: Icons.local_hospital, label: '医疗'),
    CategoryIconData(name: 'school', icon: Icons.school, label: '教育'),
    CategoryIconData(name: 'home', icon: Icons.home, label: '住房'),
    CategoryIconData(name: 'phone', icon: Icons.phone, label: '通讯'),
    CategoryIconData(name: 'water_drop', icon: Icons.water_drop, label: '水电'),
    CategoryIconData(name: 'local_gas_station', icon: Icons.local_gas_station, label: '加油'),
    CategoryIconData(name: 'fitness_center', icon: Icons.fitness_center, label: '健身'),
    CategoryIconData(name: 'pets', icon: Icons.pets, label: '宠物'),
    CategoryIconData(name: 'child_care', icon: Icons.child_care, label: '育儿'),
    CategoryIconData(name: 'card_giftcard', icon: Icons.card_giftcard, label: '礼物'),
    CategoryIconData(name: 'flight', icon: Icons.flight, label: '旅行'),
    CategoryIconData(name: 'train', icon: Icons.train, label: '火车'),
    CategoryIconData(name: 'directions_bus', icon: Icons.directions_bus, label: '公交'),
    CategoryIconData(name: 'two_wheeler', icon: Icons.two_wheeler, label: '骑行'),
    CategoryIconData(name: 'local_laundry_service', icon: Icons.local_laundry_service, label: '洗衣'),
    CategoryIconData(name: 'spa', icon: Icons.spa, label: '美容'),
    CategoryIconData(name: 'cut', icon: Icons.cut, label: '理发'),
    CategoryIconData(name: 'repair', icon: Icons.home_repair_service, label: '维修'),
    CategoryIconData(name: 'insurance', icon: Icons.security, label: '保险'),
    CategoryIconData(name: 'account_balance', icon: Icons.account_balance, label: '银行'),
    CategoryIconData(name: 'receipt_long', icon: Icons.receipt_long, label: '账单'),
    CategoryIconData(name: 'more_horiz', icon: Icons.more_horiz, label: '其他'),
  ];

  static const List<CategoryIconData> incomeIcons = [
    CategoryIconData(name: 'account_balance_wallet', icon: Icons.account_balance_wallet, label: '工资'),
    CategoryIconData(name: 'trending_up', icon: Icons.trending_up, label: '投资'),
    CategoryIconData(name: 'savings', icon: Icons.savings, label: '储蓄'),
    CategoryIconData(name: 'payments', icon: Icons.payments, label: '奖金'),
    CategoryIconData(name: 'work', icon: Icons.work, label: '兼职'),
    CategoryIconData(name: 'business', icon: Icons.business, label: '经营'),
    CategoryIconData(name: 'sell', icon: Icons.sell, label: '出售'),
    CategoryIconData(name: 'redeem', icon: Icons.redeem, label: '返现'),
    CategoryIconData(name: 'volunteer_activism', icon: Icons.volunteer_activism, label: '红包'),
    CategoryIconData(name: 'attach_money', icon: Icons.attach_money, label: '利息'),
    CategoryIconData(name: 'more_horiz', icon: Icons.more_horiz, label: '其他'),
  ];

  /// Get IconData from icon name string
  static IconData getIconData(String? iconName) {
    if (iconName == null) return Icons.category;
    
    final allIcons = [...expenseIcons, ...incomeIcons];
    final found = allIcons.where((i) => i.name == iconName).firstOrNull;
    return found?.icon ?? Icons.category;
  }
}

/// Category icon picker widget
class CategoryIconPicker extends StatelessWidget {
  final String? selectedIcon;
  final ValueChanged<String> onIconSelected;
  final bool isIncome;

  const CategoryIconPicker({
    super.key,
    this.selectedIcon,
    required this.onIconSelected,
    this.isIncome = false,
  });

  @override
  Widget build(BuildContext context) {
    final icons = isIncome ? CategoryIcons.incomeIcons : CategoryIcons.expenseIcons;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '选择图标',
          style: Theme.of(context).textTheme.titleSmall,
        ),
        const SizedBox(height: 12),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 5,
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            childAspectRatio: 1,
          ),
          itemCount: icons.length,
          itemBuilder: (context, index) {
            final iconData = icons[index];
            final isSelected = selectedIcon == iconData.name;
            
            return InkWell(
              onTap: () => onIconSelected(iconData.name),
              borderRadius: BorderRadius.circular(12),
              child: Container(
                decoration: BoxDecoration(
                  color: isSelected
                      ? Theme.of(context).colorScheme.primaryContainer
                      : Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(12),
                  border: isSelected
                      ? Border.all(
                          color: Theme.of(context).colorScheme.primary,
                          width: 2,
                        )
                      : null,
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      iconData.icon,
                      color: isSelected
                          ? Theme.of(context).colorScheme.primary
                          : Theme.of(context).colorScheme.onSurfaceVariant,
                      size: 24,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      iconData.label,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: isSelected
                                ? Theme.of(context).colorScheme.primary
                                : Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}
