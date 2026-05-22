import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:database/database.dart';

import 'dashboard_config_provider.dart';
import 'dashboard_widget_registry.dart';
import 'package:finance_app/features/home/data/home_providers.dart';

/// Customizable dashboard with reorderable widgets.
class CustomizableDashboard extends ConsumerStatefulWidget {
  const CustomizableDashboard({super.key});

  @override
  ConsumerState<CustomizableDashboard> createState() => _CustomizableDashboardState();
}

class _CustomizableDashboardState extends ConsumerState<CustomizableDashboard> {
  @override
  Widget build(BuildContext context) {
    final config = ref.watch(dashboardConfigProvider);
    final enabledWidgets = config.enabledWidgets;

    return Column(
      children: [
        // Edit mode header
        if (config.isEditMode) _buildEditModeHeader(context),
        
        // Dashboard content
        if (enabledWidgets.isEmpty)
          _buildEmptyState(context)
        else if (config.isEditMode)
          _buildReorderableList(context, enabledWidgets)
        else
          _buildStaticList(context, enabledWidgets),
      ],
    );
  }

  Widget _buildEditModeHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer,
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(16),
          bottomRight: Radius.circular(16),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.edit_outlined,
            size: 20,
            color: Theme.of(context).colorScheme.onPrimaryContainer,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '编辑模式：长按拖动排序，点击卡片切换显示',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onPrimaryContainer,
                  ),
            ),
          ),
          TextButton.icon(
            onPressed: () => _showAddWidgetSheet(context),
            icon: const Icon(Icons.add, size: 18),
            label: const Text('添加'),
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.onPrimaryContainer,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.dashboard_customize_outlined,
              size: 64,
              color: Theme.of(context).colorScheme.outline,
            ),
            const SizedBox(height: 16),
            Text(
              '仪表盘为空',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Theme.of(context).colorScheme.outline,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              '点击下方按钮添加小组件',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.outline,
                  ),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: () => _showAddWidgetSheet(context),
              icon: const Icon(Icons.add),
              label: const Text('添加小组件'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReorderableList(
    BuildContext context,
    List<DashboardWidgetConfig> widgets,
  ) {
    return ReorderableListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      buildDefaultDragHandles: false,
      itemCount: widgets.length,
      onReorder: (oldIndex, newIndex) {
        ref.read(dashboardConfigProvider.notifier).reorderWidgets(oldIndex, newIndex);
      },
      itemBuilder: (context, index) {
        final widgetConfig = widgets[index];
        final metadata = DashboardWidgetRegistry.getWidget(widgetConfig.id);
        
        if (metadata == null) return const SizedBox.shrink();

        return ReorderableDragStartListener(
          key: ValueKey(widgetConfig.id),
          index: index,
          child: _buildEditableWidgetCard(context, widgetConfig, metadata),
        );
      },
    );
  }

  Widget _buildEditableWidgetCard(
    BuildContext context,
    DashboardWidgetConfig config,
    DashboardWidgetMetadata metadata,
  ) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).colorScheme.outlineVariant,
          width: 1,
        ),
      ),
      child: InkWell(
        onTap: () => _toggleWidget(config.id),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Drag handle
              Icon(
                Icons.drag_handle,
                color: Theme.of(context).colorScheme.outline,
              ),
              const SizedBox(width: 12),
              // Widget icon
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  metadata.icon,
                  color: Theme.of(context).colorScheme.onPrimaryContainer,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              // Widget info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      metadata.title,
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      metadata.description,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                    ),
                  ],
                ),
              ),
              // Visibility toggle
              Icon(
                config.enabled ? Icons.visibility : Icons.visibility_off,
                color: config.enabled
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(context).colorScheme.outline,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStaticList(
    BuildContext context,
    List<DashboardWidgetConfig> widgets,
  ) {
    return Column(
      children: widgets.map((config) {
        return _buildWidget(context, config.id);
      }).toList(),
    );
  }

  Widget _buildWidget(BuildContext context, String widgetId) {
    switch (widgetId) {
      case 'net_worth':
        return _NetWorthWidget();
      case 'quick_stats':
        return _QuickStatsWidget();
      case 'quick_actions':
        return _QuickActionsWidget();
      case 'recent_transactions':
        return _RecentTransactionsWidget();
      case 'budget_progress':
        return _BudgetProgressWidget();
      case 'monthly_trend':
        return _MonthlyTrendWidget();
      case 'category_breakdown':
        return _CategoryBreakdownWidget();
      default:
        return const SizedBox.shrink();
    }
  }

  void _toggleWidget(String widgetId) {
    final config = ref.read(dashboardConfigProvider);
    final isEnabled = config.isWidgetEnabled(widgetId);
    ref.read(dashboardConfigProvider.notifier).setWidgetEnabled(widgetId, !isEnabled);
  }

  void _showAddWidgetSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => _AddWidgetSheet(),
    );
  }
}

