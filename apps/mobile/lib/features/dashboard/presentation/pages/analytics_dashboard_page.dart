import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';

import '../../../analytics/data/analytics_provider.dart';
import '../../../net_worth/data/net_worth_provider.dart';
import '../../../dashboard/data/dashboard_provider.dart';

class AnalyticsDashboardPage extends ConsumerStatefulWidget {
  const AnalyticsDashboardPage({super.key});

  @override
  ConsumerState<AnalyticsDashboardPage> createState() => _AnalyticsDashboardPageState();
}

class _AnalyticsDashboardPageState extends ConsumerState<AnalyticsDashboardPage> {
  final _refreshKey = GlobalKey<RefreshIndicatorState>();
  final _currencyFormat = NumberFormat.currency(symbol: '¥', decimalDigits: 2);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('数据分析'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => _refreshKey.currentState?.show(),
          ),
        ],
      ),
      body: RefreshIndicator(
        key: _refreshKey,
        onRefresh: _refreshData,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildKeyMetricsSection(),
              const SizedBox(height: 24),
              _buildSpendingByCategorySection(),
              const SizedBox(height: 24),
              _buildIncomeSourcesSection(),
              const SizedBox(height: 24),
              _buildPeriodComparisonSection(),
              const SizedBox(height: 24),
              _buildGoalProgressSection(),
              const SizedBox(height: 24),
              _buildAnomalyDetectionSection(),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _refreshData() async {
    ref.invalidate(dashboardSummaryProvider);
    ref.invalidate(currentNetWorthProvider);
    ref.invalidate(monthlySavingsRateProvider);
    ref.invalidate(expenseRatioProvider);
    ref.invalidate(monthComparisonProvider);
    ref.invalidate(yearComparisonProvider);
    ref.invalidate(spendingAnomaliesProvider);
    ref.invalidate(incomeSourcesProvider);
    ref.invalidate(spendingTrendsProvider);
  }

  Widget _buildKeyMetricsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '关键指标',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildMetricCard(
                title: '净资产',
                provider: currentNetWorthProvider,
                valueBuilder: (snapshot) => _currencyFormat.format(snapshot.netWorth),
                subtitleBuilder: (snapshot) => '资产 ${_currencyFormat.format(snapshot.assets)}',
                icon: Icons.account_balance_wallet,
                color: Colors.blue,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildMetricCard(
                title: '月储蓄率',
                provider: monthlySavingsRateProvider,
                valueBuilder: (rate) => '${rate.savingsRate.toStringAsFixed(1)}%',
                subtitleBuilder: (rate) => '储蓄 ${_currencyFormat.format(rate.savings)}',
                icon: Icons.savings,
                color: Colors.green,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildMetricCard(
                title: '本月收入',
                provider: monthlySavingsRateProvider,
                valueBuilder: (rate) => _currencyFormat.format(rate.income),
                subtitleBuilder: (rate) => '${rate.expense > 0 ? '支出 ${_currencyFormat.format(rate.expense)}' : ''}',
                icon: Icons.trending_up,
                color: Colors.orange,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildMetricCard(
                title: '本月支出',
                provider: monthlySavingsRateProvider,
                valueBuilder: (rate) => _currencyFormat.format(rate.expense),
                subtitleBuilder: (rate) => '收入 ${_currencyFormat.format(rate.income)}',
                icon: Icons.trending_down,
                color: Colors.red,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildMetricCard<T>({
    required String title,
    required FutureProvider<T> provider,
    required String Function(T) valueBuilder,
    required String Function(T) subtitleBuilder,
    required IconData icon,
    required Color color,
  }) {
    final asyncValue = ref.watch(provider);

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: asyncValue.when(
          data: (data) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icon, color: color, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      title,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            color: Colors.grey[700],
                          ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                valueBuilder(data),
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitleBuilder(data),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.grey[600],
                    ),
              ),
            ],
          ),
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => Center(
            child: Text('错误: $error', style: const TextStyle(color: Colors.red)),
          ),
        ),
      ),
    );
  }

  Widget _buildSpendingByCategorySection() {
    final asyncExpenseRatio = ref.watch(expenseRatioProvider);

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '支出分布',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 16),
            asyncExpenseRatio.when(
              data: (ratios) {
                if (ratios.isEmpty) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(32),
                      child: Text('暂无数据'),
                    ),
                  );
                }

                return Column(
                  children: [
                    SizedBox(
                      height: 200,
                      child: PieChart(
                        PieChartData(
                          sectionsSpace: 2,
                          centerSpaceRadius: 40,
                          sections: ratios.map((ratio) {
                            return PieChartSectionData(
                              color: ratio.color,
                              value: ratio.amount,
                              title: '${ratio.percentage.toStringAsFixed(1)}%',
                              radius: 60,
                              titleStyle: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    ...ratios.take(5).map((ratio) {
                      return ListTile(
                        leading: Container(
                          width: 16,
                          height: 16,
                          decoration: BoxDecoration(
                            color: ratio.color,
                            shape: BoxShape.circle,
                          ),
                        ),
                        title: Text(ratio.categoryName),
                        trailing: Text(
                          _currencyFormat.format(ratio.amount),
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      );
                    }),
                  ],
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => Text('错误: $error'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIncomeSourcesSection() {
    final asyncIncomeSources = ref.watch(incomeSourcesProvider);

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '收入来源',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 16),
            asyncIncomeSources.when(
              data: (sources) {
                if (sources.isEmpty) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(32),
                      child: Text('本月暂无收入'),
                    ),
                  );
                }

                return Column(
                  children: sources.map((source) {
                    return Card(
                      child: ListTile(
                        leading: CircleAvatar(
                          child: Text(source.source[0]),
                        ),
                        title: Text(source.source),
                        subtitle: Text('共 ${source.transactionCount} 笔'),
                        trailing: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              _currencyFormat.format(source.amount),
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            Text(
                              '${source.percentage.toStringAsFixed(1)}%',
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => Text('错误: $error'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPeriodComparisonSection() {
    final asyncMonthComparison = ref.watch(monthComparisonProvider);
    final asyncYearComparison = ref.watch(yearComparisonProvider);

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '期间对比',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildComparisonCard(asyncMonthComparison),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildComparisonCard(asyncYearComparison),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildComparisonCard(AsyncValue<PeriodComparison> asyncComparison) {
    return asyncComparison.when(
      data: (comparison) {
        final isIncrease = comparison.change > 0;
        final changeColor = isIncrease ? Colors.red : Colors.green;
        final changeIcon = isIncrease ? Icons.arrow_upward : Icons.arrow_downward;

        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.grey[100],
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                comparison.periodLabel,
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(changeIcon, color: changeColor, size: 16),
                  const SizedBox(width: 4),
                  Text(
                    '${isIncrease ? '+' : ''}${comparison.changePercent.toStringAsFixed(1)}%',
                    style: TextStyle(
                      color: changeColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                _currencyFormat.format(comparison.currentAmount),
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '上期: ${_currencyFormat.format(comparison.previousAmount)}',
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 12,
                ),
              ),
            ],
          ),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Text('错误: $error'),
    );
  }

  Widget _buildGoalProgressSection() {
    final asyncGoalProgress = ref.watch(goalProgressProvider);

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '目标进度',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                TextButton.icon(
                  onPressed: () {
                    // Navigate to goals page
                  },
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('设置目标'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            asyncGoalProgress.when(
              data: (goals) {
                if (goals.isEmpty) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(32),
                      child: Text('尚未设置财务目标'),
                    ),
                  );
                }

                return Column(
                  children: goals.map((goal) {
                    final progressColor = goal.isOnTrack ? Colors.green : Colors.orange;

                    return Card(
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text(
                                    goal.goalName,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: progressColor.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    goal.isOnTrack ? '进度正常' : '需加速',
                                    style: TextStyle(
                                      color: progressColor,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            LinearProgressIndicator(
                              value: goal.progress / 100,
                              backgroundColor: Colors.grey[300],
                              valueColor: AlwaysStoppedAnimation<Color>(progressColor),
                              minHeight: 8,
                            ),
                            const SizedBox(height: 8),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  '${_currencyFormat.format(goal.currentAmount)} / ${_currencyFormat.format(goal.targetAmount)}',
                                  style: TextStyle(
                                    color: Colors.grey[700],
                                    fontSize: 12,
                                  ),
                                ),
                                Text(
                                  '${goal.progress.toStringAsFixed(1)}%',
                                  style: TextStyle(
                                    color: progressColor,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => Text('错误: $error'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAnomalyDetectionSection() {
    final asyncAnomalies = ref.watch(spendingAnomaliesProvider);

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.warning_amber, color: Colors.orange[700], size: 24),
                const SizedBox(width: 8),
                Text(
                  '异常检测',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            asyncAnomalies.when(
              data: (anomalies) {
                if (anomalies.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        children: [
                          Icon(
                            Icons.check_circle_outline,
                            size: 48,
                            color: Colors.green[400],
                          ),
                          const SizedBox(height: 12),
                          const Text('暂未发现异常支出'),
                        ],
                      ),
                    ),
                  );
                }

                return Column(
                  children: anomalies.take(3).map((anomaly) {
                    return Card(
                      color: Colors.orange[50],
                      child: ListTile(
                        leading: Icon(
                          Icons.error_outline,
                          color: Colors.orange[700],
                        ),
                        title: Text(anomaly.category),
                        subtitle: Text(anomaly.description),
                        trailing: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              _currencyFormat.format(anomaly.actualAmount),
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.red,
                              ),
                            ),
                            Text(
                              '预期: ${_currencyFormat.format(anomaly.expectedAmount)}',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => Text('错误: $error'),
            ),
          ],
        ),
      ),
    );
  }
}
