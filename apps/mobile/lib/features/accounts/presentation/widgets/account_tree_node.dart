import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:database/database.dart';
import '../../data/account_provider.dart';
import 'package:drift/drift.dart' as drift;

/// A tree node widget for displaying accounts in a hierarchical structure.
/// 
/// Features:
/// - Collapsible expand/collapse for groups
/// - Drag handle for reordering
/// - Account type icons with color coding
/// - Balance display with roll-up for groups
/// - Context actions (edit, delete, move, add child)
class AccountTreeNodeWidget extends ConsumerStatefulWidget {
  final AccountTreeNode node;
  final int depth;
  final bool isExpanded;
  final ValueChanged<bool>? onExpansionChanged;
  final VoidCallback onTap;
  final VoidCallback onDelete;
  final VoidCallback? onMove;
  final VoidCallback? onAddChild;
  final bool enableDrag;

  const AccountTreeNodeWidget({
    super.key,
    required this.node,
    this.depth = 0,
    this.isExpanded = false,
    this.onExpansionChanged,
    required this.onTap,
    required this.onDelete,
    this.onMove,
    this.onAddChild,
    this.enableDrag = true,
  });

  @override
  ConsumerState<AccountTreeNodeWidget> createState() => _AccountTreeNodeWidgetState();
}

