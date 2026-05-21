import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:database/database.dart';
import '../../data/account_provider.dart';

/// Account tree card widget with expandable groups and drag-and-drop support.
class AccountTreeCard extends ConsumerStatefulWidget {
  final AccountTreeNode node;
  final int depth;
  final VoidCallback onTap;
  final VoidCallback onDelete;
  final VoidCallback? onAddChild;
  final bool isExpanded;
  final ValueChanged<bool>? onExpansionChanged;
  final String? parentId;
  final bool enableReordering;

  const AccountTreeCard({
    super.key,
    required this.node,
    this.depth = 0,
    required this.onTap,
    required this.onDelete,
    this.onAddChild,
    this.isExpanded = false,
    this.onExpansionChanged,
    this.parentId,
    this.enableReordering = true,
  });

  @override
  ConsumerState<AccountTreeCard> createState() => _AccountTreeCardState();
}

class _AccountTreeCardState extends ConsumerState<AccountTreeCard> {
  bool _isDragging = false;
  bool _isDropTarget = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = _getTypeColor(widget.node.account.accountType);
    final indent = widget.depth * 24.0;

    if (widget.node.isGroup) {
      // Group account - use ExpansionTile with reorderable children
      return Padding(
        padding: EdgeInsets.only(left: indent),
        child: Card(
          margin: const EdgeInsets.only(bottom: 4),
          child: ExpansionTile(
            key: PageStorageKey(widget.node.account.id),
            initiallyExpanded: widget.isExpanded,
            onExpansionChanged: widget.onExpansionChanged,
            leading: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                _getGroupIcon(widget.node.account.name),
                color: color,
                size: 20,
              ),
            ),
            title: Row(
              children: [
                Expanded(
                  child: Text(
                    widget.node.account.name,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                if (widget.node.account.code != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      widget.node.account.code!,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: color,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
              ],
            ),
            subtitle: Text(
              '小计: ¥${widget.node.subtotal.toStringAsFixed(2)}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (widget.onAddChild != null)
                  IconButton(
                    icon: const Icon(Icons.add, size: 20),
                    onPressed: widget.onAddChild,
                    tooltip: '添加子账户',
                  ),
                IconButton(
                  icon: const Icon(Icons.edit_outlined, size: 20),
                  onPressed: widget.onTap,
                  tooltip: '编辑',
                ),
                // Drag handle for group accounts
                if (widget.enableReordering)
                  ReorderableDragStartListener(
                    index: widget.node.account.sortOrder,
                    child: Icon(
                      Icons.drag_indicator,
                      size: 20,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
            children: [
              // ReorderableListView for children within this group
              if (widget.node.children.isNotEmpty && widget.enableReordering)
                _buildReorderableChildren()
              else
                ...widget.node.children.map((child) => AccountTreeCard(
                  node: child,
                  depth: widget.depth + 1,
                  onTap: widget.onTap,
                  onDelete: widget.onDelete,
                  onAddChild: widget.onAddChild,
                  parentId: widget.node.account.id,
                  enableReordering: widget.enableReordering,
                )),
            ],
          ),
        ),
      );
    }

    // Leaf account - simple card with drag handle
    return Padding(
      padding: EdgeInsets.only(left: indent),
      child: Card(
        margin: const EdgeInsets.only(bottom: 4),
        elevation: _isDropTarget ? 4 : 1,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: _isDropTarget 
              ? BorderSide(color: theme.colorScheme.primary, width: 2)
              : BorderSide.none,
        ),
        child: InkWell(
          onTap: widget.onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                // Drag handle
                if (widget.enableReordering)
                  ReorderableDragStartListener(
                    index: widget.node.account.sortOrder,
                    child: Icon(
                      Icons.drag_indicator,
                      size: 20,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                if (widget.enableReordering)
                  const SizedBox(width: 8),
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    _getAccountIcon(widget.node.account.name),
                    color: color,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
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
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                              decoration: BoxDecoration(
                                color: color.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(3),
                              ),
                              child: Text(
                                widget.node.account.code!,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: color,
                                  fontWeight: FontWeight.w500,
                                  fontSize: 10,
                                ),
                              ),
                            ),
                        ],
                      ),
                      if (widget.node.account.description != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          widget.node.account.description!,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
                Text(
                  '¥${widget.node.subtotal.toStringAsFixed(2)}',
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: color,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline, size: 20),
                  onPressed: widget.onDelete,
                  color: theme.colorScheme.error,
                  tooltip: '删除',
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Builds a reorderable list of children within a group.
  Widget _buildReorderableChildren() {
    return ReorderableListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      buildDefaultDragHandles: false,
      itemCount: widget.node.children.length,
      onReorder: (oldIndex, newIndex) {
        _handleReorder(oldIndex, newIndex);
      },
      itemBuilder: (context, index) {
        final child = widget.node.children[index];
        return AccountTreeCard(
          key: ValueKey(child.account.id),
          node: child,
          depth: widget.depth + 1,
          onTap: widget.onTap,
          onDelete: widget.onDelete,
          onAddChild: widget.onAddChild,
          parentId: widget.node.account.id,
          enableReordering: widget.enableReordering,
        );
      },
      proxyDecorator: (widget, index, animation) {
        return AnimatedBuilder(
          animation: animation,
          builder: (context, child) {
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
          child: widget,
        );
      },
    );
  }

  /// Handles reorder of children within a group.
  void _handleReorder(int oldIndex, int newIndex) {
    // Adjust newIndex if moving down (Flutter's quirk)
    if (oldIndex < newIndex) {
      newIndex -= 1;
    }

    final children = List<AccountTreeNode>.from(widget.node.children);
    final movedChild = children.removeAt(oldIndex);
    children.insert(newIndex, movedChild);

    // Get the new order of account IDs
    final newOrder = children.map((c) => c.account.id).toList();

    // Call reorderAccounts on the notifier
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
    if (lower.contains('银行') || lower.contains('bank')) return Icons.account_balance;
    if (lower.contains('现金') || lower.contains('cash')) return Icons.money;
    if (lower.contains('投资') || lower.contains('invest')) return Icons.trending_up;
    if (lower.contains('信用卡') || lower.contains('credit')) return Icons.credit_card;
    if (lower.contains('贷款') || lower.contains('loan')) return Icons.home;
    if (lower.contains('工资') || lower.contains('salary')) return Icons.work;
    if (lower.contains('日常') || lower.contains('daily')) return Icons.shopping_bag;
    if (lower.contains('交通') || lower.contains('transport')) return Icons.directions_car;
    if (lower.contains('娱乐') || lower.contains('entertainment')) return Icons.movie;
    if (lower.contains('医疗') || lower.contains('health')) return Icons.local_hospital;
    return Icons.folder;
  }

  IconData _getAccountIcon(String name) {
    final lower = name.toLowerCase();
    if (lower.contains('支付宝') || lower.contains('alipay')) return Icons.payment;
    if (lower.contains('微信') || lower.contains('wechat')) return Icons.chat;
    if (lower.contains('工商') || lower.contains('icbc')) return Icons.account_balance;
    if (lower.contains('建设') || lower.contains('ccb')) return Icons.account_balance;
    if (lower.contains('中国银行') || lower.contains('boc')) return Icons.account_balance;
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