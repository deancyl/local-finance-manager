import 'package:flutter/material.dart';
import 'package:database/database.dart';
import '../../data/account_provider.dart';

/// Account tree card widget with expandable groups.
class AccountTreeCard extends StatelessWidget {
  final AccountTreeNode node;
  final int depth;
  final VoidCallback onTap;
  final VoidCallback onDelete;
  final VoidCallback? onAddChild;
  final bool isExpanded;
  final ValueChanged<bool>? onExpansionChanged;

  const AccountTreeCard({
    super.key,
    required this.node,
    this.depth = 0,
    required this.onTap,
    required this.onDelete,
    this.onAddChild,
    this.isExpanded = false,
    this.onExpansionChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = _getTypeColor(node.account.accountType);
    final indent = depth * 24.0;

    if (node.isGroup) {
      // Group account - use ExpansionTile
      return Padding(
        padding: EdgeInsets.only(left: indent),
        child: Card(
          margin: const EdgeInsets.only(bottom: 4),
          child: ExpansionTile(
            key: PageStorageKey(node.account.id),
            initiallyExpanded: isExpanded,
            onExpansionChanged: onExpansionChanged,
            leading: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                _getGroupIcon(node.account.name),
                color: color,
                size: 20,
              ),
            ),
            title: Text(
              node.account.name,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            subtitle: Text(
              '小计: ¥${node.subtotal.toStringAsFixed(2)}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (onAddChild != null)
                  IconButton(
                    icon: const Icon(Icons.add, size: 20),
                    onPressed: onAddChild,
                    tooltip: '添加子账户',
                  ),
                IconButton(
                  icon: const Icon(Icons.edit_outlined, size: 20),
                  onPressed: onTap,
                  tooltip: '编辑',
                ),
              ],
            ),
            children: node.children.map((child) => AccountTreeCard(
              node: child,
              depth: depth + 1,
              onTap: onTap,
              onDelete: onDelete,
              onAddChild: onAddChild,
            )).toList(),
          ),
        ),
      );
    }

    // Leaf account - simple card
    return Padding(
      padding: EdgeInsets.only(left: indent),
      child: Card(
        margin: const EdgeInsets.only(bottom: 4),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    _getAccountIcon(node.account.name),
                    color: color,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        node.account.name,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (node.account.description != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          node.account.description!,
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
                  '¥${node.subtotal.toStringAsFixed(2)}',
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: color,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline, size: 20),
                  onPressed: onDelete,
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
