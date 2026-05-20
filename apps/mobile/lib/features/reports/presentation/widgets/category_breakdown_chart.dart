import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:finance_app/features/reports/data/chart_providers.dart';

/// Category breakdown pie chart showing expense distribution.
class CategoryBreakdownChart extends StatelessWidget {
  final List<CategoryBreakdown> data;
  
  const CategoryBreakdownChart({
    super.key,
    required this.data,
  });
  
  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) {
      return _buildEmptyState(context);
    }
    
    final total = data.fold<double>(0, (sum, d) => sum + d.amount);
    
    return Column(
      children: [
        Expanded(
          child: PieChart(
            PieChartData(
              sectionsSpace: 2,
              centerSpaceRadius: 40,
              sections: _buildSections(total),
              pieTouchData: PieTouchData(enabled: false),
            ),
          ),
        ),
        const SizedBox(height: 16),
        _buildLegend(context, total),
      ],
    );
  }
  
  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.pie_chart_outline,
            size: 48,
            color: Theme.of(context).colorScheme.outline,
          ),
          const SizedBox(height: 12),
          Text(
            '暂无分类数据',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: Theme.of(context).colorScheme.outline,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '记录带分类的支出后查看分析',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.outline,
            ),
          ),
        ],
      ),
    );
  }
  
  List<PieChartSectionData> _buildSections(double total) {
    final colors = _getChartColors();
    
    return data.asMap().entries.map((entry) {
      final index = entry.key;
      final breakdown = entry.value;
      final percentage = total > 0 ? (breakdown.amount / total * 100) : 0;
      
      return PieChartSectionData(
        color: colors[index % colors.length],
        value: breakdown.amount,
        title: percentage >= 5 ? '${percentage.toStringAsFixed(0)}%' : '',
        radius: 50,
        titleStyle: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      );
    }).toList();
  }
  
  Widget _buildLegend(BuildContext context, double total) {
    final colors = _getChartColors();
    
    // Show top 5 categories
    final topCategories = data.take(5).toList();
    
    return Wrap(
      spacing: 16,
      runSpacing: 8,
      children: topCategories.asMap().entries.map((entry) {
        final index = entry.key;
        final breakdown = entry.value;
        final percentage = total > 0 ? (breakdown.amount / total * 100) : 0;
        
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                color: colors[index % colors.length],
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 4),
            Text(
              '${breakdown.categoryName} (${percentage.toStringAsFixed(1)}%)',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        );
      }).toList(),
    );
  }
  
  List<Color> _getChartColors() {
    return [
      Colors.blue,
      Colors.green,
      Colors.orange,
      Colors.purple,
      Colors.red,
      Colors.teal,
      Colors.pink,
      Colors.indigo,
      Colors.amber,
      Colors.cyan,
    ];
  }
}