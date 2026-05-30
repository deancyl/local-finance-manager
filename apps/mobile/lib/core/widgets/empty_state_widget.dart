import 'package:flutter/material.dart';

/// Reusable empty state widget.
///
/// Displays a centered illustration/icon with message and optional action button.
/// Use this for consistent empty state UI across the app.
class EmptyStateWidget extends StatelessWidget {
  /// Icon to display
  final IconData icon;
  
  /// Icon size
  final double iconSize;
  
  /// Title text
  final String title;
  
  /// Optional subtitle/description
  final String? subtitle;
  
  /// Optional action button text
  final String? actionText;
  
  /// Optional action button callback
  final VoidCallback? onAction;
  
  /// Optional custom icon color
  final Color? iconColor;
  
  /// Whether to use a filled icon style
  final bool useFilledIcon;

  const EmptyStateWidget({
    super.key,
    required this.icon,
    required this.title,
    this.iconSize = 64.0,
    this.subtitle,
    this.actionText,
    this.onAction,
    this.iconColor,
    this.useFilledIcon = false,
  });

  /// Factory for journal entries empty state
  factory EmptyStateWidget.journalEntries({
    Key? key,
    bool hasFilters = false,
    VoidCallback? onClearFilters,
    VoidCallback? onCreateFirst,
  }) {
    return EmptyStateWidget(
      key: key,
      icon: hasFilters ? Icons.search_off : Icons.receipt_long_outlined,
      title: hasFilters ? '未找到匹配的凭证' : '暂无凭证记录',
      subtitle: hasFilters ? '尝试调整筛选条件' : '点击下方按钮创建新凭证',
      actionText: hasFilters ? '清除筛选' : null,
      onAction: hasFilters ? onClearFilters : null,
    );
  }

  /// Factory for accounts empty state
  factory EmptyStateWidget.accounts({
    Key? key,
    bool hasSearch = false,
    VoidCallback? onAddAccount,
  }) {
    return EmptyStateWidget(
      key: key,
      icon: hasSearch ? Icons.search_off : Icons.account_balance_wallet_outlined,
      title: hasSearch ? '未找到匹配的账户' : '暂无账户',
      subtitle: hasSearch ? '尝试调整搜索条件或筛选器' : '点击右下角按钮添加账户',
    );
  }

  /// Factory for reports empty state
  factory EmptyStateWidget.reports({
    Key? key,
    VoidCallback? onRetry,
  }) {
    return EmptyStateWidget(
      key: key,
      icon: Icons.account_balance_wallet_outlined,
      title: '暂无账户数据',
      subtitle: '请先添加账户和交易记录',
    );
  }

  /// Factory for import empty state
  factory EmptyStateWidget.import({
    Key? key,
    VoidCallback? onSelectFile,
  }) {
    return EmptyStateWidget(
      key: key,
      icon: Icons.upload_file_outlined,
      title: '导入金融机构账单',
      subtitle: '支持支付宝、微信支付、工商银行、建设银行、中国银行等导出的CSV、XLS、XLSX文件',
      actionText: '选择文件',
      onAction: onSelectFile,
      iconSize: 80,
    );
  }

  /// Factory for transactions empty state
  factory EmptyStateWidget.transactions({
    Key? key,
    bool hasFilters = false,
    VoidCallback? onClearFilters,
  }) {
    return EmptyStateWidget(
      key: key,
      icon: hasFilters ? Icons.search_off : Icons.receipt_long_outlined,
      title: hasFilters ? '未找到匹配的交易' : '暂无交易记录',
      subtitle: hasFilters ? '尝试调整筛选条件' : '添加您的第一笔交易',
      actionText: hasFilters ? '清除筛选' : null,
      onAction: hasFilters ? onClearFilters : null,
    );
  }

  /// Factory for categories empty state
  factory EmptyStateWidget.categories({
    Key? key,
    VoidCallback? onAddCategory,
  }) {
    return EmptyStateWidget(
      key: key,
      icon: Icons.category_outlined,
      title: '暂无分类',
      subtitle: '点击下方按钮添加分类',
      actionText: '添加分类',
      onAction: onAddCategory,
    );
  }

