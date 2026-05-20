import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:database/database.dart';
import '../../data/account_provider.dart';
import '../widgets/account_tree_card.dart';
import '../widgets/add_account_dialog.dart';

class AccountsPage extends ConsumerWidget {
  const AccountsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accountsAsync = ref.watch(accountsProvider);
    final hierarchy = ref.watch(accountHierarchyProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('账户管理'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _showAddDialog(context),
          ),
        ],
      ),
      body: accountsAsync.when(
        data: (accounts) {
          if (accounts.isEmpty) {
            return _buildEmptyState(context);
          }
          return _buildAccountTree(context, ref, hierarchy);
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('错误: $error')),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddDialog(context),
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.account_balance_wallet_outlined,
            size: 64,
            color: Theme.of(context).colorScheme.outline,
          ),
          const SizedBox(height: 16),
          Text(
            '暂无账户',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: Theme.of(context).colorScheme.outline,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            '点击右下角按钮添加账户',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.outline,
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildAccountTree(BuildContext context, WidgetRef ref, Map<String, List<AccountTreeNode>> hierarchy) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // ASSET section
        if (hierarchy['ASSET']?.isNotEmpty ?? false) ...[
          _buildTypeHeader(
            context, 
            '资产账户', 
            Icons.trending_up, 
            Colors.green,
            hierarchy['ASSET']!.fold(0.0, (sum, n) => sum + n.subtotal),
          ),
          ...hierarchy['ASSET']!.map((node) => AccountTreeCard(
            node: node,
            onTap: () => _showEditDialog(context, node.account),
            onDelete: () => _deleteAccount(context, ref, node.account),
            onAddChild: node.isGroup 
                ? () => _showAddChildDialog(context, node.account)
                : null,
          )),
          const SizedBox(height: 24),
        ],
        // LIABILITY section
        if (hierarchy['LIABILITY']?.isNotEmpty ?? false) ...[
          _buildTypeHeader(
            context, 
            '负债账户', 
            Icons.trending_down, 
            Colors.red,
            hierarchy['LIABILITY']!.fold(0.0, (sum, n) => sum + n.subtotal),
          ),
          ...hierarchy['LIABILITY']!.map((node) => AccountTreeCard(
            node: node,
            onTap: () => _showEditDialog(context, node.account),
            onDelete: () => _deleteAccount(context, ref, node.account),
            onAddChild: node.isGroup 
                ? () => _showAddChildDialog(context, node.account)
                : null,
          )),
          const SizedBox(height: 24),
        ],
        // INCOME section
        if (hierarchy['INCOME']?.isNotEmpty ?? false) ...[
          _buildTypeHeader(
            context, 
            '收入账户', 
            Icons.arrow_upward, 
            Colors.blue,
            hierarchy['INCOME']!.fold(0.0, (sum, n) => sum + n.subtotal),
          ),
          ...hierarchy['INCOME']!.map((node) => AccountTreeCard(
            node: node,
            onTap: () => _showEditDialog(context, node.account),
            onDelete: () => _deleteAccount(context, ref, node.account),
            onAddChild: node.isGroup 
                ? () => _showAddChildDialog(context, node.account)
                : null,
          )),
          const SizedBox(height: 24),
        ],
        // EXPENSE section
        if (hierarchy['EXPENSE']?.isNotEmpty ?? false) ...[
          _buildTypeHeader(
            context, 
            '支出账户', 
            Icons.arrow_downward, 
            Colors.orange,
            hierarchy['EXPENSE']!.fold(0.0, (sum, n) => sum + n.subtotal),
          ),
          ...hierarchy['EXPENSE']!.map((node) => AccountTreeCard(
            node: node,
            onTap: () => _showEditDialog(context, node.account),
            onDelete: () => _deleteAccount(context, ref, node.account),
            onAddChild: node.isGroup 
                ? () => _showAddChildDialog(context, node.account)
                : null,
          )),
        ],
      ],
    );
  }

  Widget _buildTypeHeader(
    BuildContext context, 
    String title, 
    IconData icon, 
    Color color,
    double total,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(width: 8),
          Text(
            title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const Spacer(),
          Text(
            '¥${total.toStringAsFixed(2)}',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  void _showAddChildDialog(BuildContext context, Account parent) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => AddAccountDialog(parentAccount: parent),
    );
  }

  void _showAddDialog(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => const AddAccountDialog(),
    );
  }

  void _showEditDialog(BuildContext context, Account account) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => AddAccountDialog(account: account),
    );
  }

  void _deleteAccount(BuildContext context, WidgetRef ref, Account account) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除账户'),
        content: Text('确定要删除账户 "${account.name}" 吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () {
              ref.read(accountNotifierProvider.notifier).deleteAccount(account.id);
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('账户已删除')),
              );
            },
            child: const Text('删除'),
          ),
        ],
      ),
    );
  }
}