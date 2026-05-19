import 'package:flutter/material.dart';

import 'package:database/database.dart';

class AccountCard extends StatelessWidget {
  final Account account;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const AccountCard({
    super.key,
    required this.account,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final isAsset = account.accountType == 'ASSET';
    final color = isAsset ? Colors.green : Colors.red;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  _getAccountIcon(account.name),
                  color: color,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      account.name,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                    if (account.description != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        account.description!,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                            ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline),
                onPressed: onDelete,
                color: Theme.of(context).colorScheme.error,
              ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _getAccountIcon(String name) {
    final lowerName = name.toLowerCase();
    if (lowerName.contains('银行') || lowerName.contains('bank')) {
      return Icons.account_balance;
    }
    if (lowerName.contains('支付宝') || lowerName.contains('alipay')) {
      return Icons.payment;
    }
    if (lowerName.contains('微信') || lowerName.contains('wechat')) {
      return Icons.chat;
    }
    if (lowerName.contains('现金') || lowerName.contains('cash')) {
      return Icons.money;
    }
    if (lowerName.contains('信用卡') || lowerName.contains('credit')) {
      return Icons.credit_card;
    }
    return Icons.account_balance_wallet;
  }
}