/// Bottom sheet for adding widgets.
class _AddWidgetSheet extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final config = ref.watch(dashboardConfigProvider);
    final allWidgets = DashboardWidgetRegistry.availableWidgets;

    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.4,
      maxChildSize: 0.9,
      expand: false,
      builder: (context, scrollController) {
        return Column(
          children: [
            // Handle
            Container(
              margin: const EdgeInsets.only(top: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.outline,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            // Header
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '添加小组件',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('完成'),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            // Widget list
            Expanded(
              child: ListView.builder(
                controller: scrollController,
                padding: const EdgeInsets.all(16),
                itemCount: allWidgets.length,
                itemBuilder: (context, index) {
                  final metadata = allWidgets[index];
                  final isEnabled = config.isWidgetEnabled(metadata.id);
                  
                  return _WidgetListTile(
                    metadata: metadata,
                    isEnabled: isEnabled,
                    onToggle: () {
                      ref.read(dashboardConfigProvider.notifier).setWidgetEnabled(
                            metadata.id,
                            !isEnabled,
                          );
                    },
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}

class _WidgetListTile extends StatelessWidget {
  final DashboardWidgetMetadata metadata;
  final bool isEnabled;
  final VoidCallback onToggle;

  const _WidgetListTile({
    required this.metadata,
    required this.isEnabled,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: isEnabled
                ? Theme.of(context).colorScheme.primaryContainer
                : Theme.of(context).colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            metadata.icon,
            color: isEnabled
                ? Theme.of(context).colorScheme.onPrimaryContainer
                : Theme.of(context).colorScheme.outline,
          ),
        ),
        title: Text(metadata.title),
        subtitle: Text(
          metadata.description,
          style: Theme.of(context).textTheme.bodySmall,
        ),
        trailing: Switch(
          value: isEnabled,
          onChanged: (_) => onToggle(),
        ),
        onTap: onToggle,
      ),
    );
  }
}

// Widget implementations

class _NetWorthWidget extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final netWorthAsync = ref.watch(netWorthProvider);
    final assetTotalAsync = ref.watch(assetTotalProvider);
    final liabilityTotalAsync = ref.watch(liabilityTotalProvider);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '净资产',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
              const SizedBox(height: 8),
              netWorthAsync.when(
                data: (value) => Text(
                  '¥ ${value.toStringAsFixed(2)}',
                  style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                loading: () => Text(
                  '¥ --',
                  style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                error: (_, __) => Text(
                  '¥ 0.00',
                  style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: assetTotalAsync.when(
                      data: (value) => _buildSummaryItem(
                        context,
                        '资产',
                        '¥ ${value.toStringAsFixed(2)}',
                        Icons.trending_up,
                        Colors.green,
                      ),
                      loading: () => _buildSummaryItem(
                        context,
                        '资产',
                        '¥ --',
                        Icons.trending_up,
                        Colors.green,
                      ),
                      error: (_, __) => _buildSummaryItem(
                        context,
                        '资产',
                        '¥ 0.00',
                        Icons.trending_up,
                        Colors.green,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: liabilityTotalAsync.when(
                      data: (value) => _buildSummaryItem(
                        context,
                        '负债',
                        '¥ ${value.toStringAsFixed(2)}',
                        Icons.trending_down,
                        Colors.red,
                      ),
                      loading: () => _buildSummaryItem(
                        context,
                        '负债',
                        '¥ --',
                        Icons.trending_down,
                        Colors.red,
                      ),
                      error: (_, __) => _buildSummaryItem(
                        context,
                        '负债',
                        '¥ 0.00',
                        Icons.trending_down,
                        Colors.red,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryItem(
    BuildContext context,
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
                Text(
                  value,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickStatsWidget extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final quickStatsAsync = ref.watch(quickStatsProvider);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: quickStatsAsync.when(
        data: (stats) => Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: _buildStatItem(context, '今日交易', '${stats.todayCount}笔'),
                ),
                Container(
                  height: 40,
                  width: 1,
                  color: Theme.of(context).colorScheme.outlineVariant,
                ),
                Expanded(
                  child: _buildStatItem(context, '本月收入', '¥${stats.monthIncome.toStringAsFixed(0)}'),
                ),
                Container(
                  height: 40,
                  width: 1,
                  color: Theme.of(context).colorScheme.outlineVariant,
                ),
                Expanded(
                  child: _buildStatItem(context, '本月支出', '¥${stats.monthExpense.toStringAsFixed(0)}'),
                ),
              ],
            ),
          ),
        ),
        loading: () => Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: const Center(child: CircularProgressIndicator()),
            ),
          ),
        ),
        error: (_, __) => const SizedBox.shrink(),
      ),
    );
  }

  Widget _buildStatItem(BuildContext context, String label, String value) {
    return Column(
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
        ),
      ],
    );
  }
}

class _QuickActionsWidget extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '快捷操作',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _buildActionButton(context, '导入账单', Icons.file_upload, () => context.push('/import')),
              const SizedBox(width: 12),
              _buildActionButton(context, '账户管理', Icons.account_balance, () => context.push('/accounts')),
              const SizedBox(width: 12),
              _buildActionButton(context, '预算设置', Icons.savings, () => context.push('/budgets')),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton(
    BuildContext context,
    String label,
    IconData icon,
    VoidCallback onTap,
  ) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: [
              Icon(icon),
              const SizedBox(height: 8),
              Text(
                label,
                style: Theme.of(context).textTheme.bodySmall,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RecentTransactionsWidget extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final transactionsAsync = ref.watch(recentTransactionsProvider);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '最近交易',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              TextButton(
                onPressed: () => context.push('/transactions'),
                child: const Text('查看全部'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          transactionsAsync.when(
            data: (transactions) {
              if (transactions.isEmpty) {
                return Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Center(
                      child: Column(
                        children: [
                          Icon(
                            Icons.receipt_long_outlined,
                            size: 48,
                            color: Theme.of(context).colorScheme.outline,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            '暂无交易记录',
                            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                  color: Theme.of(context).colorScheme.outline,
                                ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '点击下方按钮开始记账',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: Theme.of(context).colorScheme.outline,
                                ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }
              
              return Card(
                child: ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: transactions.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final transaction = transactions[index];
                    return ListTile(
                      title: Text(transaction.description ?? '无描述'),
                      subtitle: Text(
                        DateFormat('yyyy-MM-dd').format(DateTime.fromMillisecondsSinceEpoch(transaction.postDate)),
                      ),
                      trailing: Text(
                        '查看',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                      onTap: () => context.push('/transactions/${transaction.id}'),
                    );
                  },
                ),
              );
            },
            loading: () => Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Center(child: CircularProgressIndicator()),
              ),
            ),
            error: (_, __) => Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Center(child: Text('加载失败')),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BudgetProgressWidget extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '预算进度',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _buildBudgetItem(context, '餐饮', 0.75, Colors.orange),
                  const SizedBox(height: 12),
                  _buildBudgetItem(context, '交通', 0.45, Colors.blue),
                  const SizedBox(height: 12),
                  _buildBudgetItem(context, '购物', 0.90, Colors.purple),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBudgetItem(BuildContext context, String category, double progress, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              category,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            Text(
              '${(progress * 100).toInt()}%',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: progress > 0.8 ? Colors.red : null,
                  ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        LinearProgressIndicator(
          value: progress,
          backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
          valueColor: AlwaysStoppedAnimation<Color>(
            progress > 0.8 ? Colors.red : color,
          ),
        ),
      ],
    );
  }
}

class _MonthlyTrendWidget extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '月度趋势',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: SizedBox(
                height: 150,
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.show_chart,
                        size: 48,
                        color: Theme.of(context).colorScheme.outline,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '图表功能开发中',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Theme.of(context).colorScheme.outline,
                            ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CategoryBreakdownWidget extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '分类统计',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: SizedBox(
                height: 150,
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.pie_chart_outline,
                        size: 48,
                        color: Theme.of(context).colorScheme.outline,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '图表功能开发中',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Theme.of(context).colorScheme.outline,
                            ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
