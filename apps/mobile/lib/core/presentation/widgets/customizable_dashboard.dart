import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:database/database.dart';
import 'package:fl_chart/fl_chart.dart';

import 'dashboard_config_provider.dart';
import 'dashboard_widget_registry.dart';
import 'package:finance_app/features/home/data/home_providers.dart';
import 'package:finance_app/features/budgets/data/budget_provider.dart';
import 'package:finance_app/features/recurring/data/recurring_provider.dart';
import 'package:finance_app/features/quick_entry/presentation/widgets/quick_actions_panel.dart';

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
      case 'upcoming_scheduled':
        return _UpcomingScheduledTransactionsWidget();
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

class _QuickActionsWidget extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Quick actions panel
          const QuickActionsPanel(
            showCategories: false, // Disabled to keep dashboard compact
            showPayees: false,     // Disabled to keep dashboard compact
            showOneTap: true,      // Show one-tap templates
          ),
          
          // Traditional quick action buttons
          const SizedBox(height: 16),
          Text(
            '快捷功能',
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

class _BudgetProgressWidget extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final budgetsAsync = ref.watch(budgetsProvider);
    
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '预算进度',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              TextButton(
                onPressed: () => context.push('/budgets'),
                child: const Text('查看全部'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          budgetsAsync.when(
            data: (budgets) {
              final activeBudgets = budgets.where((b) => b.isActive).take(3).toList();
              
              if (activeBudgets.isEmpty) {
                return Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Center(
                      child: Column(
                        children: [
                          Icon(
                            Icons.savings_outlined,
                            size: 48,
                            color: Theme.of(context).colorScheme.outline,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            '暂无预算设置',
                            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                  color: Theme.of(context).colorScheme.outline,
                                ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '点击上方按钮添加预算',
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
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      for (int i = 0; i < activeBudgets.length; i++) ...[
                        if (i > 0) const SizedBox(height: 12),
                        _BudgetItemWidget(budget: activeBudgets[i]),
                      ],
                    ],
                  ),
                ),
              );
            },
            loading: () => Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: const Center(child: CircularProgressIndicator()),
              ),
            ),
            error: (_, __) => Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Center(
                  child: Text(
                    '加载失败',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).colorScheme.outline,
                        ),
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

class _BudgetItemWidget extends ConsumerWidget {
  final Budget budget;
  
  const _BudgetItemWidget({required this.budget});
  
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final spendingAsync = ref.watch(budgetWithSpendingProvider(budget.id));
    
    return spendingAsync.when(
      data: (data) {
        final progress = data.progress.clamp(0.0, 1.0);
        final isOverBudget = data.progress > 1.0;
        final color = isOverBudget 
            ? Colors.red 
            : data.progress > 0.8 
                ? Colors.orange 
                : Theme.of(context).colorScheme.primary;
        
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    budget.name,
                    style: Theme.of(context).textTheme.bodyMedium,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  isOverBudget 
                      ? '超支 ${(data.progress * 100).toInt()}%'
                      : '${(data.progress * 100).toInt()}%',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: isOverBudget || data.progress > 0.8 ? Colors.red : null,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            LinearProgressIndicator(
              value: progress,
              backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
            const SizedBox(height: 4),
            Text(
              '¥${data.spentAmount.toStringAsFixed(0)} / ¥${(budget.amountNum / budget.amountDenom).toStringAsFixed(0)}',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
          ],
        );
      },
      loading: () => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(budget.name, style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: 4),
          const LinearProgressIndicator(),
        ],
      ),
      error: (_, __) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(budget.name, style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: 4),
          const LinearProgressIndicator(value: 0),
        ],
      ),
    );
  }
}

