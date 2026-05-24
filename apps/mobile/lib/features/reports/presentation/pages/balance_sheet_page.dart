import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:core/core.dart';
import 'package:share_plus/share_plus.dart';

import '../../data/balance_sheet_provider.dart';
import '../../data/currency_conversion_service.dart';
import '../../../currency/data/currency_provider.dart';
import '../widgets/balance_sheet_section.dart';
import '../widgets/balance_verification_card.dart';
import '../../../export/data/export_service.dart';
import '../../../export/data/export_provider.dart';

/// Balance sheet report page with as-of date selection.
///
/// Displays the balance sheet showing:
/// - Assets (资产)
/// - Liabilities (负债)
/// - Equity (所有者权益)
/// - Balance verification (资产 = 负债 + 权益)
class BalanceSheetPage extends ConsumerStatefulWidget {
  const BalanceSheetPage({super.key});

  @override
  ConsumerState<BalanceSheetPage> createState() => _BalanceSheetPageState();
}

class _BalanceSheetPageState extends ConsumerState<BalanceSheetPage> {
  late DateTime _asOfDate;

  @override
  void initState() {
    super.initState();
    // Set default as-of date to today
    _asOfDate = DateTime.now();
    
    // Load initial data
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadData();
    });
  }

  Future<void> _loadData() async {
    await ref.read(balanceSheetProvider.notifier).setAsOfDate(_asOfDate);
  }

  Future<void> _selectAsOfDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _asOfDate,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
      locale: const Locale('zh', 'CN'),
    );

    if (picked != null) {
      setState(() {
        _asOfDate = DateTime(picked.year, picked.month, picked.day, 23, 59, 59, 999);
      });
      await _loadData();
    }
  }

  Future<void> _handleRefresh() async {
    await ref.read(balanceSheetProvider.notifier).refresh();
  }

  void _handleExport() {
    showModalBottomSheet<void>(
      context: context,
      builder: (context) => _ExportOptionsSheet(
        reportName: '资产负债表',
        startDate: null, // Balance sheet uses as-of date, not range
        endDate: _asOfDate,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final balanceSheetAsync = ref.watch(balanceSheetProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('资产负债表'),
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
          // As-of date selector
          _buildAsOfDateSelector(context),
          
          // Content
          Expanded(
            child: balanceSheetAsync.when(
              data: (balanceSheet) {
                if (balanceSheet == null) {
                  return _buildEmptyState(context);
                }
                return _buildContent(context, balanceSheet);
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, stack) => _buildErrorState(context, error),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAsOfDateSelector(BuildContext context) {
    final theme = Theme.of(context);
    final dateFormat = DateFormat('yyyy-MM-dd');
    final currencies = ref.watch(currenciesProvider);
    final selectedCurrency = ref.watch(reportCurrencyProvider);

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
          // Date selector row
          Row(
            children: [
              Icon(
                Icons.calendar_today,
                size: 20,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Text(
                '截止日期',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          InkWell(
            onTap: _selectAsOfDate,
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
                    Icons.event,
                    size: 16,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    dateFormat.format(_asOfDate),
                    style: theme.textTheme.bodyMedium,
                  ),
                  const Spacer(),
                  Icon(
                    Icons.arrow_drop_down,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ],
              ),
            ),
          ),
          
          // Currency selector row
          const SizedBox(height: 16),
          Row(
            children: [
              Icon(
                Icons.currency_exchange,
                size: 20,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Text(
                '报表币种',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: theme.colorScheme.outline,
              ),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: selectedCurrency,
                isExpanded: true,
                items: currencies.map((currency) {
                  return DropdownMenuItem(
                    value: currency.id,
                    child: Text('${currency.mnemonic} - ${currency.fullName ?? currency.id}'),
                  );
                }).toList(),
                onChanged: (value) {
                  if (value != null) {
                    ref.read(balanceSheetProvider.notifier).setCurrency(value);
                  }
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(BuildContext context, BalanceSheet balanceSheet) {
    if (balanceSheet.assets.items.isEmpty &&
        balanceSheet.liabilities.items.isEmpty &&
        balanceSheet.equity.items.isEmpty) {
      return _buildEmptyState(context);
    }

    return RefreshIndicator(
      onRefresh: _handleRefresh,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.only(top: 12, bottom: 12),
        child: Column(
          children: [
            // Assets section
            if (balanceSheet.assets.items.isNotEmpty)
              BalanceSheetSectionWidget(
                section: balanceSheet.assets,
                sectionType: AccountType.asset,
                initiallyExpanded: true,
              ),
            
            // Liabilities section
            if (balanceSheet.liabilities.items.isNotEmpty)
              BalanceSheetSectionWidget(
                section: balanceSheet.liabilities,
                sectionType: AccountType.liability,
                initiallyExpanded: true,
              ),
            
            // Equity section
            if (balanceSheet.equity.items.isNotEmpty)
              BalanceSheetSectionWidget(
                section: balanceSheet.equity,
                sectionType: AccountType.equity,
                initiallyExpanded: true,
              ),
            
            const SizedBox(height: 12),
            
            // Balance verification card
            BalanceVerificationCard.fromBalanceSheet(balanceSheet),
          ],
        ),
      ),
    );
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
            '暂无资产负债数据',
            style: theme.textTheme.titleMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '请先添加资产、负债或权益账户',
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
