import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:finance_app/features/reports/data/chart_providers.dart';

/// Monthly trend bar chart showing income and expense for last 6 months.
class MonthlyTrendChart extends StatelessWidget {
  final List<MonthlyData> data;
  
  const MonthlyTrendChart({
    super.key,
    required this.data,
  });
  
  @override
  Widget build(BuildContext context) {
    if (data.isEmpty || data.every((d) => d.income == 0 && d.expense == 0)) {
      return _buildEmptyState(context);
    }
    
    return AspectRatio(
      aspectRatio: 1.6,
      child: BarChart(
        BarChartData(
          alignment: BarChartAlignment.spaceAround,
          maxY: _calculateMaxY(),
          barTouchData: BarTouchData(enabled: false),
          titlesData: FlTitlesData(
            show: true,
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 30,
                getTitlesWidget: _getBottomTitles,
              ),
            ),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 50,
                getTitlesWidget: _getLeftTitles,
              ),
            ),
            topTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            rightTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
          ),
          borderData: FlBorderData(show: false),
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: _calculateMaxY() / 4,
            getDrawingHorizontalLine: (value) => FlLine(
              color: Theme.of(context).colorScheme.outline.withOpacity(0.2),
              strokeWidth: 1,
            ),
          ),
          barGroups: _buildBarGroups(),
        ),
      ),
    );
  }
  
  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.bar_chart_outlined,
            size: 48,
            color: Theme.of(context).colorScheme.outline,
          ),
          const SizedBox(height: 12),
          Text(
            '暂无足够数据',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: Theme.of(context).colorScheme.outline,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '记录更多交易后查看趋势分析',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.outline,
            ),
          ),
        ],
      ),
    );
  }
  
  double _calculateMaxY() {
    final maxIncome = data.map((d) => d.income).reduce((a, b) => a > b ? a : b);
    final maxExpense = data.map((d) => d.expense).reduce((a, b) => a > b ? a : b);
    final maxValue = maxIncome > maxExpense ? maxIncome : maxExpense;
    // Add 20% padding
    return maxValue * 1.2;
  }
  
  List<BarChartGroupData> _buildBarGroups() {
    return data.asMap().entries.map((entry) {
      final index = entry.key;
      final monthlyData = entry.value;
      
      return BarChartGroupData(
        x: index,
        barRods: [
          // Income bar (green)
          BarChartRodData(
            toY: monthlyData.income,
            color: Colors.green,
            width: 12,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(4),
              topRight: Radius.circular(4),
            ),
          ),
          // Expense bar (red)
          BarChartRodData(
            toY: monthlyData.expense,
            color: Colors.red,
            width: 12,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(4),
              topRight: Radius.circular(4),
            ),
          ),
        ],
      );
    }).toList();
  }
  
  Widget _getBottomTitles(double value, TitleMeta meta) {
    final index = value.toInt();
    if (index < 0 || index >= data.length) {
      return const SizedBox.shrink();
    }
    
    final monthLabel = data[index].monthLabel;
    final parts = monthLabel.split('-');
    final displayLabel = parts.length == 2 ? '${parts[0].substring(2)}/${parts[1]}' : monthLabel;
    
    return SideTitleWidget(
      meta: meta,
      space: 4,
      child: Text(
        displayLabel,
        style: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
  
  Widget _getLeftTitles(double value, TitleMeta meta) {
    if (value == 0) {
      return const SizedBox.shrink();
    }
    
    final formattedValue = _formatCurrency(value);
    
    return SideTitleWidget(
      meta: meta,
      space: 4,
      child: Text(
        formattedValue,
        style: const TextStyle(fontSize: 10),
      ),
    );
  }
  
  String _formatCurrency(double value) {
    if (value >= 10000) {
      return '¥${(value / 10000).toStringAsFixed(1)}万';
    } else if (value >= 1000) {
      return '¥${(value / 1000).toStringAsFixed(1)}k';
    } else {
      return '¥${value.toStringAsFixed(0)}';
    }
  }
}