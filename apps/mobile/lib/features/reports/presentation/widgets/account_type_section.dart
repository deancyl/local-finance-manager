import 'package:flutter/material.dart';
import 'package:core/core.dart';
import 'package:decimal/decimal.dart';
import 'account_balance_row.dart';

/// Account type section widget for trial balance report.
///
/// Groups accounts by type (资产类/负债类/权益类/收入类/费用类)
/// with expandable/collapsible functionality and subtotals.
class AccountTypeSection extends StatefulWidget {
  final AccountType accountType;
  final List<AccountBalance> accounts;
  final bool initiallyExpanded;
  final DateTime? startDate;
  final DateTime? endDate;
  final void Function(String accountId, String accountName)? onDrillDown;

  const AccountTypeSection({
    super.key,
    required this.accountType,
    required this.accounts,
    this.initiallyExpanded = true,
    this.startDate,
    this.endDate,
    this.onDrillDown,
  });

  @override
  State<AccountTypeSection> createState() => _AccountTypeSectionState();
}

class _AccountTypeSectionState extends State<AccountTypeSection> {
  late bool _isExpanded;
  final Map<String, bool> _expandedAccounts = {};

  @override
  void initState() {
    super.initState();
    _isExpanded = widget.initiallyExpanded;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = _getTypeColor(theme);
    final typeLabel = widget.accountType.labelZh;
    final (totalDebit, totalCredit) = _calculateSubtotals();

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Column(
        children: [
          // Section header
          InkWell(
            onTap: () => setState(() => _isExpanded = !_isExpanded),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: color.withOpacity(0.08),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
              ),
              child: Row(
                children: [
                  // Expand/collapse icon
                  Icon(
                    _isExpanded ? Icons.expand_less : Icons.expand_more,
                    color: color,
                  ),
                  const SizedBox(width: 8),
                  
                  // Type icon
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      _getTypeIcon(),
                      color: color,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  
                  // Type name
                  Expanded(
                    child: Text(
                      typeLabel,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: color,
                      ),
                    ),
                  ),
                  
                  // Account count
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${widget.accounts.length} 个账户',
                      style: theme.textTheme.labelSmall,
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          // Account list
          if (_isExpanded) ...[
            // Header row
            _buildHeaderRow(context),
            
            // Account rows
            ...widget.accounts.map((account) => 
              _buildAccountWithChildren(account, depth: 0),
            ),
            
            // Subtotal row
            _buildSubtotalRow(context, totalDebit, totalCredit, color),
          ],
        ],
      ),
    );
  }

  Widget _buildHeaderRow(BuildContext context) {
    final theme = Theme.of(context);
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.5),
      ),
      child: Row(
        children: [
          const SizedBox(width: 24),
          Expanded(
            flex: 3,
            child: Text(
              '账户名称',
              style: theme.textTheme.labelMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              '借方',
              style: theme.textTheme.labelMedium?.copyWith(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.right,
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              '贷方',
              style: theme.textTheme.labelMedium?.copyWith(
                color: theme.colorScheme.secondary,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAccountWithChildren(AccountBalance account, {required int depth}) {
    final hasChildren = account.children != null && account.children!.isNotEmpty;
    final isExpanded = _expandedAccounts[account.accountId] ?? false;
    
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AccountBalanceRow(
          account: account,
          depth: depth,
          isExpanded: isExpanded,
          onToggleExpand: hasChildren
              ? () => setState(() {
                _expandedAccounts[account.accountId] = !isExpanded;
              })
              : null,
          onTapDrillDown: widget.onDrillDown != null
              ? () => widget.onDrillDown!(account.accountId, account.accountName)
              : null,
        ),
        if (hasChildren && isExpanded)
          ...account.children!.map((child) => 
            _buildAccountWithChildren(child, depth: depth + 1),
          ),
      ],
    );
  }

  Widget _buildSubtotalRow(
    BuildContext context,
    Decimal totalDebit,
    Decimal totalCredit,
    Color color,
  ) {
    final theme = Theme.of(context);
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.05),
        border: Border(
          top: BorderSide(
            color: color.withOpacity(0.2),
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          const SizedBox(width: 24),
          Expanded(
            flex: 3,
            child: Text(
              '小计',
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              totalDebit != Decimal.zero ? '¥${_formatDecimal(totalDebit)}' : '-',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.right,
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              totalCredit != Decimal.zero ? '¥${_formatDecimal(totalCredit)}' : '-',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.secondary,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }

  (Decimal, Decimal) _calculateSubtotals() {
    Decimal totalDebit = Decimal.zero;
    Decimal totalCredit = Decimal.zero;
    
    void addAccountTotals(AccountBalance account) {
      totalDebit += account.debitDecimal;
      totalCredit += account.creditDecimal;
      
      if (account.children != null) {
        for (final child in account.children!) {
          addAccountTotals(child);
        }
      }
    }
    
    for (final account in widget.accounts) {
      addAccountTotals(account);
    }
    
    return (totalDebit, totalCredit);
  }

  Color _getTypeColor(ThemeData theme) {
    switch (widget.accountType) {
      case AccountType.asset:
        return Colors.green;
      case AccountType.liability:
        return Colors.red;
      case AccountType.equity:
        return Colors.purple;
      case AccountType.income:
        return Colors.blue;
      case AccountType.expense:
        return Colors.orange;
      case AccountType.investment:
        return Colors.teal;
    }
  }

  IconData _getTypeIcon() {
    switch (widget.accountType) {
      case AccountType.asset:
        return Icons.account_balance_wallet;
      case AccountType.liability:
        return Icons.credit_card;
      case AccountType.equity:
        return Icons.pie_chart;
      case AccountType.income:
        return Icons.trending_up;
      case AccountType.expense:
        return Icons.shopping_cart;
      case AccountType.investment:
        return Icons.show_chart;
    }
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
