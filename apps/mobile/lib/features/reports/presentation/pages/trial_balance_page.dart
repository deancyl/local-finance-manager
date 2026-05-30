import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:core/core.dart';
import 'package:share_plus/share_plus.dart';

import '../../data/trial_balance_provider.dart';
import '../widgets/account_type_section.dart';
import '../widgets/balance_summary_card.dart';
import '../../../export/data/export_service.dart';
import '../../../export/data/export_provider.dart';
import '../../../print/data/print_provider.dart';
import '../../../accounts/data/account_provider.dart';
import '../mixins/drill_down_mixin.dart';
import '../../../../core/widgets/loading_state_widget.dart';
import '../../../../core/widgets/empty_state_widget.dart';
import '../../../../core/widgets/error_state_widget.dart';
import '../../../../core/widgets/loading_state_widget.dart';
import '../../../../core/widgets/empty_state_widget.dart';
import '../../../../core/widgets/error_state_widget.dart';

/// Trial balance report page with date range filtering.
///
/// Displays accounts grouped by type (资产/负债/权益/收入/费用)
/// with debit/credit amounts and balance verification.
class TrialBalancePage extends ConsumerStatefulWidget {
  const TrialBalancePage({super.key});

  @override
  ConsumerState<TrialBalancePage> createState() => _TrialBalancePageState();
}

class _TrialBalancePageState extends ConsumerState<TrialBalancePage> 
    with DrillDownMixin {
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
    await ref.read(trialBalanceProvider.notifier).setDateRange(_startDate, _endDate);
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
    await ref.read(trialBalanceProvider.notifier).refresh();
  }

  void _handleExport() {
    final trialBalance = ref.read(trialBalanceProvider).valueOrNull;
    if (trialBalance == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请先加载数据')),
      );
      return;
    }
    showModalBottomSheet<void>(
      context: context,
      builder: (context) => _ExportOptionsSheet(
        reportName: '试算平衡表',
        trialBalance: trialBalance,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final trialBalanceAsync = ref.watch(trialBalanceProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('试算平衡表'),
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
            child: trialBalanceAsync.when(
              data: (trialBalance) {
                if (trialBalance == null || trialBalance.accounts.isEmpty) {
                  return EmptyStateWidget.reports(
                    onRetry: _handleRefresh,
                  );
                }
                return _buildContent(context, trialBalance);
              },
              loading: () => const LoadingStateWidget.page(
                message: '加载中...',
              ),
              error: (error, stack) => ErrorStateWidget.fromError(
                error: error,
                stackTrace: stack,
                onRetry: _handleRefresh,
              ),
            ),
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

  Widget _buildContent(BuildContext context, TrialBalance trialBalance) {
    if (trialBalance.accounts.isEmpty) {
      return _buildEmptyState(context);
    }

    // Group accounts by type
    final accountsByType = <AccountType, List<AccountBalance>>{};
    for (final account in trialBalance.accounts) {
      accountsByType.putIfAbsent(account.accountType, () => []).add(account);
    }

    // Define display order
    const typeOrder = [
      AccountType.asset,
      AccountType.liability,
      AccountType.equity,
      AccountType.income,
      AccountType.expense,
    ];

    return RefreshIndicator(
      onRefresh: _handleRefresh,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.only(top: 12, bottom: 12),
        child: Column(
          children: [
            // Account type sections
            ...typeOrder.map((type) {
              final accounts = accountsByType[type];
              if (accounts == null || accounts.isEmpty) {
                return const SizedBox.shrink();
              }
              return AccountTypeSection(
                accountType: type,
                accounts: accounts,
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
              );
            }),
            
            const SizedBox(height: 12),
            
            // Summary card
            BalanceSummaryCard.fromTrialBalance(trialBalance),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return const EmptyStateWidget.reports();
  }

  Widget _buildErrorState(BuildContext context, Object error) {
    return ErrorStateWidget(
      message: error.toString(),
      onRetry: _handleRefresh,
    );
  }
}

/// Export options bottom sheet for reports
class _ExportOptionsSheet extends ConsumerStatefulWidget {
  final String reportName;
  final TrialBalance trialBalance;

  const _ExportOptionsSheet({
    required this.reportName,
    required this.trialBalance,
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
      final pdfService = ref.read(pdfExportServiceProvider);
      final result = await pdfService.exportTrialBalanceToPDF(
        trialBalance: widget.trialBalance,
      );

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('导出成功：${result.accountCount} 个账户'),
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
      final result = await exportService.exportTrialBalanceToCSV(
        trialBalance: widget.trialBalance,
      );

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('导出成功：${result.accountCount} 个账户'),
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
