import 'dart:ui' as ui;
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:finance_app/features/reports/data/chart_providers.dart';
import 'package:finance_app/features/transactions/data/transaction_filter.dart';
import 'package:image_gallery_saver/image_gallery_saver.dart';
import 'package:permission_handler/permission_handler.dart';

/// Monthly trend bar chart showing income and expense for last 6 months.
/// 
/// Optimized features (v0.3.116):
/// - Smooth animations
/// - Interactive tooltips with detailed information
/// - Export charts as images
/// - Legend toggle
/// - Data labels
class MonthlyTrendChart extends StatefulWidget {
  final List<MonthlyData> data;
  final void Function(TransactionFilter)? onBarTap;
  
  const MonthlyTrendChart({
    super.key,
    required this.data,
    this.onBarTap,
  });
  
  @override
  State<MonthlyTrendChart> createState() => _MonthlyTrendChartState();
}

class _MonthlyTrendChartState extends State<MonthlyTrendChart>
    with SingleTickerProviderStateMixin {
  // Animation controller
  late AnimationController _animationController;
  late Animation<double> _animation;
  
  // Legend toggle
  bool _showLegend = true;
  
  // Data labels toggle
  bool _showDataLabels = false;
  
  // Export state
  final GlobalKey _chartKey = GlobalKey();
  bool _isExporting = false;
  
  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _animation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOutCubic,
    );
    _animationController.forward();
  }
  
  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }
  
  @override
  void didUpdateWidget(MonthlyTrendChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.data != widget.data) {
      _animationController.reset();
      _animationController.forward();
    }
  }
  
  @override
  Widget build(BuildContext context) {
    if (widget.data.isEmpty || widget.data.every((d) => d.income == 0 && d.expense == 0)) {
      return _buildEmptyState(context);
    }
    
    return Column(
      children: [
        // Chart controls
        _buildControls(context),
        
        const SizedBox(height: 8),
        
        // Chart with export wrapper
        Expanded(
          child: RepaintBoundary(
            key: _chartKey,
            child: AnimatedBuilder(
              animation: _animation,
              builder: (context, child) {
                return AspectRatio(
                  aspectRatio: 1.6,
                  child: BarChart(
                    BarChartData(
                      alignment: BarChartAlignment.spaceAround,
                      maxY: _calculateMaxY() * _animation.value,
                      barTouchData: BarTouchData(
                        enabled: true,
                        touchTooltipData: BarTouchTooltipData(
                          getTooltipColor: (_) => Theme.of(context).colorScheme.surface,
                          tooltipPadding: const EdgeInsets.all(12),
                          tooltipMargin: 8,
                          getTooltipItem: _getTooltipItem,
                        ),
                        touchCallback: (event, response) {
                          if (event is FlTapUpEvent && response != null && response.spot != null) {
                            final barIndex = response.spot!.spot.x.toInt();
                            
                            if (barIndex >= 0 && barIndex < widget.data.length) {
                              final monthLabel = widget.data[barIndex].monthLabel;
                              _handleBarTap(monthLabel);
                            }
                          }
                        },
                      ),
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
              },
            ),
          ),
        ),
        
        // Legend (toggleable)
        if (_showLegend) ...[
          const SizedBox(height: 16),
          _buildLegend(context),
        ],
      ],
    );
  }
  
  Widget _buildControls(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        // Legend toggle
        IconButton(
          icon: Icon(
            _showLegend ? Icons.legend_toggle : Icons.legend_toggle_outlined,
            size: 20,
          ),
          onPressed: () {
            setState(() {
              _showLegend = !_showLegend;
            });
          },
          tooltip: _showLegend ? '隐藏图例' : '显示图例',
        ),
        
        // Data labels toggle
        IconButton(
          icon: Icon(
            _showDataLabels ? Icons.label : Icons.label_outline,
            size: 20,
          ),
          onPressed: () {
            setState(() {
              _showDataLabels = !_showDataLabels;
            });
          },
          tooltip: _showDataLabels ? '隐藏数据标签' : '显示数据标签',
        ),
        
        // Export button
        IconButton(
          icon: _isExporting
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.download, size: 20),
          onPressed: _isExporting ? null : _exportChart,
          tooltip: '导出图表',
        ),
      ],
    );
  }
  
  Future<void> _exportChart() async {
    if (_isExporting) return;
    
    setState(() {
      _isExporting = true;
    });
    
    try {
      // Request storage permission
      final status = await Permission.storage.request();
      if (!status.isGranted) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('需要存储权限才能保存图表')),
          );
        }
        return;
      }
      
      // Capture the chart as image
      final boundary = _chartKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('无法捕获图表')),
          );
        }
        return;
      }
      
      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      
      if (byteData == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('无法生成图片')),
          );
        }
        return;
      }
      
      // Save to gallery
      final fileName = 'monthly_trend_${DateTime.now().millisecondsSinceEpoch}';
      final result = await ImageGallerySaver.saveImage(
        byteData.buffer.asUint8List(),
        quality: 100,
        name: fileName,
      );
      
      if (mounted) {
        if (result['isSuccess'] == true) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('图表已保存: $fileName.png')),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('保存失败')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('导出失败: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isExporting = false;
        });
      }
    }
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
    final maxIncome = widget.data.map((d) => d.income).reduce((a, b) => a > b ? a : b);
    final maxExpense = widget.data.map((d) => d.expense).reduce((a, b) => a > b ? a : b);
    final maxValue = maxIncome > maxExpense ? maxIncome : maxExpense;
    // Add 20% padding
    return maxValue * 1.2;
  }
  
  List<BarChartGroupData> _buildBarGroups() {
    return widget.data.asMap().entries.map((entry) {
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
        showingTooltipIndicators: _showDataLabels ? [0, 1] : [],
      );
    }).toList();
  }
  
  BarTooltipItem? _getTooltipItem(BarChartGroupData group, int groupIndex, BarChartRodData rod, int rodIndex) {
    if (groupIndex < 0 || groupIndex >= widget.data.length) return null;
    
    final monthlyData = widget.data[groupIndex];
    final isIncome = rodIndex == 0;
    final value = isIncome ? monthlyData.income : monthlyData.expense;
    final label = isIncome ? '收入' : '支出';
    final color = isIncome ? Colors.green : Colors.red;
    
    return BarTooltipItem(
      '$label: ${_formatCurrency(value)}',
      TextStyle(
        color: color,
        fontWeight: FontWeight.bold,
        fontSize: 12,
      ),
    );
  }
  
  Widget _buildLegend(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _buildLegendItem('收入', Colors.green),
        const SizedBox(width: 24),
        _buildLegendItem('支出', Colors.red),
      ],
    );
  }
  
  Widget _buildLegendItem(String label, Color color) {
    return Row(
      children: [
        Container(
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }
  
  Widget _getBottomTitles(double value, TitleMeta meta) {
    final index = value.toInt();
    if (index < 0 || index >= widget.data.length) {
      return const SizedBox.shrink();
    }
    
    final monthLabel = widget.data[index].monthLabel;
    final parts = monthLabel.split('-');
    final displayLabel = parts.length == 2 ? '${parts[0].substring(2)}/${parts[1]}' : monthLabel;
    
    return SideTitleWidget(
      axisSide: meta.axisSide,
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
      axisSide: meta.axisSide,
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
  
  void _handleBarTap(String monthLabel) {
    if (onBarTap == null) return;
    
    // Parse monthLabel (format: "YYYY-MM")
    final parts = monthLabel.split('-');
    if (parts.length != 2) return;
    
    final year = int.tryParse(parts[0]);
    final month = int.tryParse(parts[1]);
    if (year == null || month == null) return;
    
    // Create date range for the month
    final startDate = DateTime(year, month, 1);
    final endDate = DateTime(year, month + 1, 0, 23, 59, 59, 999);
    
    final filter = TransactionFilter(
      startDate: startDate,
      endDate: endDate,
    );
    
    onBarTap!(filter);
  }
}