class _MonthlyTrendWidget extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final trendAsync = ref.watch(monthlySpendingTrendProvider);
    
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
                height: 180,
                child: trendAsync.when(
                  data: (data) => _buildLineChart(context, data),
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (_, __) => Center(
                    child: Text(
                      '加载失败',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Theme.of(context).colorScheme.outline,
                          ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildLineChart(BuildContext context, List<MonthlySpending> data) {
    if (data.isEmpty) {
      return Center(
        child: Text(
          '暂无数据',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.outline,
              ),
        ),
      );
    }
    
    // Find max value for Y axis scaling
    final maxValue = data.fold<double>(0, (max, d) => 
      [d.expense, d.income].reduce((a, b) => a > b ? a : b) > max 
        ? [d.expense, d.income].reduce((a, b) => a > b ? a : b) 
        : max
    );
    
    final yAxisMax = (maxValue * 1.2).ceilToDouble();
    
    return LineChart(
      LineChartData(
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: yAxisMax / 4,
          getDrawingHorizontalLine: (value) => FlLine(
            color: Theme.of(context).colorScheme.outlineVariant.withOpacity(0.3),
            strokeWidth: 1,
          ),
        ),
        titlesData: FlTitlesData(
          show: true,
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 32,
              interval: 1,
              getTitlesWidget: (value, meta) {
                if (value.toInt() >= data.length) return const SizedBox();
                final monthData = data[value.toInt()];
                final monthLabel = monthData.monthLabel.split('-')[1] + '月';
                return Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    monthLabel,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                  ),
                );
              },
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 48,
              interval: yAxisMax / 4,
              getTitlesWidget: (value, meta) {
                if (value == 0) return const SizedBox();
                return Text(
                  '¥${(value / 1000).toStringAsFixed(0)}k',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                );
              },
            ),
          ),
        ),
        borderData: FlBorderData(show: false),
        minX: 0,
        maxX: (data.length - 1).toDouble(),
        minY: 0,
        maxY: yAxisMax,
        lineBarsData: [
          // Expense line (red/orange)
          LineChartBarData(
            spots: data.asMap().entries.map((e) => 
              FlSpot(e.key.toDouble(), e.value.expense)
            ).toList(),
            isCurved: true,
            curveSmoothness: 0.3,
            color: Colors.red.shade400,
            barWidth: 3,
            isStrokeCapRound: true,
            dotData: FlDotData(
              show: true,
              getDotPainter: (spot, percent, barData, index) => 
                FlDotCirclePainter(
                  radius: 4,
                  color: Colors.red.shade400,
                  strokeWidth: 0,
                ),
            ),
            belowBarData: BarAreaData(
              show: true,
              color: Colors.red.shade100,
            ),
          ),
          // Income line (green)
          LineChartBarData(
            spots: data.asMap().entries.map((e) => 
              FlSpot(e.key.toDouble(), e.value.income)
            ).toList(),
            isCurved: true,
            curveSmoothness: 0.3,
            color: Colors.green.shade400,
            barWidth: 3,
            isStrokeCapRound: true,
            dotData: FlDotData(
              show: true,
              getDotPainter: (spot, percent, barData, index) => 
                FlDotCirclePainter(
                  radius: 4,
                  color: Colors.green.shade400,
                  strokeWidth: 0,
                ),
            ),
            belowBarData: BarAreaData(
              show: true,
              color: Colors.green.shade100,
            ),
          ),
        ],
        lineTouchData: LineTouchData(
          enabled: true,
          touchTooltipData: LineTouchTooltipData(
            getTooltipColor: (_) => Theme.of(context).colorScheme.surfaceContainerHigh,
            tooltipPadding: const EdgeInsets.all(8),
            getTooltipItems: (touchedSpots) {
              return touchedSpots.map((spot) {
                final index = spot.x.toInt();
                if (index >= data.length) return null;
                final monthData = data[index];
                final isExpense = spot.barIndex == 0;
                return LineTooltipItem(
                  '${monthData.monthLabel}\n${isExpense ? '支出' : '收入'}: ¥${spot.y.toStringAsFixed(0)}',
                  Theme.of(context).textTheme.bodySmall!,
                );
              }).toList();
            },
          ),
        ),
      ),
    );
  }
}

