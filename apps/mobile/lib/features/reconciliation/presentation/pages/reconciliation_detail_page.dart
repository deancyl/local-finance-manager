import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:core/core.dart';
import 'package:database/database.dart' hide Account;

/// Page showing details of a completed reconciliation.
/// 
/// Features:
/// - List of reconciled transactions
/// - Summary of reconciliation (date, balance, count)
/// - Export button (placeholder for future implementation)
class ReconciliationDetailPage extends StatelessWidget {
  final Map<String, dynamic> reconciliationData;

  const ReconciliationDetailPage({
    super.key,
    required this.reconciliationData,
  });

  @override
  Widget build(BuildContext context) {
    final reconcileDate = DateTime.fromMillisecondsSinceEpoch(
      reconciliationData['reconcileDate'] as int,
    );
    final accountName = reconciliationData['accountName'] as String;
    final totalNum = reconciliationData['totalNum'] as int;
    final totalDenom = reconciliationData['totalDenom'] as int;
    final total = totalNum / totalDenom.toDouble();
    final splits = reconciliationData['splits'] as List;

    final dateFormat = DateFormat('yyyy-MM-dd');
    final currencyFormat = NumberFormat.currency(symbol: '¥', decimalDigits: 2);

    return Scaffold(
      appBar: AppBar(
        title: const Text('对账详情'),
        actions: [
          IconButton(
            icon: const Icon(Icons.download),
            tooltip: '导出报告',
            onPressed: () => _showExportDialog(context),
          ),
        ],
      ),
      body: Column(
        children: [
          // Summary card
          _buildSummaryCard(
            context,
            reconcileDate: reconcileDate,
            accountName: accountName,
            total: total,
            transactionCount: splits.length,
            dateFormat: dateFormat,
            currencyFormat: currencyFormat,
          ),

          // Transactions list
          Expanded(
            child: _buildTransactionsList(
              context,
              splits: splits,
              dateFormat: dateFormat,
              currencyFormat: currencyFormat,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard(
    BuildContext context, {
    required DateTime reconcileDate,
    required String accountName,
    required double total,
    required int transactionCount,
    required DateFormat dateFormat,
    required NumberFormat currencyFormat,
  }) {
    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.check_circle,
                  color: Colors.green,
                  size: 32,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '对账完成',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: Colors.green,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '日期: ${dateFormat.format(reconcileDate)}',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const Divider(height: 24),
            _buildSummaryRow(
              context,
              label: '账户',
              value: accountName,
              icon: Icons.account_balance_wallet,
            ),
            const SizedBox(height: 12),
            _buildSummaryRow(
              context,
              label: '对账余额',
              value: currencyFormat.format(total),
              icon: Icons.account_balance,
              valueColor: total >= 0 ? Colors.green : Theme.of(context).colorScheme.error,
            ),
            const SizedBox(height: 12),
            _buildSummaryRow(
              context,
              label: '交易笔数',
              value: '$transactionCount 笔',
              icon: Icons.receipt_long,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryRow(
    BuildContext context, {
    required String label,
    required String value,
    required IconData icon,
    Color? valueColor,
  }) {
    return Row(
      children: [
        Icon(
          icon,
          size: 20,
          color: Theme.of(context).colorScheme.primary,
        ),
        const SizedBox(width: 12),
        Text(
          label,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        const Spacer(),
        Text(
          value,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            color: valueColor,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildTransactionsList(
    BuildContext context, {
    required List splits,
    required DateFormat dateFormat,
    required NumberFormat currencyFormat,
  }) {
    if (splits.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.receipt_long_outlined,
              size: 48,
              color: Theme.of(context).colorScheme.outline,
            ),
            const SizedBox(height: 16),
            Text(
              '没有交易记录',
              style: Theme.of(context).textTheme.bodyLarge,
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: Text(
            '已对账交易',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: splits.length,
            itemBuilder: (context, index) {
              final split = splits[index] as Map<String, dynamic>;
              return _buildTransactionTile(
                context,
                split: split,
                dateFormat: dateFormat,
                currencyFormat: currencyFormat,
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildTransactionTile(
    BuildContext context, {
    required Map<String, dynamic> split,
    required DateFormat dateFormat,
    required NumberFormat currencyFormat,
  }) {
    final postDate = DateTime.fromMillisecondsSinceEpoch(split['postDate'] as int);
    final valueNum = split['valueNum'] as int;
    final valueDenom = split['valueDenom'] as int? ?? 1;
    final value = valueNum / valueDenom.toDouble();
    final description = split['description'] as String?;
    final memo = split['memo'] as String?;

    return ListTile(
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: value >= 0
              ? Colors.green.withOpacity(0.1)
              : Theme.of(context).colorScheme.error.withOpacity(0.1),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Icon(
          value >= 0 ? Icons.arrow_downward : Icons.arrow_upward,
          color: value >= 0 ? Colors.green : Theme.of(context).colorScheme.error,
        ),
      ),
      title: Text(
        description ?? '无描述',
        style: Theme.of(context).textTheme.bodyLarge,
      ),
      subtitle: Text(
        '${dateFormat.format(postDate)}${memo != null && memo.isNotEmpty ? ' · $memo' : ''}',
        style: Theme.of(context).textTheme.bodySmall,
      ),
      trailing: Text(
        currencyFormat.format(value),
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
          color: value >= 0 ? Colors.green : Theme.of(context).colorScheme.error,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  void _showExportDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('导出对账报告'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('选择导出格式:'),
            SizedBox(height: 16),
            Text(
              '• PDF 格式 - 适合打印和存档',
              style: TextStyle(fontSize: 14),
            ),
            SizedBox(height: 8),
            Text(
              '• CSV 格式 - 适合数据分析',
              style: TextStyle(fontSize: 14),
            ),
            SizedBox(height: 8),
            Text(
              '• Excel 格式 - 适合进一步编辑',
              style: TextStyle(fontSize: 14),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          FilledButton.icon(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('导出功能即将推出'),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
            icon: const Icon(Icons.download),
            label: const Text('导出'),
          ),
        ],
      ),
    );
  }
}
