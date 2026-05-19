import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../database/database.dart';
import '../../data/account_provider.dart';
import '../widgets/account_card.dart';
import '../widgets/add_account_dialog.dart';

class AccountsPage extends ConsumerWidget {
  const AccountsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accountsAsync = ref.watch(accountsProvider);

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
          return _buildAccountList(context, ref, accounts);
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

  Widget _buildAccountList(BuildContext context, WidgetRef ref, List<Account> accounts) {
    final assetAccounts = accounts.where((a) => a.accountType == 'ASSET').toList();
    final liabilityAccounts = accounts.where((a) => a.accountType == 'LIABILITY').toList();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (assetAccounts.isNotEmpty) ...[
          _buildSectionHeader(context, '资产账户', Icons.trending_up, Colors.green),
          ...assetAccounts.map((account) => AccountCard(
                account: account,
                onTap: () => _showEditDialog(context, account),
                onDelete: () => _deleteAccount(context, ref, account),
              )),
          const SizedBox(height: 24),
        ],
        if (liabilityAccounts.isNotEmpty) ...[
          _buildSectionHeader(context, '负债账户', Icons.trending_down, Colors.red),
          ...liabilityAccounts.map((account) => AccountCard(
                account: account,
                onTap: () => _showEditDialog(context, account),
                onDelete: () => _deleteAccount(context, ref, account),
              )),
          const SizedBox(height: 24),
        ],
      ],
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title, IconData icon, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 8),
          Text(
            title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
          ),
        ],
      ),
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