import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:finance_app/features/reports/data/balance_history_provider.dart';
import 'package:image_gallery_saver/image_gallery_saver.dart';
import 'package:permission_handler/permission_handler.dart';

/// Asset-liability trend chart showing asset, liability, and net worth over time.
/// 
/// Features:
/// - Line chart with three trend lines (assets, liabilities, net worth)
/// - Period selection (monthly, quarterly, yearly)
/// - Zoom and pan support
/// - Comparison with previous period
/// - Chinese labels
/// 
/// Optimized features (v0.3.116):
/// - Smooth animations
/// - Interactive tooltips with detailed information
/// - Export charts as images
/// - Legend toggle
/// - Data labels
class AssetTrendChart extends ConsumerStatefulWidget {
  const AssetTrendChart({super.key});

  @override
  ConsumerState<AssetTrendChart> createState() => _AssetTrendChartState();
}

class _AssetTrendChartState extends ConsumerState<AssetTrendChart>
    with SingleTickerProviderStateMixin {
  // Zoom and pan state
  double _minX = 0;
  double _maxX = 0;
  double _minY = 0;
  double _maxY = 0;
  
  // Track if we need to initialize the range
  bool _needsInit = true;
  
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
  Widget build(BuildContext context) {
    final historyAsync = ref.watch(balanceHistoryProvider);
    final period = ref.watch(balanceHistoryPeriodProvider);
    final comparisonAsync = ref.watch(balanceComparisonProvider);
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Period selection chips
        _buildPeriodSelector(),
        
        const SizedBox(height: 16),
        
        // Comparison card
        comparisonAsync.when(
          data: (comparison) {
            if (comparison == null) return const SizedBox.shrink();
            return _buildComparisonCard(comparison);
          },
          loading: () => const SizedBox.shrink(),
          error: (_, __) => const SizedBox.shrink(),
        ),
        
        const SizedBox(height: 16),
        
        // Chart controls
        _buildChartControls(context),
        
        const SizedBox(height: 8),
        
        // Chart with export wrapper
        Expanded(
          child: historyAsync.when(
            data: (history) {
              if (history.isEmpty || history.every((h) => h.totalAssets == 0 && h.totalLiabilities == 0)) {
                return _buildEmptyState(context);
              }
              
              // Initialize range on first build
              if (_needsInit) {
                _initRange(history);
                _needsInit = false;
              }
              
              return RepaintBoundary(
                key: _chartKey,
                child: AnimatedBuilder(
                  animation: _animation,
                  builder: (context, child) {
                    return _buildChart(context, history, period);
                  },
                ),
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, _) => Center(
              child: Text('加载失败: $error'),
            ),
          ),
        ),
        
        // Legend (toggleable)
        if (_showLegend) _buildLegend(context),
      ],
    );
  }
  
  Widget _buildChartControls(BuildContext context) {
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
      final fileName = 'asset_trend_${DateTime.now().millisecondsSinceEpoch}';
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
  
  Widget _buildPeriodSelector() {
    final period = ref.watch(balanceHistoryPeriodProvider);
    final notifier = ref.read(balanceHistoryNotifierProvider.notifier);
    
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _buildPeriodChip(
            label: '按月',
            selected: period == BalanceHistoryPeriod.monthly,
            onTap: () => notifier.setPeriod(BalanceHistoryPeriod.monthly),
          ),
          const SizedBox(width: 8),
          _buildPeriodChip(
            label: '按季',
            selected: period == BalanceHistoryPeriod.quarterly,
            onTap: () => notifier.setPeriod(BalanceHistoryPeriod.quarterly),
          ),
          const SizedBox(width: 8),
          _buildPeriodChip(
            label: '按年',
            selected: period == BalanceHistoryPeriod.yearly,
            onTap: () => notifier.setPeriod(BalanceHistoryPeriod.yearly),
          ),
        ],
      ),
    );
  }
  
  Widget _buildPeriodChip({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return FilterChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onTap(),
      selectedColor: Theme.of(context).colorScheme.primaryContainer,
      checkmarkColor: Theme.of(context).colorScheme.primary,
    );
  }
  
  Widget _buildComparisonCard(BalanceComparison comparison) {
    final growthColor = comparison.netWorthGrowthPercent >= 0 
        ? Colors.green 
        : Colors.red;
    final growthIcon = comparison.netWorthGrowthPercent >= 0 
        ? Icons.trending_up 
        : Icons.trending_down;
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '净资产增长',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(
                  growthIcon,
                  color: growthColor,
                  size: 32,
                ),
                const SizedBox(width: 8),
                Text(
                  '${comparison.netWorthGrowthPercent >= 0 ? '+' : ''}${comparison.netWorthGrowthPercent.toStringAsFixed(1)}%',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    color: growthColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildComparisonItem(
                  label: '资产变化',
                  value: comparison.assetChange,
                  color: Colors.blue,
                ),
                _buildComparisonItem(
                  label: '负债变化',
                  value: comparison.liabilityChange,
                  color: Colors.orange,
                ),
                _buildComparisonItem(
                  label: '净资产变化',
                  value: comparison.netWorthChange,
                  color: Colors.green,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildComparisonItem({
    required String label,
    required double value,
    required Color color,
  }) {
    return Column(
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Theme.of(context).colorScheme.outline,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '${value >= 0 ? '+' : ''}${_formatCurrency(value)}',
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
            color: color,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
  
  Widget _buildChart(BuildContext context, List<BalanceHistoryPoint> history, BalanceHistoryPeriod period) {
    return GestureDetector(
      onScaleUpdate: (details) {
        // Zoom gesture
        final scale = details.scale;
        if (scale != 1.0) {
          setState(() {
            final range = _maxX - _minX;
            final newRange = range / scale;
            final center = (_maxX + _minX) / 2;
            
            _minX = (center - newRange / 2).clamp(0.0, (history.length - 1).toDouble());
            _maxX = (center + newRange / 2).clamp(0.0, (history.length - 1).toDouble());
            
            if (_minX == _maxX) {
              _minX = (_minX - 0.5).clamp(0.0, (history.length - 1).toDouble());
              _maxX = (_maxX + 0.5).clamp(0.0, (history.length - 1).toDouble());
            }
          });
        }
      },
      onHorizontalDragUpdate: (details) {
        // Pan gesture
        setState(() {
          final delta = -details.primaryDelta! * 0.02 * (_maxX - _minX);
          _minX = (_minX + delta).clamp(0.0, (history.length - 1 - (_maxX - _minX)));
          _maxX = (_maxX + delta).clamp((_maxX - _minX), (history.length - 1).toDouble());
        });
      },
      child: LineChart(
        LineChartData(
          minX: _minX,
          maxX: _maxX,
          minY: _minY,
          maxY: _maxY,
          clipData: const FlClipData.all(),
          titlesData: FlTitlesData(
            show: true,
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 40,
                interval: _calculateBottomInterval(history.length),
                getTitlesWidget: (value, meta) => _getBottomTitles(value, meta, history),
              ),
            ),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 60,
                interval: _calculateLeftInterval(),
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
          borderData: FlBorderData(
            show: true,
            border: Border(
              bottom: BorderSide(
                color: Theme.of(context).colorScheme.outline.withOpacity(0.3),
              ),
              left: BorderSide(
                color: Theme.of(context).colorScheme.outline.withOpacity(0.3),
              ),
            ),
          ),
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: _calculateLeftInterval(),
            getDrawingHorizontalLine: (value) => FlLine(
              color: Theme.of(context).colorScheme.outline.withOpacity(0.1),
              strokeWidth: 1,
            ),
          ),
          lineBarsData: [
            // Assets line (blue)
            _buildLine(
              history: history,
              getValue: (point) => point.totalAssets,
              color: Colors.blue,
            ),
            // Liabilities line (orange)
            _buildLine(
              history: history,
              getValue: (point) => point.totalLiabilities.abs(),
              color: Colors.orange,
            ),
            // Net worth line (green)
            _buildLine(
              history: history,
              getValue: (point) => point.netWorth,
              color: Colors.green,
            ),
          ],
          lineTouchData: LineTouchData(
            enabled: true,
            touchTooltipData: LineTouchTooltipData(
              getTooltipColor: (_) => Theme.of(context).colorScheme.surface,
              tooltipPadding: const EdgeInsets.all(8),
              tooltipMargin: 8,
              getTooltipItems: (touchedSpots) {
                return touchedSpots.map((spot) {
                  final index = spot.x.toInt();
                  if (index < 0 || index >= history.length) return null;
                  
                  final point = history[index];
                  String label;
                  switch (spot.barIndex) {
                    case 0:
                      label = '资产: ${_formatCurrency(point.totalAssets)}';
                      break;
                    case 1:
                      label = '负债: ${_formatCurrency(point.totalLiabilities.abs())}';
                      break;
                    case 2:
                      label = '净资产: ${_formatCurrency(point.netWorth)}';
                      break;
                    default:
                      label = '';
                  }
                  
                  return LineTooltipItem(
                    label,
                    TextStyle(
                      color: spot.bar.color,
                      fontWeight: FontWeight.bold,
                    ),
                  );
                }).toList();
              },
            ),
          ),
        ),
      ),
    );
  }
  
  LineChartBarData _buildLine({
    required List<BalanceHistoryPoint> history,
    required double Function(BalanceHistoryPoint) getValue,
    required Color color,
  }) {
    return LineChartBarData(
      spots: history.asMap().entries.map((entry) {
        return FlSpot(entry.key.toDouble(), getValue(entry.value));
      }).toList(),
      isCurved: true,
      curveSmoothness: 0.3,
      color: color,
      barWidth: 3,
      isStrokeCapRound: true,
      dotData: FlDotData(
        show: history.length <= 12,
        getDotPainter: (spot, percent, barData, index) {
          return FlDotCirclePainter(
            radius: 4,
            color: color,
            strokeWidth: 2,
            strokeColor: Theme.of(context).colorScheme.surface,
          );
        },
      ),
      belowBarData: BarAreaData(
        show: false,
      ),
    );
  }
  
  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.show_chart,
            size: 64,
            color: Theme.of(context).colorScheme.outline,
          ),
          const SizedBox(height: 16),
          Text(
            '暂无历史数据',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: Theme.of(context).colorScheme.outline,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '记录更多交易后查看资产负债趋势',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.outline,
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildLegend(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _buildLegendItem('资产', Colors.blue),
          const SizedBox(width: 24),
          _buildLegendItem('负债', Colors.orange),
          const SizedBox(width: 24),
          _buildLegendItem('净资产', Colors.green),
        ],
      ),
    );
  }
  
  Widget _buildLegendItem(String label, Color color) {
    return Row(
      children: [
        Container(
          width: 16,
          height: 3,
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
  
  void _initRange(List<BalanceHistoryPoint> history) {
    _minX = 0;
    _maxX = (history.length - 1).toDouble();
    
    // Calculate Y range with padding
    double minVal = double.infinity;
    double maxVal = double.negativeInfinity;
    
    for (final point in history) {
      final values = [point.totalAssets, point.totalLiabilities.abs(), point.netWorth];
      final localMin = values.reduce((a, b) => a < b ? a : b);
      final localMax = values.reduce((a, b) => a > b ? a : b);
      
      if (localMin < minVal) minVal = localMin;
      if (localMax > maxVal) maxVal = localMax;
    }
    
    // Add 10% padding
    final range = maxVal - minVal;
    if (range == 0) {
      _minY = minVal - 100;
      _maxY = maxVal + 100;
    } else {
      _minY = minVal - range * 0.1;
      _maxY = maxVal + range * 0.1;
    }
  }
  
  double _calculateBottomInterval(int dataLength) {
    if (dataLength <= 6) return 1;
    if (dataLength <= 12) return 2;
    if (dataLength <= 24) return 3;
    return (dataLength / 8).ceilToDouble();
  }
  
  double _calculateLeftInterval() {
    final range = _maxY - _minY;
    if (range <= 0) return 100;
    
    // Calculate nice interval
    final magnitude = (range / 5).abs();
    final exponent = (magnitude.log10()).floor();
    final fraction = magnitude / math.pow(10, exponent);
    
    double niceFraction;
    if (fraction <= 1) {
      niceFraction = 1;
    } else if (fraction <= 2) {
      niceFraction = 2;
    } else if (fraction <= 5) {
      niceFraction = 5;
    } else {
      niceFraction = 10;
    }
    
    return niceFraction * math.pow(10, exponent);
  }
  
  Widget _getBottomTitles(double value, TitleMeta meta, List<BalanceHistoryPoint> history) {
    final index = value.toInt();
    if (index < 0 || index >= history.length) {
      return const SizedBox.shrink();
    }
    
    final label = history[index].label;
    String displayLabel;
    
    // Format label based on content
    if (label.contains('-Q')) {
      // Quarterly: "2026-Q1" -> "Q1"
      displayLabel = label.split('-').last;
    } else if (label.contains('-')) {
      // Monthly: "2026-05" -> "5月"
      final parts = label.split('-');
      displayLabel = '${int.parse(parts[1])}月';
    } else {
      // Yearly: "2026"
      displayLabel = label;
    }
    
    return SideTitleWidget(
      axisSide: meta.axisSide,
      space: 8,
      child: Text(
        displayLabel,
        style: TextStyle(
          fontSize: 10,
          color: Theme.of(context).colorScheme.onSurface,
        ),
      ),
    );
  }
  
  Widget _getLeftTitles(double value, TitleMeta meta) {
    if (value == 0 && _minY < 0 && _maxY > 0) {
      // Show zero line
      return SideTitleWidget(
        axisSide: meta.axisSide,
        child: Text(
          '0',
          style: TextStyle(
            fontSize: 10,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
      );
    }
    
    final formatted = _formatCurrency(value);
    
    return SideTitleWidget(
      axisSide: meta.axisSide,
      space: 8,
      child: Text(
        formatted,
        style: TextStyle(
          fontSize: 10,
          color: Theme.of(context).colorScheme.onSurface,
        ),
      ),
    );
  }
  
  String _formatCurrency(double value) {
    final absValue = value.abs();
    
    if (absValue >= 100000000) {
      return '¥${(value / 100000000).toStringAsFixed(1)}亿';
    } else if (absValue >= 10000) {
      return '¥${(value / 10000).toStringAsFixed(1)}万';
    } else if (absValue >= 1000) {
      return '¥${(value / 1000).toStringAsFixed(1)}k';
    } else {
      return '¥${value.toStringAsFixed(0)}';
    }
  }
}

extension on double {
  double log10() {
    if (this <= 0) return 0;
    // Use natural log to compute log10
    return math.log(this) / math.log(10);
  }
}
