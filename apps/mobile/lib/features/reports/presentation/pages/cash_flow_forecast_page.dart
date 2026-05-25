import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:go_router/go_router.dart';

import '../../data/cash_flow_forecast_provider.dart';
import '../../../recurring/data/recurring_provider.dart';

/// Cash flow forecast page showing projected balance over time.
///
/// Features:
/// - Visual timeline of projected balance
/// - Recurring transaction integration
/// - Confidence intervals
/// - Alert thresholds
/// - Daily/weekly/monthly granularity options
class CashFlowForecastPage extends ConsumerStatefulWidget {
  const CashFlowForecastPage({super.key});

  @override
  ConsumerState<CashFlowForecastPage> createState() => _CashFlowForecastPageState();
}

class _CashFlowForecastPageState extends ConsumerState<CashFlowForecastPage> {
  int _monthsAhead = 3;
  ForecastGranularity _granularity = ForecastGranularity.weekly;
  double _alertThreshold = 0;
  bool _alertEnabled = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final forecastAsync = ref.watch(cashFlowForecastProvider);
    final params = ref.watch(forecastParamsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('现金流预测'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => _showSettingsSheet(context),
            tooltip: '设置',
          ),
        ],
      ),
      body: Column(
        children: [
          // Controls
          _buildControls(context),
          
          // Content
          Expanded(
            child: forecastAsync.when(
              data: (forecast) {
                if (forecast == null || forecast.points.isEmpty) {
                  return _buildEmptyState(context);
                }
                return _buildContent(context, forecast);
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, stack) => _buildErrorState(context, error),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildControls(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        border: Border(
          bottom: BorderSide(
            color: theme.colorScheme.outlineVariant,
            width: 1,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Time range selector
          Row(
            children: [
              Icon(
                Icons.calendar_today,
                size: 20,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Text(
                '预测范围',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _buildGranularityChip('日', ForecastGranularity.daily),
              const SizedBox(width: 8),
              _buildGranularityChip('周', ForecastGranularity.weekly),
              const SizedBox(width: 8),
              _buildGranularityChip('月', ForecastGranularity.monthly),
              const Spacer(),
              _buildMonthsSelector(),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildGranularityChip(String label, ForecastGranularity granularity) {
    final theme = Theme.of(context);
    final isSelected = _granularity == granularity;

    return InkWell(
      onTap: () {
        setState(() => _granularity = granularity);
        _updateParams();
      },
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? theme.colorScheme.primaryContainer
              : theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? theme.colorScheme.primary
                : theme.colorScheme.outline,
          ),
        ),
        child: Text(
          label,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: isSelected
                ? theme.colorScheme.onPrimaryContainer
                : theme.colorScheme.onSurface,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  Widget _buildMonthsSelector() {
    final theme = Theme.of(context);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          icon: const Icon(Icons.remove),
          onPressed: _monthsAhead > 1
              ? () {
                  setState(() => _monthsAhead--);
                  _updateParams();
                }
              : null,
          iconSize: 20,
          visualDensity: VisualDensity.compact,
        ),
        Text(
          '$_monthsAhead 个月',
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        IconButton(
          icon: const Icon(Icons.add),
          onPressed: _monthsAhead < 12
              ? () {
                  setState(() => _monthsAhead++);
                  _updateParams();
                }
              : null,
          iconSize: 20,
          visualDensity: VisualDensity.compact,
        ),
      ],
    );
  }

  Widget _buildContent(BuildContext context, CashFlowForecast forecast) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Summary cards
          _buildSummaryCards(context, forecast),
          
          const SizedBox(height: 24),
          
          // Chart
          _buildChartSection(context, forecast),
          
          const SizedBox(height: 24),
          
          // Alerts
          if (forecast.alerts.isNotEmpty) ...[
            _buildAlertsSection(context, forecast),
            const SizedBox(height: 24),
          ],
          
          // Upcoming transactions
          _buildUpcomingTransactionsSection(context, forecast),
        ],
      ),
    );
  }

  Widget _buildSummaryCards(BuildContext context, CashFlowForecast forecast) {
    final theme = Theme.of(context);
    final currencyFormat = NumberFormat.currency(symbol: '¥', decimalDigits: 2);

    return Row(
      children: [
        Expanded(
          child: _buildSummaryCard(
            context,
            title: '当前余额',
            value: currencyFormat.format(forecast.startingBalance),
            icon: Icons.account_balance_wallet,
            color: theme.colorScheme.primary,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildSummaryCard(
            context,
            title: '预计余额',
            value: currencyFormat.format(forecast.endingBalance),
            icon: Icons.trending_up,
            color: forecast.endingBalance >= forecast.startingBalance
                ? Colors.green
                : Colors.red,
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryCard(
    BuildContext context, {
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 20, color: color),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChartSection(BuildContext context, CashFlowForecast forecast) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '余额趋势',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            Row(
              children: [
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 4),
                const Text('预测', style: TextStyle(fontSize: 12)),
                const SizedBox(width: 12),
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 4),
                const Text('置信区间', style: TextStyle(fontSize: 12)),
              ],
            ),
          ],
        ),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: SizedBox(
              height: 300,
              child: _buildChart(forecast),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildChart(CashFlowForecast forecast) {
    if (forecast.points.isEmpty) {
      return const Center(child: Text('暂无数据'));
    }

    final spots = forecast.points.asMap().entries.map((entry) {
      return FlSpot(entry.key.toDouble(), entry.value.projectedBalance);
    }).toList();

    final lowerSpots = forecast.points.asMap().entries.map((entry) {
      return FlSpot(entry.key.toDouble(), entry.value.confidenceLower);
    }).toList();

    final upperSpots = forecast.points.asMap().entries.map((entry) {
      return FlSpot(entry.key.toDouble(), entry.value.confidenceUpper);
    }).toList();

    final minY = forecast.points.map((p) => p.confidenceLower).reduce((a, b) => a < b ? a : b);
    final maxY = forecast.points.map((p) => p.confidenceUpper).reduce((a, b) => a > b ? a : b);

    return LineChart(
      LineChartData(
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: (maxY - minY) / 5,
          getDrawingHorizontalLine: (value) => FlLine(
            color: Theme.of(context).colorScheme.outline.withOpacity(0.2),
            strokeWidth: 1,
          ),
        ),
        titlesData: FlTitlesData(
          show: true,
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 30,
              getTitlesWidget: (value, meta) {
                final index = value.toInt();
                if (index < 0 || index >= forecast.points.length) {
                  return const SizedBox.shrink();
                }
                final date = forecast.points[index].date;
                return SideTitleWidget(
                  axisSide: meta.axisSide,
                  child: Text(
                    DateFormat('MM/dd').format(date),
                    style: const TextStyle(fontSize: 10),
                  ),
                );
              },
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 60,
              getTitlesWidget: (value, meta) {
                return SideTitleWidget(
                  axisSide: meta.axisSide,
                  child: Text(
                    _formatCompactCurrency(value),
                    style: const TextStyle(fontSize: 10),
                  ),
                );
              },
            ),
          ),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        borderData: FlBorderData(show: false),
        minX: 0,
        maxX: (forecast.points.length - 1).toDouble(),
        minY: minY,
        maxY: maxY,
        lineBarsData: [
          // Confidence interval (upper)
          LineChartBarData(
            spots: upperSpots,
            isCurved: true,
            color: Theme.of(context).colorScheme.primary.withOpacity(0.2),
            barWidth: 0,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(
              show: true,
              color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
            ),
          ),
          // Main forecast line
          LineChartBarData(
            spots: spots,
            isCurved: true,
            color: Theme.of(context).colorScheme.primary,
            barWidth: 3,
            dotData: FlDotData(
              show: forecast.points.length < 20,
              getDotPainter: (spot, percent, barData, index) {
                return FlDotCirclePainter(
                  radius: 4,
                  color: Theme.of(context).colorScheme.primary,
                  strokeWidth: 2,
                  strokeColor: Theme.of(context).colorScheme.surface,
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAlertsSection(BuildContext context, CashFlowForecast forecast) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.warning_amber,
              color: theme.colorScheme.error,
              size: 20,
            ),
            const SizedBox(width: 8),
            Text(
              '余额预警',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.error,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Card(
          color: theme.colorScheme.errorContainer,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: forecast.alerts.take(5).map((alert) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      Icon(
                        Icons.event,
                        size: 16,
                        color: theme.colorScheme.onErrorContainer,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        DateFormat('MM/dd').format(alert.date),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onErrorContainer,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          '余额: ¥${alert.balance.toStringAsFixed(2)}',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onErrorContainer,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildUpcomingTransactionsSection(BuildContext context, CashFlowForecast forecast) {
    final theme = Theme.of(context);
    final currencyFormat = NumberFormat.currency(symbol: '¥', decimalDigits: 2);

    // Collect all transactions from all forecast points
    final allTransactions = forecast.points
        .expand((p) => p.transactions)
        .where((t) => t.isRecurring)
        .toList();
    
    // Remove duplicates and sort by date
    final seen = <String>{};
    final uniqueTransactions = allTransactions.where((t) {
      final key = '${t.recurringId}_${DateFormat('yyyy-MM-dd').format(t.date)}';
      if (seen.contains(key)) return false;
      seen.add(key);
      return true;
    }).toList()
      ..sort((a, b) => a.date.compareTo(b.date));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '预计收支',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            TextButton.icon(
              onPressed: () => context.push('/recurring'),
              icon: const Icon(Icons.replay, size: 18),
              label: const Text('管理周期交易'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (uniqueTransactions.isEmpty)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      '暂无周期交易记录，添加周期交易可提高预测准确性',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          )
        else
          Card(
            child: ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: uniqueTransactions.length > 10 ? 10 : uniqueTransactions.length,
              separatorBuilder: (context, index) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final t = uniqueTransactions[index];
                return ListTile(
                  leading: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: t.isIncome
                          ? Colors.green.withOpacity(0.1)
                          : Colors.red.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      t.isIncome ? Icons.arrow_upward : Icons.arrow_downward,
                      color: t.isIncome ? Colors.green : Colors.red,
                      size: 20,
                    ),
                  ),
                  title: Text(t.name),
                  subtitle: Text(DateFormat('yyyy-MM-dd').format(t.date)),
                  trailing: Text(
                    currencyFormat.format(t.amount),
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: t.isIncome ? Colors.green : Colors.red,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                );
              },
            ),
          ),
      ],
    );
  }

  void _showSettingsSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '预测设置',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 24),
                
                // Alert threshold
                SwitchListTile(
                  title: const Text('余额预警'),
                  subtitle: const Text('当余额低于阈值时发出警告'),
                  value: _alertEnabled,
                  onChanged: (value) {
                    setState(() => _alertEnabled = value);
                  },
                ),
                
                if (_alertEnabled) ...[
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      const Text('预警阈值: '),
                      Expanded(
                        child: TextField(
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: const InputDecoration(
                            prefixText: '¥ ',
                            hintText: '0.00',
                          ),
                          controller: TextEditingController(
                            text: _alertThreshold.toStringAsFixed(2),
                          ),
                          onSubmitted: (value) {
                            final parsed = double.tryParse(value);
                            if (parsed != null) {
                              setState(() => _alertThreshold = parsed);
                              _updateParams();
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                ],
                
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    _updateParams();
                  },
                  child: const Text('应用'),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _updateParams() {
    ref.read(forecastParamsProvider.notifier).state = ForecastParams(
      monthsAhead: _monthsAhead,
      granularity: _granularity,
      alertThreshold: _alertEnabled
          ? AlertThreshold(amount: _alertThreshold, isEnabled: true)
          : null,
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.trending_up_outlined,
              size: 64,
              color: theme.colorScheme.outline,
            ),
            const SizedBox(height: 16),
            Text(
              '暂无预测数据',
              style: theme.textTheme.titleMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '请先添加账户和交易记录',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.outline,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState(BuildContext context, Object error) {
    final theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: theme.colorScheme.error,
            ),
            const SizedBox(height: 16),
            Text(
              '加载失败',
              style: theme.textTheme.titleMedium?.copyWith(
                color: theme.colorScheme.error,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              error.toString(),
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  String _formatCompactCurrency(double value) {
    if (value.abs() >= 10000) {
      return '¥${(value / 10000).toStringAsFixed(1)}万';
    } else if (value.abs() >= 1000) {
      return '¥${(value / 1000).toStringAsFixed(1)}k';
    } else {
      return '¥${value.toStringAsFixed(0)}';
    }
  }
}
