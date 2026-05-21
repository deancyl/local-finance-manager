import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../data/period_closing_provider.dart';

/// Period closing workflow page for managing fiscal period closing.
///
/// Features:
/// - Current period status display
/// - Close period action with confirmation
/// - Closed periods history
/// - Reopen functionality
class PeriodClosingPage extends ConsumerStatefulWidget {
  const PeriodClosingPage({super.key});

  @override
  ConsumerState<PeriodClosingPage> createState() => _PeriodClosingPageState();
}

class _PeriodClosingPageState extends ConsumerState<PeriodClosingPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(periodClosingNotifierProvider.notifier).refresh();
    });
  }

  Future<void> _handleClosePeriod(FiscalPeriod period) async {
    final confirmed = await _showCloseConfirmationDialog(period);
    if (!confirmed || !mounted) return;

    final success = await ref.read(periodClosingNotifierProvider.notifier).closePeriod(period);
    if (success && mounted) {
      _showSuccessSnackBar('期间 ${period.displayName} 已成功结账');
    }
  }

  Future<void> _handleReopenPeriod(FiscalPeriod period) async {
    final confirmed = await _showReopenConfirmationDialog(period);
    if (!confirmed || !mounted) return;

    final success = await ref.read(periodClosingNotifierProvider.notifier).reopenPeriod(period);
    if (success && mounted) {
      _showSuccessSnackBar('期间 ${period.displayName} 已重新开启');
    }
  }

  Future<bool> _showCloseConfirmationDialog(FiscalPeriod period) async {
    return await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认结账'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('确定要关闭期间 ${period.displayName} 吗？'),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '结账将执行以下操作：',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  _buildStepItem('1. 将收入账户余额结转至损益汇总'),
                  _buildStepItem('2. 将费用账户余额结转至损益汇总'),
                  _buildStepItem('3. 将损益汇总结转至留存收益'),
                  _buildStepItem('4. 将股利账户结转至留存收益'),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Text(
              '注意：结账后该期间的交易将无法修改。',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.error,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('确认结账'),
          ),
        ],
      ),
    ) ?? false;
  }

  Future<bool> _showReopenConfirmationDialog(FiscalPeriod period) async {
    return await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认重新开启'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('确定要重新开启期间 ${period.displayName} 吗？'),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.errorContainer,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.warning_amber,
                    color: Theme.of(context).colorScheme.onErrorContainer,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      '重新开启将删除该期间的所有结账分录。',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onErrorContainer,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('确认重新开启'),
          ),
        ],
      ),
    ) ?? false;
  }

  Widget _buildStepItem(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              text,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Theme.of(context).colorScheme.primary,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Theme.of(context).colorScheme.error,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(periodClosingNotifierProvider);

    // Show error if any
    ref.listen<PeriodClosingState>(periodClosingNotifierProvider, (prev, next) {
      if (next.error != null && next.error != prev?.error) {
        _showErrorSnackBar(next.error!);
        ref.read(periodClosingNotifierProvider.notifier).clearMessages();
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: const Text('期间结账'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.read(periodClosingNotifierProvider.notifier).refresh(),
            tooltip: '刷新',
          ),
        ],
      ),
      body: state.isLoading
          ? const Center(child: CircularProgressIndicator())
          : _buildContent(context, state),
    );
  }

  Widget _buildContent(BuildContext context, PeriodClosingState state) {
    return RefreshIndicator(
      onRefresh: () => ref.read(periodClosingNotifierProvider.notifier).refresh(),
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Current period status
            _buildCurrentPeriodCard(context, state),
            const SizedBox(height: 24),

            // Closed periods history
            _buildClosedPeriodsSection(context, state),
          ],
        ),
      ),
    );
  }

  Widget _buildCurrentPeriodCard(BuildContext context, PeriodClosingState state) {
    final theme = Theme.of(context);
    final currentPeriod = state.currentOpenPeriod;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: theme.colorScheme.outlineVariant,
          width: 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.calendar_month,
                    color: theme.colorScheme.onPrimaryContainer,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '当前期间',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        currentPeriod?.displayName ?? '无开放期间',
                        style: theme.textTheme.headlineSmall?.copyWith(
                          color: theme.colorScheme.primary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Period details
            if (currentPeriod != null) ...[
              _buildDetailRow(
                context,
                '状态',
                '开放',
                Icons.lock_open,
                theme.colorScheme.primary,
              ),
              const SizedBox(height: 12),
              _buildDetailRow(
                context,
                '日期范围',
                '${DateFormat('yyyy-MM-dd').format(currentPeriod.startDate)} 至 ${DateFormat('yyyy-MM-dd').format(currentPeriod.endDate)}',
                Icons.date_range,
                theme.colorScheme.onSurfaceVariant,
              ),
              const SizedBox(height: 24),

              // Close period button
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () => _handleClosePeriod(currentPeriod),
                  icon: const Icon(Icons.lock),
                  label: const Text('结账'),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ] else ...[
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Icon(
                        Icons.check_circle_outline,
                        size: 48,
                        color: theme.colorScheme.outline,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        '所有期间已结账',
                        style: theme.textTheme.bodyLarge?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(
    BuildContext context,
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    final theme = Theme.of(context);

    return Row(
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 12),
        Text(
          '$label: ',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildClosedPeriodsSection(BuildContext context, PeriodClosingState state) {
    final theme = Theme.of(context);
    final closedPeriods = state.closedPeriods;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.history,
              color: theme.colorScheme.primary,
              size: 20,
            ),
            const SizedBox(width: 8),
            Text(
              '已结账期间',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const Spacer(),
            Text(
              '共 ${closedPeriods.length} 个',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        if (closedPeriods.isEmpty)
          Card(
            elevation: 0,
            color: theme.colorScheme.surfaceContainerHighest,
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Center(
                child: Text(
                  '暂无已结账期间',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ),
          )
        else
          ...closedPeriods.map((period) => _buildClosedPeriodCard(context, period)),
      ],
    );
  }

  Widget _buildClosedPeriodCard(BuildContext context, FiscalPeriod period) {
    final theme = Theme.of(context);
    final dateFormat = DateFormat('yyyy-MM-dd HH:mm');

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: theme.colorScheme.outlineVariant,
          width: 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.lock,
                size: 20,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    period.displayName,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    period.closedAt != null
                        ? '结账于 ${dateFormat.format(period.closedAt!)}'
                        : '已结账',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            // Reopen button
            IconButton(
              onPressed: () => _handleReopenPeriod(period),
              icon: const Icon(Icons.lock_open),
              tooltip: '重新开启',
              style: IconButton.styleFrom(
                foregroundColor: theme.colorScheme.error,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
