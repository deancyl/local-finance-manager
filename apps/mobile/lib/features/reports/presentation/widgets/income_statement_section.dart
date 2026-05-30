import 'package:flutter/material.dart';
import 'package:core/core.dart';
import 'package:decimal/decimal.dart';

/// Income statement section widget for income statement report.
///
/// Displays a major section (收入/费用) with:
/// - Section header with title and total
/// - Color-coded by type (green=revenues, red=expenses)
/// - List of items with hierarchical support
/// - Expandable/collapsible functionality
/// - Subtotal display
class IncomeStatementSectionWidget extends StatefulWidget {
  final IncomeStatementSection section;
  final bool isRevenue;
  final bool initiallyExpanded;
  final DateTime? startDate;
  final DateTime? endDate;
  final void Function(String accountId, String accountName)? onDrillDown;

  const IncomeStatementSectionWidget({
    super.key,
    required this.section,
    required this.isRevenue,
    this.initiallyExpanded = true,
    this.startDate,
    this.endDate,
    this.onDrillDown,
  });

  @override
  State<IncomeStatementSectionWidget> createState() =>
      _IncomeStatementSectionWidgetState();
}

class _IncomeStatementSectionWidgetState
    extends State<IncomeStatementSectionWidget> {
  late bool _isExpanded;
  final Map<String, bool> _expandedItems = {};

  @override
  void initState() {
    super.initState();
    _isExpanded = widget.initiallyExpanded;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = _getSectionColor(theme);

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
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(12)),
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
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
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
            // Header row
            _buildHeaderRow(context),

            // Item rows
            ...widget.section.items
                .map((item) => _buildItemWithChildren(item, depth: 0)),

            // Total row
            _buildTotalRow(context, color),
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

  Widget _buildItemWithChildren(IncomeStatementItem item,
      {required int depth}) {
    final hasChildren = item.children != null && item.children!.isNotEmpty;
    final isExpanded = _expandedItems[item.accountId] ?? false;
    final indent = depth * 20.0;
    final theme = Theme.of(context);
    final color = _getSectionColor(theme);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        InkWell(
          onTap: hasChildren
              ? () => setState(() {
                    _expandedItems[item.accountId] = !isExpanded;
                  })
              : widget.onDrillDown != null
                  ? () => widget.onDrillDown!(item.accountId, item.accountName)
                  : null,
          onLongPress: hasChildren && widget.onDrillDown != null
              ? () => widget.onDrillDown!(item.accountId, item.accountName)
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
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 4),
                ] else if (widget.onDrillDown != null) ...[
                  Icon(
                    Icons.arrow_forward_ios,
                    size: 14,
                    color: color.withOpacity(0.5),
                  ),
                  const SizedBox(width: 8),
                ] else ...[
                  const SizedBox(width: 22),
                ],

                // Account name
                Expanded(
                  flex: 3,
                  child: Text(
                    item.accountName,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight:
                          depth == 0 ? FontWeight.w500 : FontWeight.normal,
                      color: depth == 0
                          ? theme.colorScheme.onSurface
                          : theme.colorScheme.onSurfaceVariant,
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
                      color: color,
                      fontWeight: FontWeight.w500,
                    ),
                    textAlign: TextAlign.right,
                  ),
                ),
              ],
            ),
          ),
        ),
        if (hasChildren && isExpanded)
          ...item.children!
              .map((child) => _buildItemWithChildren(child, depth: depth + 1)),
      ],
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
            flex: 3,
            child: Text(
              '${widget.section.title}合计',
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              '¥${_formatDecimal(widget.section.totalDecimal)}',
              style: theme.textTheme.titleMedium?.copyWith(
                color: color,
                fontWeight: FontWeight.w700,
              ),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }

  Color _getSectionColor(ThemeData theme) {
    // Green for revenues (收入), Red for expenses (费用)
    return widget.isRevenue ? Colors.green : Colors.red;
  }

  IconData _getSectionIcon() {
    // Trending up for revenues, Trending down for expenses
    return widget.isRevenue ? Icons.trending_up : Icons.trending_down;
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
