import 'package:flutter/material.dart';
import 'package:core/core.dart';
import 'package:decimal/decimal.dart';

/// Balance verification card widget for balance sheet report.
///
/// Displays the accounting equation verification:
/// - 资产总计 (Total Assets)
/// - 负债合计 (Total Liabilities)
/// - 权益合计 (Total Equity)
/// - Balance status (资产 = 负债 + 权益)
/// - Color-coded (green for balanced, red for unbalanced)
class BalanceVerificationCard extends StatelessWidget {
  final Decimal totalAssets;
  final Decimal totalLiabilities;
  final Decimal totalEquity;
  final bool isBalanced;

  const BalanceVerificationCard({
    super.key,
    required this.totalAssets,
    required this.totalLiabilities,
    required this.totalEquity,
    required this.isBalanced,
  });

  factory BalanceVerificationCard.fromBalanceSheet(BalanceSheet balanceSheet) {
    return BalanceVerificationCard(
      totalAssets: balanceSheet.assets.totalDecimal,
      totalLiabilities: balanceSheet.liabilities.totalDecimal,
      totalEquity: balanceSheet.equity.totalDecimal,
      isBalanced: balanceSheet.isBalanced,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final statusColor = isBalanced ? Colors.green : Colors.red;
    final difference = (totalAssets - (totalLiabilities + totalEquity)).abs();

    return Card(
      margin: const EdgeInsets.all(12),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: LinearGradient(
            colors: [
              statusColor.withOpacity(0.1),
              statusColor.withOpacity(0.05),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header row
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      isBalanced ? Icons.check_circle : Icons.error,
                      color: statusColor,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '资产负债表验证',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          isBalanced ? '资产 = 负债 + 权益' : '会计等式不平衡',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: statusColor,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Status badge
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: statusColor,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          isBalanced ? Icons.check : Icons.close,
                          color: Colors.white,
                          size: 14,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          isBalanced ? '平衡' : '不平衡',
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 20),

              // Three totals row
              Row(
                children: [
                  // Total Assets
                  Expanded(
                    child: _buildTotalCard(
                      context,
                      label: '资产总计',
                      amount: totalAssets,
                      color: Colors.green,
                      icon: Icons.account_balance_wallet,
                    ),
                  ),

                  const SizedBox(width: 8),

                  // Total Liabilities
                  Expanded(
                    child: _buildTotalCard(
                      context,
                      label: '负债合计',
                      amount: totalLiabilities,
                      color: Colors.red,
                      icon: Icons.credit_card,
                    ),
                  ),

                  const SizedBox(width: 8),

                  // Total Equity
                  Expanded(
                    child: _buildTotalCard(
                      context,
                      label: '权益合计',
                      amount: totalEquity,
                      color: Colors.purple,
                      icon: Icons.pie_chart,
                    ),
                  ),
                ],
              ),

              // Equation verification
              const SizedBox(height: 16),
              _buildEquationRow(context),

              // Difference row (only show if unbalanced)
              if (!isBalanced) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: Colors.red.withOpacity(0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.warning_amber,
                        color: Colors.red,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '差额: ¥${_formatDecimal(difference)}',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: Colors.red,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const Spacer(),
                      TextButton(
                        onPressed: () {
                          // TODO: Navigate to difference detail
                        },
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.red,
                        ),
                        child: const Text('查看详情'),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTotalCard(
    BuildContext context, {
    required String label,
    required Decimal amount,
    required Color color,
    required IconData icon,
  }) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: color.withOpacity(0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                icon,
                color: color,
                size: 14,
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  label,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: color,
                    fontWeight: FontWeight.w500,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            '¥${_formatDecimal(amount)}',
            style: theme.textTheme.titleSmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEquationRow(BuildContext context) {
    final theme = Theme.of(context);
    final statusColor = isBalanced ? Colors.green : Colors.red;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.5),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Assets
          _buildEquationItem(
            context,
            label: '资产',
            value: totalAssets,
            color: Colors.green,
          ),

          const SizedBox(width: 8),

          // Equals sign
          Text(
            '=',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: statusColor,
            ),
          ),

          const SizedBox(width: 8),

          // Liabilities
          _buildEquationItem(
            context,
            label: '负债',
            value: totalLiabilities,
            color: Colors.red,
          ),

          const SizedBox(width: 8),

          // Plus sign
          Text(
            '+',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),

          const SizedBox(width: 8),

          // Equity
          _buildEquationItem(
            context,
            label: '权益',
            value: totalEquity,
            color: Colors.purple,
          ),
        ],
      ),
    );
  }

  Widget _buildEquationItem(
    BuildContext context, {
    required String label,
    required Decimal value,
    required Color color,
  }) {
    final theme = Theme.of(context);

    return Expanded(
      child: Column(
        children: [
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            '¥${_formatDecimal(value)}',
            style: theme.textTheme.bodySmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w600,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ],
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
