import 'dart:ui' as ui;
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'dart:typed_data';
import 'package:image_gallery_saver/image_gallery_saver.dart';
import 'package:permission_handler/permission_handler.dart';

/// Chart configuration and utilities for optimized data visualization.
/// 
/// Features:
/// - Smooth animations
/// - Interactive tooltips
/// - Export charts as images
/// - Legend toggle
/// - Data labels
class ChartConfig {
  /// Default animation duration in milliseconds
  static const int animationDuration = 800;
  
  /// Default curve for animations
  static const Curve animationCurve = Curves.easeInOutCubic;
  
  /// Chart title style
  static TextStyle chartTitleStyle(BuildContext context) {
    return Theme.of(context).textTheme.titleMedium!.copyWith(
      fontWeight: FontWeight.bold,
    );
  }
  
  /// Chart subtitle style
  static TextStyle chartSubtitleStyle(BuildContext context) {
    return Theme.of(context).textTheme.bodySmall!.copyWith(
      color: Theme.of(context).colorScheme.outline,
    );
  }
  
  /// Default tooltip background color
  static Color tooltipBackgroundColor(BuildContext context) {
    return Theme.of(context).colorScheme.surface;
  }
  
  /// Default tooltip border radius
  static const double tooltipBorderRadius = 8.0;
  
  /// Default tooltip padding
  static const EdgeInsets tooltipPadding = EdgeInsets.all(12);
  
  /// Chart colors palette
  static const List<Color> chartColors = [
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
  
  /// Get color for chart index
  static Color getColor(int index) {
    return chartColors[index % chartColors.length];
  }
  
  /// Format currency value for display
  static String formatCurrency(double value) {
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
  
  /// Format percentage for display
  static String formatPercentage(double value) {
    return '${value.toStringAsFixed(1)}%';
  }
}

/// Mixin for charts that support legend toggle
mixin LegendToggleMixin<T extends StatefulWidget> on State<T> {
  bool _showLegend = true;
  
  bool get showLegend => _showLegend;
  
  void toggleLegend() {
    setState(() {
      _showLegend = !_showLegend;
    });
  }
}

/// Mixin for charts that support data labels
mixin DataLabelsMixin<T extends StatefulWidget> on State<T> {
  bool _showDataLabels = false;
  
  bool get showDataLabels => _showDataLabels;
  
  void toggleDataLabels() {
    setState(() {
      _showDataLabels = !_showDataLabels;
    });
  }
}

/// Widget wrapper that provides chart export functionality
class ChartExportWrapper extends StatefulWidget {
  final Widget child;
  final String fileName;
  final GlobalKey? chartKey;
  
  const ChartExportWrapper({
    super.key,
    required this.child,
    required this.fileName,
    this.chartKey,
  });
  
  @override
  State<ChartExportWrapper> createState() => _ChartExportWrapperState();
}

class _ChartExportWrapperState extends State<ChartExportWrapper> {
  final GlobalKey _defaultChartKey = GlobalKey();
  bool _isExporting = false;
  
  GlobalKey get _chartKey => widget.chartKey ?? _defaultChartKey;
  
  Future<void> exportChart() async {
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
      final result = await ImageGallerySaver.saveImage(
        byteData.buffer.asUint8List(),
        quality: 100,
        name: widget.fileName,
      );
      
      if (mounted) {
        if (result['isSuccess'] == true) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('图表已保存: ${widget.fileName}.png')),
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
  
  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      key: _chartKey,
      child: widget.child,
    );
  }
}

/// Enhanced tooltip widget with detailed information
class ChartTooltip extends StatelessWidget {
  final String title;
  final List<TooltipItem> items;
  final DateTime? timestamp;
  
  const ChartTooltip({
    super.key,
    required this.title,
    required this.items,
    this.timestamp,
  });
  
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: ChartConfig.tooltipPadding,
      decoration: BoxDecoration(
        color: ChartConfig.tooltipBackgroundColor(context),
        borderRadius: BorderRadius.circular(ChartConfig.tooltipBorderRadius),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          if (timestamp != null) ...[
            const SizedBox(height: 4),
            Text(
              _formatTimestamp(timestamp!),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.outline,
              ),
            ),
          ],
          const SizedBox(height: 8),
          ...items.map((item) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: item.color,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '${item.label}: ',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                Text(
                  item.value,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: item.color,
                  ),
                ),
              ],
            ),
          )),
        ],
      ),
    );
  }
  
  String _formatTimestamp(DateTime time) {
    return '${time.year}-${time.month.toString().padLeft(2, '0')}-${time.day.toString().padLeft(2, '0')}';
  }
}

/// Tooltip item for chart tooltip
class TooltipItem {
  final String label;
  final String value;
  final Color color;
  
  const TooltipItem({
    required this.label,
    required this.value,
    required this.color,
  });
}

/// Chart control buttons (export, legend toggle, data labels toggle)
class ChartControls extends StatelessWidget {
  final VoidCallback? onExport;
  final VoidCallback? onToggleLegend;
  final VoidCallback? onToggleDataLabels;
  final bool showLegend;
  final bool showDataLabels;
  final bool isExporting;
  
  const ChartControls({
    super.key,
    this.onExport,
    this.onToggleLegend,
    this.onToggleDataLabels,
    this.showLegend = true,
    this.showDataLabels = false,
    this.isExporting = false,
  });
  
  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (onToggleLegend != null)
          IconButton(
            icon: Icon(
              showLegend ? Icons.legend_toggle : Icons.legend_toggle_outlined,
              size: 20,
            ),
            onPressed: onToggleLegend,
            tooltip: showLegend ? '隐藏图例' : '显示图例',
          ),
        if (onToggleDataLabels != null)
          IconButton(
            icon: Icon(
              showDataLabels ? Icons.label : Icons.label_outline,
              size: 20,
            ),
            onPressed: onToggleDataLabels,
            tooltip: showDataLabels ? '隐藏数据标签' : '显示数据标签',
          ),
        if (onExport != null)
          IconButton(
            icon: isExporting
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.download, size: 20),
            onPressed: isExporting ? null : onExport,
            tooltip: '导出图表',
          ),
      ],
    );
  }
}