class _CategoryBreakdownWidget extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final breakdownAsync = ref.watch(categoryBreakdownProvider);
    
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
                height: 220,
                child: breakdownAsync.when(
                  data: (data) => _buildPieChart(context, data),
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (_, __) => Center(
                    child: Text(
                      '加载失败',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Theme.of(context).colorScheme.outline,
                          ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildPieChart(BuildContext context, List<CategorySpending> data) {
    if (data.isEmpty) {
      return Center(
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
              '本月暂无支出',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.outline,
                  ),
            ),
          ],
        ),
      );
    }
    
    final total = data.fold<double>(0, (sum, d) => sum + d.amount);
    
    return Row(
      children: [
        // Pie chart
        Expanded(
          flex: 2,
          child: PieChart(
            PieChartData(
              sectionsSpace: 2,
              centerSpaceRadius: 40,
              sections: data.asMap().entries.map((entry) {
                final index = entry.key;
                final item = entry.value;
                final percentage = total > 0 ? (item.amount / total * 100) : 0;
                
                return PieChartSectionData(
                  value: item.amount,
                  color: item.color,
                  radius: 60,
                  title: percentage > 5 ? '${percentage.toStringAsFixed(0)}%' : '',
                  titleStyle: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ) ?? const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                );
              }).toList(),
              pieTouchData: PieTouchData(
                enabled: true,
                touchCallback: (event, response) {
                  // Touch handling for interactivity
                },
              ),
            ),
          ),
        ),
        // Legend
        Expanded(
          flex: 1,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: data.take(5).map((item) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: item.color,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        item.categoryName,
                        style: Theme.of(context).textTheme.bodySmall,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }
}

/// Widget showing upcoming scheduled transactions for the next 7 days.
class _UpcomingScheduledTransactionsWidget extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final upcomingAsync = ref.watch(upcomingScheduledTransactionsProvider);
    final overdueAsync = ref.watch(overdueTransactionsProvider);
    final generationNotifier = ref.watch(recurringGenerationNotifierProvider);
    
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '计划交易',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              TextButton(
                onPressed: () => context.push('/recurring'),
                child: const Text('管理'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          upcomingAsync.when(
            data: (upcoming) {
              final overdue = overdueAsync.when(
                data: (list) => list,
                loading: () => [],
                error: (_, __) => [],
              );
              
              if (upcoming.isEmpty && overdue.isEmpty) {
                return Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Center(
                      child: Column(
                        children: [
                          Icon(
                            Icons.event_repeat_outlined,
                            size: 48,
                            color: Theme.of(context).colorScheme.outline,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            '暂无计划交易',
                            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                  color: Theme.of(context).colorScheme.outline,
                                ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '点击上方按钮创建周期性交易',
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
                child: Column(
                  children: [
                    // Overdue section (if any)
                    if (overdue.isNotEmpty) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.red.shade50,
                          borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(12),
                            topRight: Radius.circular(12),
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.warning_amber_rounded, color: Colors.red.shade700, size: 20),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                '${overdue.length}笔待处理交易',
                                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                      color: Colors.red.shade700,
                                      fontWeight: FontWeight.w600,
                                    ),
                              ),
                            ),
                            TextButton(
                              onPressed: () async {
                                final ids = await ref.read(recurringGenerationNotifierProvider.notifier).processAll();
                                if (ids.isNotEmpty) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('已生成 ${ids.length} 笔交易')),
                                  );
                                }
                              },
                              style: TextButton.styleFrom(
                                foregroundColor: Colors.red.shade700,
                              ),
                              child: const Text('立即生成'),
                            ),
                          ],
                        ),
                      ),
                      const Divider(height: 1),
                    ],
                    // Upcoming transactions list
                    if (upcoming.isNotEmpty)
                      ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: upcoming.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final recurring = upcoming[index];
                          final nextDate = DateTime.fromMillisecondsSinceEpoch(recurring.nextDate);
                          final daysUntil = _daysUntilNext(nextDate);
                          final amount = recurring.valueNum / recurring.valueDenom.toDouble();
                          
                          return ListTile(
                            leading: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: daysUntil <= 1
                                    ? Colors.orange.shade50
                                    : Theme.of(context).colorScheme.primaryContainer,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(
                                _getFrequencyIcon(recurring.frequency),
                                color: daysUntil <= 1
                                    ? Colors.orange.shade700
                                    : Theme.of(context).colorScheme.onPrimaryContainer,
                                size: 20,
                              ),
                            ),
                            title: Text(
                              recurring.name,
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                            subtitle: Text(
                              _formatNextDate(nextDate, daysUntil),
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: daysUntil <= 1
                                        ? Colors.orange.shade700
                                        : Theme.of(context).colorScheme.onSurfaceVariant,
                                  ),
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  '¥${amount.toStringAsFixed(2)}',
                                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                        fontWeight: FontWeight.w600,
                                      ),
                                ),
                                const SizedBox(width: 8),
                                IconButton(
                                  icon: const Icon(Icons.play_circle_outline, size: 20),
                                  onPressed: () async {
                                    final transactionId = await ref
                                        .read(recurringGenerationNotifierProvider.notifier)
                                        .generateOne(recurring.id);
                                    if (transactionId != null) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(content: Text('已生成交易: $transactionId')),
                                      );
                                    }
                                  },
                                  tooltip: '立即生成',
                                ),
                              ],
                            ),
                            onTap: () => context.push('/recurring/${recurring.id}'),
                          );
                        },
                      )
                    else if (overdue.isEmpty)
                      Padding(
                        padding: const EdgeInsets.all(20),
                        child: Center(
                          child: Text(
                            '未来7天内无计划交易',
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  color: Theme.of(context).colorScheme.outline,
                                ),
                          ),
                        ),
                      ),
                  ],
                ),
              );
            },
            loading: () => Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: const Center(child: CircularProgressIndicator()),
              ),
            ),
            error: (_, __) => Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Center(
                  child: Text(
                    '加载失败',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).colorScheme.outline,
                        ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  int _daysUntilNext(DateTime nextDate) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final next = DateTime(nextDate.year, nextDate.month, nextDate.day);
    return next.difference(today).inDays;
  }
  
  String _formatNextDate(DateTime nextDate, int daysUntil) {
    if (daysUntil < 0) {
      return '已过期 ${daysUntil.abs()} 天';
    } else if (daysUntil == 0) {
      return '今天';
    } else if (daysUntil == 1) {
      return '明天';
    } else if (daysUntil <= 7) {
      final weekdays = ['周一', '周二', '周三', '周四', '周五', '周六', '周日'];
      return '${weekdays[nextDate.weekday - 1]} (${DateFormat('MM/dd').format(nextDate)})';
    } else {
      return DateFormat('yyyy-MM-dd').format(nextDate);
    }
  }
  
  IconData _getFrequencyIcon(String frequency) {
    switch (frequency) {
      case 'daily':
        return Icons.today;
      case 'weekly':
        return Icons.calendar_view_week;
      case 'monthly':
        return Icons.calendar_month;
      case 'yearly':
        return Icons.event;
      default:
        return Icons.repeat;
    }
  }
}