  /// Factory for budgets empty state
  factory EmptyStateWidget.budgets({
    Key? key,
    VoidCallback? onAddBudget,
  }) {
    return EmptyStateWidget(
      key: key,
      icon: Icons.account_balance_wallet_outlined,
      title: '暂无预算',
      subtitle: '设置预算来控制支出',
      actionText: '创建预算',
      onAction: onAddBudget,
    );
  }

  /// Factory for tags empty state
  factory EmptyStateWidget.tags({
    Key? key,
    VoidCallback? onAddTag,
  }) {
    return EmptyStateWidget(
      key: key,
      icon: Icons.label_outline,
      title: '暂无标签',
      subtitle: '创建标签来组织交易',
      actionText: '添加标签',
      onAction: onAddTag,
    );
  }

  /// Factory for generic data empty state
  factory EmptyStateWidget.generic({
    Key? key,
    String? title,
    String? subtitle,
    IconData? icon,
  }) {
    return EmptyStateWidget(
      key: key,
      icon: icon ?? Icons.inbox_outlined,
      title: title ?? '暂无数据',
      subtitle: subtitle,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final effectiveIconColor = iconColor ?? theme.colorScheme.outline;
    
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Icon with optional animation container
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: effectiveIconColor.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                useFilledIcon ? _getFilledIcon(icon) : icon,
                size: iconSize,
                color: effectiveIconColor,
              ),
            ),
            const SizedBox(height: 24),
            
            // Title
            Text(
              title,
              style: theme.textTheme.titleLarge?.copyWith(
                color: theme.colorScheme.onSurface,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
            
            // Subtitle
            if (subtitle != null) ...[
              const SizedBox(height: 8),
              Text(
                subtitle!,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
            ],
            
            // Action button
            if (actionText != null && onAction != null) ...[
              const SizedBox(height: 24),
              FilledButton.tonal(
                onPressed: onAction,
                child: Text(actionText!),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// Get filled version of outlined icons
  IconData _getFilledIcon(IconData outlinedIcon) {
    // Map common outlined icons to filled versions
    final iconMap = {
      Icons.receipt_long_outlined: Icons.receipt_long,
      Icons.account_balance_wallet_outlined: Icons.account_balance_wallet,
      Icons.upload_file_outlined: Icons.upload_file,
      Icons.inbox_outlined: Icons.inbox,
      Icons.category_outlined: Icons.category,
      Icons.label_outline: Icons.label,
      Icons.search_off: Icons.search_off,
    };
    return iconMap[outlinedIcon] ?? outlinedIcon;
  }
}

/// Animated empty state widget with fade and scale transition.
class AnimatedEmptyStateWidget extends StatefulWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final String? actionText;
  final VoidCallback? onAction;
  final Duration animationDuration;

  const AnimatedEmptyStateWidget({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.actionText,
    this.onAction,
    this.animationDuration = const Duration(milliseconds: 400),
  });

  @override
  State<AnimatedEmptyStateWidget> createState() => _AnimatedEmptyStateWidgetState();
}

class _AnimatedEmptyStateWidgetState extends State<AnimatedEmptyStateWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: widget.animationDuration,
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.5, curve: Curves.easeOut),
      ),
    );
    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.5, curve: Curves.easeOutBack),
      ),
    );
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return FadeTransition(
          opacity: _fadeAnimation,
          child: ScaleTransition(
            scale: _scaleAnimation,
            child: EmptyStateWidget(
              icon: widget.icon,
              title: widget.title,
              subtitle: widget.subtitle,
              actionText: widget.actionText,
              onAction: widget.onAction,
            ),
          ),
        );
      },
      child: const SizedBox.shrink(),
    );
  }
}

/// Helper class for animated builder (avoid duplicate)
class AnimatedBuilder extends AnimatedWidget {
  final Widget child;
  final Widget Function(BuildContext context, Widget? child) builder;

  const AnimatedBuilder({
    super.key,
    required Animation<double> animation,
    required this.builder,
    required this.child,
  }) : super(listenable: animation);

  @override
  Widget build(BuildContext context) {
    return builder(context, child);
  }
}
