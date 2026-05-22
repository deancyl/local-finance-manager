import 'package:flutter/material.dart';

/// Metadata for a dashboard widget.
class DashboardWidgetMetadata {
  final String id;
  final String title;
  final IconData icon;
  final String description;
  final WidgetSize size;

  const DashboardWidgetMetadata({
    required this.id,
    required this.title,
    required this.icon,
    required this.description,
    this.size = WidgetSize.medium,
  });
}

/// Widget size options.
enum WidgetSize {
  small,
  medium,
  large,
}

/// Registry of all available dashboard widgets.
class DashboardWidgetRegistry {
  static const List<DashboardWidgetMetadata> availableWidgets = [
    DashboardWidgetMetadata(
      id: 'net_worth',
      title: '净资产',
      icon: Icons.account_balance_wallet,
      description: '显示总资产、负债和净资产',
      size: WidgetSize.large,
    ),
    DashboardWidgetMetadata(
      id: 'quick_stats',
      title: '快速统计',
      icon: Icons.analytics_outlined,
      description: '今日交易数、本月收支',
      size: WidgetSize.medium,
    ),
    DashboardWidgetMetadata(
      id: 'quick_actions',
      title: '快捷操作',
      icon: Icons.flash_on_outlined,
      description: '常用功能快捷入口',
      size: WidgetSize.medium,
    ),
    DashboardWidgetMetadata(
      id: 'recent_transactions',
      title: '最近交易',
      icon: Icons.receipt_long_outlined,
      description: '最近10笔交易记录',
      size: WidgetSize.large,
    ),
    DashboardWidgetMetadata(
      id: 'budget_progress',
      title: '预算进度',
      icon: Icons.savings_outlined,
      description: '各分类预算使用情况',
      size: WidgetSize.medium,
    ),
    DashboardWidgetMetadata(
      id: 'monthly_trend',
      title: '月度趋势',
      icon: Icons.trending_up_outlined,
      description: '近6个月收支趋势图',
      size: WidgetSize.large,
    ),
    DashboardWidgetMetadata(
      id: 'category_breakdown',
      title: '分类统计',
      icon: Icons.pie_chart_outline,
      description: '本月支出分类占比',
      size: WidgetSize.medium,
    ),
    DashboardWidgetMetadata(
      id: 'upcoming_scheduled',
      title: '计划交易',
      icon: Icons.event_repeat_outlined,
      description: '未来7天的计划交易',
      size: WidgetSize.large,
    ),
  ];

  /// Get widget metadata by ID.
  static DashboardWidgetMetadata? getWidget(String id) {
    try {
      return availableWidgets.firstWhere((w) => w.id == id);
    } catch (_) {
      return null;
    }
  }

  /// Get all widget IDs.
  static List<String> get allWidgetIds {
    return availableWidgets.map((w) => w.id).toList();
  }

  /// Check if a widget ID is valid.
  static bool isValidWidget(String id) {
    return availableWidgets.any((w) => w.id == id);
  }
}