class _UpcomingTransactionTile extends ConsumerWidget {
  final RecurringTransaction transaction;
  
  const _UpcomingTransactionTile({required this.transaction});
  
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final amount = transaction.valueNum.toDouble() / transaction.valueDenom.toDouble();
    final dueDate = DateTime.fromMillisecondsSinceEpoch(transaction.nextDate);
    final daysUntil = dueDate.difference(DateTime.now()).inDays;
    
    String dueText;
    Color dueColor;
    
    if (daysUntil < 0) {
      dueText = '已逾期 ${-daysUntil} 天';
      dueColor = Colors.red;
    } else if (daysUntil == 0) {
      dueText = '今天';
      dueColor = Colors.orange;
    } else if (daysUntil == 1) {
      dueText = '明天';
      dueColor = Theme.of(context).colorScheme.primary;
    } else {
      dueText = '$daysUntil 天后';
      dueColor = Theme.of(context).colorScheme.onSurfaceVariant;
    }
    
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: amount >= 0 
              ? Colors.green.withOpacity(0.1)
              : Colors.red.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(
          amount >= 0 ? Icons.arrow_upward : Icons.arrow_downward,
          color: amount >= 0 ? Colors.green : Colors.red,
          size: 20,
        ),
      ),
      title: Text(
        transaction.name,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w500,
            ),
      ),
      subtitle: Text(
        DateFormat('MM-dd').format(dueDate),
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: dueColor,
            ),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '¥${amount.abs().toStringAsFixed(2)}',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: amount >= 0 ? Colors.green : Colors.red,
                    ),
              ),
              Text(
                dueText,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: dueColor,
                    ),
              ),
            ],
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: Icon(
              Icons.play_circle_outline,
              color: Theme.of(context).colorScheme.primary,
            ),
            tooltip: '立即生成',
            onPressed: () => _generateNow(context, ref),
          ),
        ],
      ),
    );
  }
  
  Future<void> _generateNow(BuildContext context, WidgetRef ref) async {
    final notifier = ref.read(recurringNotifierProvider.notifier);
    
    try {
      await notifier.generateNow(transaction.id);
      
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('已生成交易: ${transaction.name}'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('生成失败: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
