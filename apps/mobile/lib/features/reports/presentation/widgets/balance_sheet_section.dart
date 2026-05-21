import 'package:flutter/material.dart';
import 'package:core/core.dart';
import 'package:decimal/decimal.dart';

/// Balance sheet section widget for balance sheet report.
///
/// Displays a major section (资产/负债/所有者权益) with:
/// - Section header with title and total
/// - Color-coded by type (green=assets, red=liabilities, purple=equity)
/// - List of items grouped by liquidity
/// - Expandable/collapsible functionality
/// - Subtotals for current/non-current items
class BalanceSheetSectionWidget extends StatefulWidget {
  final BalanceSheetSection section;
  final AccountType sectionType;
  final bool initiallyExpanded;

  const BalanceSheetSectionWidget({
    super.key,
    required this.section,
    required this.sectionType,
    this.initiallyExpanded = true,
  });

  @override
  State<BalanceSheetSectionWidget> createState() => _BalanceSheetSectionWidgetState();
}

class _BalanceSheetSectionWidgetState extends State<BalanceSheetSectionWidget> {
  late bool _isExpanded;
  final Map<int, bool> _expandedItems = {};

  @override
  void initState() {
    super.initState();
    _isExpanded = widget.initiallyExpanded;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = _getSectionColor(theme);
    final (currentItems, nonCurrentItems) = _groupByLiquidity();
    final currentTotal = _calculateSubtotal(currentItems);
    final nonCurrentTotal = _calculateSubtotal(nonCurrentItems);

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

                  // Section icon
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      _getSectionIcon(),
                      color: color,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),

                  // Section title
                  Expanded(
                    child: Text(
                      widget.section.title,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: color,
                      ),
                    ),
                  ),

                  // Total amount
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      '¥${_formatDecimal(widget.section.totalDecimal)}',
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: color,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Items list
          if (_isExpanded) ...[
            // Current items subsection
            if (currentItems.isNotEmpty) ...[
              _buildLiquidityHeader(
                context,
                label: '流动${widget.section.title}',
                total: currentTotal,
                color: color,
              ),
              ...currentItems.map((item) => _buildItemWithChildren(item, depth: 0)),
              _buildSubtotalRow(
                context,
                label: '流动${widget.section.title}小计',
                total: currentTotal,
                color: color,
              ),
            ],

            // Non-current items subsection
            if (nonCurrentItems.isNotEmpty) ...[
              _buildLiquidityHeader(
                context,
                label: '非流动${widget.section.title}',
                total: nonCurrentTotal,
                color: color,
              ),
              ...nonCurrentItems.map((item) => _buildItemWithChildren(item, depth: 0)),
              _buildSubtotalRow(
                context,
                label: '非流动${widget.section.title}小计',
                total: nonCurrentTotal,
                color: color,
              ),
            ],

            // Total row
            _buildTotalRow(context, color),
          ],
        ],
      ),
    );
  }

  Widget _buildLiquidityHeader(
    BuildContext context, {
    required String label,
    required Decimal total,
    required Color color,
  }) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.3),
      ),
      child: Row(
        children: [
          Icon(
            Icons.category_outlined,
            size: 16,
            color: theme.colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              style: theme.textTheme.labelMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Text(
            '¥${_formatDecimal(total)}',
            style: theme.textTheme.labelMedium?.copyWith(
              color: color,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildItemWithChildren(BalanceSheetItem item, {required int depth}) {
    final hasChildren = item.children != null && item.children!.isNotEmpty;
    final isExpanded = _expandedItems[item.accountId] ?? false;
    final indent = depth * 20.0;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        InkWell(
          onTap: hasChildren
              ? () => setState(() {
                    _expandedItems[item.accountId] = !isExpanded;
                  })
              : null,
          child: Padding(
            padding: EdgeInsets.only(
              left: indent + 16,
              right: 16,
              top: 10,
              bottom: 10,
            ),
            child: Row(
              children: [
                // Expand/collapse icon
                if (hasChildren) ...[
                  Icon(
                    isExpanded ? Icons.expand_less : Icons.expand_more,
                    size: 18,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 4),
                ] else ...[
                  const SizedBox(width: 22),
                ],

                // Account name
                Expanded(
                  child: Text(
                    item.accountName,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: depth == 0 ? FontWeight.w500 : FontWeight.normal,
                          color: depth == 0
                              ? Theme.of(context).colorScheme.onSurface
                              : Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),

                // Balance amount
                Text(
                  '¥${_formatDecimal(item.toDecimal)}',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: _getSectionColor(Theme.of(context)),
                        fontWeight: FontWeight.w500,
                      ),
                ),
              ],
            ),
          ),
        ),
        if (hasChildren && isExpanded)
          ...item.children!.map((child) => _buildItemWithChildren(child, depth: depth + 1)),
      ],
    );
  }

  Widget _buildSubtotalRow(
    BuildContext context, {
    required String label,
    required Decimal total,
    required Color color,
  }) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.03),
        border: Border(
          top: BorderSide(
            color: color.withOpacity(0.15),
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          const SizedBox(width: 22),
          Expanded(
            child: Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w500,
                color: color,
              ),
            ),
          ),
          Text(
            '¥${_formatDecimal(total)}',
            style: theme.textTheme.bodySmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTotalRow(BuildContext context, Color color) {
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
      child: Row(
        children: [
          Icon(
            Icons.calculate,
            size: 18,
            color: color,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '${widget.section.title}总计',
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ),
          Text(
            '¥${_formatDecimal(widget.section.totalDecimal)}',
            style: theme.textTheme.titleMedium?.copyWith(
              color: color,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  (List<BalanceSheetItem>, List<BalanceSheetItem>) _groupByLiquidity() {
    final currentItems = <BalanceSheetItem>[];
    final nonCurrentItems = <BalanceSheetItem>[];

    for (final item in widget.section.items) {
      if (item.isCurrent) {
        currentItems.add(item);
      } else {
        nonCurrentItems.add(item);
      }
    }

    return (currentItems, nonCurrentItems);
  }

  Decimal _calculateSubtotal(List<BalanceSheetItem> items) {
    Decimal total = Decimal.zero;

    void addItemTotal(BalanceSheetItem item) {
      total += item.toDecimal;
      if (item.children != null) {
        for (final child in item.children!) {
          addItemTotal(child);
        }
      }
    }

    for (final item in items) {
      addItemTotal(item);
    }

    return total;
  }

  Color _getSectionColor(ThemeData theme) {
    switch (widget.sectionType) {
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
    }
  }

  IconData _getSectionIcon() {
    switch (widget.sectionType) {
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
