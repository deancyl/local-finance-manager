import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:database/database.dart';

import 'package:finance_app/features/home/data/home_providers.dart';

class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final netWorthAsync = ref.watch(netWorthProvider);
    final assetTotalAsync = ref.watch(assetTotalProvider);
    final liabilityTotalAsync = ref.watch(liabilityTotalProvider);
    final recentTransactionsAsync = ref.watch(recentTransactionsProvider);
    final quickStatsAsync = ref.watch(quickStatsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('本地金融管家'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => context.push('/settings'),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildNetWorthCard(context, netWorthAsync, assetTotalAsync, liabilityTotalAsync),
            const SizedBox(height: 16),
            _buildQuickStats(context, quickStatsAsync),
            const SizedBox(height: 24),
            _buildQuickActions(context),
            const SizedBox(height: 24),
            _buildRecentTransactions(context, recentTransactionsAsync),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/transactions/add'),
        icon: const Icon(Icons.add),
        label: const Text('记一笔'),
      ),
    );
  }

  Widget _buildNetWorthCard(
    BuildContext context,
    AsyncValue<double> netWorthAsync,
    AsyncValue<double> assetTotalAsync,
    AsyncValue<double> liabilityTotalAsync,
  ) {
    return Card(
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
    );
  }

  Widget _buildQuickStats(BuildContext context, AsyncValue<QuickStats> quickStatsAsync) {
    return quickStatsAsync.when(
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
      loading: () => Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Center(child: CircularProgressIndicator()),
        ),
      ),
      error: (_, __) => const SizedBox.shrink(),
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
          Column(
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
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActions(BuildContext context) {
    return Column(
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

  Widget _buildRecentTransactions(BuildContext context, AsyncValue<List<Transaction>> transactionsAsync) {
    return Column(
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
    );
  }
}