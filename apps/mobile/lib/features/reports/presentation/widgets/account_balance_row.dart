import 'package:flutter/material.dart';
import 'package:core/core.dart';
import 'package:decimal/decimal.dart';

/// Single account balance row widget for trial balance report.
///
/// Displays account name with debit/credit amounts and supports
/// hierarchical indentation for nested accounts.
class AccountBalanceRow extends StatelessWidget {
  final AccountBalance account;
  final int depth;
  final bool isExpanded;
  final VoidCallback? onToggleExpand;
  final bool showChildren;

  const AccountBalanceRow({
    super.key,
    required this.account,
    this.depth = 0,
    this.isExpanded = false,
    this.onToggleExpand,
    this.showChildren = true,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasChildren = account.children != null && account.children!.isNotEmpty;
    final indent = depth * 20.0;

    return InkWell(
      onTap: hasChildren ? onToggleExpand : null,
      child: Padding(
        padding: EdgeInsets.only(
          left: indent + 12,
          right: 12,
          top: 8,
          bottom: 8,
        ),
        child: Row(
          children: [
            // Expand/collapse icon for parent accounts
            if (hasChildren) ...[
              Icon(
                isExpanded ? Icons.expand_less : Icons.expand_more,
                size: 20,
                color: theme.colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 4),
            ] else ...[
              const SizedBox(width: 24),
            ],
            
            // Account name
            Expanded(
              flex: 3,
              child: Text(
                account.accountName,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: depth == 0 ? FontWeight.w600 : FontWeight.normal,
                  color: depth == 0 
                      ? theme.colorScheme.onSurface 
                      : theme.colorScheme.onSurfaceVariant,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            
            // Debit amount
            Expanded(
              flex: 2,
              child: _buildAmountCell(
                context,
                account.debitDecimal,
                isDebit: true,
                showZero: false,
              ),
            ),
            
            // Credit amount
            Expanded(
              flex: 2,
              child: _buildAmountCell(
                context,
                account.creditDecimal,
                isDebit: false,
                showZero: false,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAmountCell(
    BuildContext context,
    Decimal amount,
    {required bool isDebit, required bool showZero}
  ) {
    final theme = Theme.of(context);
    final isZero = amount == Decimal.zero;
    
    if (isZero && !showZero) {
      return const SizedBox.shrink();
    }
    
    final color = isDebit
        ? theme.colorScheme.primary
        : theme.colorScheme.secondary;
    
    return Text(
      '¥${_formatDecimal(amount)}',
      style: theme.textTheme.bodyMedium?.copyWith(
        color: color,
        fontWeight: FontWeight.w500,
      ),
      textAlign: TextAlign.right,
      overflow: TextOverflow.ellipsis,
    );
  }

  String _formatDecimal(Decimal value) {
    // Format with 2 decimal places
    final str = value.toString();
    if (str.contains('.')) {
      final parts = str.split('.');
      final decimal = parts[1].padRight(2, '0').substring(0, 2);
      return '${parts[0]}.$decimal';
    }
    return '$str.00';
  }
}