class _AccountTreeNodeWidgetState extends ConsumerState<AccountTreeNodeWidget> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = _getTypeColor(widget.node.account.accountType);
    final indent = widget.depth * 20.0;

    // Group account (has children or is placeholder)
    if (widget.node.isGroup) {
      return Padding(
        padding: EdgeInsets.only(left: indent),
        child: _buildGroupNode(context, theme, color),
      );
    }

    // Leaf account
    return Padding(
      padding: EdgeInsets.only(left: indent),
      child: _buildLeafNode(context, theme, color),
    );
  }

  Widget _buildGroupNode(BuildContext context, ThemeData theme, Color color) {
    return Card(
      margin: const EdgeInsets.only(bottom: 4),
      elevation: _isHovered ? 4 : 1,
      child: MouseRegion(
        onEnter: (_) => setState(() => _isHovered = true),
        onExit: (_) => setState(() => _isHovered = false),
        child: ExpansionTile(
          key: PageStorageKey(widget.node.account.id),
          initiallyExpanded: widget.isExpanded,
          onExpansionChanged: widget.onExpansionChanged,
          leading: _buildTypeIcon(color, isGroup: true),
          title: _buildGroupTitle(theme, color),
          subtitle: _buildGroupSubtitle(theme),
          trailing: _buildGroupTrailingActions(theme),
          children: [
            // Render children with reorderable list
            if (widget.node.children.isNotEmpty)
              _buildReorderableChildren()
            else
              _buildEmptyChildrenHint(theme),
          ],
        ),
      ),
    );
  }

  Widget _buildLeafNode(BuildContext context, ThemeData theme, Color color) {
    return Card(
      margin: const EdgeInsets.only(bottom: 4),
      elevation: _isHovered ? 4 : 1,
      child: MouseRegion(
        onEnter: (_) => setState(() => _isHovered = true),
        onExit: (_) => setState(() => _isHovered = false),
        child: InkWell(
          onTap: widget.onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [
                // Drag handle
                if (widget.enableDrag) _buildDragHandle(theme),
                if (widget.enableDrag) const SizedBox(width: 8),
                // Type icon
                _buildTypeIcon(color, isGroup: false),
                const SizedBox(width: 12),
                // Account info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              widget.node.account.name,
                              style: theme.textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          if (widget.node.account.code != null)
                            _buildCodeBadge(color),
                        ],
                      ),
                      if (widget.node.account.description != null)
                        Text(
                          widget.node.account.description!,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                // Balance
                Text(
                  '¥${widget.node.subtotal.toStringAsFixed(2)}',
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: color,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                // Action buttons
                const SizedBox(width: 4),
                _buildLeafActions(theme),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTypeIcon(Color color, {required bool isGroup}) {
    final icon = isGroup
        ? _getGroupIcon(widget.node.account.name)
        : _getAccountIcon(widget.node.account.name);

    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(icon, color: color, size: 20),
    );
  }

  Widget _buildDragHandle(ThemeData theme) {
    return ReorderableDragStartListener(
      index: widget.node.account.sortOrder,
      child: MouseRegion(
        cursor: SystemMouseCursors.grab,
        child: Icon(
          Icons.drag_indicator,
          size: 20,
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }

  Widget _buildCodeBadge(Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      margin: const EdgeInsets.only(left: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        widget.node.account.code!,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _buildGroupTitle(ThemeData theme, Color color) {
    return Row(
      children: [
        Expanded(
          child: Text(
            widget.node.account.name,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        if (widget.node.account.code != null) _buildCodeBadge(color),
      ],
    );
  }

  Widget _buildGroupSubtitle(ThemeData theme) {
    final childCount = widget.node.children.length;
    return Row(
      children: [
        Text(
          '小计: ¥${widget.node.subtotal.toStringAsFixed(2)}',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(width: 8),
        Text(
          '($childCount 个子账户)',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  Widget _buildGroupTrailingActions(ThemeData theme) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (widget.onAddChild != null)
          IconButton(
            icon: const Icon(Icons.add, size: 20),
            onPressed: widget.onAddChild,
            tooltip: '添加子账户',
            visualDensity: VisualDensity.compact,
          ),
        IconButton(
          icon: const Icon(Icons.edit_outlined, size: 20),
          onPressed: widget.onTap,
          tooltip: '编辑',
          visualDensity: VisualDensity.compact,
        ),
        if (widget.onMove != null)
          IconButton(
            icon: const Icon(Icons.drive_file_move_outline, size: 20),
            onPressed: widget.onMove,
            tooltip: '移动',
            visualDensity: VisualDensity.compact,
          ),
        if (widget.enableDrag)
          ReorderableDragStartListener(
            index: widget.node.account.sortOrder,
            child: MouseRegion(
              cursor: SystemMouseCursors.grab,
              child: Icon(
                Icons.drag_indicator,
                size: 20,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildLeafActions(ThemeData theme) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (widget.onMove != null)
          IconButton(
            icon: const Icon(Icons.drive_file_move_outline, size: 18),
            onPressed: widget.onMove,
            tooltip: '移动',
            visualDensity: VisualDensity.compact,
          ),
        IconButton(
          icon: Icon(
            Icons.delete_outline,
            size: 18,
            color: theme.colorScheme.error,
          ),
          onPressed: widget.onDelete,
          tooltip: '删除',
          visualDensity: VisualDensity.compact,
        ),
      ],
    );
  }

  Widget _buildReorderableChildren() {
    return ReorderableListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      buildDefaultDragHandles: false,
      itemCount: widget.node.children.length,
      onReorder: _handleChildReorder,
      itemBuilder: (context, index) {
        final child = widget.node.children[index];
        return AccountTreeNodeWidget(
          key: ValueKey(child.account.id),
          node: child,
          depth: widget.depth + 1,
          onTap: widget.onTap,
          onDelete: widget.onDelete,
          onMove: widget.onMove,
          onAddChild: widget.onAddChild,
          enableDrag: widget.enableDrag,
        );
      },
      proxyDecorator: (child, index, animation) {
        return AnimatedBuilder(
          animation: animation,
          builder: (context, widget) {
            final animValue = Curves.easeInOut.transform(animation.value);
            final elevation = 1 + animValue * 8;
            final scale = 1 + animValue * 0.05;
            return Transform.scale(
              scale: scale,
              child: Material(
                elevation: elevation,
                borderRadius: BorderRadius.circular(12),
                child: widget,
              ),
            );
          },
          child: child,
        );
      },
    );
  }

  Widget _buildEmptyChildrenHint(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Center(
        child: Text(
          '暂无子账户',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }

  void _handleChildReorder(int oldIndex, int newIndex) {
    // Adjust for Flutter's quirk
    if (oldIndex < newIndex) {
      newIndex -= 1;
    }

    // Create new order
    final children = List<AccountTreeNode>.from(widget.node.children);
    final movedChild = children.removeAt(oldIndex);
    children.insert(newIndex, movedChild);

    // Get account IDs in new order
    final newOrder = children.map((c) => c.account.id).toList();

    // Persist the reorder
    ref.read(accountNotifierProvider.notifier).reorderAccounts(
      accountIds: newOrder,
      parentId: widget.node.account.id,
    );
  }

  Color _getTypeColor(String accountType) {
    switch (accountType) {
      case 'ASSET':
        return Colors.green;
      case 'LIABILITY':
        return Colors.red;
      case 'INCOME':
        return Colors.blue;
      case 'EXPENSE':
        return Colors.orange;
      case 'EQUITY':
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }

  IconData _getGroupIcon(String name) {
    final lower = name.toLowerCase();
    if (lower.contains('银行') || lower.contains('bank')) {
      return Icons.account_balance;
    }
    if (lower.contains('现金') || lower.contains('cash')) {
      return Icons.money;
    }
    if (lower.contains('投资') || lower.contains('invest')) {
      return Icons.trending_up;
    }
    if (lower.contains('信用卡') || lower.contains('credit')) {
      return Icons.credit_card;
    }
    if (lower.contains('贷款') || lower.contains('loan')) {
      return Icons.home;
    }
    if (lower.contains('工资') || lower.contains('salary')) {
      return Icons.work;
    }
    if (lower.contains('日常') || lower.contains('daily')) {
      return Icons.shopping_bag;
    }
    if (lower.contains('交通') || lower.contains('transport')) {
      return Icons.directions_car;
    }
    if (lower.contains('娱乐') || lower.contains('entertainment')) {
      return Icons.movie;
    }
    if (lower.contains('医疗') || lower.contains('health')) {
      return Icons.local_hospital;
    }
    if (lower.contains('餐饮') || lower.contains('food')) {
      return Icons.restaurant;
    }
    if (lower.contains('教育') || lower.contains('education')) {
      return Icons.school;
    }
    return Icons.folder;
  }

  IconData _getAccountIcon(String name) {
    final lower = name.toLowerCase();
    if (lower.contains('支付宝') || lower.contains('alipay')) {
      return Icons.payment;
    }
    if (lower.contains('微信') || lower.contains('wechat')) {
      return Icons.chat;
    }
    if (lower.contains('工商') || lower.contains('icbc')) {
      return Icons.account_balance;
    }
    if (lower.contains('建设') || lower.contains('ccb')) {
      return Icons.account_balance;
    }
    if (lower.contains('中国银行') || lower.contains('boc')) {
      return Icons.account_balance;
    }
    if (lower.contains('招商') || lower.contains('cmb')) {
      return Icons.account_balance;
    }
    if (lower.contains('农业') || lower.contains('abc')) {
      return Icons.account_balance;
    }
    if (lower.contains('储蓄') || lower.contains('savings')) {
      return Icons.savings;
    }
    if (lower.contains('理财') || lower.contains('fund')) {
      return Icons.analytics;
    }
    return Icons.account_balance_wallet;
  }
}

/// AnimatedBuilder helper for proxy decorator
class AnimatedBuilder extends AnimatedWidget {
  final Widget child;
  final Widget Function(BuildContext context, Widget? child) builder;

  const AnimatedBuilder({
    super.key,
    required Animation<double> animation,
    required this.builder,
    required this.child,
  }) : super(listenable: animation);

  @override
  Widget build(BuildContext context) {
    return builder(context, child);
  }
}
