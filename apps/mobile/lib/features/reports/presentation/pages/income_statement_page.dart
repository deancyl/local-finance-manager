import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:decimal/decimal.dart';
import 'package:core/core.dart';
import 'package:share_plus/share_plus.dart';

import '../../data/income_statement_provider.dart';
import '../widgets/income_statement_section.dart';
import '../../../export/data/export_service.dart';
import '../../../export/data/export_provider.dart';
import '../../../print/data/print_service.dart';
import '../../../print/data/print_provider.dart';
import '../mixins/drill_down_mixin.dart';
import '../../../../core/widgets/loading_state_widget.dart';
import '../../../../core/widgets/empty_state_widget.dart';
import '../../../../core/widgets/error_state_widget.dart';

/// Income statement report page with date range filtering and period comparison.
///
/// Displays revenues and expenses sections with net income calculation.
/// Supports pull-to-refresh, date range selection, and period comparison.
class IncomeStatementPage extends ConsumerStatefulWidget {
  const IncomeStatementPage({super.key});

  @override
  ConsumerState<IncomeStatementPage> createState() => _IncomeStatementPageState();
}

class _IncomeStatementPageState extends ConsumerState<IncomeStatementPage>
    with DrillDownMixin {
  DateTime? _startDate;
  DateTime? _endDate;
  PeriodComparisonType _comparisonType = PeriodComparisonType.none;
  DateTime? _comparisonStartDate;
  DateTime? _comparisonEndDate;
  bool _showComparisonSelector = false;

  @override
  void initState() {
    super.initState();
    // Set default date range to current year
    final now = DateTime.now();
    _startDate = DateTime(now.year, 1, 1);
    _endDate = DateTime(now.year, 12, 31, 23, 59, 59, 999);

    // Load initial data
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadData();
    });
  }

  Future<void> _loadData() async {
    await ref.read(incomeStatementProvider.notifier).setDateRange(_startDate, _endDate);
    await ref.read(incomeStatementProvider.notifier).setComparisonType(_comparisonType);
    if (_comparisonType == PeriodComparisonType.custom &&
        _comparisonStartDate != null &&
        _comparisonEndDate != null) {
      await ref.read(incomeStatementProvider.notifier)
          .setCustomComparisonDates(_comparisonStartDate, _comparisonEndDate);
    }
  }

  Future<void> _selectStartDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _startDate ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
      locale: const Locale('zh', 'CN'),
    );

    if (picked != null) {
      setState(() {
        _startDate = DateTime(picked.year, picked.month, picked.day);
      });
      await _loadData();
    }
  }

  Future<void> _selectEndDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _endDate ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
      locale: const Locale('zh', 'CN'),
    );

    if (picked != null) {
      setState(() {
        _endDate = DateTime(picked.year, picked.month, picked.day, 23, 59, 59, 999);
      });
      await _loadData();
    }
  }

  Future<void> _selectComparisonStartDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _comparisonStartDate ?? DateTime.now().subtract(const Duration(days: 365)),
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
      locale: const Locale('zh', 'CN'),
    );

    if (picked != null) {
      setState(() {
        _comparisonStartDate = DateTime(picked.year, picked.month, picked.day);
      });
      await _loadData();
    }
  }

  Future<void> _selectComparisonEndDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _comparisonEndDate ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
      locale: const Locale('zh', 'CN'),
    );

    if (picked != null) {
      setState(() {
        _comparisonEndDate = DateTime(picked.year, picked.month, picked.day, 23, 59, 59, 999);
      });
      await _loadData();
    }
  }

  Future<void> _handleRefresh() async {
    await ref.read(incomeStatementProvider.notifier).refresh();
  }

  void _handleExport() {
    showModalBottomSheet<void>(
      context: context,
      builder: (context) => _ExportOptionsSheet(
        reportName: '利润表',
        startDate: _startDate,
        endDate: _endDate,
      ),
    );
  }

  void _handlePrint() async {
    final statementWithComparison = ref.read(incomeStatementProvider).valueOrNull;
    if (statementWithComparison == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('利润表数据未加载')),
      );
      return;
    }

    await PrintService.showPreview(
      context: context,
      title: '利润表 - 打印预览',
      onLayout: (setup) async {
        final pdfService = ref.read(pdfExportServiceProvider);
        return pdfService.exportIncomeStatementToPDFBytes(
          incomeStatement: statementWithComparison.current,
          pageSetup: setup,
        );
      },
    );
  }

  void _handleComparisonTypeChanged(PeriodComparisonType? type) {
    if (type == null) return;
    setState(() {
      _comparisonType = type;
      _showComparisonSelector = type == PeriodComparisonType.custom;
    });
    ref.read(incomeStatementProvider.notifier).setComparisonType(type);
  }

  @override
  Widget build(BuildContext context) {
    final incomeStatementAsync = ref.watch(incomeStatementProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('利润表'),
        actions: [
          IconButton(
            icon: const Icon(Icons.print),
            onPressed: _handlePrint,
            tooltip: '打印',
          ),
          IconButton(
            icon: const Icon(Icons.download),
            onPressed: _handleExport,
            tooltip: '导出',
          ),
        ],
      ),
      body: Column(
        children: [
          // Date range selector
          _buildDateRangeSelector(context),

          // Comparison type selector
          _buildComparisonSelector(context),

          // Content
          Expanded(
            child: incomeStatementAsync.when(
              data: (statementWithComparison) {
                if (statementWithComparison == null) {
                  return const EmptyStateWidget(
                    icon: Icons.receipt_long_outlined,
                    title: '暂无收支数据',
                    subtitle: '请先添加收入和费用账户的交易记录',
                  );
                }
                return _buildContent(context, statementWithComparison);
              },
              loading: () => const LoadingStateWidget(message: '加载利润表...'),
              error: (error, stack) => ErrorStateWidget.fromError(
                error: error,
                onRetry: _handleRefresh,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDateRangeSelector(BuildContext context) {
    final theme = Theme.of(context);
    final dateFormat = DateFormat('yyyy-MM-dd');

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
          Row(
            children: [
              Icon(
                Icons.date_range,
                size: 20,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Text(
                '报告期间',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              // Start date
              Expanded(
                child: InkWell(
                  onTap: _selectStartDate,
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surface,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: theme.colorScheme.outline,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.calendar_today,
                          size: 16,
                          color: theme.colorScheme.primary,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _startDate != null
                              ? dateFormat.format(_startDate!)
                              : '开始日期',
                          style: theme.textTheme.bodyMedium,
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              const SizedBox(width: 12),

              // End date
              Expanded(
                child: InkWell(
                  onTap: _selectEndDate,
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surface,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: theme.colorScheme.outline,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.calendar_today,
                          size: 16,
                          color: theme.colorScheme.primary,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _endDate != null
                              ? dateFormat.format(_endDate!)
                              : '结束日期',
                          style: theme.textTheme.bodyMedium,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildComparisonSelector(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
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
          Row(
            children: [
              Icon(
                Icons.compare_arrows,
                size: 20,
                color: theme.colorScheme.secondary,
              ),
              const SizedBox(width: 8),
              Text(
                '期间对比',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: PeriodComparisonType.values.map((type) {
                final isSelected = _comparisonType == type;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    label: Text(_getComparisonTypeLabel(type)),
                    selected: isSelected,
                    onSelected: (_) => _handleComparisonTypeChanged(type),
                    selectedColor: theme.colorScheme.primaryContainer,
                    checkmarkColor: theme.colorScheme.primary,
                  ),
                );
              }).toList(),
            ),
          ),
          if (_showComparisonSelector) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: _selectComparisonStartDate,
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: theme.colorScheme.outline,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.calendar_today,
                            size: 16,
                            color: theme.colorScheme.secondary,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _comparisonStartDate != null
                                  ? DateFormat('yyyy-MM-dd').format(_comparisonStartDate!)
                                  : '对比开始',
                              style: theme.textTheme.bodySmall,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: InkWell(
                    onTap: _selectComparisonEndDate,
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: theme.colorScheme.outline,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.calendar_today,
                            size: 16,
                            color: theme.colorScheme.secondary,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _comparisonEndDate != null
                                  ? DateFormat('yyyy-MM-dd').format(_comparisonEndDate!)
                                  : '对比结束',
                              style: theme.textTheme.bodySmall,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  String _getComparisonTypeLabel(PeriodComparisonType type) {
    switch (type) {
      case PeriodComparisonType.none:
        return '无对比';
      case PeriodComparisonType.previousMonth:
        return '上月';
      case PeriodComparisonType.previousQuarter:
        return '上季度';
      case PeriodComparisonType.previousYear:
        return '去年同期';
      case PeriodComparisonType.custom:
        return '自定义';
    }
  }

  Widget _buildContent(BuildContext context, IncomeStatementWithComparison statementWithComparison) {
    final incomeStatement = statementWithComparison.current;
    final hasData = incomeStatement.revenues.items.isNotEmpty ||
        incomeStatement.expenses.items.isNotEmpty;

    if (!hasData) {
      return _buildEmptyState(context);
    }

    return RefreshIndicator(
      onRefresh: _handleRefresh,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.only(top: 12, bottom: 12),
        child: Column(
          children: [
            // Comparison summary card (if comparison is enabled)
            if (statementWithComparison.hasComparison)
              _buildComparisonSummaryCard(context, statementWithComparison),

            // Revenues section
            IncomeStatementSectionWidget(
              section: incomeStatement.revenues,
              isRevenue: true,
              initiallyExpanded: true,
              startDate: _startDate,
              endDate: _endDate,
              onDrillDown: (accountId, accountName) {
                navigateToTransactions(
                  context,
                  accountId: accountId,
                  accountName: accountName,
                  startDate: _startDate,
                  endDate: _endDate,
                );
              },
            ),

            // Expenses section
            IncomeStatementSectionWidget(
              section: incomeStatement.expenses,
              isRevenue: false,
              initiallyExpanded: true,
              startDate: _startDate,
              endDate: _endDate,
              onDrillDown: (accountId, accountName) {
                navigateToTransactions(
                  context,
                  accountId: accountId,
                  accountName: accountName,
                  startDate: _startDate,
                  endDate: _endDate,
                );
              },
            ),

            const SizedBox(height: 12),

            // Net income card
            _buildNetIncomeCard(context, incomeStatement),
          ],
        ),
      ),
    );
  }

  Widget _buildComparisonSummaryCard(BuildContext context, IncomeStatementWithComparison statement) {
    final theme = Theme.of(context);
    final previous = statement.previous!;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.compare_arrows,
                  size: 18,
                  color: theme.colorScheme.secondary,
                ),
                const SizedBox(width: 8),
                Text(
                  '与${statement.comparisonPeriodLabel}对比',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.secondary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Revenue change
            _buildComparisonRow(
              context,
              label: '收入变化',
              change: statement.revenueChange,
              changePercent: statement.revenueChangePercent,
              isPositiveGood: true,
            ),
            const SizedBox(height: 12),

            // Expense change
            _buildComparisonRow(
              context,
              label: '费用变化',
              change: statement.expenseChange,
              changePercent: statement.expenseChangePercent,
              isPositiveGood: false,
            ),
            const SizedBox(height: 12),

            // Net income change
            _buildComparisonRow(
              context,
              label: '净利变化',
              change: statement.netIncomeChange,
              changePercent: statement.netIncomeChangePercent,
              isPositiveGood: true,
              isHighlighted: true,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildComparisonRow(
    BuildContext context, {
    required String label,
    required Decimal change,
    required double? changePercent,
    required bool isPositiveGood,
    bool isHighlighted = false,
  }) {
    final theme = Theme.of(context);
    final isPositive = change > Decimal.zero;
    final isNegative = change < Decimal.zero;
    final isNeutral = change == Decimal.zero;

    Color getChangeColor() {
      if (isNeutral) return theme.colorScheme.outline;
      if (isPositive) {
        return isPositiveGood ? Colors.green : Colors.red;
      } else {
        return isPositiveGood ? Colors.red : Colors.green;
      }
    }

    final changeColor = getChangeColor();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: isHighlighted
            ? changeColor.withOpacity(0.1)
            : theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: isHighlighted ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
          Row(
            children: [
              Text(
                '${isPositive ? '+' : ''}${_formatDecimal(change)}',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: changeColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (changePercent != null) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: changeColor.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    '${isPositive ? '+' : ''}${changePercent.toStringAsFixed(1)}%',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: changeColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildNetIncomeCard(BuildContext context, IncomeStatement incomeStatement) {
    final theme = Theme.of(context);
    final isProfit = incomeStatement.isProfit;
    final isLoss = incomeStatement.isLoss;

    // Use theme colors - green for profit, red for loss
    final Color cardColor;
    final Color iconColor;
    final Color textColor;
    final IconData iconData;
    final String statusText;

    if (isProfit) {
      cardColor = theme.colorScheme.primaryContainer;
      iconColor = theme.colorScheme.primary;
      textColor = theme.colorScheme.onPrimaryContainer;
      iconData = Icons.trending_up;
      statusText = '盈利';
    } else if (isLoss) {
      cardColor = theme.colorScheme.errorContainer;
      iconColor = theme.colorScheme.error;
      textColor = theme.colorScheme.onErrorContainer;
      iconData = Icons.trending_down;
      statusText = '亏损';
    } else {
      cardColor = theme.colorScheme.surfaceContainerHighest;
      iconColor = theme.colorScheme.outline;
      textColor = theme.colorScheme.onSurfaceVariant;
      iconData = Icons.horizontal_rule;
      statusText = '持平';
    }

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12),
      color: cardColor,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // Header row
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  iconData,
                  size: 24,
                  color: iconColor,
                ),
                const SizedBox(width: 8),
                Text(
                  '净利润',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: textColor,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Amount
            Text(
              '¥${_formatDecimal(incomeStatement.netIncomeDecimal)}',
              style: theme.textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: textColor,
              ),
            ),

            const SizedBox(height: 8),

            // Status badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              decoration: BoxDecoration(
                color: iconColor.withOpacity(0.2),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                statusText,
                style: theme.textTheme.labelMedium?.copyWith(
                  color: iconColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),

            const SizedBox(height: 20),

            // Summary row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildSummaryItem(
                  context,
                  label: '收入合计',
                  amount: incomeStatement.grossProfit,
                  color: theme.colorScheme.primary,
                ),
                Container(
                  width: 1,
                  height: 40,
                  color: theme.colorScheme.outlineVariant,
                ),
                _buildSummaryItem(
                  context,
                  label: '费用合计',
                  amount: incomeStatement.totalExpenses,
                  color: theme.colorScheme.error,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryItem(
    BuildContext context, {
    required String label,
    required Decimal amount,
    required Color color,
  }) {
    final theme = Theme.of(context);

    return Column(
      children: [
        Text(
          label,
          style: theme.textTheme.labelMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '¥${_formatDecimal(amount)}',
          style: theme.textTheme.titleSmall?.copyWith(
            color: color,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return const EmptyStateWidget(
      icon: Icons.receipt_long_outlined,
      title: '暂无收支数据',
      subtitle: '请先添加收入和费用账户的交易记录',
    );
  }

  Widget _buildErrorState(BuildContext context, Object error) {
    return ErrorStateWidget(
      message: error.toString(),
      onRetry: _handleRefresh,
    );
  }

  String _formatDecimal(Decimal value) {
    final str = value.toString();
    if (str.contains('.')) {
      final parts = str.split('.');
      final decimal = parts[1].padRight(2, '0').substring(0, 2);
      return '${parts[0]}.$decimal';
    }
    return '$str.00';
  }
}

/// Export options bottom sheet for reports
class _ExportOptionsSheet extends ConsumerStatefulWidget {
  final String reportName;
  final DateTime? startDate;
  final DateTime? endDate;

  const _ExportOptionsSheet({
    required this.reportName,
    this.startDate,
    this.endDate,
  });

  @override
  ConsumerState<_ExportOptionsSheet> createState() => _ExportOptionsSheetState();
}

class _ExportOptionsSheetState extends ConsumerState<_ExportOptionsSheet> {
  bool _isExporting = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.download,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 12),
                Text(
                  '导出${widget.reportName}',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            if (_isExporting)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: CircularProgressIndicator(),
                ),
              )
            else
              Row(
                children: [
                  Expanded(
                    child: _ExportOptionButton(
                      icon: Icons.picture_as_pdf,
                      label: 'PDF',
                      color: Colors.red,
                      onTap: () => _exportToPDF(),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _ExportOptionButton(
                      icon: Icons.table_chart,
                      label: 'CSV',
                      color: Colors.green,
                      onTap: () => _exportToCSV(),
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _exportToPDF() async {
    setState(() => _isExporting = true);

    try {
      final exportService = ref.read(exportServiceProvider);
      final filters = ExportFilters(
        startDate: widget.startDate,
        endDate: widget.endDate,
      );

      final result = await exportService.exportTransactionsToPDF(filters: filters);

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('导出成功：${result.transactionCount} 条记录'),
            action: SnackBarAction(
              label: '分享',
              onPressed: () => Share.shareXFiles([XFile(result.filePath)]),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('导出失败: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  Future<void> _exportToCSV() async {
    setState(() => _isExporting = true);

    try {
      final exportService = ref.read(exportServiceProvider);
      final filters = ExportFilters(
        startDate: widget.startDate,
        endDate: widget.endDate,
      );

      final result = await exportService.exportTransactionsToCSV(filters: filters);

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('导出成功：${result.transactionCount} 条记录'),
            action: SnackBarAction(
              label: '分享',
              onPressed: () => Share.shareXFiles([XFile(result.filePath)]),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('导出失败: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }
}

/// Export option button widget
class _ExportOptionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ExportOptionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 32, color: color),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
