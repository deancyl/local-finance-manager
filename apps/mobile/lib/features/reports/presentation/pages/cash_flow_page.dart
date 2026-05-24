import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:decimal/decimal.dart';
import 'package:core/core.dart';
import 'package:share_plus/share_plus.dart';

import '../../data/cash_flow_provider.dart';
import '../../../export/data/export_service.dart';
import '../../../export/data/export_provider.dart';

/// Cash flow statement report page with date range filtering.
///
/// Displays operating, investing, and financing activities sections
/// with net cash flow calculation and reconciliation.
/// Supports pull-to-refresh and date range selection.
class CashFlowPage extends ConsumerStatefulWidget {
  const CashFlowPage({super.key});

  @override
  ConsumerState<CashFlowPage> createState() => _CashFlowPageState();
}

class _CashFlowPageState extends ConsumerState<CashFlowPage> {
  DateTime? _startDate;
  DateTime? _endDate;

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
    await ref.read(cashFlowStatementProvider.notifier).setDateRange(_startDate, _endDate);
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

  Future<void> _handleRefresh() async {
    await ref.read(cashFlowStatementProvider.notifier).refresh();
  }

  void _handleExport() {
    showModalBottomSheet<void>(
      context: context,
      builder: (context) => _ExportOptionsSheet(
        reportName: '现金流量表',
        startDate: _startDate,
        endDate: _endDate,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cashFlowAsync = ref.watch(cashFlowStatementProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('现金流量表'),
        actions: [
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

          // Content
          Expanded(
            child: cashFlowAsync.when(
              data: (cashFlow) {
                if (cashFlow == null) {
                  return _buildEmptyState(context);
                }
                return _buildContent(context, cashFlow);
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, stack) => _buildErrorState(context, error),
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
                '日期范围',
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

  Widget _buildContent(BuildContext context, CashFlowStatement cashFlow) {
    final hasData = cashFlow.operating.items.isNotEmpty ||
        cashFlow.investing.items.isNotEmpty ||
        cashFlow.financing.items.isNotEmpty;

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
            // Operating activities section
            _buildSectionCard(context, cashFlow.operating, Colors.blue),

            // Investing activities section
            _buildSectionCard(context, cashFlow.investing, Colors.orange),

            // Financing activities section
            _buildSectionCard(context, cashFlow.financing, Colors.purple),

            const SizedBox(height: 12),

            // Reconciliation card
            _buildReconciliationCard(context, cashFlow),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionCard(BuildContext context, CashFlowSection section, Color color) {
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Column(
        children: [
          // Section header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: color.withOpacity(0.08),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
            ),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    _getSectionIcon(section.activityType),
                    color: color,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    section.title,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: color,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    '¥${_formatDecimal(section.netCashFlowDecimal)}',
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: color,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Items list
          if (section.items.isNotEmpty) ...[
            // Header row
            _buildHeaderRow(context),

            // Item rows
            ...section.items.map((item) => _buildItemRow(context, item, color)),

            // Summary row
            _buildSectionSummaryRow(context, section, color),
          ],
        ],
      ),
    );
  }

  Widget _buildHeaderRow(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.5),
      ),
      child: Row(
        children: [
          const SizedBox(width: 24),
          Expanded(
            flex: 3,
            child: Text(
              '项目名称',
              style: theme.textTheme.labelMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              '金额',
              style: theme.textTheme.labelMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildItemRow(BuildContext context, CashFlowItem item, Color sectionColor) {
    final theme = Theme.of(context);
    final itemColor = item.isInflow ? Colors.green : Colors.red;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          // Inflow/Outflow indicator
          Icon(
            item.isInflow ? Icons.add_circle_outline : Icons.remove_circle_outline,
            size: 18,
            color: itemColor,
          ),
          const SizedBox(width: 8),

          // Account name
          Expanded(
            flex: 3,
            child: Text(
              item.name,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),

          // Amount
          Expanded(
            flex: 2,
            child: Text(
              '¥${_formatDecimal(item.amountDecimal)}',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: itemColor,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionSummaryRow(BuildContext context, CashFlowSection section, Color color) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        border: Border(
          top: BorderSide(
            color: color.withOpacity(0.3),
            width: 2,
          ),
        ),
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(12)),
      ),
      child: Column(
        children: [
          // Inflows and outflows summary
          Row(
            children: [
              Expanded(
                child: _buildSummaryItem(
                  context,
                  label: '现金流入',
                  amount: section.totalInflowDecimal,
                  color: Colors.green,
                ),
              ),
              Container(
                width: 1,
                height: 40,
                color: theme.colorScheme.outlineVariant,
              ),
              Expanded(
                child: _buildSummaryItem(
                  context,
                  label: '现金流出',
                  amount: section.totalOutflowDecimal,
                  color: Colors.red,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Net cash flow
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                section.isPositiveNetFlow ? Icons.trending_up : Icons.trending_down,
                size: 20,
                color: color,
              ),
              const SizedBox(width: 8),
              Text(
                '净现金流: ',
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
              Text(
                '¥${_formatDecimal(section.netCashFlowDecimal)}',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
            ],
          ),
        ],
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

  Widget _buildReconciliationCard(BuildContext context, CashFlowStatement cashFlow) {
    final theme = Theme.of(context);
    final isPositive = cashFlow.isPositiveNetChange;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12),
      color: isPositive
          ? theme.colorScheme.primaryContainer
          : theme.colorScheme.errorContainer,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.account_balance_wallet,
                  size: 24,
                  color: isPositive
                      ? theme.colorScheme.primary
                      : theme.colorScheme.error,
                ),
                const SizedBox(width: 8),
                Text(
                  '现金及现金等价物净增加额',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: isPositive
                        ? theme.colorScheme.onPrimaryContainer
                        : theme.colorScheme.onErrorContainer,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Net change amount
            Text(
              '¥${_formatDecimal(cashFlow.netChangeInCashDecimal)}',
              style: theme.textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: isPositive
                    ? theme.colorScheme.onPrimaryContainer
                    : theme.colorScheme.onErrorContainer,
              ),
            ),

            const SizedBox(height: 20),

            // Reconciliation details
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: theme.colorScheme.surface.withOpacity(0.5),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  _buildReconciliationRow(
                    context,
                    label: '期初现金余额',
                    amount: cashFlow.beginningCashDecimal,
                  ),
                  const Divider(height: 24),
                  _buildReconciliationRow(
                    context,
                    label: '经营活动净现金流',
                    amount: cashFlow.operating.netCashFlowDecimal,
                    isSubItem: true,
                  ),
                  _buildReconciliationRow(
                    context,
                    label: '投资活动净现金流',
                    amount: cashFlow.investing.netCashFlowDecimal,
                    isSubItem: true,
                  ),
                  _buildReconciliationRow(
                    context,
                    label: '筹资活动净现金流',
                    amount: cashFlow.financing.netCashFlowDecimal,
                    isSubItem: true,
                  ),
                  const Divider(height: 24),
                  _buildReconciliationRow(
                    context,
                    label: '期末现金余额',
                    amount: cashFlow.endingCashDecimal,
                    isTotal: true,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReconciliationRow(
    BuildContext context, {
    required String label,
    required Decimal amount,
    bool isSubItem = false,
    bool isTotal = false,
  }) {
    final theme = Theme.of(context);

    return Padding(
      padding: EdgeInsets.only(
        left: isSubItem ? 16 : 0,
        bottom: isTotal ? 0 : 8,
      ),
      child: Row(
        children: [
          if (isSubItem) ...[
            Icon(
              Icons.subdirectory_arrow_right,
              size: 16,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 4),
          ],
          Expanded(
            child: Text(
              label,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: isTotal ? FontWeight.w600 : FontWeight.normal,
                color: isTotal
                    ? theme.colorScheme.primary
                    : theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Text(
            '¥${_formatDecimal(amount)}',
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: isTotal ? FontWeight.w600 : FontWeight.w500,
              color: isTotal
                  ? theme.colorScheme.primary
                  : theme.colorScheme.onSurface,
            ),
          ),
        ],
      ),
    );
  }

  IconData _getSectionIcon(CashFlowActivityType type) {
    switch (type) {
      case CashFlowActivityType.operating:
        return Icons.business_center;
      case CashFlowActivityType.investing:
        return Icons.trending_up;
      case CashFlowActivityType.financing:
        return Icons.account_balance;
    }
  }

  Widget _buildEmptyState(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.account_balance_wallet_outlined,
            size: 64,
            color: theme.colorScheme.outline,
          ),
          const SizedBox(height: 16),
          Text(
            '暂无现金流量数据',
            style: theme.textTheme.titleMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '请先添加交易记录以生成现金流量表',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.outline,
            ),
          ),
        ],
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
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _handleRefresh,
              icon: const Icon(Icons.refresh),
              label: const Text('重试'),
            ),
          ],
        ),
      ),
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
