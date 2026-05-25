import 'dart:ui' as ui;
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:finance_app/features/reports/data/chart_providers.dart';
import 'package:finance_app/features/transactions/data/transaction_filter.dart';
import 'package:image_gallery_saver/image_gallery_saver.dart';
import 'package:permission_handler/permission_handler.dart';

/// Category breakdown pie chart showing expense distribution.
/// 
/// Optimized features (v0.3.116):
/// - Smooth animations
/// - Interactive tooltips with detailed information
/// - Export charts as images
/// - Legend toggle
/// - Data labels
class CategoryBreakdownChart extends StatefulWidget {
  final List<CategoryBreakdown> data;
  final void Function(TransactionFilter)? onCategoryTap;
  
  const CategoryBreakdownChart({
    super.key,
    required this.data,
    this.onCategoryTap,
  });
  
  @override
  State<CategoryBreakdownChart> createState() => _CategoryBreakdownChartState();
}

class _CategoryBreakdownChartState extends State<CategoryBreakdownChart>
    with SingleTickerProviderStateMixin {
  // Animation controller
  late AnimationController _animationController;
  late Animation<double> _animation;
  
  // Legend toggle
  bool _showLegend = true;
  
  // Data labels toggle
  bool _showDataLabels = true;
  
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
  void didUpdateWidget(CategoryBreakdownChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.data != widget.data) {
      _animationController.reset();
      _animationController.forward();
    }
  }
  
  @override
  Widget build(BuildContext context) {
    if (widget.data.isEmpty) {
      return _buildEmptyState(context);
    }
    
    final total = widget.data.fold<double>(0, (sum, d) => sum + d.amount);
    
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
                return PieChart(
                  PieChartData(
                    sectionsSpace: 2,
                    centerSpaceRadius: 40,
                    sections: _buildSections(total),
                    pieTouchData: PieTouchData(
                      enabled: true,
                      touchCallback: (event, response) {
                        if (event is FlTapUpEvent && response != null && response.touchedSection != null) {
                          final touchedIndex = response.touchedSection!.touchedSectionIndex;
                          if (touchedIndex >= 0 && touchedIndex < widget.data.length) {
                            final categoryId = widget.data[touchedIndex].categoryId;
                            _handleCategoryTap(categoryId);
                          }
                        }
                      },
                    ),
                    startDegreeOffset: -90,
                  ),
                );
              },
            ),
          ),
        ),
        
        // Legend (toggleable)
        if (_showLegend) ...[
          const SizedBox(height: 16),
          _buildLegend(context, total),
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
      final fileName = 'category_breakdown_${DateTime.now().millisecondsSinceEpoch}';
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
    
    return widget.data.asMap().entries.map((entry) {
      final index = entry.key;
      final breakdown = entry.value;
      final percentage = total > 0 ? (breakdown.amount / total * 100) : 0;
      
      return PieChartSectionData(
        color: colors[index % colors.length],
        value: breakdown.amount * _animation.value,
        title: _showDataLabels && percentage >= 5 
            ? '${percentage.toStringAsFixed(0)}%' 
            : '',
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
    final topCategories = widget.data.take(5).toList();
    
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
  
  void _handleCategoryTap(String categoryId) {
    if (onCategoryTap == null) return;
    
    final filter = TransactionFilter(
      categoryId: categoryId,
    );
    
    onCategoryTap!(filter);
  }
}