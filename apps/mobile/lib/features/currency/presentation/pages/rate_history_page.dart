import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';

import 'package:database/database.dart';
import 'package:finance_app/features/currency/data/currency_provider.dart';

/// 汇率历史页面 - 显示汇率变化趋势和历史记录
class RateHistoryPage extends ConsumerStatefulWidget {
  final String fromCurrency;
  final String toCurrency;

  const RateHistoryPage({
    super.key,
    required this.fromCurrency,
    required this.toCurrency,
  });

  @override
  ConsumerState<RateHistoryPage> createState() => _RateHistoryPageState();
}

class _RateHistoryPageState extends ConsumerState<RateHistoryPage> {
  String _selectedPeriod = '30d';
  final List<String> _periodOptions = ['7d', '30d', '90d', 'all'];

  @override
  Widget build(BuildContext context) {
    final params = (from: widget.fromCurrency, to: widget.toCurrency);
    final historyAsync = ref.watch(rateHistoryProvider(params));
    final statsAsync = ref.watch(rateHistoryStatsProvider(params));

    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.fromCurrency} → ${widget.toCurrency} 汇率历史'),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.calendar_today),
            initialValue: _selectedPeriod,
            onSelected: (value) {
              setState(() {
                _selectedPeriod = value;
              });
            },
            itemBuilder: (context) => [
              const PopupMenuItem(value: '7d', child: Text('最近7天')),
              const PopupMenuItem(value: '30d', child: Text('最近30天')),
              const PopupMenuItem(value: '90d', child: Text('最近90天')),
              const PopupMenuItem(value: 'all', child: Text('全部')),
            ],
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 统计卡片
            statsAsync.when(
              data: (stats) => _buildStatsCard(context, stats),
              loading: () => const Card(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Center(child: CircularProgressIndicator()),
                ),
              ),
              error: (e, _) => Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text('加载统计数据失败: $e'),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // 趋势图表
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '汇率趋势',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      height: 200,
                      child: historyAsync.when(
                        data: (rates) => _buildChart(rates),
                        loading: () => const Center(child: CircularProgressIndicator()),
                        error: (e, _) => Center(child: Text('加载图表失败: $e')),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // 历史记录列表
            Text(
              '历史记录',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            historyAsync.when(
              data: (rates) => _buildHistoryList(context, rates),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('加载历史记录失败: $e')),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsCard(BuildContext context, RateHistoryStats stats) {
    if (stats.count == 0) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Text('暂无历史数据'),
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '当前汇率',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                Text(
                  '数据点: ${stats.count}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              stats.latest.toStringAsFixed(4),
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    color: Theme.of(context).colorScheme.primary,
                  ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildStatItem(
                    context,
                    '变化',
                    '${stats.changePercent >= 0 ? '+' : ''}${stats.changePercent.toStringAsFixed(2)}%',
                    stats.changePercent >= 0 ? Colors.green : Colors.red,
                  ),
                ),
                Expanded(
                  child: _buildStatItem(
                    context,
                    '最高',
                    stats.max.toStringAsFixed(4),
                    null,
                  ),
                ),
                Expanded(
                  child: _buildStatItem(
                    context,
                    '最低',
                    stats.min.toStringAsFixed(4),
                    null,
                  ),
                ),
                Expanded(
                  child: _buildStatItem(
                    context,
                    '平均',
                    stats.average.toStringAsFixed(4),
                    null,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '数据范围: ${DateFormat('yyyy-MM-dd').format(stats.oldestDate)} 至 ${DateFormat('yyyy-MM-dd').format(stats.latestDate)}',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.grey,
                  ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(
    BuildContext context,
    String label,
    String value,
    Color? color,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall,
        ),
        Text(
          value,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: color,
                fontWeight: FontWeight.bold,
              ),
        ),
      ],
    );
  }

  Widget _buildChart(List<ExchangeRate> rates) {
    if (rates.isEmpty) {
      return const Center(child: Text('暂无数据'));
    }

    // Sort by date ascending for chart
    final sortedRates = List<ExchangeRate>.from(rates)
      ..sort((a, b) => a.date.compareTo(b.date));

    // Filter by selected period
    final now = DateTime.now();
    final filteredRates = sortedRates.where((rate) {
      final rateDate = DateTime.fromMillisecondsSinceEpoch(rate.date);
      switch (_selectedPeriod) {
        case '7d':
          return rateDate.isAfter(now.subtract(const Duration(days: 7)));
        case '30d':
          return rateDate.isAfter(now.subtract(const Duration(days: 30)));
        case '90d':
          return rateDate.isAfter(now.subtract(const Duration(days: 90)));
        default:
          return true;
      }
    }).toList();

    if (filteredRates.isEmpty) {
      return const Center(child: Text('所选时间段无数据'));
    }

    final spots = <FlSpot>[];
    for (int i = 0; i < filteredRates.length; i++) {
      spots.add(FlSpot(i.toDouble(), filteredRates[i].rate));
    }

    final minRate = filteredRates.map((r) => r.rate).reduce((a, b) => a < b ? a : b);
    final maxRate = filteredRates.map((r) => r.rate).reduce((a, b) => a > b ? a : b);
    final padding = (maxRate - minRate) * 0.1;

    return LineChart(
      LineChartData(
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: (maxRate - minRate) / 4,
        ),
        titlesData: FlTitlesData(
          show: true,
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 30,
              getTitlesWidget: (value, meta) {
                if (value.toInt() >= filteredRates.length) {
                  return const Text('');
                }
                final date = DateTime.fromMillisecondsSinceEpoch(
                  filteredRates[value.toInt()].date,
                );
                return Padding(
                  padding: const EdgeInsets.only(top: 8),
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
              reservedSize: 50,
              getTitlesWidget: (value, meta) {
                return Text(
                  value.toStringAsFixed(2),
                  style: const TextStyle(fontSize: 10),
                );
              },
            ),
          ),
        ),
        borderData: FlBorderData(show: false),
        minX: 0,
        maxX: (filteredRates.length - 1).toDouble(),
        minY: minRate - padding,
        maxY: maxRate + padding,
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            color: Theme.of(context).colorScheme.primary,
            barWidth: 2,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(
              show: true,
              color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
            ),
          ),
        ],
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            getTooltipItems: (touchedSpots) {
              return touchedSpots.map((spot) {
                final index = spot.x.toInt();
                if (index >= filteredRates.length) return null;
                final rate = filteredRates[index];
                final date = DateTime.fromMillisecondsSinceEpoch(rate.date);
                return LineTooltipItem(
                  '${DateFormat('yyyy-MM-dd').format(date)}\n汇率: ${rate.rate.toStringAsFixed(4)}',
                  const TextStyle(color: Colors.white),
                );
              }).toList();
            },
          ),
        ),
      ),
    );
  }

  Widget _buildHistoryList(BuildContext context, List<ExchangeRate> rates) {
    if (rates.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Text('暂无历史记录'),
        ),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: rates.length,
      itemBuilder: (context, index) {
        final rate = rates[index];
        final date = DateTime.fromMillisecondsSinceEpoch(rate.date);
        final prevRate = index < rates.length - 1 ? rates[index + 1] : null;
        final change = prevRate != null
            ? ((rate.rate - prevRate.rate) / prevRate.rate) * 100
            : null;

        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: _getSourceColor(rate.source),
              child: Text(
                _getSourceIcon(rate.source),
                style: const TextStyle(fontSize: 12),
              ),
            ),
            title: Text(
              rate.rate.toStringAsFixed(4),
              style: Theme.of(context).textTheme.titleMedium,
            ),
            subtitle: Text(
              '${DateFormat('yyyy-MM-dd HH:mm').format(date)} • ${_getSourceLabel(rate.source)}',
            ),
            trailing: change != null
                ? Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: change >= 0 ? Colors.green.withOpacity(0.1) : Colors.red.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      '${change >= 0 ? '+' : ''}${change.toStringAsFixed(2)}%',
                      style: TextStyle(
                        color: change >= 0 ? Colors.green : Colors.red,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  )
                : null,
          ),
        );
      },
    );
  }

  Color _getSourceColor(String source) {
    switch (source) {
      case 'manual':
        return Colors.orange;
      case 'open.er-api':
        return Colors.blue;
      case 'exchangerate-api':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  String _getSourceIcon(String source) {
    switch (source) {
      case 'manual':
        return '手';
      case 'open.er-api':
        return 'API';
      case 'exchangerate-api':
        return 'API';
      default:
        return '?';
    }
  }

  String _getSourceLabel(String source) {
    switch (source) {
      case 'manual':
        return '手动输入';
      case 'open.er-api':
        return 'Open ER API';
      case 'exchangerate-api':
        return 'ExchangeRate API';
      default:
        return source;
    }
  }
}
